import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';

/// Átomo de UI: Divisor Hairline de Precisión (StudioHairline).
///
/// Dibuja líneas de demarcación técnica de exactamente 1px en orientación horizontal
/// o vertical, delimitando áreas de trabajo sin emplear sombras difusas.
class StudioHairline extends StatelessWidget {
  final Axis orientation;
  final Color? color;
  final double? length;

  const StudioHairline({
    super.key,
    this.orientation = Axis.horizontal,
    this.color,
    this.length,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final effectiveColor = color ?? tokens.borderHairline;

    if (orientation == Axis.horizontal) {
      return Container(
        width: length ?? double.infinity,
        height: tokens.borderWidth,
        color: effectiveColor,
      );
    } else {
      return Container(
        width: tokens.borderWidth,
        height: length ?? double.infinity,
        color: effectiveColor,
      );
    }
  }
}
