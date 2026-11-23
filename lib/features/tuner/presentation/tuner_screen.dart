import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design_system/atoms/studio_icon.dart';
import '../../../core/design_system/domain/studio_icon_catalog.dart';
import '../../../core/design_system/studio_design_tokens.dart';
import '../../../core/design_system/studio_theme_provider.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../acoustic_lab/presentation/harmonic_spectrogram_modal.dart';
import '../../audio_synthesizer/presentation/instrument_soundfont_selector_modal.dart';
import '../../chord_analyzer/presentation/chord_analyzer_modal.dart';
import '../../customization/presentation/theme_customization_modal.dart';
import '../../drone/presentation/harmonic_drone_modal.dart';
import '../../exercise_generator/presentation/exercise_generator_modal.dart';
import '../../instrument/presentation/widgets/smart_instrument_badge.dart';
import '../../persistence/domain/app_user_settings_entity.dart';
import '../../practice_evaluator/presentation/practice_report_modal.dart';
import '../../practice_recorder/presentation/practice_recording_player_modal.dart';
import '../../score_editor/presentation/score_editor_modal.dart';
import '../../workspaces/domain/workspace_type.dart';
import '../../workspaces/presentation/composition_notation_workspace_view.dart';
import '../../workspaces/presentation/learning_practice_workspace_view.dart';
import '../../workspaces/presentation/production_acoustic_lab_workspace_view.dart';
import '../../workspaces/presentation/workspace_switch_bar.dart';
import '../domain/temperament_engine.dart';
import 'acoustic_rigor_profile_ui_ext.dart';
import 'concert_pitch_selector_modal.dart';
import 'microphone_calibration_modal.dart';
import 'modals/tuner_instrument_modal.dart';
import 'modals/tuner_library_modal.dart';
import 'modals/tuner_mixer_modal.dart';
import 'temperament_selector_modal.dart';
import 'tuner_viewmodel.dart';
import 'widgets/essential_tuner_panel.dart';

class TunerScreen extends StatelessWidget {
  const TunerScreen({super.key});

  void _showLibraryModal(BuildContext context, TunerViewModel viewModel) {
    TunerLibraryModal.show(context, viewModel);
  }

  void _showCustomizationModal(BuildContext context, TunerViewModel viewModel) {
    ThemeCustomizationModal.show(context, viewModel);
  }

  void _showMixerModal(BuildContext context, TunerViewModel viewModel) {
    TunerMixerModal.show(context, viewModel);
  }

  void _showInstrumentModal(BuildContext context, TunerViewModel viewModel) {
    TunerInstrumentModal.show(context, viewModel);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    final tokens = StudioThemeScope.of(context);
    final palette = viewModel.currentPalette;
    final isEssential = viewModel.isEssentialMode;

    return Scaffold(
      backgroundColor: tokens.canvasBackground,
      appBar: AppBar(
        title: Text(
          isEssential ? 'Tunner' : 'Tunner Pro',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final maxActionsWidth = screenWidth > 200 ? screenWidth - 140 : 200.0;
              return SizedBox(
                width: maxActionsWidth,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: isEssential
                        ? _buildEssentialActions(context, viewModel, tokens, palette)
                        : _buildProActions(context, viewModel, tokens, palette),
                  ),
                ),
              );
            },
          ),
        ],
        bottom: isEssential
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: WorkspaceSwitchBar(
                  activeWorkspace: viewModel.activeWorkspace,
                  onWorkspaceSelected: viewModel.setWorkspace,
                  palette: palette,
                ),
              ),
      ),
      body: isEssential
          ? EssentialTunerPanel(viewModel: viewModel, palette: palette)
          : _buildWorkspaceBody(context, viewModel, palette),
    );
  }

  List<Widget> _buildEssentialActions(
    BuildContext context,
    TunerViewModel viewModel,
    StudioDesignTokens tokens,
    TunnerThemePalette palette,
  ) {
    return [
      _buildConcertPitchChip(context, viewModel, tokens),
      _buildSmartInstrumentBadge(context, viewModel, palette),
      _buildInstrumentSelectorButton(context, viewModel, tokens),
      _buildIsolationButton(
        key: const Key('toggle_instrument_isolation_btn_essential'),
        viewModel: viewModel,
        tokens: tokens,
      ),
      _buildSoundFontButton(
        key: const Key('open_soundfont_modal_btn_essential'),
        context: context,
        viewModel: viewModel,
        tokens: tokens,
      ),
      _buildMicCalibrationButton(
        key: const Key('open_mic_calibration_btn_essential'),
        context: context,
        viewModel: viewModel,
        tokens: tokens,
      ),
      _buildRigorPresetChip(
        key: const Key('essential_rigor_preset_chip'),
        context: context,
        viewModel: viewModel,
        tokens: tokens,
      ),
      _buildTemperamentChip(
        key: const Key('essential_temperament_selector_chip'),
        context: context,
        viewModel: viewModel,
        tokens: tokens,
      ),
      _buildDroneChip(
        key: const Key('essential_drone_modal_btn'),
        context: context,
        viewModel: viewModel,
        tokens: tokens,
      ),
      _buildChordChip(
        key: const Key('essential_chord_modal_btn'),
        context: context,
        viewModel: viewModel,
        tokens: tokens,
      ),
      IconButton(
        key: const Key('toggle_pro_mode_btn'),
        icon: StudioIcon(
          StudioIconId.uiWorkspaceLayout,
          color: tokens.accentSecondary,
          size: 20,
          tintCustomAsset: true,
        ),
        tooltip: 'Cambiar a Modo Conservatorio Pro',
        onPressed: () => viewModel.setDisplayMode(AppDisplayMode.conservatoryPro),
      ),
    ];
  }

  List<Widget> _buildProActions(
    BuildContext context,
    TunerViewModel viewModel,
    StudioDesignTokens tokens,
    TunnerThemePalette palette,
  ) {
    return [
      IconButton(
        key: const Key('toggle_essential_mode_btn'),
        icon: StudioIcon(
          StudioIconId.uiAutomations,
          color: tokens.accentPrimary,
          size: 20,
          tintCustomAsset: true,
        ),
        tooltip: 'Cambiar a Modo Esencial (Afinador Rápido)',
        onPressed: () => viewModel.setDisplayMode(AppDisplayMode.essential),
      ),
      _buildConcertPitchChip(context, viewModel, tokens),
      _buildTemperamentChip(
        key: const Key('pro_temperament_selector_chip'),
        context: context,
        viewModel: viewModel,
        tokens: tokens,
      ),
      _buildDroneChip(
        key: const Key('pro_drone_modal_btn'),
        context: context,
        viewModel: viewModel,
        tokens: tokens,
      ),
      _buildChordChip(
        key: const Key('pro_chord_modal_btn'),
        context: context,
        viewModel: viewModel,
        tokens: tokens,
      ),
      _buildSmartInstrumentBadge(context, viewModel, palette),
      _buildInstrumentSelectorButton(context, viewModel, tokens),
      _buildIsolationButton(
        key: const Key('toggle_instrument_isolation_btn_pro'),
        viewModel: viewModel,
        tokens: tokens,
      ),
      _buildSoundFontButton(
        key: const Key('open_soundfont_modal_btn_pro'),
        context: context,
        viewModel: viewModel,
        tokens: tokens,
      ),
      _buildMicCalibrationButton(
        key: const Key('open_mic_calibration_btn_pro'),
        context: context,
        viewModel: viewModel,
        tokens: tokens,
      ),
      _buildRigorPresetChip(
        key: const Key('pro_rigor_preset_chip'),
        context: context,
        viewModel: viewModel,
        tokens: tokens,
      ),
      if (viewModel.lastReport != null)
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.accentPrimary.withValues(alpha: 0.2),
              border: Border.all(color: tokens.accentPrimary, width: 1.2),
            ),
            child: StudioIcon(
              StudioIconId.modulePedagogy,
              color: tokens.accentPrimary,
              size: 16,
              tintCustomAsset: true,
            ),
          ),
          tooltip: 'Ver Analítica de la Última Sesión',
          onPressed: () {
            PracticeReportModal.show(
              context: context,
              report: viewModel.lastReport!,
              palette: palette,
              onRetry: () => viewModel.startSongWithCountIn(),
            );
          },
        ),
      if (viewModel.activeRecording != null)
        IconButton(
          icon: StudioIcon(
            StudioIconId.audioHeadphones,
            color: tokens.accentPrimary,
            size: 20,
            tintCustomAsset: true,
          ),
          tooltip: 'Reproductor de Auto-Escucha (Toma lista)',
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const PracticeRecordingPlayerModal(),
            );
          },
        ),
      IconButton(
        icon: StudioIcon(
          StudioIconId.fileMusicXmlMidi,
          color: viewModel.isScorePlaybackEnabled ? tokens.accentPrimary : tokens.textMuted,
          size: 20,
          tintCustomAsset: true,
        ),
        tooltip: viewModel.isScorePlaybackEnabled
            ? 'Audio de Partitura Activado'
            : 'Audio de Partitura Desactivado (Minus One)',
        onPressed: viewModel.toggleScorePlayback,
      ),
      IconButton(
        icon: StudioIcon(
          StudioIconId.moduleScoreSheet,
          color: tokens.accentPrimary,
          size: 20,
          tintCustomAsset: true,
        ),
        tooltip: 'Biblioteca & Descompositor de Canciones',
        onPressed: () => _showLibraryModal(context, viewModel),
      ),
      IconButton(
        icon: StudioIcon(
          StudioIconId.moduleTuner,
          color: tokens.accentSecondary,
          size: 20,
          tintCustomAsset: true,
        ),
        tooltip: 'Consola Mezcladora de Pistas (Stems)',
        onPressed: () => _showMixerModal(context, viewModel),
      ),
      IconButton(
        icon: StudioIcon(
          StudioIconId.uiCustomizations,
          color: tokens.textPrimary,
          size: 20,
          tintCustomAsset: true,
        ),
        tooltip: 'Personalización Estética y Compás',
        onPressed: () => _showCustomizationModal(context, viewModel),
      ),
      IconButton(
        icon: StudioIcon(
          viewModel.isLiveTranscriptionActive
              ? StudioIconId.audioMicOn
              : StudioIconId.audioMicOff,
          color: viewModel.isLiveTranscriptionActive ? tokens.accentDanger : tokens.textPrimary,
          size: 20,
          tintCustomAsset: true,
        ),
        tooltip: viewModel.isLiveTranscriptionActive
            ? 'Detener Transcripción en Vivo'
            : 'Iniciar Transcripción de Micrófono a Partitura',
        onPressed: () {
          viewModel.toggleLiveTranscription();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                viewModel.isLiveTranscriptionActive
                    ? 'Transcripción acústica en vivo iniciada: toca tu instrumento'
                    : 'Transcripción acústica finalizada y volcada a la partitura',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
      IconButton(
        icon: StudioIcon(
          StudioIconId.moduleScoreEditor,
          color: tokens.textPrimary,
          size: 20,
          tintCustomAsset: true,
        ),
        tooltip: 'Editor de Partituras SMuFL & Exportación',
        onPressed: () => ScoreEditorModal.show(context),
      ),
      IconButton(
        icon: StudioIcon(
          StudioIconId.moduleSpectrogram,
          color: tokens.textPrimary,
          size: 20,
          tintCustomAsset: true,
        ),
        tooltip: 'Laboratorio de Armónicos y Timbre',
        onPressed: () => HarmonicSpectrogramModal.show(context),
      ),
      IconButton(
        icon: StudioIcon(
          StudioIconId.uiAutomations,
          color: tokens.textPrimary,
          size: 20,
          tintCustomAsset: true,
        ),
        tooltip: 'Generador Algorítmico de Ejercicios y Escalas',
        onPressed: () => ExerciseGeneratorModal.show(context),
      ),
    ];
  }

  Widget _buildConcertPitchChip(
    BuildContext context,
    TunerViewModel viewModel,
    StudioDesignTokens tokens,
  ) {
    final isNonStandard = (viewModel.referencePitch - 440.0).abs() > 0.1;
    return GestureDetector(
      onTap: () => ConcertPitchSelectorModal.show(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isNonStandard ? tokens.accentSecondary : tokens.borderHairline,
            width: isNonStandard ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A4',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${viewModel.referencePitch.toStringAsFixed(1)}Hz',
              style: TextStyle(
                color: isNonStandard ? tokens.accentSecondary : tokens.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartInstrumentBadge(
    BuildContext context,
    TunerViewModel viewModel,
    TunnerThemePalette palette,
  ) {
    return SmartInstrumentBadge(
      isSmartTuningActive: viewModel.isSmartInstrumentTuningActive,
      autoSwitchEnabled: viewModel.autoSwitchInstrumentEnabled,
      match: viewModel.lastDetectedMatch,
      activeInstrument: viewModel.activeInstrument,
      palette: palette,
      onToggleSmartTuning: viewModel.toggleSmartInstrumentTuning,
      onToggleAutoSwitch: viewModel.toggleAutoSwitchInstrument,
      onApplyMatch: viewModel.applyDetectedInstrumentMatch,
      onDismissMatch: viewModel.dismissSmartInstrumentMatch,
      onOpenSelector: () => _showInstrumentModal(context, viewModel),
    );
  }

  Widget _buildInstrumentSelectorButton(
    BuildContext context,
    TunerViewModel viewModel,
    StudioDesignTokens tokens,
  ) {
    return IconButton(
      icon: StudioIcon(
        StudioIconId.modulePianoRoll,
        color: tokens.accentSecondary,
        size: 20,
        tintCustomAsset: true,
      ),
      tooltip: 'Seleccionar Instrumento (${viewModel.activeInstrument.name})',
      onPressed: () => _showInstrumentModal(context, viewModel),
    );
  }

  Widget _buildIsolationButton({
    required Key key,
    required TunerViewModel viewModel,
    required StudioDesignTokens tokens,
  }) {
    final active = viewModel.isInstrumentIsolationActive;
    return IconButton(
      key: key,
      icon: StudioIcon(
        StudioIconId.uiLock,
        color: active ? tokens.accentPrimary : tokens.textMuted,
        size: 20,
        tintCustomAsset: true,
      ),
      tooltip: active
          ? 'Aislamiento Acústico Activo (${viewModel.activeInstrument.name}: filtra ruidos y voz)'
          : 'Aislamiento Acústico Desactivado (modo abierto)',
      onPressed: () => viewModel.toggleInstrumentIsolation(),
    );
  }

  Widget _buildSoundFontButton({
    required Key key,
    required BuildContext context,
    required TunerViewModel viewModel,
    required StudioDesignTokens tokens,
  }) {
    return IconButton(
      key: key,
      icon: StudioIcon(
        StudioIconId.filePreset,
        color: tokens.accentPrimary,
        size: 20,
        tintCustomAsset: true,
      ),
      tooltip: 'Timbres Acústicos SoundFont SF2',
      onPressed: () => InstrumentSoundFontSelectorModal.show(
        context,
        synthService: viewModel.soundFontSynthesizer,
        onPlayPreviewWav: viewModel.audioSynthesizer.playPcmWav,
        onInstrumentSelected: (patch, name) {
          viewModel.selectSoundFontPatch(patch);
        },
      ),
    );
  }

  Widget _buildMicCalibrationButton({
    required Key key,
    required BuildContext context,
    required TunerViewModel viewModel,
    required StudioDesignTokens tokens,
  }) {
    return IconButton(
      key: key,
      icon: StudioIcon(
        StudioIconId.audioMicOn,
        color: tokens.accentSecondary,
        size: 20,
        tintCustomAsset: true,
      ),
      tooltip: 'Calibración y Adaptación de Micrófono',
      onPressed: () => MicrophoneCalibrationModal.show(context, viewModel),
    );
  }

  Widget _buildRigorPresetChip({
    required Key key,
    required BuildContext context,
    required TunerViewModel viewModel,
    required StudioDesignTokens tokens,
  }) {
    return GestureDetector(
      key: key,
      onTap: () => MicrophoneCalibrationModal.show(context, viewModel),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: tokens.accentSecondary.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudioIcon(
              StudioIconId.uiSettings,
              size: 13,
              color: tokens.accentSecondary,
              tintCustomAsset: true,
              fallbackOverride: viewModel.acousticRigorProfile.preset.icon,
            ),
            const SizedBox(width: 4),
            Text(
              viewModel.acousticRigorProfile.preset.displayName.split(' ').first,
              style: TextStyle(
                color: tokens.accentSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperamentChip({
    required Key key,
    required BuildContext context,
    required TunerViewModel viewModel,
    required StudioDesignTokens tokens,
  }) {
    final isHistorical = viewModel.selectedTemperament.id != 'equal';
    return GestureDetector(
      key: key,
      onTap: () => TemperamentSelectorModal.show(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tokens.panelBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHistorical ? tokens.accentPrimary : tokens.borderHairline,
            width: isHistorical ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudioIcon(
              StudioIconId.moduleTuner,
              size: 13,
              color: isHistorical ? tokens.accentPrimary : tokens.textMuted,
              tintCustomAsset: true,
            ),
            const SizedBox(width: 4),
            Text(
              isHistorical
                  ? '${viewModel.selectedTemperament.name.split(' ').first} (${TemperamentEngine.chromaticNoteNames[viewModel.temperamentRootKey]})'
                  : '12-EDO',
              style: TextStyle(
                color: isHistorical ? tokens.accentPrimary : tokens.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDroneChip({
    required Key key,
    required BuildContext context,
    required TunerViewModel viewModel,
    required StudioDesignTokens tokens,
  }) {
    final active = viewModel.isDronePlaying;
    return GestureDetector(
      key: key,
      onTap: () => HarmonicDroneModal.show(context, viewModel),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? tokens.accentPrimary.withValues(alpha: 0.2) : tokens.panelBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? tokens.accentPrimary : tokens.borderHairline,
            width: active ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudioIcon(
              StudioIconId.moduleDrone,
              size: 13,
              color: active ? tokens.accentPrimary : tokens.textMuted,
              tintCustomAsset: true,
            ),
            const SizedBox(width: 4),
            Text(
              active ? 'Dron: ${viewModel.droneConfig.rootDisplayName}' : 'Dron',
              style: TextStyle(
                color: active ? tokens.accentPrimary : tokens.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChordChip({
    required Key key,
    required BuildContext context,
    required TunerViewModel viewModel,
    required StudioDesignTokens tokens,
  }) {
    final active = viewModel.isChordRecognitionActive;
    return GestureDetector(
      key: key,
      onTap: () => ChordAnalyzerModal.show(context, viewModel),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? tokens.accentSecondary.withValues(alpha: 0.2) : tokens.panelBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? tokens.accentSecondary : tokens.borderHairline,
            width: active ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudioIcon(
              StudioIconId.moduleChordAnalyzer,
              size: 13,
              color: active ? tokens.accentSecondary : tokens.textMuted,
              tintCustomAsset: true,
            ),
            const SizedBox(width: 4),
            Text(
              active && viewModel.recognizedChord.isRecognized
                  ? 'Acorde: ${viewModel.recognizedChord.symbol}'
                  : 'Acordes',
              style: TextStyle(
                color: active ? tokens.accentSecondary : tokens.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceBody(
    BuildContext context,
    TunerViewModel viewModel,
    TunnerThemePalette palette,
  ) {
    switch (viewModel.activeWorkspace) {
      case WorkspaceType.learning:
        return LearningPracticeWorkspaceView(
          viewModel: viewModel,
          palette: palette,
          onOpenInstrumentModal: () => _showInstrumentModal(context, viewModel),
        );
      case WorkspaceType.composition:
        return CompositionNotationWorkspaceView(
          viewModel: viewModel,
          palette: palette,
          onOpenLibraryModal: () => _showLibraryModal(context, viewModel),
          onOpenMixerModal: () => _showMixerModal(context, viewModel),
        );
      case WorkspaceType.production:
        return ProductionAcousticLabWorkspaceView(
          viewModel: viewModel,
          palette: palette,
          onOpenMixerModal: () => _showMixerModal(context, viewModel),
        );
    }
  }
}
