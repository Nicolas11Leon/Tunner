import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../tuner_viewmodel.dart';
import '../../tuner/presentation/strobe_tuner_widget.dart';
import '../../pedagogy_profiles/presentation/learner_profile_selector_modal.dart';
import '../../pedagogy_report/presentation/pedagogical_report_modal.dart';
import '../../exercise_generator/presentation/exercise_generator_modal.dart';
import '../../drone/presentation/harmonic_drone_modal.dart';
import '../../metronome/presentation/tap_tempo_modal.dart';
import '../../practice_recorder/presentation/practice_recorder_dock.dart';
import '../../practice_recorder/presentation/spectral_comparator_modal.dart';

/// Vista especializada para el Modo 1: Práctica & Aprendizaje.
/// Enfocada 100% en el instrumentista/estudiante: afinador estroboscópico,
/// metrónomo anti-bleed, andamiaje pedagógico adaptativo y reportes.
class LearningPracticeWorkspaceView extends StatelessWidget {
  final TunerViewModel viewModel;
  final TunnerThemePalette palette;
  final VoidCallback onOpenInstrumentModal;

  const LearningPracticeWorkspaceView({
    super.key,
    required this.viewModel,
    required this.palette,
    required this.onOpenInstrumentModal,
  });

  @override
  Widget build(BuildContext context) {
    final displayNote = viewModel.hasTransposition
        ? (viewModel.writtenNoteName.isEmpty ? "--" : viewModel.writtenNoteName)
        : (viewModel.noteName.isEmpty ? "--" : viewModel.noteName);
    final cents = viewModel.cents;
    final isListening = viewModel.isRecording;
    final effectiveTol = viewModel.centsTolerance;
    final isInTune = cents.abs() <= effectiveTol && viewModel.frequency > 0;
    final centsColor = isInTune
        ? palette.correctPitchColor
        : (cents.abs() <= effectiveTol * 1.5 ? palette.secondaryAccent : palette.errorPitchColor);

    final diagnostic = viewModel.lastPedagogicalDiagnostic;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Perfil Pedagógico y Andamiaje
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.psychology_outlined, size: 18, color: palette.primaryAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              viewModel.learnerProfile.title,
                              style: TextStyle(
                                color: palette.textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Tolerancia: ±${viewModel.centsTolerance.toStringAsFixed(1)} cents • ${viewModel.learnerProfile.feedbackStyle.name}",
                              style: TextStyle(
                                color: palette.textMutedColor,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ActionChip(
                      key: const Key('instrument_selector_chip'),
                      avatar: Icon(Icons.piano, size: 14, color: palette.secondaryAccent),
                      label: Text(
                        '${viewModel.activeInstrument.name} (${viewModel.activeInstrument.key.displayName})',
                      ),
                      backgroundColor: palette.cardBackground,
                      labelStyle: TextStyle(
                        color: palette.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                      onPressed: onOpenInstrumentModal,
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      key: const Key('open_learner_profile_chip'),
                      avatar: Icon(Icons.tune, size: 14, color: palette.primaryAccent),
                      label: const Text('Pedagogía'),
                      backgroundColor: palette.primaryAccent.withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        color: palette.primaryAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      side: BorderSide(color: palette.primaryAccent.withValues(alpha: 0.3)),
                      onPressed: () => LearnerProfileSelectorModal.show(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tarjeta Heroica Monumental de la Nota
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isInTune
                    ? palette.correctPitchColor.withValues(alpha: 0.6)
                    : palette.staffLinesColor.withValues(alpha: 0.2),
                width: isInTune ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isInTune
                      ? palette.correctPitchColor.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayNote,
                  key: const Key('essential_note_display'),
                  style: TextStyle(
                    fontSize: 68,
                    fontWeight: FontWeight.w900,
                    color: isInTune ? palette.correctPitchColor : palette.textColor,
                    letterSpacing: -1,
                    fontFamily: 'monospace',
                  ),
                ),
                if (viewModel.hasTransposition &&
                    viewModel.frequency > 0 &&
                    viewModel.noteName.isNotEmpty &&
                    viewModel.noteName != "--") ...[
                  const SizedBox(height: 2),
                  Container(
                    key: const Key('essential_sounding_badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: palette.secondaryAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.secondaryAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      "Sonando: ${viewModel.noteName} (Tono Real)",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: palette.secondaryAccent,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  viewModel.frequency > 0
                      ? "${viewModel.frequency.toStringAsFixed(1)} Hz"
                      : "-- Hz",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: palette.textMutedColor,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: centsColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: centsColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    viewModel.frequency > 0
                        ? (isInTune
                            ? "AFINADO (${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents)"
                            : "${cents >= 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents")
                        : "ESPERANDO AUDIO",
                    style: TextStyle(
                      color: centsColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Afinador Estroboscópico de Alta Precisión
          StrobeTunerWidget(
            cents: viewModel.cents,
            frequency: viewModel.frequency,
            noteName: viewModel.hasTransposition ? viewModel.writtenNoteName : viewModel.noteName,
            soundingNoteName: viewModel.hasTransposition ? viewModel.noteName : null,
            isRecording: viewModel.isRecording,
            onPlayReferenceTone: () => viewModel.playReferenceTone("La4"),
            palette: palette,
            centsTolerance: viewModel.centsTolerance,
          ),
          const SizedBox(height: 10),

          // Tarjeta de Diagnóstico Biomecánico Pedagógico en Vivo
          if (diagnostic != null && viewModel.frequency > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: diagnostic.isInTune
                    ? palette.correctPitchColor.withValues(alpha: 0.1)
                    : palette.secondaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: diagnostic.isInTune
                      ? palette.correctPitchColor.withValues(alpha: 0.3)
                      : palette.secondaryAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    diagnostic.isInTune ? Icons.check_circle_outline : Icons.lightbulb_outline,
                    color: diagnostic.isInTune ? palette.correctPitchColor : palette.secondaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          diagnostic.primaryFeedback,
                          style: TextStyle(
                            color: diagnostic.isInTune
                                ? palette.correctPitchColor
                                : palette.secondaryAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (diagnostic.biomechanicalCue != null)
                          Text(
                            diagnostic.biomechanicalCue!,
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 11,
                            ),
                          )
                        else
                          Text(
                            diagnostic.motivationalCue,
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),

          // Barra de Metrónomo Compacto (Clean-Tick Anti-Bleed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        viewModel.isMetronomeActive ? Icons.stop_circle : Icons.play_circle_fill,
                        color: viewModel.isMetronomeActive ? palette.errorPitchColor : palette.primaryAccent,
                        size: 28,
                      ),
                      onPressed: viewModel.toggleMetronome,
                      tooltip: viewModel.isMetronomeActive ? "Detener Metrónomo" : "Iniciar Metrónomo",
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${viewModel.bpm} BPM",
                          style: TextStyle(
                            color: palette.primaryAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          viewModel.currentTempoMark.italianName.toUpperCase(),
                          style: TextStyle(
                            color: palette.secondaryAccent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, color: palette.textMutedColor, size: 18),
                      onPressed: () => viewModel.decrementBpm(1),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: palette.textMutedColor, size: 18),
                      onPressed: () => viewModel.incrementBpm(1),
                    ),
                    InkWell(
                      key: const Key('tap_tempo_modal_btn'),
                      onTap: () => TapTempoModal.show(context, viewModel),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: palette.primaryAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.primaryAccent.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'TAP',
                          style: TextStyle(
                            color: palette.primaryAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Fila de Filtros y Evaluación Pedagógica
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  avatar: Icon(
                    viewModel.isPracticeMode ? Icons.school : Icons.school_outlined,
                    size: 15,
                    color: viewModel.isPracticeMode ? Colors.black : palette.primaryAccent,
                  ),
                  label: Text(
                    viewModel.isPracticeMode
                        ? "Evaluando (${viewModel.practiceEvaluationsCount})"
                        : "Modo Evaluación",
                  ),
                  selected: viewModel.isPracticeMode,
                  selectedColor: palette.primaryAccent,
                  backgroundColor: palette.cardBackground,
                  labelStyle: TextStyle(
                    color: viewModel.isPracticeMode ? Colors.black : palette.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(
                    color: viewModel.isPracticeMode
                        ? palette.primaryAccent
                        : palette.staffLinesColor.withValues(alpha: 0.3),
                  ),
                  onSelected: (_) => viewModel.togglePracticeMode(),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: Icon(
                    Icons.hourglass_top_rounded,
                    size: 15,
                    color: viewModel.isSmartWaitEnabled ? Colors.black : palette.secondaryAccent,
                  ),
                  label: const Text("Smart Wait"),
                  selected: viewModel.isSmartWaitEnabled,
                  selectedColor: palette.secondaryAccent,
                  backgroundColor: palette.cardBackground,
                  labelStyle: TextStyle(
                    color: viewModel.isSmartWaitEnabled ? Colors.black : palette.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(
                    color: viewModel.isSmartWaitEnabled
                        ? palette.secondaryAccent
                        : palette.staffLinesColor.withValues(alpha: 0.3),
                  ),
                  onSelected: (_) => viewModel.toggleSmartWait(),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: const Key('open_spectral_comparator_chip'),
                  avatar: Icon(Icons.compare_arrows, size: 15, color: palette.secondaryAccent),
                  label: const Text("Comparar Tomas"),
                  backgroundColor: palette.cardBackground,
                  labelStyle: TextStyle(
                    color: palette.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                  onPressed: () => SpectralComparatorModal.show(context, viewModel),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: const Key('open_pedagogical_report_chip'),
                  avatar: Icon(Icons.picture_as_pdf_outlined, size: 15, color: palette.primaryAccent),
                  label: const Text('Informe PDF'),
                  backgroundColor: palette.cardBackground,
                  labelStyle: TextStyle(
                    color: palette.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                  onPressed: () => PedagogicalReportModal.show(context),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: const Key('exercise_generator_modal_btn'),
                  avatar: Icon(Icons.fitness_center_outlined, size: 15, color: palette.secondaryAccent),
                  label: const Text('Generar Ejercicios'),
                  backgroundColor: palette.cardBackground,
                  labelStyle: TextStyle(
                    color: palette.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                  onPressed: () => ExerciseGeneratorModal.show(context),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: const Key('learning_drone_chip'),
                  avatar: Icon(Icons.waves, size: 15, color: palette.primaryAccent),
                  label: Text(
                    viewModel.isDronePlaying
                        ? 'Dron: ${viewModel.droneConfig.rootDisplayName}'
                        : 'Dron Armónico',
                  ),
                  backgroundColor: viewModel.isDronePlaying
                      ? palette.primaryAccent.withValues(alpha: 0.2)
                      : palette.cardBackground,
                  labelStyle: TextStyle(
                    color: viewModel.isDronePlaying ? palette.primaryAccent : palette.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(
                    color: viewModel.isDronePlaying
                        ? palette.primaryAccent
                        : palette.staffLinesColor.withValues(alpha: 0.3),
                  ),
                  onPressed: () => HarmonicDroneModal.show(context, viewModel),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Dock de Grabación de Práctica
          const PracticeRecorderDock(),
          const SizedBox(height: 12),

          // Botón Flotante Central de Micrófono
          Center(
            child: FloatingActionButton.extended(
              key: const Key('essential_mic_toggle_btn'),
              onPressed: viewModel.toggleRecording,
              backgroundColor: isListening
                  ? palette.errorPitchColor.withValues(alpha: 0.2)
                  : palette.primaryAccent,
              elevation: 3,
              icon: Icon(
                isListening ? Icons.mic_off : Icons.mic,
                color: isListening ? palette.errorPitchColor : Colors.black,
              ),
              label: Text(
                isListening ? "DETENER ESCUCHA" : "INICIAR AFINACIÓN",
                style: TextStyle(
                  color: isListening ? palette.errorPitchColor : Colors.black,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
