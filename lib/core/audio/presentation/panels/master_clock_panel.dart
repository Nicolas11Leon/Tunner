import 'package:flutter/material.dart';
import '../../../design_system/atoms/studio_icon.dart';
import '../../../design_system/domain/studio_icon_catalog.dart';
import '../../../design_system/studio_design_tokens.dart';
import '../../infrastructure/studio_master_clock_service.dart';

/// Panel de reloj maestro de transporte global, ajuste de BPM, Tap Tempo y controles PLAY/STOP.
class MasterClockPanel extends StatelessWidget {
  final StudioDesignTokens tokens;
  final StudioMasterClockService clockService;

  const MasterClockPanel({
    super.key,
    required this.tokens,
    required this.clockService,
  });

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
                StudioIconId.moduleMetronome,
                size: 14,
                color: tokens.accentSecondary,
                tintCustomAsset: true,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'RELOJ MAESTRO DE TRANSPORTE',
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
          const SizedBox(height: 12),

          // Display Grande de BPM y Tap Tempo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: tokens.panelHeaderBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderHairline),
                ),
                child: Row(
                  children: [
                    Text(
                      clockService.bpm.toStringAsFixed(1),
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'BPM',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Botones +/- BPM
              Column(
                children: [
                  InkWell(
                    key: const Key('bpm_increment_btn'),
                    onTap: () => clockService.setBpm(clockService.bpm + 1.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: tokens.panelHeaderBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: StudioIcon(
                        StudioIconId.uiAddRemove,
                        size: 14,
                        color: tokens.textPrimary,
                        tintCustomAsset: true,
                        fallbackOverride: Icons.arrow_drop_up,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  InkWell(
                    key: const Key('bpm_decrement_btn'),
                    onTap: () => clockService.setBpm(clockService.bpm - 1.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: tokens.panelHeaderBackground,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: StudioIcon(
                        StudioIconId.uiAddRemove,
                        size: 14,
                        color: tokens.textSecondary,
                        tintCustomAsset: true,
                        fallbackOverride: Icons.arrow_drop_down,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Boton Tap Tempo
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accentSecondary.withValues(alpha: 0.15),
                    foregroundColor: tokens.accentSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: tokens.accentSecondary.withValues(alpha: 0.5)),
                  ),
                  onPressed: clockService.registerTap,
                  child: const Text(
                    'TAP TEMPO',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Posicion de Compas y Metrica
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'COMPÁS: ${clockService.currentMeasure} | TIEMPO: ${clockService.currentBeat} / ${clockService.meterNumerator}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: clockService.isDownbeat ? tokens.accentPrimary : tokens.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: clockService.isPlaying
                      ? (clockService.isDownbeat ? tokens.accentPrimary : tokens.accentWarning)
                      : tokens.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Botones Maestros PLAY ALL / STOP ALL
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: clockService.isPlaying ? tokens.accentSuccess : tokens.accentPrimary,
                    foregroundColor: tokens.textOnAccent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: StudioIcon(
                    clockService.isPlaying ? StudioIconId.transportPause : StudioIconId.transportPlay,
                    size: 16,
                    color: tokens.textOnAccent,
                    tintCustomAsset: true,
                  ),
                  label: Text(
                    clockService.isPlaying ? 'PAUSE ALL' : 'PLAY ALL',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: clockService.togglePlayPause,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.accentDanger,
                  side: BorderSide(color: tokens.accentDanger),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
                icon: StudioIcon(
                  StudioIconId.transportStop,
                  size: 16,
                  color: tokens.accentDanger,
                  tintCustomAsset: true,
                ),
                label: const Text(
                  'STOP ALL',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                onPressed: clockService.stopTransport,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
