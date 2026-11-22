import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../media_vault/domain/wav_pcm_codec.dart';
import '../../tuner_viewmodel.dart';
import '../domain/app_tool_item.dart';
import 'app_tool_item_ui_ext.dart';
import '../../tuner/presentation/microphone_calibration_modal.dart';
import '../../tuner/presentation/concert_pitch_selector_modal.dart';
import '../../tuner/presentation/temperament_selector_modal.dart';
import '../../instrument/presentation/instrument_selector_modal.dart';
import '../../pedagogy_report/presentation/pedagogical_report_modal.dart';
import '../../song_library/presentation/song_decomposer_modal.dart';
import '../../dj_console/presentation/dj_console_modal.dart';
import '../../dj_console/presentation/dj_console_view_model.dart';
import '../../harmonic_tutor/presentation/harmonic_tutor_modal.dart';
import '../../harmonic_tutor/presentation/harmonic_tutor_view_model.dart';
import '../../score_editor/presentation/score_editor_modal.dart';
import '../../exercise_generator/presentation/exercise_generator_modal.dart';
import '../../chord_analyzer/presentation/chord_analyzer_modal.dart';
import '../../vocal_autotune/presentation/vocal_autotune_modal.dart';
import '../../metronome/presentation/tap_tempo_modal.dart';
import '../../audio_synthesizer/presentation/instrument_soundfont_selector_modal.dart';

/// Modal predictivo de búsqueda universal (Spotlight Search) para localizar y lanzar
/// cualquier herramienta del software en menos de 2 segundos.
class ToolSearchModal extends StatefulWidget {
  final TunerViewModel viewModel;
  final void Function(int tabIndex)? onNavigateToTab;

  const ToolSearchModal({
    super.key,
    required this.viewModel,
    this.onNavigateToTab,
  });

  static Future<void> show(
    BuildContext context,
    TunerViewModel viewModel, {
    void Function(int tabIndex)? onNavigateToTab,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: ToolSearchModal(
          viewModel: viewModel,
          onNavigateToTab: onNavigateToTab,
        ),
      ),
    );
  }

  @override
  State<ToolSearchModal> createState() => _ToolSearchModalState();
}

class _ToolSearchModalState extends State<ToolSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  List<AppToolItem> _filteredTools = AppToolCatalog.tools;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredTools = AppToolCatalog.searchTools(_searchController.text);
    });
  }

  void _executeTool(AppToolItem tool) {
    final parentContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();

    // 1. Si la herramienta redirige a una pestaña del shell
    if (tool.targetTabIndex != null && widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(tool.targetTabIndex!);
    }

    // 2. Si la herramienta tiene una acción modal asociada
    if (tool.actionId != null && parentContext.mounted) {
      _handleAction(tool.actionId!, parentContext);
    }
  }

  void _handleAction(String actionId, BuildContext hostContext) {
    switch (actionId) {
      case 'open_mic_calibration':
        MicrophoneCalibrationModal.show(hostContext, widget.viewModel);
        break;
      case 'open_concert_pitch':
        ConcertPitchSelectorModal.show(hostContext);
        break;
      case 'open_temperament_selector':
        TemperamentSelectorModal.show(hostContext);
        break;
      case 'open_pedagogical_report':
        PedagogicalReportModal.show(hostContext);
        break;
      case 'open_instrument_selector':
        InstrumentSelectorModal.show(hostContext, widget.viewModel);
        break;
      case 'open_score_importer':
        SongDecomposerModal.show(hostContext, widget.viewModel);
        break;
      case 'open_score_editor':
        ScoreEditorModal.show(hostContext);
        break;
      case 'open_exercise_generator':
        ExerciseGeneratorModal.show(hostContext);
        break;
      case 'open_chord_analyzer':
        ChordAnalyzerModal.show(hostContext, widget.viewModel);
        break;
      case 'open_autotune':
        VocalAutoTuneModal.show(hostContext, widget.viewModel);
        break;
      case 'open_tap_tempo':
        TapTempoModal.show(hostContext, widget.viewModel);
        break;
      case 'open_soundfont_bank':
        InstrumentSoundFontSelectorModal.show(
          hostContext,
          synthService: widget.viewModel.soundFontSynthesizer,
          onPlayPreviewWav: widget.viewModel.audioSynthesizer.playPcmWav,
          onInstrumentSelected: (patch, name) => widget.viewModel.selectSoundFontPatch(patch),
        );
        break;
      case 'focus_metronome':
      case 'open_spectral_comparator':
        widget.onNavigateToTab?.call(1);
        break;
      case 'open_drone_studio':
        widget.onNavigateToTab?.call(3);
        break;
      case 'open_dj_console':
        final djVm = DjConsoleViewModel();
        DjConsoleModal.show(hostContext, djVm, widget.viewModel.currentPalette).whenComplete(djVm.dispose);
        break;
      case 'open_harmonic_tutor':
        final tutorVm = HarmonicTutorViewModel(
          onPlayDroneSamples: (samples, sampleRate) {
            final wavBytes = const WavPcmCodec().encodeMono16Bit(
              Float64List.fromList(samples),
              sampleRate: sampleRate,
            );
            unawaited(widget.viewModel.audioSynthesizer.startDroneLoop(wavBytes));
          },
          onStopDrone: () {
            unawaited(widget.viewModel.audioSynthesizer.stopDroneLoop());
          },
        );
        void onTelemetry() {
          final freq = widget.viewModel.telemetryListenable.value.frequency;
          if (freq > 0.0) {
            tutorVm.onPitchDetected(freq);
          }
        }
        widget.viewModel.telemetryListenable.addListener(onTelemetry);
        HarmonicTutorModal.show(
          hostContext,
          viewModel: tutorVm,
          palette: widget.viewModel.currentPalette,
          isMicrophoneActive: () => widget.viewModel.isRecording,
          onToggleMicrophone: widget.viewModel.toggleRecording,
        ).whenComplete(() {
          widget.viewModel.telemetryListenable.removeListener(onTelemetry);
          tutorVm.dispose();
        });
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.viewModel.currentPalette;

    return Container(
      key: const Key('tool_search_modal'),
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Barra de agarre superior
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: palette.staffLinesColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Campo de búsqueda con icono y botón de limpiar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              key: const Key('universal_search_input'),
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: palette.textColor, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Buscar herramienta, función o ajuste...',
                hintStyle: TextStyle(color: palette.textMutedColor, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: palette.primaryAccent),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: palette.textMutedColor, size: 20),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: palette.cardBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: palette.primaryAccent, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Contador de resultados
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredTools.length} herramientas disponibles',
                  style: TextStyle(color: palette.textMutedColor, fontSize: 12),
                ),
                Text(
                  'Toca para abrir',
                  style: TextStyle(
                    color: palette.secondaryAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: palette.staffLinesColor.withValues(alpha: 0.15), height: 1),

          // Lista de resultados
          Expanded(
            child: _filteredTools.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: palette.textMutedColor),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron herramientas para "${_searchController.text}"',
                          style: TextStyle(color: palette.textMutedColor, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Intenta con términos como "afinar", "lección", "grabar" o "442"',
                          style: TextStyle(
                            color: palette.secondaryAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredTools.length,
                    itemBuilder: (context, index) {
                      final tool = _filteredTools[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: palette.cardBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: palette.staffLinesColor.withValues(alpha: 0.15),
                            ),
                          ),
                          child: ListTile(
                          key: Key('tool_search_item_${tool.id}'),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: palette.primaryAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(tool.icon, color: palette.primaryAccent, size: 22),
                          ),
                          title: Text(
                            tool.title,
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            tool.subtitle,
                            style: TextStyle(color: palette.textMutedColor, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.staffLinesColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tool.category.displayName.split(' ').first,
                              style: TextStyle(
                                color: palette.secondaryAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          onTap: () => _executeTool(tool),
                        ),
                      ),
                    );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
