import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';

/// Divisor interactivo y de alta precisión para redimensionar paneles en la estación de trabajo.
/// Ofrece una zona de interacción táctil/ratón ergonómica (6px) con cursor dedicado
/// y una línea visual hairline ultra-fina (1px) con feedback reactivo al hover y arrastre.
class StudioSplitter extends StatefulWidget {
  final Axis orientation;
  final ValueChanged<double> onDelta;
  final VoidCallback? onDoubleTapReset;

  const StudioSplitter({
    super.key,
    this.orientation = Axis.horizontal,
    required this.onDelta,
    this.onDoubleTapReset,
  });

  @override
  State<StudioSplitter> createState() => _StudioSplitterState();
}

class _StudioSplitterState extends State<StudioSplitter> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);
    final isHorizontal = widget.orientation == Axis.horizontal;

    final cursor = isHorizontal
        ? SystemMouseCursors.resizeColumn
        : SystemMouseCursors.resizeRow;

    final activeColor = (_isDragging || _isHovered)
        ? tokens.accentPrimary
        : tokens.borderHairline;

    return MouseRegion(
      cursor: cursor,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onDoubleTapReset,
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanEnd: (_) => setState(() => _isDragging = false),
        onPanCancel: () => setState(() => _isDragging = false),
        onPanUpdate: (details) {
          final delta = isHorizontal ? details.delta.dx : details.delta.dy;
          widget.onDelta(delta);
        },
        child: Container(
          width: isHorizontal ? 6.0 : double.infinity,
          height: isHorizontal ? double.infinity : 6.0,
          alignment: Alignment.center,
          color: _isDragging
              ? tokens.accentPrimary.withValues(alpha: 0.08)
              : Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: isHorizontal ? (_isDragging ? 2.0 : 1.0) : double.infinity,
            height: isHorizontal ? double.infinity : (_isDragging ? 2.0 : 1.0),
            color: activeColor,
          ),
        ),
      ),
    );
  }
}
