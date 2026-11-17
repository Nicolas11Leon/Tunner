import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Highly responsive, vector-rendered DJ Jog Wheel platter with vinyl grooves,
/// true polar angle rotation tracking, mouse wheel scrubbing, and linear swipe fallback.
class VectorJogWheel extends StatefulWidget {
  final String deckLabel; // 'A' or 'B'
  final Color accentColor;
  final bool isPlaying;
  final double rotationAngle; // in radians
  final ValueChanged<double>? onScratch; // delta radians
  final VoidCallback? onTap;
  final double diameter;

  const VectorJogWheel({
    super.key,
    required this.deckLabel,
    required this.accentColor,
    required this.isPlaying,
    required this.rotationAngle,
    this.onScratch,
    this.onTap,
    this.diameter = 160.0,
  });

  @override
  State<VectorJogWheel> createState() => _VectorJogWheelState();
}

class _VectorJogWheelState extends State<VectorJogWheel> {
  double? _lastAngle;
  Offset? _lastPanPos;

  void _onPanStart(DragStartDetails details, Offset center) {
    final dx = details.localPosition.dx - center.dx;
    final dy = details.localPosition.dy - center.dy;
    _lastAngle = math.atan2(dy, dx);
    _lastPanPos = details.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails details, Offset center) {
    if (widget.onScratch == null) return;
    final dx = details.localPosition.dx - center.dx;
    final dy = details.localPosition.dy - center.dy;
    final currentAngle = math.atan2(dy, dx);

    if (_lastAngle != null) {
      var delta = currentAngle - _lastAngle!;
      // Normalizar discontinuidad angular [-pi, pi]
      if (delta > math.pi) delta -= 2 * math.pi;
      if (delta < -math.pi) delta += 2 * math.pi;

      if (delta.abs() > 0.002) {
        widget.onScratch!(delta * 1.6);
      } else if (_lastPanPos != null) {
        // Fallback intuitivo lineal: arrastre horizontal (izquierda = rebobinar, derecha = avanzar)
        final linearDx = details.localPosition.dx - _lastPanPos!.dx;
        if (linearDx.abs() > 0.8) {
          widget.onScratch!(linearDx * 0.035);
        }
      }
    }
    _lastAngle = currentAngle;
    _lastPanPos = details.localPosition;
  }

  void _onPanEnd(DragEndDetails details) {
    _lastAngle = null;
    _lastPanPos = null;
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(widget.diameter, widget.diameter);
    final center = Offset(widget.diameter / 2, widget.diameter / 2);

    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent && widget.onScratch != null) {
          // Scroll hacia arriba (dy < 0) => avanzar en la pista
          // Scroll hacia abajo (dy > 0) => rebobinar en la pista
          final scrollDelta = -pointerSignal.scrollDelta.dy;
          final radiansDelta = (scrollDelta / 70.0).clamp(-2.5, 2.5);
          widget.onScratch!(radiansDelta);
        }
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onPanStart: (d) => _onPanStart(d, center),
        onPanUpdate: (d) => _onPanUpdate(d, center),
        onPanEnd: _onPanEnd,
        onPanCancel: () {
          _lastAngle = null;
          _lastPanPos = null;
        },
        behavior: HitTestBehavior.opaque,
        child: RepaintBoundary(
          child: CustomPaint(
            size: size,
            painter: _JogWheelPainter(
              deckLabel: widget.deckLabel,
              accentColor: widget.accentColor,
              rotationAngle: widget.rotationAngle,
              isPlaying: widget.isPlaying,
            ),
          ),
        ),
      ),
    );
  }
}

class _JogWheelPainter extends CustomPainter {
  final String deckLabel;
  final Color accentColor;
  final double rotationAngle;
  final bool isPlaying;

  _JogWheelPainter({
    required this.deckLabel,
    required this.accentColor,
    required this.rotationAngle,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Platter Outer Ring (Dark metallic rim)
    final rimPaint = Paint()
      ..color = const Color(0xFF1E1E26)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, rimPaint);

    final borderPaint = Paint()
      ..color = isPlaying ? accentColor.withValues(alpha: 0.6) : Colors.white10
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 1, borderPaint);

    // 2. Vinyl Grooves (Concentric textured circles)
    final groovePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double r = radius * 0.45; r < radius * 0.90; r += 5.0) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // 3. Center Vinyl Label
    final labelRadius = radius * 0.38;
    final labelPaint = Paint()
      ..color = const Color(0xFF121218)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, labelRadius, labelPaint);

    final labelBorder = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, labelRadius, labelBorder);

    // 4. Center Spindle
    final spindlePaint = Paint()
      ..color = const Color(0xFFE0E0E8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.08, spindlePaint);

    // 5. Angular Position Marker (Needle / Strobe notch)
    final markerPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final markerX1 = center.dx + (radius * 0.45) * math.cos(rotationAngle);
    final markerY1 = center.dy + (radius * 0.45) * math.sin(rotationAngle);
    final markerX2 = center.dx + (radius * 0.92) * math.cos(rotationAngle);
    final markerY2 = center.dy + (radius * 0.92) * math.sin(rotationAngle);
    canvas.drawLine(Offset(markerX1, markerY1), Offset(markerX2, markerY2), markerPaint);

    // 6. Deck Label Text ('A' or 'B')
    final textSpan = TextSpan(
      text: 'DECK $deckLabel',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - labelRadius * 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _JogWheelPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.accentColor != accentColor;
  }
}
