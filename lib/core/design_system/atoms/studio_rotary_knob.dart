import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../studio_theme_provider.dart';

/// Perilla rotatoria vectorial de grado estudio (StudioRotaryKnob).
/// Diseñada para emular controles de hardware analógico y consolas DJ de club (Pioneer/Allen&Heath).
/// Admite arrastre vertical para regular valor, doble toque para centrar a 0, y retorno háptico/visual.
class StudioRotaryKnob extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final String label;
  final ValueChanged<double> onChanged;
  final Color? activeColor;
  final double size;
  final String Function(double)? valueFormatter;

  const StudioRotaryKnob({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.5,
    this.defaultValue = 1.0,
    required this.label,
    required this.onChanged,
    this.activeColor,
    this.size = 52.0,
    this.valueFormatter,
  });

  @override
  State<StudioRotaryKnob> createState() => _StudioRotaryKnobState();
}

class _StudioRotaryKnobState extends State<StudioRotaryKnob> {
  double _dragStartY = 0.0;
  double _dragStartValue = 0.0;

  void _onVerticalDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _dragStartValue = widget.value;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final deltaY = _dragStartY - details.globalPosition.dy;
    final range = widget.max - widget.min;
    final sensitivity = range / 160.0;
    final newValue = (_dragStartValue + deltaY * sensitivity).clamp(widget.min, widget.max);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.controllerOf(context)?.tokens;
    final effectiveAccent =
        widget.activeColor ?? (tokens?.accentPrimary ?? const Color(0xFF00E5FF));
    final labelColor = tokens?.textSecondary ?? Colors.white70;
    final isDefault = widget.value == widget.defaultValue;
    final valueColor = tokens != null
        ? (isDefault ? tokens.textPrimary : effectiveAccent)
        : (isDefault ? Colors.white38 : effectiveAccent);

    final isLight = tokens?.brightness == Brightness.light;
    final trackColor = tokens != null
        ? (isLight
            ? tokens.borderHairline
            : tokens.borderHairline.withValues(alpha: 0.9))
        : Colors.white12;
    final dialColors = tokens != null
        ? (isLight
            ? <Color>[
                tokens.panelBackground,
                tokens.elevatedSurface,
                tokens.borderHairline,
              ]
            : <Color>[
                tokens.elevatedSurface,
                tokens.panelHeaderBackground,
                tokens.panelBackground,
              ])
        : const <Color>[
            Color(0xFF2E3440),
            Color(0xFF1E222A),
            Color(0xFF14161C),
          ];
    final rimColor = tokens != null
        ? tokens.borderHairline
        : Colors.white.withValues(alpha: 0.15);
    final notchColor = tokens != null
        ? tokens.textSecondary.withValues(alpha: 0.65)
        : Colors.white30;

    final normalized = ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    // Rango de ángulo: -135° a +135° (270° de rotación total)
    final angle = (-135.0 + normalized * 270.0) * (math.pi / 180.0);

    final formattedValue = widget.valueFormatter != null
        ? widget.valueFormatter!(widget.value)
        : (widget.value == 1.0
            ? '0 dB'
            : (widget.value > 1.0
                ? '+${((widget.value - 1.0) * 12).toStringAsFixed(1)} dB'
                : '-${((1.0 - widget.value) * 26).toStringAsFixed(1)} dB'));

    return GestureDetector(
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onDoubleTap: () => widget.onChanged(widget.defaultValue),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título de la perilla (HIGH, MID, LOW, etc.)
          Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              color: labelColor,
              fontSize: 9.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),

          // Cuerpo de la perilla
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _KnobPainter(
                angle: angle,
                normalized: normalized,
                activeColor: effectiveAccent,
                trackColor: trackColor,
                dialColors: dialColors,
                rimColor: rimColor,
                notchColor: notchColor,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Valor numérico
          Text(
            formattedValue,
            style: TextStyle(
              color: valueColor,
              fontSize: 8.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  final double angle;
  final double normalized;
  final Color activeColor;
  final Color trackColor;
  final List<Color> dialColors;
  final Color rimColor;
  final Color notchColor;

  const _KnobPainter({
    required this.angle,
    required this.normalized,
    required this.activeColor,
    required this.trackColor,
    required this.dialColors,
    required this.rimColor,
    required this.notchColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Arco de fondo exterior
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final startAngle = -135.0 * (math.pi / 180.0) - math.pi / 2;
    final sweepAngle = 270.0 * (math.pi / 180.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 3),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // 2. Arco activo iluminado
    final activeArcPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 3),
      startAngle,
      normalized * sweepAngle,
      false,
      activeArcPaint,
    );

    // 3. Dial metálico interior con degradado
    final knobPaint = Paint()
      ..shader = RadialGradient(
        colors: dialColors,
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 6));

    canvas.drawCircle(center, radius - 6, knobPaint);

    // Borde biselado
    final rimPaint = Paint()
      ..color = rimColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 6, rimPaint);

    // 4. Aguja indicadora
    final needleRadius = radius - 8;
    final needleEnd = Offset(
      center.dx + needleRadius * math.cos(angle - math.pi / 2),
      center.dy + needleRadius * math.sin(angle - math.pi / 2),
    );
    final needleStart = Offset(
      center.dx + (needleRadius * 0.45) * math.cos(angle - math.pi / 2),
      center.dy + (needleRadius * 0.45) * math.sin(angle - math.pi / 2),
    );

    final needlePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(needleStart, needleEnd, needlePaint);

    // Muesca central de 0 dB en la parte superior
    final centerNotchPaint = Paint()
      ..color = notchColor
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius + 1),
      Offset(center.dx, center.dy - radius + 5),
      centerNotchPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.normalized != normalized ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.rimColor != rimColor ||
        oldDelegate.notchColor != notchColor ||
        oldDelegate.dialColors[0] != dialColors[0] ||
        oldDelegate.dialColors[1] != dialColors[1] ||
        oldDelegate.dialColors[2] != dialColors[2];
  }
}
