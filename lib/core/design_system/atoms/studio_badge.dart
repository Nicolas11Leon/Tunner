import 'package:flutter/material.dart';

import '../studio_theme_provider.dart';

/// Tabular monospace technical badge for BPM, Camelot keys, timecodes, and formats.
class StudioBadge extends StatelessWidget {
  final String label;
  final Color? accentColor;

  const StudioBadge({
    super.key,
    required this.label,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);
    final color = accentColor ?? tokens.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.inputSurface,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(
          color: accentColor?.withValues(alpha: 0.6) ?? tokens.borderHairline,
          width: tokens.borderWidth,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
