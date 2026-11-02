import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'tuner_viewmodel.dart';
import 'tuner/presentation/strobe_tuner_widget.dart';
import 'song_library/presentation/song_decomposer_modal.dart';
import 'practice_evaluator/presentation/practice_report_modal.dart';
import 'instrument/domain/instrument_profile_entity.dart';
import 'customization/presentation/theme_customization_modal.dart';
import 'practice_recorder/presentation/practice_recording_player_modal.dart';
import 'tuner/presentation/concert_pitch_selector_modal.dart';
import 'tuner/presentation/temperament_selector_modal.dart';
import 'tuner/domain/temperament_engine.dart';
import 'score_editor/presentation/score_editor_modal.dart';
import 'acoustic_lab/presentation/harmonic_spectrogram_modal.dart';
import 'exercise_generator/presentation/exercise_generator_modal.dart';
import 'persistence/domain/app_user_settings_entity.dart';
import 'drone/presentation/harmonic_drone_modal.dart';
import 'chord_analyzer/presentation/chord_analyzer_modal.dart';
import 'workspaces/domain/workspace_type.dart';
import 'workspaces/presentation/workspace_switch_bar.dart';
import 'workspaces/presentation/learning_practice_workspace_view.dart';
import 'workspaces/presentation/composition_notation_workspace_view.dart';
import 'workspaces/presentation/production_acoustic_lab_workspace_view.dart';
import 'audio_synthesizer/presentation/instrument_soundfont_selector_modal.dart';
import '../core/theme/tunner_theme.dart';

class TunerScreen extends StatelessWidget {
  const TunerScreen({super.key});

  void _showLibraryModal(BuildContext context, TunerViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: viewModel.currentPalette.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final palette = viewModel.currentPalette;
            final library = viewModel.curatedLibrary;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.library_music, color: palette.primaryAccent, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            "BIBLIOTECA & DESCOMPOSITOR",
                            style: TextStyle(
                              color: palette.primaryAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: palette.textMutedColor, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Repertorio curado con pistas separadas (stems) y carga personalizada",
                    style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                  ),
                  const SizedBox(height: 16),

                  // Botón destacado para subir / descomponer canción externa
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      SongDecomposerModal.show(context, viewModel);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: palette.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.primaryAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.file_upload_outlined, color: palette.primaryAccent, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Subir & Descomponer Canción",
                                  style: TextStyle(color: palette.primaryAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "Carga un archivo local (MIDI / MusicXML) y aísla sus instrumentos",
                                  style: TextStyle(color: palette.textMutedColor, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, color: palette.primaryAccent, size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lista del repertorio curado
                  Text("Repertorio Clásico & Popular", style: TextStyle(color: palette.textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),

                  ...library.map((pkg) {
                    final isCurrent = viewModel.activePackage.id == pkg.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: palette.staffBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isCurrent ? palette.secondaryAccent : Colors.white10),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: isCurrent ? palette.secondaryAccent.withValues(alpha: 0.2) : Colors.white10,
                          child: Icon(Icons.music_note, color: isCurrent ? palette.secondaryAccent : palette.textColor, size: 18),
                        ),
                        title: Text(
                          pkg.title,
                          style: TextStyle(color: palette.textColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${pkg.composer} • ${pkg.tracks.length} Pistas • ${pkg.defaultBpm} BPM",
                          style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCurrent ? palette.secondaryAccent : palette.primaryAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            viewModel.loadSongPackage(pkg);
                            Navigator.pop(context);
                          },
                          child: Text(
                            isCurrent ? "Activa" : "Cargar",
                            style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomizationModal(BuildContext context, TunerViewModel viewModel) {
    ThemeCustomizationModal.show(context, viewModel);
  }

  void _showMixerModal(BuildContext context, TunerViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: viewModel.currentPalette.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final palette = viewModel.currentPalette;
            final mixer = viewModel.mixerConsole;
            final allTracks = [mixer.metronomeTrack, ...mixer.stems];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.equalizer, color: palette.primaryAccent, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            "CONSOLA MEZCLADORA (STEMS)",
                            style: TextStyle(
                              color: palette.primaryAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: palette.textMutedColor, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Balance independiente de metrónomo y pistas de acompañamiento",
                    style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                  ),
                  const SizedBox(height: 16),

                  // Faders de cada canal / stem
                  ...allTracks.map((track) {
                    final isMetro = track.id == "metronome";
                    final iconData = isMetro
                        ? Icons.timer_outlined
                        : (track.instrumentIcon == "mic"
                            ? Icons.mic
                            : (track.instrumentIcon == "piano" ? Icons.piano : Icons.music_note));

                    final effectiveGain = track.getEffectiveGain(hasAnySolo: mixer.hasAnySolo);
                    final isEffectivelySilenced = effectiveGain == 0.0 && track.volume > 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: palette.staffBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: track.isSolo
                              ? palette.secondaryAccent
                              : (track.isMuted ? palette.errorPitchColor.withValues(alpha: 0.4) : Colors.white10),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(iconData, color: isMetro ? palette.primaryAccent : palette.textColor, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    track.title,
                                    style: TextStyle(
                                      color: isEffectivelySilenced ? palette.textMutedColor : palette.textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: isEffectivelySilenced ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  // Botón MUTE (M)
                                  GestureDetector(
                                    onTap: () {
                                      viewModel.toggleTrackMute(track.id);
                                      setModalState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: track.isMuted ? palette.errorPitchColor : Colors.white10,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "M",
                                        style: TextStyle(
                                          color: track.isMuted ? Colors.white : palette.textMutedColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Botón SOLO (S)
                                  GestureDetector(
                                    onTap: () {
                                      viewModel.toggleTrackSolo(track.id);
                                      setModalState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: track.isSolo ? palette.secondaryAccent : Colors.white10,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "S",
                                        style: TextStyle(
                                          color: track.isSolo ? Colors.black : palette.textMutedColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 38,
                                    child: Text(
                                      "${(track.volume * 100).round()}%",
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: isMetro ? palette.primaryAccent : palette.textColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: const SliderThemeData(
                              trackHeight: 3,
                              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                            ),
                            child: Slider(
                              value: track.volume,
                              min: 0.0,
                              max: 1.0,
                              activeColor: isMetro ? palette.primaryAccent : palette.secondaryAccent,
                              inactiveColor: Colors.white10,
                              onChanged: (val) {
                                viewModel.setTrackVolume(track.id, val);
                                setModalState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showInstrumentModal(BuildContext context, TunerViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: viewModel.currentPalette.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final palette = viewModel.currentPalette;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.piano, color: palette.secondaryAccent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        "SELECTOR DE INSTRUMENTO",
                        style: TextStyle(
                          color: palette.secondaryAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: palette.textMutedColor, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Transposición armónica automática de partitura y afinador según la clave del instrumento",
                style: TextStyle(color: palette.textMutedColor, fontSize: 11),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: InstrumentProfileEntity.standardInstruments.length,
                  itemBuilder: (context, index) {
                    final inst = InstrumentProfileEntity.standardInstruments[index];
                    final isSelected = viewModel.activeInstrument.id == inst.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? palette.primaryAccent.withValues(alpha: 0.15)
                            : palette.scaffoldBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? palette.primaryAccent : Colors.white10,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          viewModel.setInstrumentProfile(inst);
                          Navigator.pop(ctx);
                        },
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? palette.primaryAccent
                              : palette.cardBackground,
                          child: Icon(
                            inst.family == InstrumentFamily.brass
                                ? Icons.sports_bar
                                : (inst.family == InstrumentFamily.strings
                                    ? Icons.queue_music
                                    : Icons.music_note),
                            color: isSelected ? Colors.black : palette.primaryAccent,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          inst.name,
                          style: TextStyle(
                            color: palette.textColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${inst.family.displayName} • ${inst.key.displayName} • ${inst.clef.displayName} (${inst.transpositionSemitones >= 0 ? '+' : ''}${inst.transpositionSemitones} st)',
                          style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (inst.isTransposing)
                              IconButton(
                                key: Key('transpose_score_btn_${inst.id}'),
                                icon: Icon(Icons.transform, size: 18, color: palette.secondaryAccent),
                                tooltip: "Transponer partitura a ${inst.name}",
                                onPressed: () {
                                  viewModel.transposeActiveScoreForInstrument(inst);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Partitura transpuesta para ${inst.name}"),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            if (isSelected)
                              Icon(Icons.check_circle, color: palette.primaryAccent),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    final palette = viewModel.currentPalette;
    final isEssential = viewModel.isEssentialMode;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          isEssential ? "Tunner" : "Tunner Pro",
          style: TextStyle(fontWeight: FontWeight.w600, color: palette.textColor, fontSize: 16),
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
                    children: [
                      if (isEssential) ...[
            // En Modo Esencial: Calibración A4, Instrumento y botón para pasar a Modo Pro
            GestureDetector(
              onTap: () => ConcertPitchSelectorModal.show(context),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (viewModel.referencePitch - 440.0).abs() > 0.1
                        ? palette.secondaryAccent
                        : palette.staffLinesColor.withValues(alpha: 0.3),
                    width: (viewModel.referencePitch - 440.0).abs() > 0.1 ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'A4',
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${viewModel.referencePitch.toStringAsFixed(1)}Hz',
                      style: TextStyle(
                        color: (viewModel.referencePitch - 440.0).abs() > 0.1
                            ? palette.secondaryAccent
                            : palette.textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.piano, color: palette.secondaryAccent),
              tooltip: "Seleccionar Instrumento (${viewModel.activeInstrument.name})",
              onPressed: () => _showInstrumentModal(context, viewModel),
            ),
            IconButton(
              key: const Key('open_soundfont_modal_btn_essential'),
              icon: Icon(Icons.library_music_outlined, color: palette.primaryAccent),
              tooltip: "Timbres Acústicos SoundFont SF2",
              onPressed: () => InstrumentSoundFontSelectorModal.show(
                context,
                synthService: viewModel.soundFontSynthesizer,
                onInstrumentSelected: (patch, name) {
                  viewModel.selectSoundFontPatch(patch);
                },
              ),
            ),
            // Chip de Temperamento Histórico en Modo Esencial
            GestureDetector(
              key: const Key('essential_temperament_selector_chip'),
              onTap: () => TemperamentSelectorModal.show(context),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: viewModel.selectedTemperament.id != 'equal'
                        ? palette.primaryAccent
                        : palette.staffLinesColor.withValues(alpha: 0.3),
                    width: viewModel.selectedTemperament.id != 'equal' ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_edu,
                      size: 13,
                      color: viewModel.selectedTemperament.id != 'equal'
                          ? palette.primaryAccent
                          : palette.textMutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      viewModel.selectedTemperament.id == 'equal'
                          ? '12-EDO'
                          : '${viewModel.selectedTemperament.name.split(' ').first} (${TemperamentEngine.chromaticNoteNames[viewModel.temperamentRootKey]})',
                      style: TextStyle(
                        color: viewModel.selectedTemperament.id != 'equal'
                            ? palette.primaryAccent
                            : palette.textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Chip de Dron Armónico en Modo Esencial
            GestureDetector(
              key: const Key('essential_drone_modal_btn'),
              onTap: () => HarmonicDroneModal.show(context, viewModel),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: viewModel.isDronePlaying
                      ? palette.primaryAccent.withValues(alpha: 0.2)
                      : palette.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: viewModel.isDronePlaying
                        ? palette.primaryAccent
                        : palette.staffLinesColor.withValues(alpha: 0.3),
                    width: viewModel.isDronePlaying ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.waves,
                      size: 13,
                      color: viewModel.isDronePlaying ? palette.primaryAccent : palette.textMutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      viewModel.isDronePlaying
                          ? 'Dron: ${viewModel.droneConfig.rootDisplayName}'
                          : 'Dron',
                      style: TextStyle(
                        color: viewModel.isDronePlaying ? palette.primaryAccent : palette.textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Chip de Reconocimiento de Acordes en Modo Esencial
            GestureDetector(
              key: const Key('essential_chord_modal_btn'),
              onTap: () => ChordAnalyzerModal.show(context, viewModel),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: viewModel.isChordRecognitionActive
                      ? palette.secondaryAccent.withValues(alpha: 0.2)
                      : palette.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: viewModel.isChordRecognitionActive
                        ? palette.secondaryAccent
                        : palette.staffLinesColor.withValues(alpha: 0.3),
                    width: viewModel.isChordRecognitionActive ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hub_outlined,
                      size: 13,
                      color: viewModel.isChordRecognitionActive
                          ? palette.secondaryAccent
                          : palette.textMutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      viewModel.isChordRecognitionActive && viewModel.recognizedChord.isRecognized
                          ? 'Acorde: ${viewModel.recognizedChord.symbol}'
                          : 'Acordes',
                      style: TextStyle(
                        color: viewModel.isChordRecognitionActive
                            ? palette.secondaryAccent
                            : palette.textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: const Key('toggle_pro_mode_btn'),
              icon: Icon(Icons.dashboard_customize_outlined, color: palette.secondaryAccent),
              tooltip: "Cambiar a Modo Conservatorio Pro",
              onPressed: () => viewModel.setDisplayMode(AppDisplayMode.conservatoryPro),
            ),
          ] else ...[
            // En Modo Conservatorio Pro: Botón para simplificar a Esencial + herramientas avanzadas
            IconButton(
              key: const Key('toggle_essential_mode_btn'),
              icon: Icon(Icons.flash_on_outlined, color: palette.primaryAccent),
              tooltip: "Cambiar a Modo Esencial (Afinador Rápido)",
              onPressed: () => viewModel.setDisplayMode(AppDisplayMode.essential),
            ),
            // Chip de Calibración de Afinación de Concierto A4
            GestureDetector(
              onTap: () => ConcertPitchSelectorModal.show(context),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (viewModel.referencePitch - 440.0).abs() > 0.1
                        ? palette.secondaryAccent
                        : palette.staffLinesColor.withValues(alpha: 0.3),
                    width: (viewModel.referencePitch - 440.0).abs() > 0.1 ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'A4',
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${viewModel.referencePitch.toStringAsFixed(1)}Hz',
                      style: TextStyle(
                        color: (viewModel.referencePitch - 440.0).abs() > 0.1
                            ? palette.secondaryAccent
                            : palette.textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Chip de Temperamento Histórico en Modo Conservatorio Pro
            GestureDetector(
              key: const Key('pro_temperament_selector_chip'),
              onTap: () => TemperamentSelectorModal.show(context),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: viewModel.selectedTemperament.id != 'equal'
                        ? palette.primaryAccent
                        : palette.staffLinesColor.withValues(alpha: 0.3),
                    width: viewModel.selectedTemperament.id != 'equal' ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_edu,
                      size: 13,
                      color: viewModel.selectedTemperament.id != 'equal'
                          ? palette.primaryAccent
                          : palette.textMutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      viewModel.selectedTemperament.id == 'equal'
                          ? '12-EDO'
                          : '${viewModel.selectedTemperament.name.split(' ').first} (${TemperamentEngine.chromaticNoteNames[viewModel.temperamentRootKey]})',
                      style: TextStyle(
                        color: viewModel.selectedTemperament.id != 'equal'
                            ? palette.primaryAccent
                            : palette.textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Chip de Dron Armónico en Modo Pro
            GestureDetector(
              key: const Key('pro_drone_modal_btn'),
              onTap: () => HarmonicDroneModal.show(context, viewModel),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: viewModel.isDronePlaying
                      ? palette.primaryAccent.withValues(alpha: 0.2)
                      : palette.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: viewModel.isDronePlaying
                        ? palette.primaryAccent
                        : palette.staffLinesColor.withValues(alpha: 0.3),
                    width: viewModel.isDronePlaying ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.waves,
                      size: 13,
                      color: viewModel.isDronePlaying ? palette.primaryAccent : palette.textMutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      viewModel.isDronePlaying
                          ? 'Dron: ${viewModel.droneConfig.rootDisplayName}'
                          : 'Dron',
                      style: TextStyle(
                        color: viewModel.isDronePlaying ? palette.primaryAccent : palette.textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Chip de Reconocimiento de Acordes en Modo Pro
            GestureDetector(
              key: const Key('pro_chord_modal_btn'),
              onTap: () => ChordAnalyzerModal.show(context, viewModel),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: viewModel.isChordRecognitionActive
                      ? palette.secondaryAccent.withValues(alpha: 0.2)
                      : palette.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: viewModel.isChordRecognitionActive
                        ? palette.secondaryAccent
                        : palette.staffLinesColor.withValues(alpha: 0.3),
                    width: viewModel.isChordRecognitionActive ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hub_outlined,
                      size: 13,
                      color: viewModel.isChordRecognitionActive
                          ? palette.secondaryAccent
                          : palette.textMutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      viewModel.isChordRecognitionActive && viewModel.recognizedChord.isRecognized
                          ? 'Acorde: ${viewModel.recognizedChord.symbol}'
                          : 'Acordes',
                      style: TextStyle(
                        color: viewModel.isChordRecognitionActive
                            ? palette.secondaryAccent
                            : palette.textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.piano, color: palette.secondaryAccent),
              tooltip: "Seleccionar Instrumento (${viewModel.activeInstrument.name})",
              onPressed: () => _showInstrumentModal(context, viewModel),
            ),
            IconButton(
              key: const Key('open_soundfont_modal_btn_pro'),
              icon: Icon(Icons.library_music_outlined, color: palette.primaryAccent),
              tooltip: "Timbres Acústicos SoundFont SF2",
              onPressed: () => InstrumentSoundFontSelectorModal.show(
                context,
                synthService: viewModel.soundFontSynthesizer,
                onInstrumentSelected: (patch, name) {
                  viewModel.selectSoundFontPatch(patch);
                },
              ),
            ),
            if (viewModel.lastReport != null)
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.primaryAccent.withValues(alpha: 0.2),
                    border: Border.all(color: palette.primaryAccent, width: 1.2),
                  ),
                  child: Icon(Icons.insights_rounded, color: palette.primaryAccent, size: 18),
                ),
                tooltip: "Ver Analítica de la Última Sesión",
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
                icon: Icon(Icons.headphones_rounded, color: palette.primaryAccent),
                tooltip: "Reproductor de Auto-Escucha (Toma lista)",
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const PracticeRecordingPlayerModal(),
                  );
                },
              ),
            IconButton(
              icon: Icon(
                viewModel.isScorePlaybackEnabled ? Icons.music_note : Icons.music_off,
                color: viewModel.isScorePlaybackEnabled ? palette.primaryAccent : palette.textMutedColor,
              ),
              tooltip: viewModel.isScorePlaybackEnabled
                  ? "Audio de Partitura Activado"
                  : "Audio de Partitura Desactivado (Minus One)",
              onPressed: viewModel.toggleScorePlayback,
            ),
            IconButton(
              icon: Icon(Icons.library_music, color: palette.primaryAccent),
              tooltip: "Biblioteca & Descompositor de Canciones",
              onPressed: () => _showLibraryModal(context, viewModel),
            ),
            IconButton(
              icon: Icon(Icons.equalizer, color: palette.secondaryAccent),
              tooltip: "Consola Mezcladora de Pistas (Stems)",
              onPressed: () => _showMixerModal(context, viewModel),
            ),
            IconButton(
              icon: Icon(Icons.tune, color: palette.textColor),
              tooltip: "Personalización Estética y Compás",
              onPressed: () => _showCustomizationModal(context, viewModel),
            ),
            IconButton(
              icon: Icon(
                viewModel.isLiveTranscriptionActive ? Icons.mic : Icons.mic_none,
                color: viewModel.isLiveTranscriptionActive ? palette.errorPitchColor : palette.textColor,
              ),
              tooltip: viewModel.isLiveTranscriptionActive
                  ? "Detener Transcripción en Vivo"
                  : "Iniciar Transcripción de Micrófono a Partitura",
              onPressed: () {
                viewModel.toggleLiveTranscription();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      viewModel.isLiveTranscriptionActive
                          ? "Transcripción acústica en vivo iniciada: toca tu instrumento"
                          : "Transcripción acústica finalizada y volcada a la partitura",
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.edit_note, color: palette.textColor),
              tooltip: "Editor de Partituras SMuFL & Exportación",
              onPressed: () => ScoreEditorModal.show(context),
            ),
            IconButton(
              icon: Icon(Icons.graphic_eq, color: palette.textColor),
              tooltip: "Laboratorio de Armónicos y Timbre",
              onPressed: () => HarmonicSpectrogramModal.show(context),
            ),
            IconButton(
              icon: Icon(Icons.auto_awesome, color: palette.textColor),
              tooltip: "Generador Algorítmico de Ejercicios y Escalas",
              onPressed: () => ExerciseGeneratorModal.show(context),
            ),
          ],
        ],
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
          ? _buildEssentialModeView(context, viewModel, palette)
          : _buildWorkspaceBody(context, viewModel, palette),
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

  Widget _buildEssentialModeView(
    BuildContext context,
    TunerViewModel viewModel,
    TunnerThemePalette palette,
  ) {
    final displayNote = viewModel.hasTransposition
        ? (viewModel.writtenNoteName.isEmpty ? "--" : viewModel.writtenNoteName)
        : (viewModel.noteName.isEmpty ? "--" : viewModel.noteName);
    final cents = viewModel.cents;
    final isListening = viewModel.isRecording;
    final isInTune = cents.abs() <= 5.0 && viewModel.frequency > 0;
    final centsColor = isInTune
        ? palette.correctPitchColor
        : (cents.abs() <= 15 ? palette.secondaryAccent : palette.errorPitchColor);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // Tarjeta Heroica Monumental de la Nota
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(24),
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
                        : Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
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
                      fontSize: 72,
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
                          fontSize: 12,
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
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: palette.textMutedColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: centsColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
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
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

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
            const SizedBox(height: 16),

            // Barra de Controles Esenciales
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.extended(
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
                    isListening ? "Pausar Escucha" : "Activar Afinador",
                    style: TextStyle(
                      color: isListening ? palette.errorPitchColor : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                OutlinedButton.icon(
                  onPressed: () => viewModel.playReferenceTone("La4"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.secondaryAccent,
                    side: BorderSide(color: palette.secondaryAccent.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.volume_up_outlined, size: 18),
                  label: const Text(
                    "Tono La4",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Acceso Rápido al Modo Pro
            InkWell(
              key: const Key('essential_switch_to_pro_card'),
              onTap: () => viewModel.setDisplayMode(AppDisplayMode.conservatoryPro),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.cardBackground.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_outlined, size: 18, color: palette.secondaryAccent),
                    const SizedBox(width: 8),
                    Text(
                      "Modo Conservatorio Pro (Partituras, Stems, Labs)",
                      style: TextStyle(
                        color: palette.textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 14, color: palette.secondaryAccent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
