import 'package:flutter/material.dart';

import '../studio_theme_provider.dart';

/// Docked Adobe-style matte panel with crisp 1px hairline border and optional
/// uppercase technical header strip.
class StudioPanel extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const StudioPanel({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.panelBackground,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(
          color: tokens.borderHairline,
          width: tokens.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null || trailing != null)
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: tokens.panelHeaderBackground,
                border: Border(
                  bottom: BorderSide(
                    color: tokens.borderHairline,
                    width: tokens.borderWidth,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ?trailing,
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
