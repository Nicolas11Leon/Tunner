import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system/atoms/studio_text_controller_scope.dart';
import '../../../core/logging/infrastructure/studio_debug_logger.dart';
import '../domain/rack_module_entity.dart';
import '../domain/port_id.dart';
import 'modular_rack_viewmodel.dart';
import 'studio_patchbay_modal.dart';
import '../../instrument/presentation/visual_interface_profile_ui_ext.dart';
import '../../instrument/presentation/instrument_emulation_surface_widget.dart';
import '../../navigation/presentation/contextual_help_sheet.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../tuner_viewmodel.dart';
import '../../metronome/presentation/tap_tempo_modal.dart';
import '../../vocal_autotune/presentation/vocal_autotune_modal.dart';
import '../../vocal_autotune/domain/autotune_config_entity.dart';
import '../../drone/presentation/harmonic_drone_modal.dart';
import '../../drone/domain/harmonic_drone_config.dart';
import '../../acoustic_lab/presentation/harmonic_spectrogram_modal.dart';
import '../../chord_analyzer/presentation/chord_analyzer_modal.dart';
import '../../guided_lessons/presentation/guided_lessons_modal.dart';
import '../../ear_training/presentation/blind_ear_trainer_modal.dart';
import '../../score_editor/presentation/score_editor_modal.dart';
import '../../practice_recorder/presentation/practice_recording_player_modal.dart';
import '../../song_library/presentation/studio_assets_modals.dart';

/// Tarjeta contenedora de una unidad de módulo montada en el Rack de Estudio.
/// Soporta reordenamiento por arrastre, colapso compacto, apagado y puertos In/Out.
class RackUnitCard extends StatelessWidget {
  final RackModuleEntity module;
  final ModularRackViewModel viewModel;
  final int index;

  const RackUnitCard({
    super.key,
    required this.module,
    required this.viewModel,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final instrument = viewModel.activeInstrument;
    final primaryColor = instrument.visualProfile.primaryAccentColor;
    final isExpanded = module.viewMode == ModuleViewMode.expanded;
    final isPowered = module.isPoweredOn;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPowered ? primaryColor.withValues(alpha: 0.4) : Colors.white12,
          width: isPowered ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de cabecera del módulo (Chassis Rack Bar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: isExpanded ? Radius.zero : const Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                // Manija de arrastre (Drag Handle)
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.drag_indicator, color: Colors.white38, size: 20),
                  ),
                ),

                // Insignia técnica del módulo (Studio Code)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    module.moduleType.icon,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Título del módulo interactivo (Tap para renombrar)
                Expanded(
                  child: InkWell(
                    onTap: () => _showRenameDialog(context),
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            module.title.toUpperCase(),
                            style: TextStyle(
                              color: isPowered ? Colors.white : Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_outlined, color: Colors.white24, size: 12),
                      ],
                    ),
                  ),
                ),

                // Botón Exportar Herramienta (.tnt)
                IconButton(
                  icon: const Icon(Icons.save_alt, color: Colors.white38, size: 16),
                  tooltip: 'Guardar Herramienta como Preset (.tnt)',
                  onPressed: () => _exportToolPreset(context),
                ),

                // Botón Desacoplar Módulo en Ventana Flotante Libre
                IconButton(
                  key: Key('rack_float_module_btn_${module.moduleId}'),
                  icon: Icon(Icons.picture_in_picture_alt_outlined, color: primaryColor, size: 16),
                  tooltip: 'Desacoplar en Ventana Flotante Movible',
                  onPressed: () => _showFloatingModuleWindow(context),
                ),

                // Insignia de ayuda contextual (?)
                Padding(
                  padding: const EdgeInsets.only(left: 6, right: 6),
                  child: ContextualHelpBadge(
                    toolId: module.moduleType.code,
                    palette: TunnerThemePalette.obsidianStudio,
                    size: 18,
                  ),
                ),

                // Interruptor de encendido (Power LED)
                InkWell(
                  onTap: () => viewModel.toggleModulePower(module.moduleId),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPowered ? const Color(0xFF10B981) : Colors.white24,
                            boxShadow: isPowered
                                ? [const BoxShadow(color: Color(0xFF10B981), blurRadius: 6, spreadRadius: 1)]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPowered ? 'ON' : 'OFF',
                          style: TextStyle(
                            color: isPowered ? const Color(0xFF10B981) : Colors.white24,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Botón Compactar / Expandir
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white54,
                    size: 20,
                  ),
                  tooltip: isExpanded ? 'Modo Compacto' : 'Modo Expandido',
                  onPressed: () => viewModel.toggleViewMode(module.moduleId),
                ),

                // Botón Quitar del Rack
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                  tooltip: 'Quitar del Rack',
                  onPressed: () => viewModel.removeModule(module.moduleId),
                ),
              ],
            ),
          ),

          // Fila de Puertos de Entrada y Salida (Signal Badges)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: Colors.white.withValues(alpha: 0.02),
              child: Row(
                children: [
                  if (module.inputPorts.isNotEmpty) ...[
                    const Text('IN: ', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                    ...module.inputPorts.map((p) => _buildPortBadge(context, p, isInput: true)),
                  ],
                  const Spacer(),
                  if (module.outputPorts.isNotEmpty) ...[
                    const Text('OUT: ', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                    ...module.outputPorts.map((p) => _buildPortBadge(context, p, isInput: false)),
                  ],
                ],
              ),
            ),

          // Cuerpo expandido interactivo del módulo
          if (isExpanded && isPowered)
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildModuleContent(context),
            )
          else if (isExpanded && !isPowered)
            Container(
              height: 60,
              alignment: Alignment.center,
              child: const Text(
                'Módulo apagado en standby para ahorrar batería.',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  void _showFloatingModuleWindow(BuildContext context) {
    Offset windowOffset = const Offset(80, 70);
    Size windowSize = const Size(520, 360);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setFloatingState) {
            final screenSize = MediaQuery.of(ctx).size;
            final maxLeft = (screenSize.width - windowSize.width).clamp(0.0, screenSize.width);
            final maxTop = (screenSize.height - windowSize.height).clamp(0.0, screenSize.height);
            final left = windowOffset.dx.clamp(0.0, maxLeft);
            final top = windowOffset.dy.clamp(0.0, maxTop);

            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: windowSize.width,
                  height: windowSize.height,
                  child: Material(
                    color: const Color(0xFF161F30),
                    elevation: 18,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Barra de título arrastrable
                            GestureDetector(
                              onPanUpdate: (details) {
                                setFloatingState(() {
                                  windowOffset = Offset(
                                    (left + details.delta.dx).clamp(0.0, maxLeft),
                                    (top + details.delta.dy).clamp(0.0, maxTop),
                                  );
                                });
                              },
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                color: const Color(0xFF0F172A),
                                child: Row(
                                  children: [
                                    const Icon(Icons.drag_indicator, color: Color(0xFF38BDF8), size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${module.title.toUpperCase()} (VENTANA FLOTANTE)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                                      tooltip: 'Acoplar de nuevo al Rack',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      onPressed: () => Navigator.of(dialogCtx).pop(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(14),
                                child: ListenableBuilder(
                                  listenable: viewModel,
                                  builder: (innerCtx, _) => _buildModuleContent(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Tirador de redimensionamiento en esquina inferior derecha
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setFloatingState(() {
                                windowSize = Size(
                                  (windowSize.width + details.delta.dx).clamp(320.0, screenSize.width * 0.95),
                                  (windowSize.height + details.delta.dy).clamp(220.0, screenSize.height * 0.90),
                                );
                              });
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.bottomRight,
                              padding: const EdgeInsets.all(3),
                              child: const Icon(Icons.south_east, size: 14, color: Color(0xFF38BDF8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StudioTextControllerScope(
        initialText: module.title,
        builder: (ctx, controller) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'RENOMBRAR HERRAMIENTA',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Nombre Personalizado',
              labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  viewModel.renameModule(module.moduleId, controller.text.trim());
                }
                Navigator.pop(ctx);
              },
              child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  void _exportToolPreset(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await viewModel.exportToolPresetToFile(module.moduleId);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Herramienta "${module.title}" exportada como preset (.tnt)'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Widget _buildPortBadge(BuildContext context, PortId port, {required bool isInput}) {
    // Verificar si el puerto tiene una conexión activa en el bus
    final hasActiveConn = viewModel.signalBus.activeConnections.any((c) =>
        (isInput ? c.destinationPort == port : c.sourcePort == port));

    final badgeColor = hasActiveConn
        ? const Color(0xFF10B981)
        : (isInput ? const Color(0xFF38BDF8) : const Color(0xFFA855F7));

    return InkWell(
      onTap: () => StudioPatchbayModal.show(context, viewModel, focusPort: port),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasActiveConn ? const Color(0xFF10B981) : Colors.white38,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              port.id,
              style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  static TunerViewModel? _staticFallbackViewModel;
  static TunerViewModel get _fallbackViewModel => _staticFallbackViewModel ??= TunerViewModel();

  TunerViewModel _resolveTunerViewModel(BuildContext context) {
    try {
      final vm = Provider.of<TunerViewModel>(context, listen: true);
      return vm;
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'RackUnitCard',
        'TunerViewModel no montado en contexto; usando fallback: $e',
        error: e,
        stackTrace: st,
      );
      return _fallbackViewModel;
    }
  }

  Widget _buildModuleContent(BuildContext context) {
    final tunerViewModel = _resolveTunerViewModel(context);
    switch (module.moduleType) {
      case RackModuleType.strobeTuner:
        return _buildStrobeTunerContent(tunerViewModel);
      case RackModuleType.metronome:
        return _buildMetronomeContent(tunerViewModel, context);
      case RackModuleType.scoreNotation:
        return _buildScoreNotationContent(tunerViewModel, context);
      case RackModuleType.practiceRecorder:
        return _buildRecorderContent(tunerViewModel, context);
      case RackModuleType.vocalAutoTune:
        return _buildAutoTuneContent(tunerViewModel, context);
      case RackModuleType.harmonicDrone:
        return _buildDroneContent(tunerViewModel, context);
      case RackModuleType.spectrogram:
        return _buildSpectrogramContent(tunerViewModel, context);
      case RackModuleType.chordAnalyzer:
        return _buildChordAnalyzerContent(tunerViewModel, context);
      case RackModuleType.guidedLessons:
        return _buildGuidedLessonsContent(tunerViewModel, context);
      case RackModuleType.earTrainer:
        return _buildEarTrainerContent(tunerViewModel, context);
      case RackModuleType.djConsole:
      case RackModuleType.stemMixer:
        return _buildStudioAudioModuleSummary(module);
    }
  }

  Widget _buildStudioAudioModuleSummary(RackModuleEntity mod) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        '${mod.title} (${mod.inputPorts.length} IN / ${mod.outputPorts.length} OUT)',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  // --- SUB-VISTAS INTERACTIVAS POR MÓDULO ---

  Widget _buildStrobeTunerContent(TunerViewModel tuner) {
    final instrument = viewModel.activeInstrument;
    final hasPitch = tuner.frequency > 20.0;
    final displayNote = hasPitch
        ? tuner.writtenNoteName
        : (instrument.acousticRange.standardTuningNoteNames.isNotEmpty
            ? instrument.acousticRange.standardTuningNoteNames.first
            : 'A4');
    final cents = tuner.cents;
    final isInTune = hasPitch && cents.abs() <= tuner.centsTolerance;
    final deviationText = hasPitch
        ? '${cents >= 0 ? "+" : ""}${cents.toStringAsFixed(1)} ¢ (${isInTune ? "EN TONO" : (cents > 0 ? "ALTO" : "BAJO")})'
        : 'EN ESPERA DE SEÑAL';
    final deviationColor = hasPitch
        ? (isInTune ? const Color(0xFF10B981) : (cents.abs() < 15 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)))
        : Colors.white38;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text('NOTA ACTIVA', style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 0.5)),
                Text(
                  displayNote,
                  style: TextStyle(
                    color: instrument.visualProfile.primaryAccentColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const Text('DESVIACIÓN EN CENTS', style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 0.5)),
                Text(
                  deviationText,
                  style: TextStyle(
                    color: deviationColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  hasPitch
                      ? '${tuner.frequency.toStringAsFixed(1)} Hz'
                      : '${instrument.acousticRange.minFrequencyHz.toStringAsFixed(1)} Hz (Ref Min)',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        InstrumentEmulationSurfaceWidget(
          instrument: instrument,
          onFrequencyTriggered: (freq) {
            if (freq > 20.0) {
              tuner.audioSynthesizer.playNoteTone(
                frequency: freq,
                duration: const Duration(milliseconds: 350),
                volume: 0.7,
              );
            }
          },
          onDrumHitTriggered: (padIndex) {
            tuner.audioSynthesizer.playMetronomeClick(
              isDownbeat: padIndex == 0,
              volume: 0.8,
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetronomeContent(TunerViewModel tuner, BuildContext context) {
    final sig = tuner.currentMeasureTimeSignature;
    final isPlaying = tuner.isMetronomePlaying;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TEMPO: ${tuner.bpm} BPM • ${sig.numerator}/${sig.denominator}',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                ActionChip(
                  label: const Text('TAP TEMPO'),
                  labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  backgroundColor: Colors.white12,
                  onPressed: () => TapTempoModal.show(context, tuner),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: isPlaying ? 'Pausar Metrónomo' : 'Iniciar Metrónomo',
                  icon: Icon(
                    isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: isPlaying ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    size: 28,
                  ),
                  onPressed: tuner.toggleMetronome,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: tuner.bpm.clamp(40, 240).toDouble(),
            min: 40,
            max: 240,
            activeColor: const Color(0xFF10B981),
            inactiveColor: Colors.white12,
            onChanged: (val) => tuner.updateBpm(val.round()),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreNotationContent(TunerViewModel tuner, BuildContext context) {
    final title = tuner.activePackage.title;
    final currentMeasure = tuner.currentMeasureIndex + 1;
    final totalMeasures = tuner.totalMeasures;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('𝄞', style: TextStyle(fontSize: 28, color: Color(0xFFF59E0B))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title : 'Partitura de Estudio',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Compás $currentMeasure de $totalMeasures • Clave de Sol',
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar en Editor Canónico SMuFL',
                icon: const Icon(Icons.edit_note, color: Colors.white70, size: 20),
                onPressed: () => ScoreEditorModal.show(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  side: const BorderSide(color: Colors.white24),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.add, size: 14, color: Colors.white70),
                label: const Text('NUEVA', style: TextStyle(color: Colors.white70, fontSize: 10)),
                onPressed: () => StudioAssetsModals.showNewScoreDialog(
                  context: context,
                  viewModel: tuner,
                  onNavigateToTab: (_) {},
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  side: const BorderSide(color: Colors.white24),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.file_download, size: 14, color: Colors.white70),
                label: const Text('IMPORTAR', style: TextStyle(color: Colors.white70, fontSize: 10)),
                onPressed: () => StudioAssetsModals.showImportScoreDialog(
                  context: context,
                  viewModel: tuner,
                  onNavigateToTab: (_) {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildRecorderContent(TunerViewModel tuner, BuildContext context) {
    final isRecording = tuner.isAudioRecording;
    final hasHistory = tuner.recordingHistory.isNotEmpty;
    final lastRecording = hasHistory ? tuner.recordingHistory.last : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              isRecording ? Icons.radio_button_checked : Icons.graphic_eq,
              color: isRecording ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
              size: 32,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRecording
                      ? 'GRABANDO: ${_formatDuration(tuner.recordingDuration)}'
                      : (lastRecording != null
                          ? '${lastRecording.songTitle} (${_formatDuration(lastRecording.duration)})'
                          : 'GRABADOR DE ESTUDIO EN ESPERA'),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  isRecording ? '44.1 kHz • 24-bit PCM Flotante' : '${tuner.recordingHistory.length} tomas en sesión',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              tooltip: isRecording ? 'Detener Grabación' : 'Iniciar Grabación de Práctica',
              icon: Icon(
                isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                color: const Color(0xFFEF4444),
                size: 26,
              ),
              onPressed: () {
                if (isRecording) {
                  tuner.stopPracticeRecording();
                } else {
                  tuner.startPracticeRecording();
                }
              },
            ),
            IconButton(
              tooltip: hasHistory ? 'Abrir Reproductor de Auto-Escucha' : 'Sin grabaciones en sesión',
              icon: Icon(
                Icons.play_arrow,
                color: hasHistory ? Colors.white : Colors.white24,
                size: 26,
              ),
              onPressed: hasHistory ? () => PracticeRecordingPlayerModal.show(context) : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutoTuneContent(TunerViewModel tuner, BuildContext context) {
    final config = tuner.autoTuneConfig;
    final isActive = tuner.isAutoTuneActive;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'VELOCIDAD: ${config.retuneSpeedMs.toStringAsFixed(0)} ms',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            Text(
              'ESCALA: ${config.scaleType.displayName.toUpperCase()}',
              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.tune, size: 14, color: Color(0xFF38BDF8)),
                label: const Text('CONFIGURAR AUTOTUNE', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                onPressed: () => VocalAutoTuneModal.show(context, tuner),
              ),
            ),
            const SizedBox(width: 10),
            Switch(
              value: isActive,
              activeThumbColor: const Color(0xFF38BDF8),
              onChanged: (_) => tuner.toggleAutoTune(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDroneContent(TunerViewModel tuner, BuildContext context) {
    final cfg = tuner.droneConfig;
    final rootName = HarmonicDroneConfig.chromaticNoteNames[cfg.rootNoteIndex];
    final isPlaying = tuner.isDronePlaying;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FUNDAMENTAL: $rootName${cfg.octave}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              cfg.includeFifth ? '+ Quinta Justa • Timbre ${cfg.timbre.name}' : 'Tono simple • Timbre ${cfg.timbre.name}',
              style: const TextStyle(color: Color(0xFFA855F7), fontSize: 10),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              tooltip: isPlaying ? 'Detener Tono Pedal' : 'Activar Tono Pedal',
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: isPlaying ? const Color(0xFFEF4444) : const Color(0xFFA855F7),
                size: 26,
              ),
              onPressed: () => tuner.toggleDrone(),
            ),
            IconButton(
              tooltip: 'Configuración Avanzada de Dron',
              icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
              onPressed: () => HarmonicDroneModal.show(context, tuner),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpectrogramContent(TunerViewModel tuner, BuildContext context) {
    final hasSignal = tuner.frequency > 20.0;
    final chroma = tuner.activeChromaVector;

    return InkWell(
      onTap: () => HarmonicSpectrogramModal.show(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (i) {
                final energy = hasSignal && chroma.length > i ? chroma[i] : 0.05;
                final barHeight = (8.0 + (energy * 42.0)).clamp(6.0, 50.0);
                return Container(
                  width: 8,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: hasSignal
                        ? const Color(0xFF38BDF8).withValues(alpha: (0.4 + energy * 0.6).clamp(0.2, 1.0))
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            const Text(
              'Toca para abrir Laboratorio Acústico y Análisis de Armónicos',
              style: TextStyle(color: Colors.white38, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChordAnalyzerContent(TunerViewModel tuner, BuildContext context) {
    final chord = tuner.recognizedChord;
    final isActive = tuner.isChordRecognitionActive;
    final chordName = chord.displayName.isNotEmpty ? chord.displayName : 'Sin acordes detectados';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACORDE: $chordName',
                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                isActive ? 'Escuchando polifonía en vivo' : 'Detector en standby',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              tooltip: isActive ? 'Pausar Reconocimiento' : 'Activar Reconocimiento',
              icon: Icon(
                isActive ? Icons.graphic_eq : Icons.mic_off,
                color: isActive ? const Color(0xFFF59E0B) : Colors.white38,
                size: 22,
              ),
              onPressed: tuner.toggleChordRecognition,
            ),
            IconButton(
              tooltip: 'Abrir Radar y Voicing Polifónico',
              icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
              onPressed: () => ChordAnalyzerModal.show(context, tuner),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGuidedLessonsContent(TunerViewModel tuner, BuildContext context) {
    final hasLesson = tuner.hasActiveGuidedLesson;
    final progress = tuner.activeLessonProgress;
    final lessonTitle = hasLesson && progress != null ? progress.lesson.title : 'SIN LECCIÓN ACTIVA';
    final accuracy = hasLesson && progress != null ? '${(progress.totalAccumulatedAccuracy * 100).toStringAsFixed(0)}%' : '--%';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lessonTitle,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'PRECISIÓN ACÚSTICA: $accuracy',
                style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF10B981)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.school, size: 14, color: Color(0xFF10B981)),
          label: Text(
            hasLesson ? 'VER GUÍA' : 'ELEGIR',
            style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
          ),
          onPressed: () => GuidedLessonsModal.show(context, tuner),
        ),
      ],
    );
  }

  Widget _buildEarTrainerContent(TunerViewModel tuner, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ENTRENAMIENTO A CIEGAS',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Text(
              'Identificación de intervalos auditivos',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.hearing, size: 14),
          label: const Text('ENTRENAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          onPressed: () => BlindEarTrainerModal.show(context, tuner),
        ),
      ],
    );
  }
}
