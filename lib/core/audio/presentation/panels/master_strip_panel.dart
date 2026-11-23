import 'package:flutter/material.dart';
import '../../../design_system/atoms/studio_icon.dart';
import '../../../design_system/atoms/studio_stereo_vu_meter.dart';
import '../../../design_system/domain/studio_icon_catalog.dart';
import '../../../design_system/studio_design_tokens.dart';
import '../../domain/audio_device_matrix_entity.dart';
import '../../infrastructure/studio_audio_device_matrix_service.dart';

/// Panel de tira de canal maestro con vumetros estereo L/R, fader de ganancia,
/// modificadores MUTE/DIM/MONO y grabacion directa del bus maestro.
class MasterStripPanel extends StatelessWidget {
  final StudioDesignTokens tokens;
  final AudioDeviceMatrixEntity matrix;
  final StudioAudioDeviceMatrixService matrixService;

  const MasterStripPanel({
    super.key,
    required this.tokens,
    required this.matrix,
    required this.matrixService,
  });

  @override
  Widget build(BuildContext context) {
    final meter = matrixService.masterMeterData;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panelBackground.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Vumetros Estereo L/R
          Column(
            children: [
              Text(
                'VÚMETRO MASTER',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  StudioStereoVuMeter(
                    levelLeft: meter.leftRms,
                    levelRight: meter.rightRms,
                    peakLeft: (meter.leftPeakDb + 60.0) / 60.0,
                    peakRight: (meter.rightPeakDb + 60.0) / 60.0,
                    height: 110,
                    width: 24,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${meter.leftPeakDb.toStringAsFixed(1)} dB',
                    style: TextStyle(
                      color: meter.isClipping ? tokens.accentDanger : tokens.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),

          // Fader Maestro Tactil Proporcional
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GANANCIA MAESTRA (MASTER GAIN):',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${matrix.masterGainDb.toStringAsFixed(1)} dB (${(matrix.masterGain * 100).toInt()}%)',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: tokens.accentPrimary,
                    inactiveTrackColor: tokens.panelHeaderBackground,
                    thumbColor: tokens.accentPrimary,
                    overlayColor: tokens.accentPrimary.withValues(alpha: 0.2),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: matrix.masterGain,
                    min: 0.0,
                    max: 1.5,
                    onChanged: (val) => matrixService.setMasterGain(val),
                  ),
                ),
                const SizedBox(height: 10),

                // Botones Utilitarios de Estudio: MUTE, DIM, MONO, REC
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('master_mute_btn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: matrix.isMuted
                              ? tokens.accentDanger
                              : tokens.panelHeaderBackground,
                          foregroundColor: matrix.isMuted ? tokens.textOnAccent : tokens.textPrimary,
                          side: BorderSide(
                            color: matrix.isMuted ? tokens.accentDanger : tokens.borderHairline,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: matrixService.toggleMute,
                        child: const Text(
                          'MUTE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('master_dim_btn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: matrix.isDimmed
                              ? tokens.accentWarning
                              : tokens.panelHeaderBackground,
                          foregroundColor: matrix.isDimmed ? tokens.textOnAccent : tokens.textPrimary,
                          side: BorderSide(
                            color: matrix.isDimmed ? tokens.accentWarning : tokens.borderHairline,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: matrixService.toggleDim,
                        child: const Text(
                          'DIM (-20dB)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('master_mono_btn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: matrix.isMono
                              ? tokens.accentSecondary
                              : tokens.panelHeaderBackground,
                          foregroundColor: matrix.isMono ? tokens.textOnAccent : tokens.textPrimary,
                          side: BorderSide(
                            color: matrix.isMono ? tokens.accentSecondary : tokens.borderHairline,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: matrixService.toggleMono,
                        child: const Text(
                          'MONO',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('master_rec_btn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: matrix.isMasterRecording
                              ? tokens.accentDanger
                              : tokens.panelHeaderBackground,
                          foregroundColor: matrix.isMasterRecording
                              ? tokens.textOnAccent
                              : tokens.textPrimary,
                          side: BorderSide(
                            color: matrix.isMasterRecording
                                ? tokens.accentDanger
                                : tokens.borderHairline,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: StudioIcon(
                          StudioIconId.transportRecord,
                          size: 13,
                          color: matrix.isMasterRecording ? tokens.textOnAccent : tokens.accentDanger,
                          tintCustomAsset: true,
                        ),
                        label: Text(
                          matrix.isMasterRecording ? 'GRABANDO' : 'REC MASTER',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          if (matrix.isMasterRecording) {
                            matrixService.stopMasterRecording();
                          } else {
                            final path =
                                'recordings/master_mix_${DateTime.now().millisecondsSinceEpoch}.wav';
                            matrixService.startMasterRecording(path);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
