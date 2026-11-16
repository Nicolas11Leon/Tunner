import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Medidor de nivel acústico estéreo de estudio (StudioStereoVuMeter).
/// Renderiza dos columnas verticales de segmentos LED (Canal L y R) con colores
/// verde, amarillo y rojo (CLIP), y retención de picos de señal.
class StudioStereoVuMeter extends StatelessWidget {
  final double levelLeft;
  final double levelRight;
  final double peakLeft;
  final double peakRight;
  final double height;
  final double width;

  const StudioStereoVuMeter({
    super.key,
    required this.levelLeft,
    required this.levelRight,
    this.peakLeft = 0.0,
    this.peakRight = 0.0,
    this.height = 120.0,
    this.width = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _StereoVuMeterPainter(
          levelL: levelLeft.clamp(0.0, 1.2),
          levelR: levelRight.clamp(0.0, 1.2),
          peakL: math.max(levelLeft, peakLeft).clamp(0.0, 1.2),
          peakR: math.max(levelRight, peakRight).clamp(0.0, 1.2),
        ),
      ),
    );
  }
}

class _StereoVuMeterPainter extends CustomPainter {
  final double levelL;
  final double levelR;
  final double peakL;
  final double peakR;

  static const int segmentCount = 14;

  const _StereoVuMeterPainter({
    required this.levelL,
    required this.levelR,
    required this.peakL,
    required this.peakR,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final channelWidth = (size.width - 2) / 2;
    final segmentHeight = (size.height - (segmentCount - 1) * 2) / segmentCount;

    // Dibujar canal izquierdo (L)
    _drawChannel(canvas, 0, channelWidth, segmentHeight, levelL, peakL);

    // Dibujar canal derecho (R)
    _drawChannel(canvas, channelWidth + 2, channelWidth, segmentHeight, levelR, peakR);
  }

  void _drawChannel(
    Canvas canvas,
    double xOffset,
    double width,
    double segmentHeight,
    double level,
    double peak,
  ) {
    final activeSegments = (level * segmentCount).round().clamp(0, segmentCount);
    final peakSegment = (peak * segmentCount).round().clamp(0, segmentCount - 1);

    for (int i = 0; i < segmentCount; i++) {
      // Invertir para que 0 sea abajo y segmentCount arriba
      final visualIndex = segmentCount - 1 - i;
      final y = visualIndex * (segmentHeight + 2);

      Color color;
      if (i >= segmentCount - 2) {
        color = const Color(0xFFEF4444); // Rojo (Clip / +6 dB)
      } else if (i >= segmentCount - 5) {
        color = const Color(0xFFF59E0B); // Ámbar (0 dB a +3 dB)
      } else {
        color = const Color(0xFF10B981); // Verde (-24 dB a -3 dB)
      }

      final isLit = i < activeSegments;
      final isPeak = i == peakSegment && peak > 0.05;

      final paint = Paint()
        ..color = isLit
            ? color
            : (isPeak ? color : color.withValues(alpha: 0.12));

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(xOffset, y, width, segmentHeight),
        const Radius.circular(1.0),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StereoVuMeterPainter oldDelegate) {
    return oldDelegate.levelL != levelL ||
        oldDelegate.levelR != levelR ||
        oldDelegate.peakL != peakL ||
        oldDelegate.peakR != peakR;
  }
}
