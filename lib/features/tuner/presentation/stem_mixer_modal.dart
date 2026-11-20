import 'package:flutter/material.dart';
import '../../tuner_viewmodel.dart';

/// Modal de consola mezcladora de pistas y stems de acompañamiento (Stems & Metronome Mixer).
class StemMixerModal {
  static void show(BuildContext context, TunerViewModel viewModel) {
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
}
