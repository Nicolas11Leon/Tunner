import 'package:flutter/material.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../tuner_viewmodel.dart';
import 'polyphonic_synth_modal.dart';
import '../../sheet_music/presentation/real_sheet_music_painter.dart';
import '../../song_library/presentation/song_decomposer_modal.dart';
import '../../score_editor/presentation/score_editor_modal.dart';
import '../../metronome/presentation/tap_tempo_modal.dart';
import '../../audio_synthesizer/presentation/audio_midi_export_modal.dart';

/// Vista especializada para el Modo 2: Composición & Partituras.
/// Enfocada en el lienzo del pentagrama tipográfico SMuFL, transcripción de audio,
/// edición de compases/notas y separación de temas en partitura.
class CompositionNotationWorkspaceView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);

    return Column(
      children: [
        // Encabezado de la Obra y Navegación de Compases
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: InkWell(
                  onTap: onOpenLibraryModal,
                  borderRadius: BorderRadius.circular(tokens.radiusMedium),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

        // Barra de Compases
        if (viewModel.totalMeasures > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: StudioIcon(
                    StudioIconId.transportRewind,
                    color: tokens.textSecondary,
                    size: 16,
                    tintCustomAsset: true,
                  ),
                  onPressed: () => viewModel.previousMeasure(),
                  tooltip: "Compás Anterior",
                ),
                Text(
                  "Compás ${viewModel.currentMeasureIndex + 1} de ${viewModel.totalMeasures}  (${viewModel.currentMeasureTimeSignature})",
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
                IconButton(
                  icon: StudioIcon(
                    StudioIconId.transportForward,
                    color: tokens.textSecondary,
                    size: 16,
                    tintCustomAsset: true,
                  ),
                  onPressed: () => viewModel.nextMeasure(),
                  tooltip: "Siguiente Compás",
                ),
              ],
            ),
          ),

        // Lienzo del Pentagrama Tipográfico SMuFL
        if (viewModel.workspaceConfiguration.showSheetMusicCanvas)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: tokens.inputSurface,
                borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
                border: Border.all(color: tokens.borderHairline),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
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
                  );

                  return GestureDetector(
                    key: const Key('score_interactive_canvas_gesture'),
                    onTapDown: (details) {
                      final tappedIndex = painter.findNoteIndexAtOffset(
                        details.localPosition,
                        Size(constraints.maxWidth, constraints.maxHeight),
                      );
                      if (tappedIndex != null) {
                        viewModel.selectAndPreviewScoreNote(tappedIndex);
                      } else {
                        viewModel.clearSelectedScoreNote();
                      }
                    },
                    child: CustomPaint(
                      painter: painter,
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  );
                },
              ),
            ),
          ),

        // Barra de Transcripción de Audio en Vivo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    Text(
                      viewModel.isLiveTranscriptionActive
                          ? "Transcripción en vivo activa"
                          : "Transcripción de Audio en Pentagrama",
                      style: TextStyle(
                        color: viewModel.isLiveTranscriptionActive
                            ? tokens.accentPrimary
                            : tokens.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: viewModel.isLiveTranscriptionActive,
                  activeTrackColor: tokens.accentPrimary,
                  onChanged: (_) => viewModel.toggleLiveTranscription(),
                ),
              ],
            ),
          ),
        ),

        // Barra de Herramientas de Composición y Exportación
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
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
                  onPressed: onOpenMixerModal,
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
  }
}
