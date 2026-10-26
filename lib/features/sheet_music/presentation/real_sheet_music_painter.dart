import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/score_tree.dart';

/// Registro de ejecución de una nota o silencio por el usuario para coloreado histórico.
class PlayedRecord {
  final String noteName;
  final double cents;
  final bool isCorrect;
  final bool isRest;

  const PlayedRecord(
    this.noteName,
    this.cents,
    this.isCorrect, {
    this.isRest = false,
  });
}

/// Motor gráfico vectorial para el renderizado del pentagrama musical clásico,
/// figuras, silencios, armaduras, playhead dinámico y retroalimentación de afinación en vivo.
class RealSheetMusicPainter extends CustomPainter {
  final int currentSubTick;
  final List<HierarchicalNote> notes;
  final Map<int, PlayedRecord> history;
  final String liveNote;
  final double liveCents;
  final bool isCountingIn;
  final int countInBeat;
  final TimeSignature timeSignature;
  final int measureIndex;
  final int totalMeasures;
  final TunnerThemePalette palette;

  RealSheetMusicPainter({
    required this.currentSubTick,
    required this.notes,
    required this.history,
    required this.liveNote,
    required this.liveCents,
    required this.isCountingIn,
    required this.countInBeat,
    this.timeSignature = TimeSignature.commonTime44,
    this.measureIndex = 0,
    this.totalMeasures = 1,
    this.palette = TunnerThemePalette.obsidianStudio,
  });

  int _getNoteStep(String note) {
    if (note.isEmpty || note == "--") return -100;
    String raw = note.replaceAll(RegExp(r'[0-9#]'), '').toLowerCase();
    int octave = int.tryParse(note.replaceAll(RegExp(r'[^0-9]'), '')) ?? 4;
    
    int step = 0;
    switch (raw) {
      case "do": step = 0; break;
      case "re": step = 1; break;
      case "mi": step = 2; break; // Línea inferior del pentagrama
      case "fa": step = 3; break;
      case "sol": step = 4; break;
      case "la": step = 5; break;
      case "si": step = 6; break; // Tercera línea (Centro)
      default: step = 0;
    }
    step += (octave - 4) * 7;
    return step;
  }

  void _drawUnicodeText(Canvas canvas, String text, double x, double y, double size, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontFamily: 'serif')),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(x - (textPainter.width / 2), y - (textPainter.height / 2)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = palette.staffLinesColor..strokeWidth = 2.0;
    
    final double leftMargin = 75.0;
    final double rightMargin = 20.0;
    final double playAreaWidth = size.width - leftMargin - rightMargin;
    final int totalMeasureTicks = timeSignature.totalTicks;
    final double stepWidth = playAreaWidth / totalMeasureTicks; 
    final double staffSpacing = size.height / 14;
    final double centerY = size.height / 2;
    
    double baseMi4Y = centerY + (staffSpacing * 2); 
    double topStaffY = baseMi4Y - (4 * staffSpacing);

    // 1. Dibujar el Pentagrama (5 líneas equidistantes)
    for (int i = 0; i < 5; i++) {
      double y = baseMi4Y - (i * staffSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Barra divisoria o final de compás (Barline)
    final double barX = size.width - rightMargin;
    if (measureIndex == totalMeasures - 1) {
      canvas.drawLine(Offset(barX - 6, topStaffY), Offset(barX - 6, baseMi4Y), linePaint..strokeWidth = 2.0);
      canvas.drawLine(Offset(barX, topStaffY), Offset(barX, baseMi4Y), linePaint..strokeWidth = 5.0);
    } else {
      canvas.drawLine(Offset(barX, topStaffY), Offset(barX, baseMi4Y), linePaint..strokeWidth = 3.0);
    }

    // Numeración del compás sobre la barra inicial
    _drawUnicodeText(canvas, "${measureIndex + 1}", leftMargin - 15, topStaffY - 14, 16, palette.textMutedColor);

    // 2. Dibujar la Clave de Sol (𝄞)
    _drawUnicodeText(canvas, "𝄞", 25, centerY + (staffSpacing * 0.5), 100, palette.musicalSymbolsColor);

    // Indicador numérico de Métrica / Compás (e.g. 4/4, 3/4, 6/8)
    _drawUnicodeText(canvas, "${timeSignature.numerator}", 55, centerY - (staffSpacing * 0.8), 24, palette.musicalSymbolsColor);
    _drawUnicodeText(canvas, "${timeSignature.denominator}", 55, centerY + (staffSpacing * 0.8), 24, palette.musicalSymbolsColor);

    // Conteo de entrada gigante
    if (isCountingIn) {
      final textPainter = TextPainter(
        text: TextSpan(text: "$countInBeat", style: TextStyle(color: palette.secondaryAccent, fontSize: 120, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return; 
    }

    // 3. Dibujar las Figuras Musicales de la Partitura
    final targetPaintFill = Paint()..color = palette.musicalSymbolsColor..style = PaintingStyle.fill;
    final targetPaintStroke = Paint()..color = palette.musicalSymbolsColor..style = PaintingStyle.stroke..strokeWidth = 3;

    for (var note in notes) {
      double startX = leftMargin + (note.startTick * stepWidth);
      double noteCenterX = startX + (stepWidth / 2);

      if (note.isRest) {
        String restSymbol = "";
        if (note.durationTicks >= 16) {
          restSymbol = "𝄻"; // Redonda
        } else if (note.durationTicks >= 8) {
          restSymbol = "𝄼"; // Blanca
        } else if (note.durationTicks >= 4) {
          restSymbol = "𝄽"; // Negra
        } else if (note.durationTicks >= 2) {
          restSymbol = "𝄾"; // Corchea
        } else {
          restSymbol = "𝄿"; // Semicorchea
        }
        
        _drawUnicodeText(canvas, restSymbol, noteCenterX, centerY, 55, palette.musicalSymbolsColor);
      } else {
        int step = _getNoteStep(note.noteName);
        double noteY = baseMi4Y - ((step - 2) * (staffSpacing / 2));
        
        bool isFilled = note.durationTicks <= 4;
        bool hasStem = note.durationTicks < 16;
        bool stemGoesDown = step >= 6; 
        
        // Cabeza de la nota
        canvas.save();
        canvas.translate(noteCenterX, noteY);
        canvas.rotate(-0.2); 
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 22, height: 16), isFilled ? targetPaintFill : targetPaintStroke);
        canvas.restore();

        // Plica (Stem)
        if (hasStem) {
          double stemX = stemGoesDown ? noteCenterX - 9 : noteCenterX + 9;
          double stemYStart = noteY;
          double stemYEnd = stemGoesDown ? noteY + (staffSpacing * 3.5) : noteY - (staffSpacing * 3.5);
          
          canvas.drawLine(Offset(stemX, stemYStart), Offset(stemX, stemYEnd), targetPaintFill..strokeWidth = 3.0);
          
          // Corchetes (Flags)
          if (note.durationTicks <= 2) { 
            double flagHeight = stemGoesDown ? -25 : 25;
            canvas.drawPath(
              Path()..moveTo(stemX, stemYEnd)..quadraticBezierTo(stemX + 15, stemYEnd + flagHeight/2, stemX + 5, stemYEnd + flagHeight),
              targetPaintStroke..strokeWidth = 3.0
            );
            if (note.durationTicks == 1) {
              double offset2 = stemGoesDown ? -10 : 10;
              canvas.drawPath(
                Path()..moveTo(stemX, stemYEnd - offset2)..quadraticBezierTo(stemX + 15, stemYEnd - offset2 + flagHeight/2, stemX + 5, stemYEnd - offset2 + flagHeight),
                targetPaintStroke..strokeWidth = 3.0
              );
            }
          }
        }
        
        // Líneas adicionales
        if (step <= 0 || step >= 12) {
          canvas.drawLine(Offset(noteCenterX - 18, noteY), Offset(noteCenterX + 18, noteY), targetPaintFill..strokeWidth = 2.0);
        }
      }
    }

    // 4. Cursor de Tiempo Analítico (Playhead con color de la paleta)
    if (currentSubTick >= 0) {
      final cursorPaint = Paint()..color = palette.playheadColor.withValues(alpha: 0.2);
      canvas.drawRect(Rect.fromLTWH(leftMargin + (currentSubTick * stepWidth), 0, stepWidth, size.height), cursorPaint);
    }

    // 5. Historial Dinámico de Colores
    history.forEach((tick, record) {
      double recordX = leftMargin + (tick * stepWidth) + (stepWidth / 2);
      
      if (record.isRest) {
        final p = Paint()..color = record.isCorrect ? palette.correctPitchColor.withValues(alpha: 0.5) : palette.errorPitchColor.withValues(alpha: 0.5);
        canvas.drawCircle(Offset(recordX, size.height - 20), 5, p);
      } else {
        int playedStep = _getNoteStep(record.noteName);
        if (playedStep > -100) {
          double playedY = baseMi4Y - ((playedStep - 2) * (staffSpacing / 2));
          Color dotColor = record.isCorrect ? (record.cents.abs() <= 15 ? palette.correctPitchColor : palette.warningPitchColor) : palette.errorPitchColor;
          
          final p = Paint()..color = dotColor..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);
          canvas.drawCircle(Offset(recordX, playedY), 10, p);
        }
      }
    });

    // 6. Efecto de "Esfera Flotante" para la afinación en tiempo real
    if (currentSubTick >= 0 && liveNote != "--") {
      int liveStep = _getNoteStep(liveNote);
      if (liveStep > -100) {
        double currentX = leftMargin + (currentSubTick * stepWidth) + (stepWidth / 2);
        double liveY = baseMi4Y - ((liveStep - 2) * (staffSpacing / 2));
        liveY -= (liveCents / 50.0) * (staffSpacing / 4);

        Color liveColor = (liveCents.abs() <= 15) ? palette.correctPitchColor : palette.warningPitchColor;

        final livePaint = Paint()
          ..color = liveColor.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(Offset(currentX, liveY), 14, livePaint);
        canvas.drawCircle(Offset(currentX, liveY), 6, Paint()..color = palette.musicalSymbolsColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RealSheetMusicPainter oldDelegate) {
    return oldDelegate.currentSubTick != currentSubTick ||
        oldDelegate.liveNote != liveNote ||
        oldDelegate.liveCents != liveCents ||
        oldDelegate.isCountingIn != isCountingIn ||
        oldDelegate.countInBeat != countInBeat ||
        oldDelegate.measureIndex != measureIndex ||
        oldDelegate.timeSignature != timeSignature ||
        oldDelegate.palette != palette ||
        oldDelegate.notes != notes ||
        oldDelegate.history.length != history.length;
  }
}
