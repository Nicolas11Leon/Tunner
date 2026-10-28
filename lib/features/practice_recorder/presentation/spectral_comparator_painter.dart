import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/spectral_comparator_service.dart';

/// Pintor vectorial de alto rendimiento para la contrastación visual de entonación y espectro entre dos tomas.
class SpectralComparatorPainter extends CustomPainter {
  final SpectralComparisonResult comparison;
  final TunnerThemePalette palette;
  final Color colorTakeA;
  final Color colorTakeB;
  final double currentPlaybackPositionNormalized; // 0.0 a 1.0

  SpectralComparatorPainter({
    required this.comparison,
    required this.palette,
    Color? colorTakeA,
    Color? colorTakeB,
    this.currentPlaybackPositionNormalized = 0.0,
  })  : colorTakeA = colorTakeA ?? const Color(0xFF00E5FF), // Cyan brillante para Toma A
        colorTakeB = colorTakeB ?? const Color(0xFFFFD700); // Oro brillante para Toma B

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final bgPaint = Paint()..color = palette.staffBackground;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      bgPaint,
    );

    // Distribución vertical: 75% para entonación (cents), 25% para brillo espectral (Hz)
    final pitchHeight = size.height * 0.72;
    final spectralTop = size.height * 0.76;
    final spectralHeight = size.height * 0.20;

    _drawPitchGrid(canvas, size.width, pitchHeight);
    _drawPitchCurves(canvas, size.width, pitchHeight);
    _drawSpectralEnvelope(canvas, size.width, spectralTop, spectralHeight);

    if (currentPlaybackPositionNormalized > 0.0 && currentPlaybackPositionNormalized <= 1.0) {
      _drawPlayhead(canvas, size.width, size.height);
    }
  }

  void _drawPitchGrid(Canvas canvas, double width, double height) {
    final zeroY = height * 0.5; // 0 cents en el centro vertical
    const maxCents = 50.0;
    final scaleY = (height * 0.42) / maxCents;

    // Banda de tolerancia pura de conservatorio (+-5 cents)
    final toleranceRect = Rect.fromLTRB(
      36,
      zeroY - (5.0 * scaleY),
      width - 12,
      zeroY + (5.0 * scaleY),
    );
    final tolerancePaint = Paint()
      ..color = palette.correctPitchColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRect(toleranceRect, tolerancePaint);

    final linePaint = Paint()
      ..color = palette.staffLinesColor.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    final centerLinePaint = Paint()
      ..color = palette.correctPitchColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;

    // Líneas de referencia (-50, -25, 0, +25, +50 cents)
    final centLevels = [-50.0, -25.0, 0.0, 25.0, 50.0];
    for (final level in centLevels) {
      final y = zeroY - (level * scaleY);
      final isCenter = level == 0.0;
      canvas.drawLine(
        Offset(36, y),
        Offset(width - 12, y),
        isCenter ? centerLinePaint : linePaint,
      );

      // Texto de nivel
      final label = isCenter ? "0 c" : "${level > 0 ? '+' : ''}${level.toInt()}";
      _drawText(
        canvas,
        label,
        Offset(4, y - 6),
        isCenter ? palette.correctPitchColor : palette.textMutedColor,
        9.0,
        fontWeight: isCenter ? FontWeight.bold : FontWeight.normal,
      );
    }
  }

  void _drawPitchCurves(Canvas canvas, double width, double height) {
    final points = comparison.comparisonPoints;
    if (points.isEmpty) return;

    final zeroY = height * 0.5;
    const maxCents = 50.0;
    final scaleY = (height * 0.42) / maxCents;
    final graphWidth = width - 48;
    final startX = 36.0;

    final paintA = Paint()
      ..color = colorTakeA
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paintB = Paint()
      ..color = colorTakeB
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Path? pathA;
    Path? pathB;

    for (int i = 0; i < points.length; i++) {
      final normX = i / (points.length - 1);
      final x = startX + (normX * graphWidth);

      // Curva Toma A
      if (points[i].centsA != null) {
        final clampedCentsA = points[i].centsA!.clamp(-maxCents, maxCents);
        final yA = zeroY - (clampedCentsA * scaleY);
        if (pathA == null) {
          pathA = Path()..moveTo(x, yA);
        } else {
          pathA.lineTo(x, yA);
        }
      } else {
        if (pathA != null) {
          canvas.drawPath(pathA, paintA);
          pathA = null;
        }
      }

      // Curva Toma B
      if (points[i].centsB != null) {
        final clampedCentsB = points[i].centsB!.clamp(-maxCents, maxCents);
        final yB = zeroY - (clampedCentsB * scaleY);
        if (pathB == null) {
          pathB = Path()..moveTo(x, yB);
        } else {
          pathB.lineTo(x, yB);
        }
      } else {
        if (pathB != null) {
          canvas.drawPath(pathB, paintB);
          pathB = null;
        }
      }
    }

    if (pathA != null) canvas.drawPath(pathA, paintA);
    if (pathB != null) canvas.drawPath(pathB, paintB);
  }

  void _drawSpectralEnvelope(Canvas canvas, double width, double top, double height) {
    final points = comparison.comparisonPoints;
    if (points.isEmpty) return;

    final graphWidth = width - 48;
    final startX = 36.0;
    const maxCentroid = 2500.0;

    // Etiqueta lateral
    _drawText(canvas, "TIMBRE", Offset(4, top + (height / 2) - 5), palette.textMutedColor, 8.0);

    final linePaint = Paint()
      ..color = palette.staffLinesColor.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(startX, top), Offset(width - 12, top), linePaint);
    canvas.drawLine(Offset(startX, top + height), Offset(width - 12, top + height), linePaint);

    final paintSpecA = Paint()
      ..color = colorTakeA.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paintSpecB = Paint()
      ..color = colorTakeB.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    Path? pathSpecA;
    Path? pathSpecB;

    for (int i = 0; i < points.length; i++) {
      final normX = i / (points.length - 1);
      final x = startX + (normX * graphWidth);

      if (points[i].centroidA != null && points[i].centroidA! > 0) {
        final normCentroid = (points[i].centroidA! / maxCentroid).clamp(0.0, 1.0);
        final y = top + height - (normCentroid * height);
        if (pathSpecA == null) {
          pathSpecA = Path()..moveTo(x, y);
        } else {
          pathSpecA.lineTo(x, y);
        }
      } else {
        if (pathSpecA != null) {
          canvas.drawPath(pathSpecA, paintSpecA);
          pathSpecA = null;
        }
      }

      if (points[i].centroidB != null && points[i].centroidB! > 0) {
        final normCentroid = (points[i].centroidB! / maxCentroid).clamp(0.0, 1.0);
        final y = top + height - (normCentroid * height);
        if (pathSpecB == null) {
          pathSpecB = Path()..moveTo(x, y);
        } else {
          pathSpecB.lineTo(x, y);
        }
      } else {
        if (pathSpecB != null) {
          canvas.drawPath(pathSpecB, paintSpecB);
          pathSpecB = null;
        }
      }
    }

    if (pathSpecA != null) canvas.drawPath(pathSpecA, paintSpecA);
    if (pathSpecB != null) canvas.drawPath(pathSpecB, paintSpecB);
  }

  void _drawPlayhead(Canvas canvas, double width, double height) {
    final graphWidth = width - 48;
    final x = 36.0 + (currentPlaybackPositionNormalized * graphWidth);
    final headPaint = Paint()
      ..color = palette.playheadColor
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(x, 4), Offset(x, height - 4), headPaint);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant SpectralComparatorPainter oldDelegate) {
    return oldDelegate.comparison != comparison ||
        oldDelegate.palette != palette ||
        oldDelegate.currentPlaybackPositionNormalized != currentPlaybackPositionNormalized;
  }
}
