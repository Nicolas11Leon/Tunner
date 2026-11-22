import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../tuner/domain/note_entity.dart';
import '../../tuner_viewmodel.dart';

/// Modal de edición interactiva de partituras SMuFL y exportación canónica MusicXML/MIDI.
class ScoreEditorModal extends StatefulWidget {
  const ScoreEditorModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ScoreEditorModal(),
    );
  }

  @override
  State<ScoreEditorModal> createState() => _ScoreEditorModalState();
}

class _ScoreEditorModalState extends State<ScoreEditorModal> {
  int _selectedMeasureIndex = 0;
  int _selectedStartTick = 0;
  int _selectedDurationTicks = 4; // Negra por defecto
  String _selectedBaseNote = "Do";
  String _selectedAccidental = ""; // "", "#", "b"
  int _selectedOctave = 4;
  bool _isRestMode = false;
  bool _isChordMode = false;
  final List<String> _chordNotes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<TunerViewModel>();
      setState(() {
        _selectedMeasureIndex = vm.currentMeasureIndex.clamp(0, vm.activePackage.totalMeasures - 1);
        final selectedIndex = vm.selectedScoreNoteIndex;
        if (selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < vm.currentMeasureNotes.length) {
          final note = vm.currentMeasureNotes[selectedIndex];
          _selectedStartTick = note.startTick;
          _selectedDurationTicks = note.durationTicks;
          if (note.isRest || note.noteName == "--") {
            _isRestMode = true;
          } else {
            _isRestMode = false;
            final clean = note.noteName.trim();
            final octaveMatch = RegExp(r'[-+]?[0-9]+').firstMatch(clean);
            if (octaveMatch != null) {
              _selectedOctave = (int.tryParse(octaveMatch.group(0)!) ?? 4).clamp(0, 8);
            }
            if (clean.contains('#')) {
              _selectedAccidental = '#';
            } else if (clean.contains('b')) {
              _selectedAccidental = 'b';
            } else {
              _selectedAccidental = '';
            }
            final base = clean.replaceAll(RegExp(r'[-+]?[0-9#b]+'), '').trim();
            if (base.isNotEmpty) _selectedBaseNote = base;
          }
        }
      });
    });
  }

  String get _currentFormattedNoteName {
    if (_isRestMode) return "--";
    return "$_selectedBaseNote$_selectedAccidental$_selectedOctave";
  }

  void _insertCurrentNote(TunerViewModel vm, int safeMeasureIndex, int totalTicks) {
    if (_isChordMode && !_isRestMode) {
      final notesToInsert = _chordNotes.isNotEmpty
          ? List<String>.from(_chordNotes)
          : <String>[_currentFormattedNoteName];
      vm.insertScoreChordNotes(
        measureIndex: safeMeasureIndex,
        startTick: _selectedStartTick,
        durationTicks: _selectedDurationTicks,
        noteNames: notesToInsert,
      );
      setState(() {
        _selectedStartTick = (_selectedStartTick + _selectedDurationTicks).clamp(0, totalTicks - 1);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Acorde (${notesToInsert.join(', ')}) insertado en compás ${safeMeasureIndex + 1}",
          ),
          duration: const Duration(milliseconds: 1000),
        ),
      );
      return;
    }

    vm.insertOrUpdateScoreNote(
      measureIndex: safeMeasureIndex,
      startTick: _selectedStartTick,
      durationTicks: _selectedDurationTicks,
      noteName: _currentFormattedNoteName,
    );
    setState(() {
      _selectedStartTick = (_selectedStartTick + _selectedDurationTicks).clamp(0, totalTicks - 1);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Nota $_currentFormattedNoteName insertada en compás ${safeMeasureIndex + 1}"),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  Future<void> _exportScoreToFile({
    required TunerViewModel vm,
    required String extension,
    required Uint8List bytes,
    required String Function(String savedPath) buildMessage,
    String? clipboardText,
  }) async {
    if (clipboardText != null) {
      unawaited(Clipboard.setData(ClipboardData(text: clipboardText)));
    }
    final fileName = 'tunner_score_${DateTime.now().millisecondsSinceEpoch}.$extension';
    String savedPath = '';
    Object? exportError;
    try {
      savedPath = await vm.platformFileGateway.saveExportedBytes(fileName, bytes);
    } catch (e) {
      exportError = e;
    }
    if (!mounted) return;
    final message = exportError != null
        ? (clipboardText != null
            ? "${buildMessage('')} (error al guardar en disco: $exportError)"
            : "Error al guardar archivo .$extension en disco: $exportError")
        : buildMessage(savedPath);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TunerViewModel>();
    final palette = vm.currentPalette;
    final totalMeasures = vm.activePackage.totalMeasures;
    final safeMeasureIndex = _selectedMeasureIndex.clamp(0, totalMeasures - 1);
    final activeMeasure = vm.activePackage.score.measures[safeMeasureIndex];
    final totalTicks = activeMeasure.timeSignature.totalTicks;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          setState(() {
            _selectedStartTick = (_selectedStartTick + 1).clamp(0, totalTicks - 1);
          });
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          setState(() {
            _selectedStartTick = (_selectedStartTick - 1).clamp(0, totalTicks - 1);
          });
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            _selectedOctave = (_selectedOctave + 1).clamp(0, 8);
          });
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            _selectedOctave = (_selectedOctave - 1).clamp(0, 8);
          });
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          _insertCurrentNote(vm, safeMeasureIndex, totalTicks);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
      height: MediaQuery.of(context).size.height * 0.72,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle superior
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: palette.textMutedColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_note, color: palette.primaryAccent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ESTUDIO DE EDICIÓN SMuFL",
                        style: TextStyle(
                          color: palette.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        "${vm.activePackage.title} (${activeMeasure.timeSignature})",
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Botones Deshacer y Rehacer
                IconButton(
                  icon: Icon(Icons.undo,
                      color: vm.canUndoScoreEdit ? palette.primaryAccent : palette.textMutedColor.withValues(alpha: 0.3)),
                  tooltip: "Deshacer (Undo)",
                  onPressed: vm.canUndoScoreEdit ? () => vm.undoScoreEdit() : null,
                ),
                IconButton(
                  icon: Icon(Icons.redo,
                      color: vm.canRedoScoreEdit ? palette.secondaryAccent : palette.textMutedColor.withValues(alpha: 0.3)),
                  tooltip: "Rehacer (Redo)",
                  onPressed: vm.canRedoScoreEdit ? () => vm.redoScoreEdit() : null,
                ),
              ],
            ),

            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Selector de Compás
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: palette.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, size: 16),
                            color: safeMeasureIndex > 0 ? palette.primaryAccent : palette.textMutedColor.withValues(alpha: 0.3),
                            onPressed: safeMeasureIndex > 0
                                ? () => setState(() => _selectedMeasureIndex = safeMeasureIndex - 1)
                                : null,
                          ),
                          Expanded(
                            child: Text(
                              "Compás ${safeMeasureIndex + 1} de $totalMeasures",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            color: safeMeasureIndex < totalMeasures - 1
                                ? palette.primaryAccent
                                : palette.textMutedColor.withValues(alpha: 0.3),
                            onPressed: safeMeasureIndex < totalMeasures - 1
                                ? () => setState(() => _selectedMeasureIndex = safeMeasureIndex + 1)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: palette.textColor, size: 20),
                            onSelected: (val) {
                              if (val == 'add') {
                                vm.addScoreMeasure();
                                setState(() => _selectedMeasureIndex = totalMeasures);
                              } else if (val == 'remove') {
                                vm.removeScoreMeasure(safeMeasureIndex);
                                setState(() => _selectedMeasureIndex = (safeMeasureIndex - 1).clamp(0, totalMeasures));
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'add',
                                child: Text('Añadir Compás al Final'),
                              ),
                              if (totalMeasures > 1)
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Eliminar Compás Actual'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2. Paleta de Duraciones Rítmicas
                    Text(
                      "FIGURA RÍTMICA",
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _durationChip(label: "Redonda", ticks: 16, palette: palette),
                        _durationChip(
                          label: "Blanca.",
                          tooltip: "Blanca con puntillo (12 ticks)",
                          ticks: 12,
                          palette: palette,
                        ),
                        _durationChip(label: "Blanca", ticks: 8, palette: palette),
                        _durationChip(
                          label: "Negra.",
                          tooltip: "Negra con puntillo (6 ticks)",
                          ticks: 6,
                          palette: palette,
                        ),
                        _durationChip(label: "Negra", ticks: 4, palette: palette),
                        _durationChip(
                          label: "Corchea.",
                          tooltip: "Corchea con puntillo (3 ticks)",
                          ticks: 3,
                          palette: palette,
                        ),
                        _durationChip(label: "Corchea", ticks: 2, palette: palette),
                        _durationChip(label: "Semicorchea", ticks: 1, palette: palette),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 3. Posición Temporal (Tick de Inicio)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "PULSO DE INICIO (TICK)",
                          style: TextStyle(
                            color: palette.textMutedColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          "Tick $_selectedStartTick / $totalTicks",
                          style: TextStyle(
                            color: palette.primaryAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: palette.primaryAccent,
                        inactiveTrackColor: palette.staffLinesColor.withValues(alpha: 0.3),
                        thumbColor: palette.primaryAccent,
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _selectedStartTick.clamp(0, totalTicks - 1).toDouble(),
                        min: 0,
                        max: (totalTicks - 1).toDouble(),
                        divisions: totalTicks - 1,
                        onChanged: (val) => setState(() => _selectedStartTick = val.round()),
                      ),
                    ),

                    // 4. Selector de Nota, Alteración y Octava
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            "ALTURA Y TONO",
                            style: TextStyle(
                              color: palette.textMutedColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilterChip(
                              key: const Key('score_editor_chord_mode_toggle'),
                              label: const Text("Acorde"),
                              selected: _isChordMode,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              selectedColor: palette.primaryAccent.withValues(alpha: 0.3),
                              labelStyle: TextStyle(
                                color: _isChordMode ? palette.primaryAccent : palette.textColor,
                                fontWeight: _isChordMode ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (selected) => setState(() {
                                _isChordMode = selected;
                                if (_isChordMode) {
                                  _isRestMode = false;
                                }
                              }),
                            ),
                            const SizedBox(width: 4),
                            Checkbox(
                              value: _isRestMode,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              activeColor: palette.secondaryAccent,
                              onChanged: (val) => setState(() {
                                _isRestMode = val ?? false;
                                if (_isRestMode) _isChordMode = false;
                              }),
                            ),
                            Text("Silencio", style: TextStyle(color: palette.textColor, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),

                    if (!_isRestMode) ...[
                      // Teclado diatónico
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"].map((note) {
                          final isSel = _selectedBaseNote == note;
                          return ChoiceChip(
                            label: Text(note),
                            selected: isSel,
                            selectedColor: palette.primaryAccent.withValues(alpha: 0.3),
                            labelStyle: TextStyle(
                              color: isSel ? palette.primaryAccent : palette.textColor,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (_) => setState(() => _selectedBaseNote = note),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),

                      // Alteraciones y Octava
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              children: [
                                _accidentalChip(label: "♮ Natural", val: "", palette: palette),
                                _accidentalChip(label: "♯ Sostenido", val: "#", palette: palette),
                                _accidentalChip(label: "♭ Bemol", val: "b", palette: palette),
                              ],
                            ),
                          ),
                          // Octava
                          Row(
                            children: [
                              IconButton(
                                key: const Key('score_editor_octave_down_btn'),
                                icon: const Icon(Icons.remove_circle_outline, size: 18),
                                color: palette.textColor,
                                onPressed: _selectedOctave > 0
                                    ? () => setState(() => _selectedOctave--)
                                    : null,
                              ),
                              Text("Oct $_selectedOctave",
                                  style: TextStyle(color: palette.primaryAccent, fontWeight: FontWeight.bold)),
                              IconButton(
                                key: const Key('score_editor_octave_up_btn'),
                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                color: palette.textColor,
                                onPressed: _selectedOctave < 8
                                    ? () => setState(() => _selectedOctave++)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),

                      if (_isChordMode) ...[
                        const SizedBox(height: 10),
                        Container(
                          key: const Key('score_editor_chord_panel'),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: palette.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: palette.secondaryAccent.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "ACORDE POLIFÓNICO (${_chordNotes.length} notas)",
                                      style: TextStyle(
                                        color: palette.textMutedColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    key: const Key('score_editor_add_chord_note_btn'),
                                    onPressed: () {
                                      final note = _currentFormattedNoteName;
                                      if (!_chordNotes.contains(note)) {
                                        setState(() => _chordNotes.add(note));
                                      }
                                    },
                                    icon: Icon(Icons.playlist_add, size: 16, color: palette.primaryAccent),
                                    label: Text(
                                      "Añadir $_currentFormattedNoteName",
                                      style: TextStyle(color: palette.primaryAccent, fontSize: 12),
                                    ),
                                  ),
                                  if (_chordNotes.isNotEmpty)
                                    TextButton(
                                      key: const Key('score_editor_clear_chord_btn'),
                                      onPressed: () => setState(() => _chordNotes.clear()),
                                      child: Text(
                                        "Limpiar",
                                        style: TextStyle(color: palette.errorPitchColor, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                              if (_chordNotes.isEmpty)
                                Text(
                                  "Selecciona notas y pulsa Añadir para construir el acorde simultáneo.",
                                  style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                                )
                              else
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _chordNotes.map((note) {
                                    return InputChip(
                                      key: Key('chord_note_chip_$note'),
                                      label: Text(note, style: TextStyle(color: palette.textColor, fontSize: 12)),
                                      deleteIconColor: palette.errorPitchColor,
                                      onDeleted: () => setState(() => _chordNotes.remove(note)),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 16),

                    // Tarjeta de previsualización gráfica de la nota a insertar
                    Container(
                      key: const Key('score_editor_note_preview_card'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: palette.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.primaryAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.music_note, color: palette.primaryAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isChordMode && !_isRestMode
                                  ? "Vista Previa Acorde: ${_chordNotes.isEmpty ? _currentFormattedNoteName : _chordNotes.join(' + ')}"
                                  : "Vista Previa: $_currentFormattedNoteName",
                              style: TextStyle(color: palette.textColor, fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isRestMode
                                ? "Silencio"
                                : (_isChordMode
                                    ? "${_chordNotes.isEmpty ? 1 : _chordNotes.length} voces"
                                    : "${NoteEntity.frequencyForNote(_currentFormattedNoteName, a4Ref: vm.referencePitch).toStringAsFixed(1)} Hz"),
                            style: TextStyle(color: palette.primaryAccent, fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Botones de Inserción y Eliminación
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            key: const Key('score_editor_insert_btn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.primaryAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              _isChordMode && !_isRestMode
                                  ? "Insertar Acorde (${_chordNotes.isEmpty ? _currentFormattedNoteName : _chordNotes.join(', ')})"
                                  : "Insertar $_currentFormattedNoteName",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () => _insertCurrentNote(vm, safeMeasureIndex, totalTicks),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.errorPitchColor,
                              side: BorderSide(color: palette.errorPitchColor.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text("Borrar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () {
                              vm.deleteScoreNote(
                                measureIndex: safeMeasureIndex,
                                startTick: _selectedStartTick,
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 5. Sección de Exportación Canónica Universal
                    Text(
                      "EXPORTACIÓN UNIVERSAL",
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('export_musicxml_btn'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.textColor,
                              side: BorderSide(color: palette.primaryAccent.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.code, size: 18),
                            label: const Text("MusicXML", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () async {
                              final xml = vm.exportActiveScoreToMusicXml();
                              await _exportScoreToFile(
                                vm: vm,
                                extension: 'musicxml',
                                bytes: Uint8List.fromList(utf8.encode(xml)),
                                clipboardText: xml,
                                buildMessage: (savedPath) => savedPath.isNotEmpty
                                    ? "Partitura copiada en formato MusicXML estándar ($savedPath)"
                                    : "Partitura copiada en formato MusicXML estándar",
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('export_midi_btn'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.textColor,
                              side: BorderSide(color: palette.secondaryAccent.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.piano, size: 18),
                            label: const Text("MIDI (SMF)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () async {
                              final midiBytes = vm.exportActiveScoreToMidi();
                              await _exportScoreToFile(
                                vm: vm,
                                extension: 'mid',
                                bytes: midiBytes,
                                buildMessage: (savedPath) => savedPath.isNotEmpty
                                    ? "Archivo MIDI exportado (${midiBytes.length} bytes generados) en $savedPath"
                                    : "Archivo MIDI exportado (${midiBytes.length} bytes generados)",
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('export_abc_btn'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.textColor,
                              side: BorderSide(color: palette.primaryAccent.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.text_snippet_outlined, size: 18),
                            label: const Text("ABC Notation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () async {
                              final abc = vm.exportActiveScoreToAbc();
                              await _exportScoreToFile(
                                vm: vm,
                                extension: 'abc',
                                bytes: Uint8List.fromList(utf8.encode(abc)),
                                clipboardText: abc,
                                buildMessage: (savedPath) => savedPath.isNotEmpty
                                    ? "Partitura copiada en formato ABC Notation ($savedPath)"
                                    : "Partitura copiada en formato ABC Notation",
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('export_pdf_btn'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.textColor,
                              side: BorderSide(color: palette.secondaryAccent.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text("PDF Imprimible", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () async {
                              final pdfBytes = vm.exportActiveScoreToPdf();
                              final sizeKb = (pdfBytes.length / 1024).toStringAsFixed(1);
                              await _exportScoreToFile(
                                vm: vm,
                                extension: 'pdf',
                                bytes: pdfBytes,
                                buildMessage: (savedPath) => savedPath.isNotEmpty
                                    ? "Partitura exportada a PDF vectorial ($sizeKb KB) en $savedPath"
                                    : "Partitura exportada a PDF vectorial ($sizeKb KB)",
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _durationChip({
    required String label,
    required int ticks,
    required TunnerThemePalette palette,
    String? tooltip,
  }) {
    final isSel = _selectedDurationTicks == ticks;
    final chip = ChoiceChip(
      key: Key('duration_chip_$ticks'),
      label: Text(label),
      selected: isSel,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: palette.primaryAccent.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSel ? palette.primaryAccent : palette.textColor,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedDurationTicks = ticks),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: chip);
    }
    return chip;
  }

  Widget _accidentalChip({required String label, required String val, required TunnerThemePalette palette}) {
    final isSel = _selectedAccidental == val;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: palette.secondaryAccent.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSel ? palette.secondaryAccent : palette.textColor,
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedAccidental = val),
    );
  }
}
