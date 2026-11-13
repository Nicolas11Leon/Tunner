import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/just_intonation_calculator.dart';

/// Interactive vector gauge visually displaying acoustic beat frequency and cents offset.
class HarmonicBeatGauge extends StatefulWidget {
  final double centsOffset;
  final double beatFrequencyHz;
  final HarmonicLockStatus status;
  final Color accentColor;

  const HarmonicBeatGauge({
    super.key,
    required this.centsOffset,
    required this.beatFrequencyHz,
    required this.status,
    required this.accentColor,
  });

  @override
  State<HarmonicBeatGauge> createState() => _HarmonicBeatGaugeState();
}

class _HarmonicBeatGaugeState extends State<HarmonicBeatGauge> with SingleTickerProviderStateMixin {
  late AnimationController _wobbleController;

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _wobbleController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 140),
          painter: _HarmonicBeatPainter(
            centsOffset: widget.centsOffset,
            beatHz: widget.beatFrequencyHz,
            status: widget.status,
            accentColor: widget.accentColor,
            animValue: _wobbleController.value,
          ),
        );
      },
    );
  }
}

class _HarmonicBeatPainter extends CustomPainter {
  final double centsOffset;
  final double beatHz;
  final HarmonicLockStatus status;
  final Color accentColor;
  final double animValue;

  _HarmonicBeatPainter({
    required this.centsOffset,
    required this.beatHz,
    required this.status,
    required this.accentColor,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.height * 0.75;

    // 1. Draw Gauge Arc Background
    final arcPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      arcPaint,
    );

    // 2. Draw Consonance Target Zone (±3.0 cents zone around top)
    final lockZonePaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    const lockAngleWidth = (3.0 / 50.0) * (math.pi / 2.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      (1.5 * math.pi) - lockAngleWidth,
      lockAngleWidth * 2.0,
      false,
      lockZonePaint,
    );

    // 3. Compute Needle Angle
    // Cents offset clamped to [-50, +50] cents mapped across [pi, 2*pi]
    final clampedCents = centsOffset.clamp(-50.0, 50.0);
    var baseAngle = (1.5 * math.pi) + (clampedCents / 50.0) * (math.pi / 2.2);

    // If beating is active and not locked, add wobble proportional to beatHz
    if (status != HarmonicLockStatus.pureConsonance) {
      final wobbleSpeed = (beatHz.clamp(0.5, 15.0));
      final wobbleAmount = (0.04 * (wobbleSpeed / 15.0)).clamp(0.005, 0.05);
      final wobbleOffset = math.sin(animValue * 2.0 * math.pi * wobbleSpeed) * wobbleAmount;
      baseAngle += wobbleOffset;
    }

    // Determine status color
    final needleColor = status == HarmonicLockStatus.pureConsonance
        ? const Color(0xFF00E676) // Pure green
        : status == HarmonicLockStatus.adjusting
            ? const Color(0xFFFFB300) // Amber
            : const Color(0xFFE53935); // Red

    // 4. Draw Needle
    final needleLength = radius * 0.90;
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(baseAngle),
      center.dy + needleLength * math.sin(baseAngle),
    );

    final needlePaint = Paint()
      ..color = needleColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(center, needleEnd, needlePaint);

    // Center pivot point
    final pivotPaint = Paint()..color = needleColor;
    canvas.drawCircle(center, 5.0, pivotPaint);

    // 5. Draw Digital Readings
    final tp = TextPainter(
      text: TextSpan(
        text: status == HarmonicLockStatus.pureConsonance
            ? '0.0 Hz  •  LOCK'
            : '${beatHz.toStringAsFixed(1)} Hz Batimiento',
        style: TextStyle(
          color: needleColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(center.dx - (tp.width / 2), size.height * 0.05));
  }

  @override
  bool shouldRepaint(covariant _HarmonicBeatPainter oldDelegate) {
    return oldDelegate.centsOffset != centsOffset ||
        oldDelegate.beatHz != beatHz ||
        oldDelegate.status != status ||
        oldDelegate.animValue != animValue;
  }
}
