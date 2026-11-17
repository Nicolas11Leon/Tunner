import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';

/// Átomo de UI: Visualizador de Métricas de Precisión (StudioMetricDisplay).
///
/// Implementa tipografía monoespaciada tabular para lecturas acústicas en vivo
/// (frecuencia en Hz, desviación en Cents, tempo en BPM, nivel en dB).
/// Evita fluctuaciones en el ancho de texto a 60/120 FPS.
class StudioMetricDisplay extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color? valueColor;
  final double fontSize;
  final bool compact;

  const StudioMetricDisplay({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor,
    this.fontSize = 20.0,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final effectiveValueColor = valueColor ?? tokens.textPrimary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6.0 : 10.0,
        vertical: compact ? 3.0 : 6.0,
      ),
      decoration: BoxDecoration(
        color: tokens.inputSurface,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(
          color: tokens.borderSubtle,
          width: tokens.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: compact ? 8.5 : 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: effectiveValueColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -0.5,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: fontSize * 0.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
