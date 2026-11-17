import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';

/// Molécula de UI: Medidor Acústico VU / Peak Meter de Estudio (StudioVuMeter).
///
/// Representa niveles de amplitud y presión sonora en dBFS de -60 dB a 0 dB.
/// Emplea segmentación en barra y umbrales de color de estudio (verde -> ámbar -> rojo clip).
class StudioVuMeter extends StatelessWidget {
  /// Valor normalizado de 0.0 (silencio) a 1.0 (clipping a 0 dBFS).
  final double normalizedLevel;
  final double width;
  final double height;
  final Axis orientation;
  final bool showPeakIndicator;

  const StudioVuMeter({
    super.key,
    required this.normalizedLevel,
    this.width = 120.0,
    this.height = 8.0,
    this.orientation = Axis.horizontal,
    this.showPeakIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final clampedLevel = normalizedLevel.clamp(0.0, 1.0);
    final isHorizontal = orientation == Axis.horizontal;

    // Determinación del color del medidor según la intensidad
    Color meterColor = tokens.accentSuccess;
    if (clampedLevel > 0.88) {
      meterColor = tokens.accentDanger;
    } else if (clampedLevel > 0.70) {
      meterColor = tokens.accentWarning;
    }

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(1.0),
      decoration: BoxDecoration(
        color: tokens.inputSurface,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(
          color: tokens.borderSubtle,
          width: tokens.borderWidth,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxDimension = isHorizontal ? constraints.maxWidth : constraints.maxHeight;
          final fillDimension = maxDimension * clampedLevel;

          return Stack(
            children: [
              // Barra de relleno activo
              Align(
                alignment: isHorizontal ? Alignment.centerLeft : Alignment.bottomCenter,
                child: Container(
                  width: isHorizontal ? fillDimension : constraints.maxWidth,
                  height: isHorizontal ? constraints.maxHeight : fillDimension,
                  decoration: BoxDecoration(
                    color: meterColor,
                    borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  ),
                ),
              ),
              // Marcador de advertencia (Línea de -3 dB)
              if (showPeakIndicator)
                Positioned(
                  left: isHorizontal ? maxDimension * 0.85 : 0.0,
                  right: isHorizontal ? null : 0.0,
                  top: isHorizontal ? 0.0 : null,
                  bottom: isHorizontal ? 0.0 : maxDimension * 0.85,
                  child: Container(
                    width: isHorizontal ? 1.0 : constraints.maxWidth,
                    height: isHorizontal ? constraints.maxHeight : 1.0,
                    color: tokens.borderHairline.withValues(alpha: 0.8),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
