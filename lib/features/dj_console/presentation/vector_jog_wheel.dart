import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Highly responsive, vector-rendered DJ Jog Wheel platter with vinyl grooves and rotation tracking.
class VectorJogWheel extends StatelessWidget {
  final String deckLabel; // 'A' or 'B'
  final Color accentColor;
  final bool isPlaying;
  final double rotationAngle; // in radians
  final ValueChanged<double>? onScratch; // delta radians
  final VoidCallback? onTap;

  const VectorJogWheel({
    super.key,
    required this.deckLabel,
    required this.accentColor,
    required this.isPlaying,
    required this.rotationAngle,
    this.onScratch,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onPanUpdate: (details) {
        if (onScratch != null) {
          // Approximate rotational delta from pan delta
          final delta = (details.delta.dx - details.delta.dy) * 0.02;
          onScratch!(delta);
        }
      },
      child: RepaintBoundary(
        child: CustomPaint(
          size: const Size(160, 160),
          painter: _JogWheelPainter(
            deckLabel: deckLabel,
            accentColor: accentColor,
            rotationAngle: rotationAngle,
            isPlaying: isPlaying,
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
