import 'package:flutter/material.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../tuner_viewmodel.dart';
import '../../tuner/presentation/strobe_tuner_widget.dart';
import '../../pedagogy_profiles/presentation/learner_profile_selector_modal.dart';
import '../../pedagogy_report/presentation/pedagogical_report_modal.dart';
import '../../exercise_generator/presentation/exercise_generator_modal.dart';
import '../../drone/presentation/harmonic_drone_modal.dart';
import '../../metronome/presentation/tap_tempo_modal.dart';
import '../../practice_recorder/presentation/practice_recorder_dock.dart';
import '../../practice_recorder/presentation/spectral_comparator_modal.dart';
import '../../guided_lessons/presentation/guided_lessons_modal.dart';
import '../../vocal_autotune/presentation/vocal_autotune_modal.dart';

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
    final tokens = StudioThemeScope.of(context);
    final displayNote = viewModel.hasTransposition
        ? (viewModel.writtenNoteName.isEmpty ? "--" : viewModel.writtenNoteName)
        : (viewModel.noteName.isEmpty ? "--" : viewModel.noteName);
    final cents = viewModel.cents;
    final isListening = viewModel.isRecording;
    final effectiveTol = viewModel.centsTolerance;
    final isInTune = cents.abs() <= effectiveTol && viewModel.frequency > 0;
    final centsColor = isInTune
        ? tokens.accentSuccess
        : (cents.abs() <= effectiveTol * 1.5
            ? tokens.accentWarning
            : tokens.accentDanger);

    final diagnostic = viewModel.lastPedagogicalDiagnostic;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Perfil Pedagógico, Andamiaje y CTA Rápido de Micrófono
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    StudioIcon(
                      StudioIconId.modulePedagogy,
                      size: 18,
                      color: tokens.accentPrimary,
                      tintCustomAsset: true,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            viewModel.learnerProfile.title,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Tolerancia: ±${viewModel.centsTolerance.toStringAsFixed(1)} cents • ${viewModel.learnerProfile.feedbackStyle.name}",
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      key: const Key('learning_top_quick_start_mic_btn'),
                      onPressed: viewModel.toggleRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isListening
                            ? tokens.accentDanger
                            : tokens.accentPrimary,
                        foregroundColor:
                            isListening ? Colors.white : tokens.textOnAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(tokens.radiusMedium),
                        ),
                      ),
                      icon: StudioIcon(
                        isListening
                            ? StudioIconId.audioMicOff
                            : StudioIconId.audioMicOn,
                        size: 15,
                        color: isListening ? Colors.white : tokens.textOnAccent,
                        tintCustomAsset: true,
                      ),
                      label: Text(
                        isListening ? 'Detener Mic' : 'Iniciar Afinación',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      key: const Key('instrument_selector_chip'),
                      avatar: StudioIcon(
                        StudioIconId.modulePianoRoll,
                        size: 14,
                        color: tokens.accentSecondary,
                        tintCustomAsset: true,
                      ),
                      label: Text(
                        '${viewModel.activeInstrument.name} (${viewModel.activeInstrument.key.displayName})',
                      ),
                      backgroundColor: tokens.elevatedSurface,
                      labelStyle: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      side: BorderSide(color: tokens.borderHairline),
                      onPressed: onOpenInstrumentModal,
                    ),
                    ActionChip(
                      key: const Key('open_learner_profile_chip'),
                      avatar: StudioIcon(
                        StudioIconId.moduleTuner,
                        size: 14,
                        color: tokens.accentPrimary,
                        tintCustomAsset: true,
                      ),
                      label: const Text('Pedagogía'),
                      backgroundColor: tokens.elevatedSurface,
                      labelStyle: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      side: BorderSide(
                          color: tokens.borderFocus.withValues(alpha: 0.45)),
                      onPressed: () => LearnerProfileSelectorModal.show(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tira horizontal compacta de flujo pedagógico en 3 etapas
          SingleChildScrollView(
            key: const Key('learning_three_stage_flow_bar'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStageBadge(
                  badgeKey: const Key('practice_stage_prepare_badge'),
                  label: '1. PREPARAR (Instrumento & Dron)',
                  isActive: !isListening &&
                      !viewModel.isMetronomeActive &&
                      !viewModel.isPracticeMode,
                  accentColor: tokens.accentSecondary,
                  tokens: tokens,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: tokens.textMuted,
                  ),
                ),
                _buildStageBadge(
                  badgeKey: const Key('practice_stage_execute_badge'),
                  label: '2. EJECUTAR (Afinación & Metrónomo)',
                  isActive: isListening || viewModel.isMetronomeActive,
                  accentColor: tokens.accentPrimary,
                  tokens: tokens,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: tokens.textMuted,
                  ),
                ),
                _buildStageBadge(
                  badgeKey: const Key('practice_stage_evaluate_badge'),
                  label: '3. EVALUAR (Grabación & Reporte)',
                  isActive: viewModel.isPracticeMode,
                  accentColor: tokens.accentSuccess,
                  tokens: tokens,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tarjeta Heroica Monumental de la Nota
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: tokens.panelBackground,
              borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
              border: Border.all(
                color: isInTune
                    ? tokens.accentSuccess.withValues(alpha: 0.7)
                    : tokens.borderHairline,
                width: isInTune ? 1.5 : tokens.borderWidth,
              ),
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
                    color: isInTune ? tokens.accentSuccess : tokens.textPrimary,
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
                      color: tokens.elevatedSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Text(
                      "Sonando: ${viewModel.noteName} (Tono Real)",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: tokens.accentSecondary,
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
                    color: tokens.textMuted,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: centsColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(tokens.radiusMedium),
                    border: Border.all(color: centsColor.withValues(alpha: 0.45)),
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
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Afinador Estroboscópico de Alta Precisión
          if (viewModel.workspaceConfiguration.showStrobeTuner) ...[
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
          ],

          // Tarjeta de Diagnóstico Biomecánico Pedagógico en Vivo
          if (diagnostic != null && viewModel.frequency > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: diagnostic.isInTune
                    ? tokens.accentSuccess.withValues(alpha: 0.1)
                    : tokens.accentWarning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(tokens.radiusMedium),
                border: Border.all(
                  color: diagnostic.isInTune
                      ? tokens.accentSuccess.withValues(alpha: 0.35)
                      : tokens.accentWarning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    diagnostic.isInTune ? Icons.check_circle_outline : Icons.lightbulb_outline,
                    color: diagnostic.isInTune ? tokens.accentSuccess : tokens.accentWarning,
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
                                ? tokens.accentSuccess
                                : tokens.accentWarning,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (diagnostic.biomechanicalCue != null)
                          Text(
                            diagnostic.biomechanicalCue!,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 11,
                            ),
                          )
                        else
                          Text(
                            diagnostic.motivationalCue,
                            style: TextStyle(
                              color: tokens.textPrimary,
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
          if (viewModel.workspaceConfiguration.showMetronome) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: tokens.panelBackground,
                borderRadius: BorderRadius.circular(tokens.radiusMedium),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: StudioIcon(
                          viewModel.isMetronomeActive
                              ? StudioIconId.transportStop
                              : StudioIconId.transportPlay,
                          color: viewModel.isMetronomeActive
                              ? tokens.accentDanger
                              : tokens.accentPrimary,
                          size: 20,
                          tintCustomAsset: true,
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
                              color: tokens.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            viewModel.currentTempoMark.italianName.toUpperCase(),
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, color: tokens.textSecondary, size: 18),
                        onPressed: () => viewModel.decrementBpm(1),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: tokens.textSecondary, size: 18),
                        onPressed: () => viewModel.incrementBpm(1),
                      ),
                      InkWell(
                        key: const Key('tap_tempo_modal_btn'),
                        onTap: () => TapTempoModal.show(context, viewModel),
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: tokens.elevatedSurface,
                            borderRadius: BorderRadius.circular(tokens.radiusSmall),
                            border: Border.all(color: tokens.borderHairline),
                          ),
                          child: Text(
                            'TAP',
                            style: TextStyle(
                              color: tokens.accentPrimary,
                              fontSize: 11,
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
            const SizedBox(height: 10),
          ],

          // Fila de Filtros y Evaluación Pedagógica
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  avatar: StudioIcon(
                    StudioIconId.modulePedagogy,
                    size: 14,
                    color: viewModel.isPracticeMode ? tokens.textOnAccent : tokens.accentPrimary,
                    tintCustomAsset: true,
                  ),
                  label: Text(
                    viewModel.isPracticeMode
                        ? "Evaluando (${viewModel.practiceEvaluationsCount})"
                        : "Modo Evaluación",
                  ),
                  selected: viewModel.isPracticeMode,
                  selectedColor: tokens.accentPrimary,
                  backgroundColor: tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: viewModel.isPracticeMode ? tokens.textOnAccent : tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(
                    color: viewModel.isPracticeMode
                        ? tokens.borderFocus
                        : tokens.borderHairline,
                  ),
                  onSelected: (_) => viewModel.togglePracticeMode(),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: StudioIcon(
                    StudioIconId.moduleMetronome,
                    size: 14,
                    color: viewModel.isSmartWaitEnabled ? tokens.textOnAccent : tokens.accentSecondary,
                    tintCustomAsset: true,
                  ),
                  label: const Text("Smart Wait"),
                  selected: viewModel.isSmartWaitEnabled,
                  selectedColor: tokens.accentPrimary,
                  backgroundColor: tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: viewModel.isSmartWaitEnabled ? tokens.textOnAccent : tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(
                    color: viewModel.isSmartWaitEnabled
                        ? tokens.borderFocus
                        : tokens.borderHairline,
                  ),
                  onSelected: (_) => viewModel.toggleSmartWait(),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: const Key('open_guided_lessons_chip'),
                  avatar: StudioIcon(
                    StudioIconId.moduleScoreSheet,
                    size: 14,
                    color: tokens.accentPrimary,
                    tintCustomAsset: true,
                  ),
                  label: Text(
                    viewModel.hasActiveGuidedLesson
                        ? 'Lección: ${viewModel.activeLessonProgress!.lesson.title}'
                        : 'Lecciones Guiadas',
                  ),
                  backgroundColor: viewModel.hasActiveGuidedLesson
                      ? tokens.elevatedSurface
                      : tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(
                    color: viewModel.hasActiveGuidedLesson
                        ? tokens.borderFocus
                        : tokens.borderHairline,
                  ),
                  onPressed: () => GuidedLessonsModal.show(context, viewModel),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: const Key('open_vocal_autotune_chip'),
                  avatar: StudioIcon(
                    StudioIconId.moduleAutotune,
                    size: 14,
                    color: tokens.accentSecondary,
                    tintCustomAsset: true,
                  ),
                  label: Text(
                    viewModel.isAutoTuneActive ? 'AutoTune: ON' : 'Vocal AutoTune',
                  ),
                  backgroundColor: viewModel.isAutoTuneActive
                      ? tokens.elevatedSurface
                      : tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(
                    color: viewModel.isAutoTuneActive
                        ? tokens.borderFocus
                        : tokens.borderHairline,
                  ),
                  onPressed: () => VocalAutoTuneModal.show(context, viewModel),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: const Key('open_spectral_comparator_chip'),
                  avatar: StudioIcon(
                    StudioIconId.moduleSpectrogram,
                    size: 14,
                    color: tokens.accentSecondary,
                    tintCustomAsset: true,
                  ),
                  label: const Text("Comparar Tomas"),
                  backgroundColor: tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(color: tokens.borderHairline),
                  onPressed: () => SpectralComparatorModal.show(context, viewModel),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: const Key('open_pedagogical_report_chip'),
                  avatar: StudioIcon(
                    StudioIconId.fileExportPdf,
                    size: 14,
                    color: tokens.accentPrimary,
                    tintCustomAsset: true,
                  ),
                  label: const Text('Informe PDF'),
                  backgroundColor: tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(color: tokens.borderHairline),
                  onPressed: () => PedagogicalReportModal.show(context),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: const Key('exercise_generator_modal_btn'),
                  avatar: StudioIcon(
                    StudioIconId.uiAutomations,
                    size: 14,
                    color: tokens.accentSecondary,
                    tintCustomAsset: true,
                  ),
                  label: const Text('Generar Ejercicios'),
                  backgroundColor: tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(color: tokens.borderHairline),
                  onPressed: () => ExerciseGeneratorModal.show(context),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  key: const Key('learning_drone_chip'),
                  avatar: StudioIcon(
                    StudioIconId.moduleDrone,
                    size: 14,
                    color: tokens.accentPrimary,
                    tintCustomAsset: true,
                  ),
                  label: Text(
                    viewModel.isDronePlaying
                        ? 'Dron: ${viewModel.droneConfig.rootDisplayName}'
                        : 'Dron Armónico',
                  ),
                  backgroundColor: viewModel.isDronePlaying
                      ? tokens.elevatedSurface
                      : tokens.panelBackground,
                  labelStyle: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(
                    color: viewModel.isDronePlaying
                        ? tokens.borderFocus
                        : tokens.borderHairline,
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
                  ? tokens.accentDanger.withValues(alpha: 0.18)
                  : tokens.accentPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
                side: BorderSide(
                  color: isListening ? tokens.accentDanger : tokens.borderFocus,
                ),
              ),
              icon: StudioIcon(
                isListening ? StudioIconId.audioMicOff : StudioIconId.audioMicOn,
                size: 18,
                color: isListening ? tokens.accentDanger : tokens.textOnAccent,
                tintCustomAsset: true,
              ),
              label: Text(
                isListening ? "DETENER ESCUCHA" : "INICIAR AFINACIÓN",
                style: TextStyle(
                  color: isListening ? tokens.accentDanger : tokens.textOnAccent,
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

  /// Construye una píldora compacta para una etapa del flujo pedagógico.
  Widget _buildStageBadge({
    required Key badgeKey,
    required String label,
    required bool isActive,
    required Color accentColor,
    required StudioDesignTokens tokens,
  }) {
    return Container(
      key: badgeKey,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? accentColor.withValues(alpha: 0.16)
            : tokens.panelBackground,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(
          color: isActive
              ? accentColor.withValues(alpha: 0.65)
              : tokens.borderHairline,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? accentColor : tokens.textSecondary,
          fontSize: 10.5,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
        ),
      ),
    );
  }
}
