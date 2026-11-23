import 'package:flutter/material.dart';
import '../../../design_system/atoms/studio_icon.dart';
import '../../../design_system/domain/studio_icon_catalog.dart';
import '../../../design_system/studio_design_tokens.dart';
import '../../domain/audio_device_matrix_entity.dart';
import '../../infrastructure/studio_audio_device_matrix_service.dart';

/// Panel de cadena DSP de masterizacion: ecualizador parametrico de 3 bandas y compresor dinamico.
class MasteringChainPanel extends StatelessWidget {
  final StudioDesignTokens tokens;
  final AudioDeviceMatrixEntity matrix;
  final StudioAudioDeviceMatrixService matrixService;

  const MasteringChainPanel({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudioIcon(
                StudioIconId.moduleSpectrogram,
                size: 14,
                color: tokens.accentPrimary,
                tintCustomAsset: true,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'CADENA DSP DE MASTERIZACIÓN (3-BAND EQ & COMPRESOR DE PICO)',
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ecualizador de 3 Bandas
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.panelHeaderBackground.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'ECUALIZADOR PARAMÉTRICO',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            key: const Key('master_eq_bypass_btn'),
                            onTap: matrixService.toggleEqBypass,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: matrix.isEqBypassed
                                    ? tokens.accentWarning
                                    : tokens.panelBackground,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: tokens.borderHairline),
                              ),
                              child: Text(
                                matrix.isEqBypassed ? 'BYPASS ACTIVO' : 'ACTIVO',
                                style: TextStyle(
                                  color: matrix.isEqBypassed
                                      ? tokens.textOnAccent
                                      : tokens.accentSuccess,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDspSlider(
                        'LOW (100 Hz)',
                        matrix.eqLowDb,
                        -12.0,
                        12.0,
                        matrixService.setEqLow,
                      ),
                      _buildDspSlider(
                        'MID (1 kHz)',
                        matrix.eqMidDb,
                        -12.0,
                        12.0,
                        matrixService.setEqMid,
                      ),
                      _buildDspSlider(
                        'HIGH (8 kHz)',
                        matrix.eqHighDb,
                        -12.0,
                        12.0,
                        matrixService.setEqHigh,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Compresor Dinamico y Medidor GR
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.panelHeaderBackground.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'COMPRESOR & LIMITADOR',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            key: const Key('master_comp_bypass_btn'),
                            onTap: matrixService.toggleCompBypass,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: matrix.isCompBypassed
                                    ? tokens.accentWarning
                                    : tokens.panelBackground,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: tokens.borderHairline),
                              ),
                              child: Text(
                                matrix.isCompBypassed ? 'BYPASS ACTIVO' : 'ACTIVO',
                                style: TextStyle(
                                  color: matrix.isCompBypassed
                                      ? tokens.textOnAccent
                                      : tokens.accentSuccess,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDspSlider(
                        'UMBRAL (THRESHOLD)',
                        matrix.compThresholdDb,
                        -30.0,
                        0.0,
                        matrixService.setCompThreshold,
                        unit: 'dB',
                      ),
                      _buildDspSlider(
                        'RATIO',
                        matrix.compRatio,
                        1.0,
                        20.0,
                        matrixService.setCompRatio,
                        unit: ':1',
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'REDUCCIÓN (GR): ',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${meter.gainReductionDb.toStringAsFixed(1)} dB',
                            style: TextStyle(
                              color: meter.gainReductionDb < -0.1
                                  ? tokens.accentWarning
                                  : tokens.textMuted,
                              fontSize: 9.0,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: tokens.panelBackground,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: (meter.gainReductionDb.abs() / 15.0).clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: tokens.accentWarning,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDspSlider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) onChanged, {
    String unit = 'dB',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: tokens.textSecondary, fontSize: 8.5)),
            Text(
              unit == 'dB'
                  ? '${value >= 0 ? "+" : ""}${value.toStringAsFixed(1)} dB'
                  : '${value.toStringAsFixed(1)}$unit',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: tokens.accentPrimary,
            inactiveTrackColor: tokens.panelBackground,
            thumbColor: tokens.accentPrimary,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
            trackHeight: 3,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
