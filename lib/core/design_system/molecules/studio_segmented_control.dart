import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';

/// Segmento individual para [StudioSegmentedControl].
class StudioSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const StudioSegment({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Molécula de UI: Selector Segmentado Compacto (StudioSegmentedControl).
///
/// Selector de opciones mutualmente excluyentes inspirado en las barras de herramientas
/// de Adobe Audition y Premiere Pro. Geometría plana, bordes 1px y feedback táctil claro.
class StudioSegmentedControl<T> extends StatelessWidget {
  final List<StudioSegment<T>> segments;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;
  final double height;

  const StudioSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedValue,
    required this.onValueChanged,
    this.height = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: tokens.inputSurface,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(
          color: tokens.borderSubtle,
          width: tokens.borderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments.map((seg) {
          final isSelected = seg.value == selectedValue;

          return InkWell(
            onTap: () => onValueChanged(seg.value),
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? tokens.accentPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (seg.icon != null) ...[
                    Icon(
                      seg.icon,
                      size: 13,
                      color: isSelected ? tokens.textOnAccent : tokens.textSecondary,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    seg.label.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? tokens.textOnAccent : tokens.textSecondary,
                      fontSize: 10.0,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
