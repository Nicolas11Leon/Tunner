import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/chord_entity.dart';

/// Widget vectorial de alta precisión que renderiza el Radar Cromático (Chroma Radar).
/// Visualiza la distribución de energía en las 12 clases de tono ($C \dots B$) dispuestas
/// circularmente en sentido horario como un reloj armónico de quintas / semitonos.
class ChordRadarWidget extends StatelessWidget {
  final List<double> chromaVector;
  final ChordEntity recognizedChord;
  final TunnerThemePalette palette;
  final double size;

  const ChordRadarWidget({
    super.key,
    required this.chromaVector,
    required this.recognizedChord,
    required this.palette,
    this.size = 260.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ChordRadarPainter(
          chromaVector: chromaVector,
          recognizedChord: recognizedChord,
          palette: palette,
        ),
      ),
    );
  }
}

class _ChordRadarPainter extends CustomPainter {
  final List<double> chromaVector;
  final ChordEntity recognizedChord;
  final TunnerThemePalette palette;

  const _ChordRadarPainter({
    required this.chromaVector,
    required this.recognizedChord,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 24;

    // 1. Dibujar anillos concéntricos de referencia de energía
    final ringPaint = Paint()
      ..color = palette.staffLinesColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int r = 1; r <= 3; r++) {
      canvas.drawCircle(center, maxRadius * (r / 3), ringPaint);
    }

    // 2. Dibujar ejes radiales de los 12 semitonos
    final axisPaint = Paint()
      ..color = palette.staffLinesColor.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    final List<Offset> energyPoints = [];
    final activePitchClasses = <int>{};

    if (recognizedChord.isRecognized) {
      for (final interval in recognizedChord.quality.intervalsInSemitones) {
        activePitchClasses.add((recognizedChord.rootNoteIndex + interval) % 12);
      }
    }

    const startAngle = -math.pi / 2; // C (Do) en las 12 en punto

    for (int i = 0; i < 12; i++) {
      final angle = startAngle + (i * 2 * math.pi / 12);
      final dir = Offset(math.cos(angle), math.sin(angle));
      final edge = center + dir * maxRadius;

      canvas.drawLine(center, edge, axisPaint);

      // Calcular punto de energía
      final energy = (i < chromaVector.length ? chromaVector[i] : 0.0).clamp(0.0, 1.0);
      final pointRadius = math.max(6.0, maxRadius * (0.15 + 0.85 * energy));
      energyPoints.add(center + dir * pointRadius);

      // 3. Dibujar etiqueta de la nota
      final labelOffset = center + dir * (maxRadius + 14);
      final isChordNote = activePitchClasses.contains(i);

      final textSpan = TextSpan(
        text: ChordEntity.internationalNoteNames[i],
        style: TextStyle(
          color: isChordNote
              ? palette.primaryAccent
              : (energy > 0.35 ? palette.secondaryAccent : palette.textMutedColor),
          fontSize: isChordNote ? 12 : 10,
          fontWeight: isChordNote ? FontWeight.w900 : FontWeight.w600,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        labelOffset - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    // 4. Dibujar polígono de energía cromática con relleno traslúcido
    if (energyPoints.length == 12) {
      final polyPath = Path()..moveTo(energyPoints[0].dx, energyPoints[0].dy);
      for (int i = 1; i < 12; i++) {
        polyPath.lineTo(energyPoints[i].dx, energyPoints[i].dy);
      }
      polyPath.close();

      final fillPaint = Paint()
        ..color = palette.secondaryAccent.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawPath(polyPath, fillPaint);

      final strokePaint = Paint()
        ..color = palette.secondaryAccent.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawPath(polyPath, strokePaint);
    }

    // 5. Destacar nodos del acorde detectado
    for (int i = 0; i < 12; i++) {
      final isChordNote = activePitchClasses.contains(i);
      final point = energyPoints[i];

      final nodePaint = Paint()
        ..color = isChordNote
            ? palette.primaryAccent
            : palette.cardBackground
        ..style = PaintingStyle.fill;

      canvas.drawCircle(point, isChordNote ? 5.5 : 3.0, nodePaint);

      if (isChordNote) {
        final glowPaint = Paint()
          ..color = palette.primaryAccent.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
        canvas.drawCircle(point, 7.5, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChordRadarPainter oldDelegate) {
    return oldDelegate.recognizedChord != recognizedChord ||
        oldDelegate.chromaVector != chromaVector ||
        oldDelegate.palette != palette;
  }
}
