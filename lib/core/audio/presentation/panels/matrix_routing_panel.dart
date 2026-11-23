import 'package:flutter/material.dart';
import '../../../design_system/atoms/studio_icon.dart';
import '../../../design_system/domain/studio_icon_catalog.dart';
import '../../../design_system/studio_design_tokens.dart';
import '../../domain/audio_device_matrix_entity.dart';
import '../../infrastructure/studio_audio_device_matrix_service.dart';

/// Panel de matriz universal de enrutamiento de buses (Patchbay) para canales virtuales.
class MatrixRoutingPanel extends StatelessWidget {
  final StudioDesignTokens tokens;
  final AudioDeviceMatrixEntity matrix;
  final StudioAudioDeviceMatrixService matrixService;

  const MatrixRoutingPanel({
    super.key,
    required this.tokens,
    required this.matrix,
    required this.matrixService,
  });

  static const List<(String, String, StudioIconId)> _channels = [
    ('dj_deck_a', 'DJ Deck A (Plato Principal)', StudioIconId.moduleDjConsole),
    ('dj_deck_b', 'DJ Deck B (Plato Secundario)', StudioIconId.moduleDjConsole),
    ('metronome_click', 'Metrónomo Acústico', StudioIconId.moduleMetronome),
    ('tuning_diapason', 'Diapasón y Tono de Afinación', StudioIconId.moduleTuner),
    ('instrument_note', 'Teclado y Sintetizador', StudioIconId.modulePianoRoll),
    ('harmonic_drone', 'Bucle de Dron Armónico', StudioIconId.moduleDrone),
    ('practice_take', 'Tomas de Práctica', StudioIconId.moduleRecorder),
    ('score_synth', 'Sintetizador de Partitura SMuFL', StudioIconId.moduleScoreSheet),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panelBackground.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudioIcon(
                StudioIconId.modulePatchbay,
                size: 14,
                color: tokens.accentPrimary,
                tintCustomAsset: true,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'MATRIZ UNIVERSAL DE ENRUTAMIENTO DE BUSES (PATCHBAY)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._channels.map((ch) {
            final routing = matrix.channelRoutings[ch.$1] ?? 'master';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  StudioIcon(
                    ch.$3,
                    size: 14,
                    color: tokens.textSecondary,
                    tintCustomAsset: true,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ch.$2,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildBusSelectorChip(
                    keyName: 'routing_${ch.$1}_master',
                    label: 'MASTER',
                    isSelected: routing == 'master',
                    activeColor: tokens.accentSuccess,
                    onTap: () => matrixService.setChannelRouting(ch.$1, 'master'),
                  ),
                  const SizedBox(width: 4),
                  _buildBusSelectorChip(
                    keyName: 'routing_${ch.$1}_cue',
                    label: 'CUE',
                    isSelected: routing == 'cue',
                    activeColor: tokens.accentWarning,
                    onTap: () => matrixService.setChannelRouting(ch.$1, 'cue'),
                  ),
                  const SizedBox(width: 4),
                  _buildBusSelectorChip(
                    keyName: 'routing_${ch.$1}_mute',
                    label: 'MUTE',
                    isSelected: routing == 'mute',
                    activeColor: tokens.accentDanger,
                    onTap: () => matrixService.setChannelRouting(ch.$1, 'mute'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBusSelectorChip({
    required String keyName,
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: Key(keyName),
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.25) : tokens.panelHeaderBackground,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isSelected ? activeColor : tokens.borderHairline,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : tokens.textMuted,
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
