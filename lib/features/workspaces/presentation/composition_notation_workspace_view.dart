import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/channels/domain/studio_patchbay_routing_service.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../tuner_viewmodel.dart';
import 'polyphonic_synth_modal.dart';
import '../../sheet_music/presentation/real_sheet_music_painter.dart';
import '../../song_library/presentation/song_decomposer_modal.dart';
import '../../score_editor/presentation/score_editor_modal.dart';
import '../../metronome/presentation/tap_tempo_modal.dart';
import '../../audio_synthesizer/presentation/audio_midi_export_modal.dart';
import '../../song_library/domain/song_package_entity.dart';

enum ScoreCanvasEditMode {
  write,
  select,
  erase,
}

enum ScoreWorkflowTaskMode {
  all,      // Vista completa por defecto (retrocompatible con todos los tests existentes)
  write,    // Modo Steinberg Dorico 'Write': foco en edición de notas y pentagrama
  mixStems, // Modo Dorico/Moises 'Play & Mix': foco en barra 4-Stems, Minus-One y Síntesis
  practice, // Modo 'Practice & Loop': foco en pentagrama limpio, Bucle A-B y transcripción en vivo
}

/// Vista especializada para el Modo 2: Composición & Partituras.
/// Soporta edición directa en el lienzo SMuFL (clic y arrastre vertical para colocar/mover notas,
/// clic derecho o modo borrador para eliminar, barra de figuras, alteraciones y gestión multi-compás).
class CompositionNotationWorkspaceView extends StatefulWidget {
  final TunerViewModel viewModel;
  final TunnerThemePalette palette;
  final VoidCallback onOpenLibraryModal;
  final VoidCallback onOpenMixerModal;

  const CompositionNotationWorkspaceView({
    super.key,
    required this.viewModel,
    required this.palette,
    required this.onOpenLibraryModal,
    required this.onOpenMixerModal,
  });

  @override
  State<CompositionNotationWorkspaceView> createState() =>
      _CompositionNotationWorkspaceViewState();
}

class _CompositionNotationWorkspaceViewState
    extends State<CompositionNotationWorkspaceView> {
  ScoreWorkflowTaskMode _workflowTaskMode = ScoreWorkflowTaskMode.all;
  ScoreCanvasEditMode _editMode = ScoreCanvasEditMode.write;
  int _selectedDurationTicks = 4; // Negra por defecto
  String _selectedAccidental = ''; // '', '#', 'b'
  bool _isRestMode = false;
  int? _draggingTick;
  String? _lastDraggedNoteName;
  int? _hoverGhostTick;
  String? _hoverGhostNoteName;
  int _loopMeasureA = 1;
  int _loopMeasureB = 1;
  bool _isAbLoopActive = false;
  bool _isDoricoPopoverOpen = false;
  final TextEditingController _doricoPopoverController = TextEditingController();

  @override
  void dispose() {
    _doricoPopoverController.dispose();
    super.dispose();
  }

  TunerViewModel get viewModel => widget.viewModel;
  TunnerThemePalette get palette => widget.palette;

  void _setLoopPointA() {
    setState(() {
      _loopMeasureA = viewModel.currentMeasureIndex + 1;
      if (_loopMeasureB < _loopMeasureA) {
        _loopMeasureB = _loopMeasureA;
      }
      if (_isAbLoopActive) {
        viewModel.scorePlaybackCoordinator.setMeasureLoopRange(
          _loopMeasureA - 1,
          _loopMeasureB - 1,
        );
      }
    });
  }

  void _setLoopPointB() {
    setState(() {
      _loopMeasureB = viewModel.currentMeasureIndex + 1;
      if (_loopMeasureB < _loopMeasureA) {
        _loopMeasureA = _loopMeasureB;
      }
      _isAbLoopActive = true;
      viewModel.scorePlaybackCoordinator.setMeasureLoopRange(
        _loopMeasureA - 1,
        _loopMeasureB - 1,
      );
    });
  }

  void _clearAbLoop() {
    setState(() {
      _isAbLoopActive = false;
      viewModel.scorePlaybackCoordinator.clearMeasureLoop();
    });
  }

  void _sendActiveScoreToPatchbayChannelA(BuildContext context) {
    final title = viewModel.activePackage.title;
    final bpm = viewModel.bpm;
    StudioPatchbayRoutingService().publishChannelParameters(
      'canal_a',
      title: 'Partitura: $title',
      bpm: bpm.toDouble(),
      isPlaying: viewModel.isMetronomePlaying,
    );
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Partitura "$title" publicada en Canal A del Patchbay ($bpm BPM).',
          ),
        ),
      );
  }

  void _handleCanvasTapDown(
    TapDownDetails details,
    RealSheetMusicPainter painter,
    Size canvasSize,
  ) {
    final tappedIndex = painter.findNoteIndexAtOffset(
      details.localPosition,
      canvasSize,
    );

    if (_editMode == ScoreCanvasEditMode.erase) {
      if (tappedIndex != null &&
          tappedIndex >= 0 &&
          tappedIndex < viewModel.currentMeasureNotes.length) {
        final targetNote = viewModel.currentMeasureNotes[tappedIndex];
        viewModel.deleteScoreNote(
          measureIndex: viewModel.currentMeasureIndex,
          startTick: targetNote.startTick,
        );
      }
      return;
    }

    if (_editMode == ScoreCanvasEditMode.select) {
      if (tappedIndex != null) {
        viewModel.selectAndPreviewScoreNote(tappedIndex);
      } else {
        viewModel.clearSelectedScoreNote();
      }
      return;
    }

    // Modo Escritura Directa en el Lienzo (ScoreCanvasEditMode.write)
    if (details.localPosition.dx < 68.0) {
      if (tappedIndex != null) {
        viewModel.selectAndPreviewScoreNote(tappedIndex);
      }
      return;
    }

    final int targetTick;
    final int targetDuration;
    if (tappedIndex != null &&
        tappedIndex >= 0 &&
        tappedIndex < viewModel.currentMeasureNotes.length) {
      final existing = viewModel.currentMeasureNotes[tappedIndex];
      targetTick = existing.startTick;
      targetDuration = _selectedDurationTicks;
    } else {
      final quantize = math.min(_selectedDurationTicks, 4);
      targetTick = painter.resolveTickAtOffset(
        details.localPosition,
        canvasSize,
        quantizeTicks: quantize,
      );
      targetDuration = _selectedDurationTicks;
    }

    final String noteName = _isRestMode
        ? '--'
        : painter.resolveNoteNameAtOffset(
            details.localPosition,
            canvasSize,
            accidental: _selectedAccidental,
          );

    viewModel.insertOrUpdateScoreNote(
      measureIndex: viewModel.currentMeasureIndex,
      startTick: targetTick,
      durationTicks: targetDuration,
      noteName: noteName,
      playAudibleFeedback: true,
    );

    final updatedIdx = viewModel.currentMeasureNotes.indexWhere(
      (n) => n.startTick == targetTick,
    );
    if (updatedIdx >= 0) {
      viewModel.selectAndPreviewScoreNote(updatedIdx);
    }
  }

  void _handleCanvasSecondaryTapDown(
    TapDownDetails details,
    RealSheetMusicPainter painter,
    Size canvasSize,
  ) {
    final tappedIndex = painter.findNoteIndexAtOffset(
      details.localPosition,
      canvasSize,
    );
    if (tappedIndex != null &&
        tappedIndex >= 0 &&
        tappedIndex < viewModel.currentMeasureNotes.length) {
      final targetNote = viewModel.currentMeasureNotes[tappedIndex];
      viewModel.deleteScoreNote(
        measureIndex: viewModel.currentMeasureIndex,
        startTick: targetNote.startTick,
      );
    }
  }

  void _handleCanvasVerticalDragStart(
    DragStartDetails details,
    RealSheetMusicPainter painter,
    Size canvasSize,
  ) {
    final tappedIndex = painter.findNoteIndexAtOffset(
      details.localPosition,
      canvasSize,
    );
    if (tappedIndex != null &&
        tappedIndex >= 0 &&
        tappedIndex < viewModel.currentMeasureNotes.length) {
      final note = viewModel.currentMeasureNotes[tappedIndex];
      _draggingTick = note.startTick;
      _lastDraggedNoteName = note.noteName;
      viewModel.selectAndPreviewScoreNote(tappedIndex);
    } else if (_editMode == ScoreCanvasEditMode.write &&
        details.localPosition.dx >= 68.0) {
      final quantize = math.min(_selectedDurationTicks, 4);
      _draggingTick = painter.resolveTickAtOffset(
        details.localPosition,
        canvasSize,
        quantizeTicks: quantize,
      );
      _lastDraggedNoteName = null;
    }
  }

  void _handleCanvasVerticalDragUpdate(
    DragUpdateDetails details,
    RealSheetMusicPainter painter,
    Size canvasSize,
  ) {
    final tick = _draggingTick;
    if (tick == null) return;

    final newNoteName = painter.resolveNoteNameAtOffset(
      details.localPosition,
      canvasSize,
      accidental: _selectedAccidental,
    );
    if (newNoteName == _lastDraggedNoteName) return;
    _lastDraggedNoteName = newNoteName;

    final existingIdx = viewModel.currentMeasureNotes.indexWhere(
      (n) => n.startTick == tick,
    );
    final duration = existingIdx >= 0
        ? viewModel.currentMeasureNotes[existingIdx].durationTicks
        : _selectedDurationTicks;

    viewModel.insertOrUpdateScoreNote(
      measureIndex: viewModel.currentMeasureIndex,
      startTick: tick,
      durationTicks: duration,
      noteName: newNoteName,
      playAudibleFeedback: true,
    );
  }

  void _handleCanvasVerticalDragEnd(DragEndDetails _) {
    _draggingTick = null;
    _lastDraggedNoteName = null;
  }

  Widget _buildDirectCanvasEditToolbar(
    BuildContext context,
    StudioDesignTokens tokens,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.0),
      child: Container(
        key: const Key('direct_canvas_edit_toolbar'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          border: Border.all(color: tokens.borderHairline),
        ),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // 1. Modo de Herramienta (Escribir / Seleccionar / Borrar)
            _buildToolChip(
              key: const Key('score_tool_write_btn'),
              tokens: tokens,
              icon: Icons.edit,
              label: 'Escribir',
              isSelected: _editMode == ScoreCanvasEditMode.write,
              onTap: () => setState(() => _editMode = ScoreCanvasEditMode.write),
            ),
            _buildToolChip(
              key: const Key('score_tool_select_btn'),
              tokens: tokens,
              icon: Icons.touch_app_outlined,
              label: 'Seleccionar',
              isSelected: _editMode == ScoreCanvasEditMode.select,
              onTap: () => setState(() => _editMode = ScoreCanvasEditMode.select),
            ),
            _buildToolChip(
              key: const Key('score_tool_erase_btn'),
              tokens: tokens,
              icon: Icons.auto_fix_off,
              label: 'Borrador',
              isSelected: _editMode == ScoreCanvasEditMode.erase,
              activeColor: tokens.accentDanger,
              onTap: () => setState(() => _editMode = ScoreCanvasEditMode.erase),
            ),
            _buildToolbarDivider(tokens),

            // 2. Figuras Musicales (1/1, 1/2, 1/4, 1/8, 1/16, Silencio)
            _buildDurationChip(tokens, 16, '1/1 Redonda'),
            _buildDurationChip(tokens, 8, '1/2 Blanca'),
            _buildDurationChip(tokens, 4, '1/4 Negra'),
            _buildDurationChip(tokens, 2, '1/8 Corchea'),
            _buildDurationChip(tokens, 1, '1/16 Semic.'),
            _buildToolChip(
              key: const Key('score_tool_rest_toggle'),
              tokens: tokens,
              icon: Icons.pause_circle_outline,
              label: 'Silencio',
              isSelected: _isRestMode,
              onTap: () => setState(() {
                _isRestMode = !_isRestMode;
                _editMode = ScoreCanvasEditMode.write;
              }),
            ),
            _buildToolbarDivider(tokens),

            // 3. Alteraciones (Natural, Sostenido #, Bemol b)
            _buildAccidentalChip(tokens, '', '♮'),
            _buildAccidentalChip(tokens, '#', '♯'),
            _buildAccidentalChip(tokens, 'b', '♭'),
            _buildToolbarDivider(tokens),

            // 4. Deshacer / Rehacer / Compases
            IconButton(
              key: const Key('score_canvas_undo_btn'),
              tooltip: 'Deshacer cambio en partitura',
              icon: Icon(
                Icons.undo,
                size: 15,
                color: viewModel.canUndoScoreEdit
                    ? tokens.textPrimary
                    : tokens.textMuted,
              ),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(24, 24),
              ),
              onPressed: viewModel.canUndoScoreEdit
                  ? viewModel.undoScoreEdit
                  : null,
            ),
            IconButton(
              key: const Key('score_canvas_redo_btn'),
              tooltip: 'Rehacer cambio en partitura',
              icon: Icon(
                Icons.redo,
                size: 15,
                color: viewModel.canRedoScoreEdit
                    ? tokens.textPrimary
                    : tokens.textMuted,
              ),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(24, 24),
              ),
              onPressed: viewModel.canRedoScoreEdit
                  ? viewModel.redoScoreEdit
                  : null,
            ),
            _buildToolChip(
              key: const Key('score_add_measure_btn'),
              tokens: tokens,
              icon: Icons.add,
              label: '+ Compás',
              isSelected: false,
              onTap: () {
                viewModel.addScoreMeasure();
                viewModel.selectMeasure(viewModel.totalMeasures - 1);
              },
            ),
            if (viewModel.totalMeasures > 1)
              _buildToolChip(
                key: const Key('score_remove_measure_btn'),
                tokens: tokens,
                icon: Icons.remove,
                label: '- Compás',
                isSelected: false,
                onTap: () => viewModel.removeScoreMeasure(
                  viewModel.currentMeasureIndex,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarDivider(StudioDesignTokens tokens) {
    return Container(
      height: 18,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: tokens.borderHairline,
    );
  }

  Widget _buildToolChip({
    Key? key,
    required StudioDesignTokens tokens,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final effectiveColor = activeColor ?? tokens.accentPrimary;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: 0.22)
              : tokens.elevatedSurface,
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          border: Border.all(
            color: isSelected ? effectiveColor : tokens.borderHairline,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? effectiveColor : tokens.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChip(
    StudioDesignTokens tokens,
    int ticks,
    String label,
  ) {
    final isSelected = !_isRestMode && _selectedDurationTicks == ticks;
    return InkWell(
      key: Key('score_duration_chip_$ticks'),
      onTap: () => setState(() {
        _selectedDurationTicks = ticks;
        _isRestMode = false;
        _editMode = ScoreCanvasEditMode.write;
      }),
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.accentPrimary.withValues(alpha: 0.22)
              : tokens.elevatedSurface,
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          border: Border.all(
            color: isSelected ? tokens.accentPrimary : tokens.borderHairline,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? tokens.textPrimary : tokens.textSecondary,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAccidentalChip(
    StudioDesignTokens tokens,
    String accidental,
    String label,
  ) {
    final isSelected = !_isRestMode && _selectedAccidental == accidental;
    return InkWell(
      key: Key('score_accidental_chip_${accidental.isEmpty ? "nat" : accidental}'),
      onTap: () => setState(() {
        _selectedAccidental = accidental;
        _isRestMode = false;
        _editMode = ScoreCanvasEditMode.write;
      }),
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.accentSecondary.withValues(alpha: 0.22)
              : tokens.elevatedSurface,
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          border: Border.all(
            color: isSelected ? tokens.accentSecondary : tokens.borderHairline,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? tokens.textPrimary : tokens.textSecondary,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _openSongPickerSheet(
    BuildContext context,
    StudioDesignTokens tokens,
  ) {
    final List<SongPackage> allSongs = [];
    final Set<String> seenIds = {};
    for (final pkg in [...viewModel.workspaceScores, ...viewModel.curatedLibrary]) {
      if (seenIds.add(pkg.id)) {
        allSongs.add(pkg);
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.panelBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.78;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tokens.borderHairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            StudioIcon(
                              StudioIconId.moduleScoreSheet,
                              color: tokens.accentPrimary,
                              size: 20,
                              tintCustomAsset: true,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Repertorio & Obras del Proyecto',
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar selector de obras',
                        icon: Icon(Icons.close, size: 18, color: tokens.textMuted),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    key: const Key('song_picker_import_from_disk_btn'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      widget.onOpenLibraryModal();
                    },
                    borderRadius: BorderRadius.circular(tokens.radiusMedium),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: tokens.accentPrimary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(tokens.radiusMedium),
                        border: Border.all(
                          color: tokens.accentPrimary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          StudioIcon(
                            StudioIconId.fileOpen,
                            color: tokens.accentPrimary,
                            size: 18,
                            tintCustomAsset: true,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Importar Audio (MP3/WAV) o Partitura del Computador...',
                              style: TextStyle(
                                color: tokens.accentPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: tokens.accentPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Obras disponibles (${allSongs.length})',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: allSongs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final pkg = allSongs[index];
                        final isSelected = pkg.id == viewModel.activePackage.id;
                        return InkWell(
                          key: Key('song_picker_item_${pkg.id}'),
                          onTap: () {
                            viewModel.loadSongPackage(pkg);
                            Navigator.of(sheetContext).pop();
                          },
                          borderRadius: BorderRadius.circular(tokens.radiusMedium),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tokens.accentPrimary.withValues(alpha: 0.14)
                                  : tokens.elevatedSurface,
                              borderRadius: BorderRadius.circular(tokens.radiusMedium),
                              border: Border.all(
                                color: isSelected
                                    ? tokens.accentPrimary
                                    : tokens.borderHairline,
                                width: isSelected ? 1.2 : 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : Icons.music_note_rounded,
                                  size: 18,
                                  color: isSelected
                                      ? tokens.accentPrimary
                                      : tokens.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pkg.title,
                                        style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${pkg.composer} • ${pkg.defaultBpm} BPM • ${pkg.totalMeasures} compases • ${pkg.tracks.length} pistas',
                                        style: TextStyle(
                                          color: tokens.textMuted,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _applyDoricoQuickCommand() {
    final raw = _doricoPopoverController.text.trim().toLowerCase();
    if (raw.isEmpty) return;

    final measureMatch = RegExp(r'^(?:m|comp[aá]s)\s*(\d+)$').firstMatch(raw);
    if (measureMatch != null) {
      final measureNumber = int.tryParse(measureMatch.group(1) ?? '');
      if (measureNumber != null) {
        final targetIndex = (measureNumber - 1).clamp(0, math.max(0, viewModel.totalMeasures - 1)).toInt();
        viewModel.selectMeasure(targetIndex);
        setState(() {
          _isDoricoPopoverOpen = false;
          _doricoPopoverController.clear();
        });
        return;
      }
    }

    final bpmValue = int.tryParse(raw.replaceAll(RegExp(r'\s*bpm$'), ''));
    if (bpmValue != null) {
      viewModel.updateBpm(bpmValue);
      setState(() {
        _isDoricoPopoverOpen = false;
        _doricoPopoverController.clear();
      });
    }
  }

  Widget _buildDoricoWorkflowModeSelector(
    BuildContext context,
    StudioDesignTokens tokens,
  ) {
    Widget buildModeChip({
      required Key key,
      required ScoreWorkflowTaskMode mode,
      required IconData icon,
      required String label,
    }) {
      final isSelected = _workflowTaskMode == mode;
      return InkWell(
        key: key,
        onTap: () => setState(() => _workflowTaskMode = mode),
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? tokens.accentPrimary.withValues(alpha: 0.22)
                : tokens.elevatedSurface,
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
            border: Border.all(
              color: isSelected ? tokens.accentPrimary : tokens.borderHairline,
              width: isSelected ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: isSelected ? tokens.accentPrimary : tokens.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Container(
        key: const Key('dorico_score_task_mode_selector'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          border: Border.all(color: tokens.borderHairline),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text(
                'Flujo Dorico:',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              buildModeChip(
                key: const Key('dorico_mode_all_chip'),
                mode: ScoreWorkflowTaskMode.all,
                icon: Icons.dashboard_customize_outlined,
                label: 'Todo',
              ),
              const SizedBox(width: 6),
              buildModeChip(
                key: const Key('dorico_mode_write_chip'),
                mode: ScoreWorkflowTaskMode.write,
                icon: Icons.edit_note_rounded,
                label: 'Escribir (Write)',
              ),
              const SizedBox(width: 6),
              buildModeChip(
                key: const Key('dorico_mode_mix_chip'),
                mode: ScoreWorkflowTaskMode.mixStems,
                icon: Icons.tune_rounded,
                label: 'Mezclar Stems (Mix)',
              ),
              const SizedBox(width: 6),
              buildModeChip(
                key: const Key('dorico_mode_practice_chip'),
                mode: ScoreWorkflowTaskMode.practice,
                icon: Icons.repeat_rounded,
                label: 'Practicar (Practice)',
              ),
              const SizedBox(width: 8),
              InkWell(
                key: const Key('btn_open_dorico_quick_popover'),
                onTap: () => setState(() {
                  _isDoricoPopoverOpen = !_isDoricoPopoverOpen;
                }),
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isDoricoPopoverOpen
                        ? tokens.accentPrimary.withValues(alpha: 0.22)
                        : tokens.elevatedSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    border: Border.all(
                      color: _isDoricoPopoverOpen
                          ? tokens.accentPrimary
                          : tokens.borderHairline,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 12,
                        color: tokens.accentPrimary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Popover Rápido (Tempo/Compás)',
                        style: TextStyle(
                          color: _isDoricoPopoverOpen
                              ? tokens.textPrimary
                              : tokens.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_workflowTaskMode != ScoreWorkflowTaskMode.practice) ...[
                const SizedBox(width: 8),
                _buildToolChip(
                  key: const Key('btn_set_loop_point_a'),
                  tokens: tokens,
                  icon: Icons.first_page_rounded,
                  label: 'Fijar A',
                  isSelected: _isAbLoopActive,
                  onTap: _setLoopPointA,
                ),
                const SizedBox(width: 6),
                _buildToolChip(
                  key: const Key('btn_set_loop_point_b'),
                  tokens: tokens,
                  icon: Icons.last_page_rounded,
                  label: 'Fijar B',
                  isSelected: _isAbLoopActive,
                  onTap: _setLoopPointB,
                ),
                if (_isAbLoopActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    key: const Key('chip_ab_loop_status'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tokens.accentSecondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      border: Border.all(color: tokens.accentSecondary),
                    ),
                    child: Text(
                      'LOOP A-B: Compás $_loopMeasureA - $_loopMeasureB',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    key: const Key('btn_clear_ab_loop'),
                    onTap: _clearAbLoop,
                    child: Icon(Icons.close_rounded, size: 14, color: tokens.textMuted),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoricoQuickPopoverBar(
    BuildContext context,
    StudioDesignTokens tokens,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Container(
        key: const Key('dorico_quick_command_popover'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          border: Border.all(
            color: tokens.accentPrimary.withValues(alpha: 0.7),
            width: 1.1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bolt_rounded,
              size: 15,
              color: tokens.accentPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              'Popover Rápido (Tempo/Compás):',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 28,
                child: TextField(
                  key: const Key('dorico_popover_input_field'),
                  controller: _doricoPopoverController,
                  onSubmitted: (_) => _applyDoricoQuickCommand(),
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ej: 120 (BPM) o m3 (Ir a compás 3)',
                    hintStyle: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 10.5,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    filled: true,
                    fillColor: tokens.inputSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      borderSide: BorderSide(color: tokens.borderHairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      borderSide: BorderSide(color: tokens.borderHairline),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              key: const Key('dorico_popover_apply_btn'),
              onTap: _applyDoricoQuickCommand,
              borderRadius: BorderRadius.circular(tokens.radiusSmall),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tokens.accentPrimary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  border: Border.all(color: tokens.accentPrimary),
                ),
                child: Text(
                  'Aplicar',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbMeasureLoopBar(
    BuildContext context,
    StudioDesignTokens tokens,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Container(
        key: const Key('score_ab_measure_loop_bar'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          border: Border.all(color: tokens.borderHairline),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Icon(
                Icons.repeat_rounded,
                size: 13,
                color: _isAbLoopActive ? tokens.accentSecondary : tokens.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                'Bucle A-B:',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _buildToolChip(
                key: const Key('btn_set_loop_point_a'),
                tokens: tokens,
                icon: Icons.first_page_rounded,
                label: 'Fijar A',
                isSelected: _isAbLoopActive,
                onTap: _setLoopPointA,
              ),
              const SizedBox(width: 6),
              _buildToolChip(
                key: const Key('btn_set_loop_point_b'),
                tokens: tokens,
                icon: Icons.last_page_rounded,
                label: 'Fijar B',
                isSelected: _isAbLoopActive,
                onTap: _setLoopPointB,
              ),
              if (_isAbLoopActive) ...[
                const SizedBox(width: 8),
                Container(
                  key: const Key('chip_ab_loop_status'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.accentSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    border: Border.all(color: tokens.accentSecondary),
                  ),
                  child: Text(
                    'LOOP A-B: Compás $_loopMeasureA - $_loopMeasureB',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  key: const Key('btn_clear_ab_loop'),
                  onTap: _clearAbLoop,
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: tokens.elevatedSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded, size: 12, color: tokens.accentDanger),
                        const SizedBox(width: 3),
                        Text(
                          'Limpiar',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineStemsAndMinusOneBar(
    BuildContext context,
    StudioDesignTokens tokens,
  ) {
    final tracks = viewModel.activePackage.tracks;
    if (tracks.isEmpty) {
      return const SizedBox.shrink();
    }

    final stems = viewModel.mixerConsole.stems.isNotEmpty
        ? viewModel.mixerConsole.stems
        : tracks;
    final isMinusOne = viewModel.isMinusOneActive;
    final targetTrackId = viewModel.minusOneUserTrackId ?? tracks.first.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Container(
        key: const Key('inline_stems_minus_one_bar'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          border: Border.all(color: tokens.borderHairline),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              InkWell(
                key: const Key('inline_minus_one_toggle_chip'),
                onTap: () => viewModel.toggleMinusOneMode(
                  targetTrackId: targetTrackId,
                ),
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMinusOne
                        ? tokens.accentSecondary.withValues(alpha: 0.22)
                        : tokens.elevatedSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    border: Border.all(
                      color: isMinusOne
                          ? tokens.accentSecondary
                          : tokens.borderHairline,
                      width: isMinusOne ? 1.2 : 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMinusOne
                            ? Icons.headset_mic_rounded
                            : Icons.headset_mic_outlined,
                        size: 13,
                        color: isMinusOne
                            ? tokens.accentSecondary
                            : tokens.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Minus-One',
                        style: TextStyle(
                          color: isMinusOne
                              ? tokens.textPrimary
                              : tokens.textSecondary,
                          fontSize: 10.5,
                          fontWeight: isMinusOne
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildToolbarDivider(tokens),
              ...stems.map((track) {
                final isAudible = !track.isMuted;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: InkWell(
                    key: Key('inline_stem_toggle_${track.id}'),
                    onTap: () => viewModel.toggleTrackMute(track.id),
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAudible
                            ? tokens.accentPrimary.withValues(alpha: 0.16)
                            : tokens.elevatedSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(
                          color: isAudible
                              ? tokens.accentPrimary.withValues(alpha: 0.65)
                              : tokens.borderHairline,
                          width: isAudible ? 1.1 : 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAudible
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            size: 13,
                            color: isAudible
                                ? tokens.accentPrimary
                                : tokens.accentDanger,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            track.title,
                            style: TextStyle(
                              color: isAudible
                                  ? tokens.textPrimary
                                  : tokens.textMuted,
                              fontSize: 10.5,
                              fontWeight: isAudible
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              decoration: isAudible
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Column(
          children: [
            // Encabezado de la Obra y Navegación de Compases
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: InkWell(
                      key: const Key('score_workspace_song_picker_btn'),
                      onTap: () => _openSongPickerSheet(context, tokens),
                      borderRadius: BorderRadius.circular(tokens.radiusMedium),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: tokens.panelBackground,
                      borderRadius: BorderRadius.circular(tokens.radiusMedium),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StudioIcon(
                          StudioIconId.moduleScoreSheet,
                          size: 15,
                          color: tokens.accentPrimary,
                          tintCustomAsset: true,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            viewModel.activePackage.title,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 16, color: tokens.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Navegación de compases integrada
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: StudioIcon(
                      StudioIconId.transportRewind,
                      color: tokens.textSecondary,
                      size: 15,
                      tintCustomAsset: true,
                    ),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(24, 24),
                    ),
                    onPressed: () => viewModel.previousMeasure(),
                    tooltip: "Compás Anterior",
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      "Compás ${viewModel.currentMeasureIndex + 1} de ${viewModel.totalMeasures}  (${viewModel.currentMeasureTimeSignature})",
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: StudioIcon(
                      StudioIconId.transportForward,
                      color: tokens.textSecondary,
                      size: 15,
                      tintCustomAsset: true,
                    ),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(24, 24),
                    ),
                    onPressed: () => viewModel.nextMeasure(),
                    tooltip: "Siguiente Compás",
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Controles de tempo y reproducción
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: StudioIcon(
                      viewModel.isMetronomePlaying
                          ? StudioIconId.transportStop
                          : StudioIconId.transportPlay,
                      color: viewModel.isMetronomePlaying
                          ? tokens.accentDanger
                          : tokens.accentPrimary,
                      size: 20,
                      tintCustomAsset: true,
                    ),
                    onPressed: () {
                      if (viewModel.isMetronomePlaying) {
                        viewModel.stopSong();
                      } else {
                        viewModel.startSongWithCountIn();
                      }
                    },
                    tooltip: viewModel.isMetronomePlaying ? "Detener Partitura" : "Reproducir Obra",
                  ),
                  Text(
                    "${viewModel.bpm}",
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    "BPM",
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    key: const Key('tap_tempo_comp_btn'),
                    onTap: () => TapTempoModal.show(context, viewModel),
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: tokens.elevatedSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(color: tokens.borderHairline),
                      ),
                      child: Text(
                        'TAP',
                        style: TextStyle(
                          color: tokens.accentPrimary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Popover Rápido estilo Dorico (Shift+T / Shift+M)
        if (_isDoricoPopoverOpen)
          _buildDoricoQuickPopoverBar(context, tokens),

        // Selector segmentado de Modos de Flujo Musical estilo Steinberg Dorico 5 (US-UX-07)
        _buildDoricoWorkflowModeSelector(context, tokens),

        // Barra Interactiva de Edición Directa sobre el Lienzo del Pentagrama
        if (_workflowTaskMode == ScoreWorkflowTaskMode.all ||
            _workflowTaskMode == ScoreWorkflowTaskMode.write)
          _buildDirectCanvasEditToolbar(context, tokens),

        // Barra Rápida de Bucle de Práctica A-B por Compases (en modo Practicar)
        if (_workflowTaskMode == ScoreWorkflowTaskMode.practice)
          _buildAbMeasureLoopBar(context, tokens),

        // Lienzo del Pentagrama Tipográfico SMuFL (Edición Directa con Clic y Arrastre Vertical)
        if (viewModel.workspaceConfiguration.showSheetMusicCanvas)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: tokens.inputSurface,
                borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
                border: Border.all(color: tokens.borderHairline),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final painter = RealSheetMusicPainter(
                    currentSubTick: viewModel.currentSubTick,
                    notes: viewModel.currentMeasureNotes,
                    history: viewModel.measureHistory,
                    liveNote: viewModel.noteName,
                    liveCents: viewModel.cents,
                    isCountingIn: viewModel.isCountingIn,
                    countInBeat: viewModel.countInBeat,
                    timeSignature: viewModel.currentMeasureTimeSignature,
                    measureIndex: viewModel.currentMeasureIndex,
                    totalMeasures: viewModel.totalMeasures,
                    palette: palette,
                    clef: viewModel.activeInstrument.clef,
                    selectedNoteIndex: viewModel.selectedScoreNoteIndex,
                    loopStartMeasure: _isAbLoopActive ? (_loopMeasureA - 1) : null,
                    loopEndMeasure: _isAbLoopActive ? (_loopMeasureB - 1) : null,
                    ghostHoverTick: _editMode == ScoreCanvasEditMode.write
                        ? _hoverGhostTick
                        : null,
                    ghostHoverNoteName: _editMode == ScoreCanvasEditMode.write
                        ? _hoverGhostNoteName
                        : null,
                    ghostHoverDurationTicks: _selectedDurationTicks,
                    ghostHoverIsRest: _isRestMode,
                  );

                  return MouseRegion(
                    cursor: _editMode == ScoreCanvasEditMode.erase
                        ? SystemMouseCursors.precise
                        : SystemMouseCursors.click,
                    onHover: (event) {
                      if (_editMode != ScoreCanvasEditMode.write) {
                        if (_hoverGhostTick != null ||
                            _hoverGhostNoteName != null) {
                          setState(() {
                            _hoverGhostTick = null;
                            _hoverGhostNoteName = null;
                          });
                        }
                        return;
                      }
                      final int nextTick = painter.resolveSubTickAtOffset(
                        event.localPosition,
                        canvasSize,
                      );
                      final String nextNoteName = painter.resolveNoteNameAtOffset(
                        event.localPosition,
                        canvasSize,
                        accidental: _selectedAccidental,
                      );
                      if (nextTick != _hoverGhostTick ||
                          nextNoteName != _hoverGhostNoteName) {
                        setState(() {
                          _hoverGhostTick = nextTick;
                          _hoverGhostNoteName = nextNoteName;
                        });
                      }
                    },
                    onExit: (_) {
                      if (_hoverGhostTick != null ||
                          _hoverGhostNoteName != null) {
                        setState(() {
                          _hoverGhostTick = null;
                          _hoverGhostNoteName = null;
                        });
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          key: const Key('score_interactive_canvas_gesture'),
                          onTapDown: (details) => _handleCanvasTapDown(
                            details,
                            painter,
                            canvasSize,
                          ),
                          onSecondaryTapDown: (details) =>
                              _handleCanvasSecondaryTapDown(
                            details,
                            painter,
                            canvasSize,
                          ),
                          onVerticalDragStart: (details) =>
                              _handleCanvasVerticalDragStart(
                            details,
                            painter,
                            canvasSize,
                          ),
                          onVerticalDragUpdate: (details) =>
                              _handleCanvasVerticalDragUpdate(
                            details,
                            painter,
                            canvasSize,
                          ),
                          onVerticalDragEnd: _handleCanvasVerticalDragEnd,
                          child: CustomPaint(
                            painter: painter,
                            size: canvasSize,
                          ),
                        ),
                        if (_hoverGhostNoteName != null &&
                            _hoverGhostTick != null &&
                            _editMode == ScoreCanvasEditMode.write)
                          Positioned(
                            top: 8,
                            left: 12,
                            child: IgnorePointer(
                              child: Container(
                                key: const Key('score_ghost_note_hover_badge'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.panelBackground.withValues(
                                    alpha: 0.92,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    tokens.radiusSmall,
                                  ),
                                  border: Border.all(
                                    color: tokens.accentPrimary.withValues(
                                      alpha: 0.65,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Previsualización: ${_isRestMode ? "Silencio" : _hoverGhostNoteName} (Pulso ${(_hoverGhostTick! ~/ 4) + 1})',
                                  style: TextStyle(
                                    color: tokens.accentPrimary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

        // Barra de Transcripción de Audio en Vivo y Transformador de Archivos a Partitura
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              borderRadius: BorderRadius.circular(tokens.radiusMedium),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      StudioIcon(
                        viewModel.isLiveTranscriptionActive
                            ? StudioIconId.audioMicOn
                            : StudioIconId.audioMicOff,
                        color: viewModel.isLiveTranscriptionActive
                            ? tokens.accentSuccess
                            : tokens.textMuted,
                        size: 16,
                        tintCustomAsset: true,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          viewModel.isLiveTranscriptionActive
                              ? "Transcripción en vivo activa • ${viewModel.noteName} (${viewModel.frequency.toStringAsFixed(1)} Hz)"
                              : "Transcripción de Audio en Pentagrama",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: viewModel.isLiveTranscriptionActive
                                ? tokens.accentPrimary
                                : tokens.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ActionChip(
                      key: const Key('transcribe_audio_file_to_score_btn'),
                      avatar: StudioIcon(
                        StudioIconId.fileWavAudio,
                        size: 14,
                        color: tokens.accentPrimary,
                        tintCustomAsset: true,
                      ),
                      label: const Text('Transformar Archivo (MP3/WAV)'),
                      backgroundColor: tokens.inputSurface,
                      labelStyle: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(color: tokens.accentPrimary.withValues(alpha: 0.45)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: widget.onOpenLibraryModal,
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: viewModel.isLiveTranscriptionActive,
                      activeTrackColor: tokens.accentPrimary,
                      onChanged: (_) => viewModel.toggleLiveTranscription(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Barra Integrada de 4 Stems y Minus-One (US-UX-01)
        if (viewModel.activePackage.tracks.isNotEmpty &&
            (_workflowTaskMode == ScoreWorkflowTaskMode.all ||
                _workflowTaskMode == ScoreWorkflowTaskMode.mixStems ||
                _workflowTaskMode == ScoreWorkflowTaskMode.practice))
          _buildInlineStemsAndMinusOneBar(context, tokens),

        // Barra de Herramientas de Composición y Exportación
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  key: const Key('poly_synth_settings_btn'),
                  avatar: StudioIcon(
                    StudioIconId.modulePianoRoll,
                    size: 15,
                    color: tokens.accentPrimary,
                    tintCustomAsset: true,
                  ),
                  label: Text('Sintetizador: ${viewModel.polyphonicVoicePool.waveform.name.toUpperCase()}'),
                  backgroundColor: tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(color: tokens.borderHairline),
                  onPressed: () => PolyphonicSynthModal.show(context, viewModel, palette),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: StudioIcon(
                    StudioIconId.moduleScoreEditor,
                    size: 15,
                    color: tokens.accentPrimary,
                    tintCustomAsset: true,
                  ),
                  label: const Text('Editor de Partituras'),
                  backgroundColor: tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(color: tokens.borderHairline),
                  onPressed: () => ScoreEditorModal.show(context),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: StudioIcon(
                    StudioIconId.fileWavAudio,
                    size: 15,
                    color: tokens.accentSecondary,
                    tintCustomAsset: true,
                  ),
                  label: const Text('Descomponer Audio'),
                  backgroundColor: tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(color: tokens.borderHairline),
                  onPressed: () => SongDecomposerModal.show(context, viewModel),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: StudioIcon(
                    StudioIconId.moduleSpectrogram,
                    size: 15,
                    color: tokens.textPrimary,
                    tintCustomAsset: true,
                  ),
                  label: const Text('Mezclador Stems'),
                  backgroundColor: tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(color: tokens.borderHairline),
                  onPressed: widget.onOpenMixerModal,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: const Key('export_stems_midi_btn'),
                  avatar: StudioIcon(
                    StudioIconId.fileMusicXmlMidi,
                    size: 15,
                    color: tokens.accentSecondary,
                    tintCustomAsset: true,
                  ),
                  label: const Text('Exportar Stems & MIDI'),
                  backgroundColor: tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(color: tokens.borderHairline),
                  onPressed: () => AudioMidiExportModal.show(context, viewModel),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: const Key('btn_send_score_to_patchbay_channel_a'),
                  avatar: Icon(
                    Icons.cable_rounded,
                    size: 15,
                    color: tokens.accentPrimary,
                  ),
                  label: const Text('Enviar a Patchbay (CH A)'),
                  backgroundColor: tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(color: tokens.borderHairline),
                  onPressed: () => _sendActiveScoreToPatchbayChannelA(context),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: StudioIcon(
                    StudioIconId.audioVolumeOn,
                    color: viewModel.isScorePlaybackEnabled
                        ? tokens.accentPrimary
                        : tokens.textMuted,
                    size: 18,
                    tintCustomAsset: true,
                  ),
                  tooltip: viewModel.isScorePlaybackEnabled
                      ? "Audio de Partitura Activado"
                      : "Audio de Partitura Desactivado (Minus One)",
                  onPressed: viewModel.toggleScorePlayback,
                ),
              ],
            ),
          ),
        ),
      ],
    );
      },
    );
  }
}
