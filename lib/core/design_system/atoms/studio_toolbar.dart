import 'package:flutter/material.dart';

import '../studio_theme_provider.dart';

/// Compact horizontal studio option/transport bar with 1px bottom hairline.
class StudioToolbar extends StatelessWidget {
  final List<Widget> children;
  final double? height;

  const StudioToolbar({
    super.key,
    required this.children,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);

    return Container(
      height: height ?? tokens.toolbarHeight,
      width: double.infinity,
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: children,
        ),
      ),
    );
  }
}
