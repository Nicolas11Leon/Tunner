import 'package:flutter/material.dart';
import '../../design_system/studio_design_tokens.dart';
import '../../design_system/studio_theme_provider.dart';
import '../domain/studio_master_audio_mixer.dart';
import '../infrastructure/studio_audio_device_matrix_service.dart';

/// Mini-píldora compacta para la barra de estado inferior (Status Bar)
/// que proporciona telemetría en tiempo real del bus maestro y acceso
/// rápido a la Consola Maestra de E/S de Hardware.
class StudioMasterMeterMiniPillWidget extends StatelessWidget {
  final StudioAudioDeviceMatrixService matrixService;
  final VoidCallback onTap;

  const StudioMasterMeterMiniPillWidget({
    super.key,
    required this.matrixService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    StudioDesignTokens tokens;
    try {
      tokens = StudioThemeScope.tokensOf(context);
    } catch (_) {
      tokens = StudioDesignTokens.studioDark;
    }

    return ListenableBuilder(
      listenable: matrixService,
      builder: (context, _) {
        final matrix = matrixService.matrix;

        return Tooltip(
          message: 'Consola Maestra de E/S de Hardware (Ctrl+Shift+I)',
          waitDuration: const Duration(milliseconds: 400),
          child: InkWell(
            key: const Key('master_meter_mini_pill'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(4.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: matrix.isMuted
                    ? tokens.accentDanger.withValues(alpha: 0.15)
                    : matrix.isDimmed
                        ? tokens.accentWarning.withValues(alpha: 0.15)
                        : tokens.panelBackground.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(
                  color: matrix.isMuted
                      ? tokens.accentDanger.withValues(alpha: 0.5)
                      : matrix.isDimmed
                          ? tokens.accentWarning.withValues(alpha: 0.5)
                          : tokens.borderHairline,
                  width: tokens.borderWidth,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador LED de Estado
                  Container(
                    width: 6.0,
                    height: 6.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: matrix.isMuted
                          ? tokens.accentDanger
                          : matrix.isDimmed
                              ? tokens.accentWarning
                              : tokens.accentSuccess,
                      boxShadow: [
                        BoxShadow(
                          color: (matrix.isMuted
                                  ? tokens.accentDanger
                                  : matrix.isDimmed
                                      ? tokens.accentWarning
                                      : tokens.accentSuccess)
                              .withValues(alpha: 0.6),
                          blurRadius: 3.0,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Etiqueta MASTER
                  Text(
                    'MTR:',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 9.0,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 4),

                  if (matrix.isMasterRecording) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        'REC',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],

                  // Nivel o Estado en Texto
                  if (matrix.isMuted)
                    Text(
                      'MUTED',
                      style: TextStyle(
                        color: tokens.accentDanger,
                        fontSize: 9.0,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                      ),
                    )
                  else if (matrix.isDimmed)
                    Text(
                      'DIM -20dB',
                      style: TextStyle(
                        color: tokens.accentWarning,
                        fontSize: 9.0,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                      ),
                    )
                  else
                    Text(
                      '${matrix.masterGainDb.toStringAsFixed(1)} dB',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 9.0,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  const SizedBox(width: 6),

                  // Micro Vúmetro Estéreo L/R
                  SizedBox(
                    width: 28.0,
                    height: 8.0,
                    child: StreamBuilder<StudioStereoLevelMeterData>(
                      stream: matrixService.masterMeterStream,
                      initialData: matrixService.masterMeterData,
                      builder: (context, snapshot) {
                        final meter = snapshot.data ?? StudioStereoLevelMeterData.zero;
                        final leftFraction = ((meter.leftPeakDb + 60.0) / 63.0).clamp(0.0, 1.0);
                        final rightFraction = ((meter.rightPeakDb + 60.0) / 63.0).clamp(0.0, 1.0);

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMicroBar(leftFraction, tokens, meter.isClipping),
                            _buildMicroBar(rightFraction, tokens, meter.isClipping),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Latencia de Búfer
                  Text(
                    '${matrix.bufferSize} smp (${matrix.estimatedBufferLatencyMs.toStringAsFixed(1)}ms)',
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 8.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMicroBar(double fraction, StudioDesignTokens tokens, bool isClipping) {
    Color barColor;
    if (isClipping) {
      barColor = tokens.accentDanger;
    } else if (fraction > 0.85) {
      barColor = tokens.accentWarning;
    } else {
      barColor = tokens.accentSuccess;
    }

    return Container(
      height: 3.0,
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.inputSurface,
        borderRadius: BorderRadius.circular(1.0),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction,
        child: Container(
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(1.0),
          ),
        ),
      ),
    );
  }
}
