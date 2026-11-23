import 'package:flutter/material.dart';
import '../../design_system/studio_theme_provider.dart';

/// Divisor interactivo y arrastrable para redimensionar paneles divididos en tiempo real.
class StudioSplitterDivider extends StatefulWidget {
  final Axis direction;
  final ValueChanged<double> onDragDelta;

  const StudioSplitterDivider({
    super.key,
    required this.direction,
    required this.onDragDelta,
  });

  @override
  State<StudioSplitterDivider> createState() => _StudioSplitterDividerState();
}

class _StudioSplitterDividerState extends State<StudioSplitterDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);
    final isVertical = widget.direction == Axis.vertical;

    final cursor = isVertical
        ? SystemMouseCursors.resizeRow
        : SystemMouseCursors.resizeColumn;

    return MouseRegion(
      cursor: cursor,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanEnd: (_) => setState(() => _isDragging = false),
        onPanCancel: () => setState(() => _isDragging = false),
        onPanUpdate: (details) {
          final delta = isVertical ? details.delta.dy : details.delta.dx;
          widget.onDragDelta(delta);
        },
        child: Container(
          width: isVertical ? double.infinity : 6.0,
          height: isVertical ? 6.0 : double.infinity,
          color: _isDragging
              ? tokens.accentPrimary
              : (_isHovered ? tokens.accentPrimary.withValues(alpha: 0.5) : tokens.borderHairline),
          child: Center(
            child: Container(
              width: isVertical ? 24.0 : 2.0,
              height: isVertical ? 2.0 : 24.0,
              decoration: BoxDecoration(
                color: _isDragging || _isHovered ? tokens.textPrimary : tokens.textMuted,
                borderRadius: BorderRadius.circular(1.0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
