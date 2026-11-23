import 'package:flutter/material.dart';

import '../../../../core/design_system/atoms/studio_icon.dart';
import '../../../../core/design_system/domain/studio_icon_catalog.dart';
import '../../../../core/design_system/studio_theme_provider.dart';
import '../tuner_viewmodel.dart';

/// Modal de Consola Mezcladora de Pistas (Stems) extraído de [TunerScreen].
/// Estilizado con [StudioThemeScope] y [StudioIcon].
class TunerMixerModal extends StatelessWidget {
  final TunerViewModel viewModel;

  const TunerMixerModal({
    super.key,
    required this.viewModel,
  });

  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    final tokens = StudioThemeScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.panelBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TunerMixerModal(viewModel: viewModel),
    );
  }

  StudioIconId _iconForTrack({required bool isMetro, required String instrumentIcon}) {
    if (isMetro) return StudioIconId.moduleMetronome;
    if (instrumentIcon == 'mic') return StudioIconId.audioMicOn;
    if (instrumentIcon == 'piano') return StudioIconId.modulePianoRoll;
    return StudioIconId.fileMusicXmlMidi;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);

    return StatefulBuilder(
      builder: (context, setModalState) {
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
                    color: tokens.borderHairline,
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
                      StudioIcon(
                        StudioIconId.moduleTuner,
                        color: tokens.accentPrimary,
                        size: 22,
                        tintCustomAsset: true,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CONSOLA MEZCLADORA (STEMS)',
                        style: TextStyle(
                          color: tokens.accentPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    key: const Key('close_mixer_modal_btn'),
                    icon: StudioIcon(
                      StudioIconId.uiCloseConfirm,
                      color: tokens.textMuted,
                      size: 20,
                      tintCustomAsset: true,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Balance independiente de metrónomo y pistas de acompañamiento',
                style: TextStyle(color: tokens.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 16),

              // Faders de cada canal / stem
              ...allTracks.map((track) {
                final isMetro = track.id == 'metronome';
                final iconId = _iconForTrack(
                  isMetro: isMetro,
                  instrumentIcon: track.instrumentIcon,
                );
                final effectiveGain = track.getEffectiveGain(hasAnySolo: mixer.hasAnySolo);
                final isEffectivelySilenced = effectiveGain == 0.0 && track.volume > 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.elevatedSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: track.isSolo
                          ? tokens.accentSecondary
                          : (track.isMuted
                              ? tokens.accentDanger.withValues(alpha: 0.5)
                              : tokens.borderSubtle),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              StudioIcon(
                                iconId,
                                color: isMetro ? tokens.accentPrimary : tokens.textPrimary,
                                size: 18,
                                tintCustomAsset: true,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                track.title,
                                style: TextStyle(
                                  color: isEffectivelySilenced
                                      ? tokens.textMuted
                                      : tokens.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  decoration: isEffectivelySilenced
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Botón MUTE (M)
                              GestureDetector(
                                key: Key('mixer_mute_btn_${track.id}'),
                                onTap: () {
                                  viewModel.toggleTrackMute(track.id);
                                  setModalState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: track.isMuted
                                        ? tokens.accentDanger
                                        : tokens.inputSurface,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'M',
                                    style: TextStyle(
                                      color: track.isMuted
                                          ? tokens.textPrimary
                                          : tokens.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Botón SOLO (S)
                              GestureDetector(
                                key: Key('mixer_solo_btn_${track.id}'),
                                onTap: () {
                                  viewModel.toggleTrackSolo(track.id);
                                  setModalState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: track.isSolo
                                        ? tokens.accentSecondary
                                        : tokens.inputSurface,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'S',
                                    style: TextStyle(
                                      color: track.isSolo
                                          ? tokens.textOnAccent
                                          : tokens.textMuted,
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
                                  '${(track.volume * 100).round()}%',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    color: isMetro ? tokens.accentPrimary : tokens.textPrimary,
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
                          key: Key('mixer_volume_slider_${track.id}'),
                          value: track.volume,
                          min: 0.0,
                          max: 1.0,
                          activeColor:
                              isMetro ? tokens.accentPrimary : tokens.accentSecondary,
                          inactiveColor: tokens.borderSubtle,
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
  }
}
