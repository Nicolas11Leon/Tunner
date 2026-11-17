import 'package:flutter/material.dart';

import '../studio_theme_provider.dart';

enum StudioButtonVariant {
  primary,
  secondary,
  ghost,
  danger,
}

/// Crisp, sharp-cornered Tunner Studio style button without Material bloat.
class StudioButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final StudioButtonVariant variant;
  final bool compact;

  const StudioButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = StudioButtonVariant.secondary,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);
    final isDisabled = onPressed == null;

    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case StudioButtonVariant.primary:
        bg = tokens.accentPrimary;
        fg = tokens.textOnAccent;
        border = tokens.accentPrimary;
      case StudioButtonVariant.secondary:
        bg = tokens.elevatedSurface;
        fg = tokens.textPrimary;
        border = tokens.borderHairline;
      case StudioButtonVariant.ghost:
        bg = Colors.transparent;
        fg = tokens.textSecondary;
        border = Colors.transparent;
      case StudioButtonVariant.danger:
        bg = tokens.accentDanger;
        fg = tokens.textOnAccent;
        border = tokens.accentDanger;
    }

    if (isDisabled) {
      bg = bg.withValues(alpha: 0.4);
      fg = tokens.textMuted;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 11,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
            border: Border.all(color: border, width: tokens.borderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: compact ? 13 : 15, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact toggle chip with crisp 1px border for studio transport/filter bars.
class StudioToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const StudioToggleChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);
    final bg = selected ? tokens.accentPrimary : tokens.inputSurface;
    final fg = selected ? tokens.textOnAccent : tokens.textSecondary;
    final border = selected ? tokens.accentPrimary : tokens.borderHairline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          border: Border.all(color: border, width: tokens.borderWidth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
