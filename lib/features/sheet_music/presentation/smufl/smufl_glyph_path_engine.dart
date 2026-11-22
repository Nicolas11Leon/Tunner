import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Motor geométrico vectorial para la renderización de glifos musicales basados en la
/// especificación SMuFL (Standard Music Font Layout, W3C Music Notation Community Group).
///
/// Todas las dimensiones y proporciones se derivan dinámicamente de [staffSpace] ($sp$),
/// que representa la distancia métrica entre dos líneas consecutivas del pentagrama.
class SmuflGlyphPathEngine {
  const SmuflGlyphPathEngine();

  // W3C SMuFL 1.4 Canonical Codepoints (Bravura reference mapping)
  static const int codepointGClef = 0xE050;
  static const int codepointFClef = 0xE062;
  static const int codepointCClef = 0xE05C;
  static const int codepointNoteheadWhole = 0xE0A2;
  static const int codepointNoteheadHalf = 0xE0A3;
  static const int codepointNoteheadBlack = 0xE0A4;
  static const int codepointAugmentationDot = 0xE1E7;
  static const int codepointFlag8thUp = 0xE240;
  static const int codepointFlag8thDown = 0xE241;
  static const int codepointFlag16thUp = 0xE242;
  static const int codepointFlag16thDown = 0xE243;
  static const int codepointAccidentalFlat = 0xE260;
  static const int codepointAccidentalNatural = 0xE261;
  static const int codepointAccidentalSharp = 0xE262;
  static const int codepointRestWhole = 0xE4E3;
  static const int codepointRestHalf = 0xE4E4;
  static const int codepointRestQuarter = 0xE4E5;
  static const int codepointRest8th = 0xE4E6;
  static const int codepointRest16th = 0xE4E7;

  /// Retorna el punto de anclaje de plica ascendente (`stemUpSE`) relativo al centro de la nota.
  Offset getStemUpAnchor(double staffSpace) {
    return Offset(staffSpace * 0.58, -staffSpace * 0.16);
  }

  /// Retorna el punto de anclaje de plica descendente (`stemDownNW`) relativo al centro de la nota.
  Offset getStemDownAnchor(double staffSpace) {
    return Offset(-staffSpace * 0.58, staffSpace * 0.16);
  }

  /// Dibuja una cabeza de nota musical vectorial con la rotación y proporciones canónicas de SMuFL.
  ///
  /// - Negra / Corchea ([noteheadBlack]): Elipse rellena inclinada a ~14 grados.
  /// - Blanca ([noteheadHalf]): Elipse hueca con corte interior orientado.
  /// - Redonda ([noteheadWhole]): Cabeza de nota ancha con cortes simétricos.
  void drawNotehead(
    Canvas canvas, {
    required Offset center,
    required double staffSpace,
    required Color color,
    bool isWhole = false,
    bool isHalf = false,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    if (isWhole) {
      // noteheadWhole: ancho ~1.4 sp, alto ~0.9 sp
      final radiusX = staffSpace * 0.72;
      final radiusY = staffSpace * 0.46;
      final rect = Rect.fromCenter(center: Offset.zero, width: radiusX * 2, height: radiusY * 2);

      final outerPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // Corte central caracteristico con PathFillType.evenOdd (sin saveLayer)
      final innerRect = Rect.fromCenter(
        center: Offset.zero,
        width: radiusX * 0.95,
        height: radiusY * 0.42,
      );
      final wholePath = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(rect)
        ..addOval(innerRect);
      canvas.drawPath(wholePath, outerPaint);
    } else {
      // Rotación canónica de 14 grados (~0.244 radianes)
      canvas.rotate(-14.0 * math.pi / 180.0);

      final radiusX = staffSpace * 0.60;
      final radiusY = staffSpace * 0.44;
      final rect = Rect.fromCenter(center: Offset.zero, width: radiusX * 2, height: radiusY * 2);

      final paint = Paint()
        ..color = color
        ..style = isHalf ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = isHalf ? (staffSpace * 0.22) : 0.0;

      canvas.drawOval(rect, paint);
    }

    canvas.restore();
  }

  /// Dibuja un puntillo de aumentacion vectorial SMuFL (`augmentationDot`, U+E1E7).
  void drawAugmentationDot(
    Canvas canvas, {
    required Offset center,
    required double staffSpace,
    required Color color,
  }) {
    final dotRadius = staffSpace * 0.20;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, dotRadius, dotPaint);
  }

  /// Dibuja la plica de una nota musical con anclaje al borde exacto de la cabeza.
  ///
  /// Longitud estándar: 3.5 staff spaces.
  /// Grosor estándar: ~0.12 staff spaces.
  void drawStem(
    Canvas canvas, {
    required Offset noteCenter,
    required double staffSpace,
    required bool isUp,
    required Color color,
    double lengthSpaces = 3.5,
  }) {
    final stemThickness = math.max(1.2, staffSpace * 0.12);
    final stemLength = staffSpace * lengthSpaces;
    final noteWidth = staffSpace * 0.60;

    // Si la plica va hacia arriba, se ancla al borde derecho de la cabeza.
    // Si va hacia abajo, se ancla al borde izquierdo.
    final startX = isUp ? (noteCenter.dx + noteWidth - stemThickness / 2) : (noteCenter.dx - noteWidth + stemThickness / 2);
    final startY = noteCenter.dy;
    final endY = isUp ? (startY - stemLength) : (startY + stemLength);

    final paint = Paint()
      ..color = color
      ..strokeWidth = stemThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(startX, startY), Offset(startX, endY), paint);
  }

  /// Dibuja el corchete vectorial canónico SMuFL (para corcheas y semicorcheas).
  void drawFlag(
    Canvas canvas, {
    required Offset stemTip,
    required double staffSpace,
    required bool isUp,
    required int flagCount,
    required Color color,
  }) {
    final flagHeight = staffSpace * 1.5;
    final flagWidth = staffSpace * 0.9;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < flagCount; i++) {
      final yOffset = i * (staffSpace * 0.85);
      final origin = Offset(stemTip.dx, isUp ? (stemTip.dy + yOffset) : (stemTip.dy - yOffset));

      final path = Path();
      path.moveTo(origin.dx, origin.dy);

      if (isUp) {
        // Corchete superior descendente
        path.cubicTo(
          origin.dx + flagWidth * 0.8,
          origin.dy + flagHeight * 0.25,
          origin.dx + flagWidth,
          origin.dy + flagHeight * 0.65,
          origin.dx + flagWidth * 0.2,
          origin.dy + flagHeight,
        );
        path.cubicTo(
          origin.dx + flagWidth * 0.5,
          origin.dy + flagHeight * 0.5,
          origin.dx + flagWidth * 0.3,
          origin.dy + flagHeight * 0.2,
          origin.dx,
          origin.dy + flagHeight * 0.15,
        );
      } else {
        // Corchete inferior ascendente
        path.cubicTo(
          origin.dx + flagWidth * 0.8,
          origin.dy - flagHeight * 0.25,
          origin.dx + flagWidth,
          origin.dy - flagHeight * 0.65,
          origin.dx + flagWidth * 0.2,
          origin.dy - flagHeight,
        );
        path.cubicTo(
          origin.dx + flagWidth * 0.5,
          origin.dy - flagHeight * 0.5,
          origin.dx + flagWidth * 0.3,
          origin.dy - flagHeight * 0.2,
          origin.dx,
          origin.dy - flagHeight * 0.15,
        );
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  /// Dibuja la Clave de Sol vectorial SMuFL (`gClef`), anclada en la segunda línea del pentagrama.
  void drawGClef(
    Canvas canvas, {
    required Offset anchorLine2,
    required double staffSpace,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(anchorLine2.dx, anchorLine2.dy);

    final scale = staffSpace / 10.0;
    canvas.scale(scale, scale);

    final path = Path();
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Eje vertical con bucle superior y gancho inferior con gota
    path.moveTo(0, -32);
    path.cubicTo(-6, -20, -8, -12, -4, -4);
    path.cubicTo(0, 4, 8, 4, 9, -2);
    path.cubicTo(10, -8, 2, -14, -6, -8);
    path.cubicTo(-14, -2, -12, 10, 0, 16);
    path.cubicTo(6, 19, 8, 24, 6, 29);
    path.cubicTo(4, 34, -2, 35, -5, 32);

    canvas.drawPath(path, strokePaint);

    // Gota / punto terminal inferior
    canvas.drawCircle(const Offset(-5, 32), 3.2, fillPaint);
    // Bucle central con masa
    canvas.drawCircle(const Offset(1, -2), 3.0, fillPaint);

    canvas.restore();
  }

  /// Dibuja la Clave de Fa vectorial SMuFL (`fClef`), centrada en la cuarta línea del pentagrama.
  void drawFClef(
    Canvas canvas, {
    required Offset anchorLine4,
    required double staffSpace,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(anchorLine4.dx, anchorLine4.dy);

    final scale = staffSpace / 10.0;
    canvas.scale(scale, scale);

    final path = Path();
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Cabeza inicial en la línea 4
    canvas.drawCircle(const Offset(-6, 0), 3.8, fillPaint);

    // Curva principal en C descendente
    path.moveTo(-6, 0);
    path.cubicTo(-2, -12, 12, -14, 12, -2);
    path.cubicTo(12, 8, 4, 16, -6, 22);
    canvas.drawPath(path, strokePaint);

    // Dos puntos canónicos en espacios 3 y 4 (arriba y abajo de la línea 4)
    canvas.drawCircle(const Offset(18, -5), 2.4, fillPaint);
    canvas.drawCircle(const Offset(18, 5), 2.4, fillPaint);

    canvas.restore();
  }

  /// Dibuja la Clave de Do vectorial SMuFL (`cClef`, U+E05C), centrada en la línea seleccionada.
  void drawCClef(
    Canvas canvas, {
    required Offset anchorLine,
    required double staffSpace,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(anchorLine.dx, anchorLine.dy);

    final scale = staffSpace / 10.0;
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Dos barras verticales a la izquierda
    canvas.drawLine(const Offset(-10, -20), const Offset(-10, 20), strokePaint);
    canvas.drawRect(const Rect.fromLTWH(-7, -20, 2.5, 40), fillPaint);

    // Arcos superior e inferior que confluyen en la línea central (y = 0)
    final path = Path();
    path.moveTo(-4, -20);
    path.cubicTo(6, -20, 8, -10, -4, 0);
    path.cubicTo(8, 10, 6, 20, -4, 20);
    canvas.drawPath(path, strokePaint);

    // Muesca central
    final notch = Path();
    notch.moveTo(-4, -4);
    notch.lineTo(0, 0);
    notch.lineTo(-4, 4);
    notch.close();
    canvas.drawPath(notch, fillPaint);

    canvas.restore();
  }

  /// Dibuja silencios vectoriales normalizados SMuFL según su duración en ticks.
  ///
  /// - 16 ticks: Silencio de redonda (`restWhole`, rectángulo colgado bajo la línea 4).
  /// - 8 ticks: Silencio de blanca (`restHalf`, rectángulo apoyado sobre la línea 3).
  /// - 4 ticks: Silencio de negra (`restQuarter`, glifo en zigzag).
  /// - 2 ticks: Silencio de corchea (`rest8th`, gota curva en espacio 3 con plica oblicua).
  /// - 1 tick: Silencio de semicorchea (`rest16th`).
  void drawRest(
    Canvas canvas, {
    required Offset centerLine3,
    required double staffSpace,
    required int durationTicks,
    required Color color,
  }) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (durationTicks >= 16) {
      // Silencio de Redonda: colgado debajo de la línea 4
      final topY = centerLine3.dy - staffSpace;
      final rect = Rect.fromLTWH(
        centerLine3.dx - staffSpace * 0.5,
        topY,
        staffSpace * 1.0,
        staffSpace * 0.48,
      );
      canvas.drawRect(rect, fillPaint);
    } else if (durationTicks >= 8) {
      // Silencio de Blanca: sentado sobre la línea 3
      final bottomY = centerLine3.dy;
      final rect = Rect.fromLTWH(
        centerLine3.dx - staffSpace * 0.5,
        bottomY - staffSpace * 0.48,
        staffSpace * 1.0,
        staffSpace * 0.48,
      );
      canvas.drawRect(rect, fillPaint);
    } else if (durationTicks >= 4) {
      // Silencio de Negra: zigzag vectorial
      canvas.save();
      canvas.translate(centerLine3.dx, centerLine3.dy);
      final scale = staffSpace / 10.0;
      canvas.scale(scale, scale);

      final path = Path();
      path.moveTo(-3, -12);
      path.lineTo(3, -5);
      path.lineTo(-4, 2);
      path.lineTo(2, 9);
      path.cubicTo(1, 14, -5, 14, -5, 12);
      path.cubicTo(-2, 10, 0, 7, -2, 5);
      path.lineTo(2, 1);
      path.lineTo(-4, -6);
      path.close();

      canvas.drawPath(path, fillPaint);
      canvas.restore();
    } else {
      // Silencio de Corchea / Semicorchea
      final is16th = durationTicks <= 1;
      canvas.save();
      canvas.translate(centerLine3.dx, centerLine3.dy);
      final scale = staffSpace / 10.0;
      canvas.scale(scale, scale);

      // Plica oblicua
      final strokePaint = Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(const Offset(3, -12), const Offset(-3, 12), strokePaint);
      // Gota superior en espacio 3
      canvas.drawCircle(const Offset(0, -6), 2.5, fillPaint);
      if (is16th) {
        // Gota adicional en espacio 2
        canvas.drawCircle(const Offset(-1.5, 2), 2.5, fillPaint);
      }

      canvas.restore();
    }
  }

  /// Dibuja alteraciones vectoriales: sostenido (#), bemol (b) o becuadro.
  void drawAccidental(
    Canvas canvas, {
    required Offset center,
    required double staffSpace,
    required String accidental,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final scale = staffSpace / 10.0;
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (accidental == '#' || accidental == '♯') {
      // Sostenido: dos barras verticales y dos barras diagonales inclinadas gruesas
      canvas.drawLine(const Offset(-3, -12), const Offset(-3, 12), strokePaint);
      canvas.drawLine(const Offset(3, -10), const Offset(3, 14), strokePaint);

      final barPaint = Paint()
        ..color = color
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(const Offset(-6, -2), const Offset(6, -5), barPaint);
      canvas.drawLine(const Offset(-6, 5), const Offset(6, 2), barPaint);
    } else if (accidental == 'b' || accidental == '♭') {
      // Bemol: línea vertical alta y lóbulo curvado
      canvas.drawLine(const Offset(-3, -14), const Offset(-3, 6), strokePaint);

      final path = Path();
      path.moveTo(-3, 6);
      path.cubicTo(4, 6, 5, -2, -3, -2);
      path.close();
      canvas.drawPath(path, fillPaint);
    } else if (accidental == 'n' || accidental == '♮') {
      // Becuadro: dos verticales paralelas y dos diagonales
      canvas.drawLine(const Offset(-3, -12), const Offset(-3, 6), strokePaint);
      canvas.drawLine(const Offset(3, -6), const Offset(3, 12), strokePaint);

      final barPaint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;

      canvas.drawLine(const Offset(-3, -5), const Offset(3, -8), barPaint);
      canvas.drawLine(const Offset(-3, 5), const Offset(3, 2), barPaint);
    }

    canvas.restore();
  }

  /// Dibuja líneas adicionales del pentagrama (*ledger lines*) si la nota se encuentra fuera del pentagrama.
  void drawLedgerLines(
    Canvas canvas, {
    required Offset noteCenter,
    required double staffSpace,
    required int stepFromLine1,
    required Color color,
    double lineWidth = 24.0,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.max(1.0, staffSpace * 0.12)
      ..style = PaintingStyle.stroke;

    final halfWidth = lineWidth / 2.0;

    // Si está por debajo de la línea 1 (step < 0)
    if (stepFromLine1 < 0) {
      for (int step = -2; step >= stepFromLine1; step -= 2) {
        final lineY = noteCenter.dy + ((stepFromLine1 - step) * (staffSpace / 2.0));
        canvas.drawLine(
          Offset(noteCenter.dx - halfWidth, lineY),
          Offset(noteCenter.dx + halfWidth, lineY),
          paint,
        );
      }
    }

    // Si está por encima de la línea 5 (step > 8)
    if (stepFromLine1 > 8) {
      for (int step = 10; step <= stepFromLine1; step += 2) {
        final lineY = noteCenter.dy + ((stepFromLine1 - step) * (staffSpace / 2.0));
        canvas.drawLine(
          Offset(noteCenter.dx - halfWidth, lineY),
          Offset(noteCenter.dx + halfWidth, lineY),
          paint,
        );
      }
    }
  }
}
