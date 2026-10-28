import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../tuner_viewmodel.dart';
import '../../sheet_music/presentation/real_sheet_music_painter.dart';
import '../../song_library/presentation/song_decomposer_modal.dart';
import '../../score_editor/presentation/score_editor_modal.dart';
import '../../metronome/presentation/tap_tempo_modal.dart';

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
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.library_music, size: 16, color: palette.primaryAccent),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            viewModel.activePackage.title,
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 16, color: palette.textMutedColor),
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
                    icon: Icon(
                      viewModel.isMetronomePlaying ? Icons.stop_circle : Icons.play_circle_fill,
                      color: viewModel.isMetronomePlaying ? palette.errorPitchColor : palette.secondaryAccent,
                      size: 26,
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
                      color: palette.primaryAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    "BPM",
                    style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    key: const Key('tap_tempo_comp_btn'),
                    onTap: () => TapTempoModal.show(context, viewModel),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: palette.primaryAccent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'TAP',
                        style: TextStyle(
                          color: palette.primaryAccent,
                          fontSize: 9.5,
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

        // Barra de Compases
        if (viewModel.totalMeasures > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous, color: palette.textMutedColor, size: 18),
                  onPressed: () => viewModel.previousMeasure(),
                  tooltip: "Compás Anterior",
                ),
                Text(
                  "Compás ${viewModel.currentMeasureIndex + 1} de ${viewModel.totalMeasures}  (${viewModel.currentMeasureTimeSignature})",
                  style: TextStyle(
                    color: palette.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.skip_next, color: palette.textMutedColor, size: 18),
                  onPressed: () => viewModel.nextMeasure(),
                  tooltip: "Siguiente Compás",
                ),
              ],
            ),
          ),

        // Lienzo del Pentagrama Tipográfico SMuFL
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: palette.staffBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              painter: RealSheetMusicPainter(
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
              ),
              size: Size.infinite,
            ),
          ),
        ),

        // Barra de Transcripción de Audio en Vivo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      viewModel.isLiveTranscriptionActive ? Icons.mic : Icons.mic_none,
                      color: viewModel.isLiveTranscriptionActive ? palette.primaryAccent : palette.textMutedColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      viewModel.isLiveTranscriptionActive
                          ? "Transcripción en vivo activa"
                          : "Transcripción de Audio en Pentagrama",
                      style: TextStyle(
                        color: viewModel.isLiveTranscriptionActive ? palette.primaryAccent : palette.textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: viewModel.isLiveTranscriptionActive,
                  activeTrackColor: palette.primaryAccent,
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
                  avatar: Icon(Icons.edit_note, size: 16, color: palette.primaryAccent),
                  label: const Text('Editor de Partituras'),
                  backgroundColor: palette.cardBackground,
                  labelStyle: TextStyle(
                    color: palette.textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                  onPressed: () => ScoreEditorModal.show(context),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: Icon(Icons.audio_file_outlined, size: 16, color: palette.secondaryAccent),
                  label: const Text('Descomponer Audio'),
                  backgroundColor: palette.cardBackground,
                  labelStyle: TextStyle(
                    color: palette.textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                  onPressed: () => SongDecomposerModal.show(context, viewModel),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: Icon(Icons.equalizer, size: 16, color: palette.textColor),
                  label: const Text('Mezclador Stems'),
                  backgroundColor: palette.cardBackground,
                  labelStyle: TextStyle(
                    color: palette.textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
                  onPressed: onOpenMixerModal,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    viewModel.isScorePlaybackEnabled ? Icons.music_note : Icons.music_off,
                    color: viewModel.isScorePlaybackEnabled ? palette.primaryAccent : palette.textMutedColor,
                    size: 20,
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
