import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../instrument/domain/instrument_profile_entity.dart';
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
/// figuras, silencios, armaduras, claves (Sol y Fa), playhead dinámico y retroalimentación de afinación en vivo.
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
  final InstrumentClef clef;

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
    this.clef = InstrumentClef.treble,
  });

  /// Calcula el offset de semiespacio de la nota respecto a la línea 1 del pentagrama.
  /// Línea 1 = 0, Línea 2 = 2, Línea 3 (centro) = 4, Línea 4 = 6, Línea 5 = 8.
  int _getNoteStep(String note) {
    if (note.isEmpty || note == "--") return -100;
    String raw = note.replaceAll(RegExp(r'[0-9#b♭♯]'), '').toLowerCase();
    int octave = int.tryParse(note.replaceAll(RegExp(r'[^0-9]'), '')) ?? 4;

    int diatonic = 0;
    switch (raw) {
      case "do": case "c": diatonic = 0; break;
      case "re": case "d": diatonic = 1; break;
      case "mi": case "e": diatonic = 2; break;
      case "fa": case "f": diatonic = 3; break;
      case "sol": case "g": diatonic = 4; break;
      case "la": case "a": diatonic = 5; break;
      case "si": case "b": diatonic = 6; break;
      default: diatonic = 0;
    }
    final absStep = (octave * 7) + diatonic;

    // En Clave de Sol (treble): Línea 1 es Mi4 (4*7 + 2 = 30)
    // En Clave de Fa (bass): Línea 1 es Sol2 (2*7 + 4 = 18)
    final refStep = (clef == InstrumentClef.bass) ? 18 : 30;
    return absStep - refStep;
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
    
    // Línea 1 inferior del pentagrama
    double baseLine1Y = centerY + (staffSpacing * 2); 
    double topStaffY = baseLine1Y - (4 * staffSpacing);

    // 1. Dibujar el Pentagrama (5 líneas equidistantes)
    for (int i = 0; i < 5; i++) {
      double y = baseLine1Y - (i * staffSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Barra divisoria o final de compás (Barline)
    final double barX = size.width - rightMargin;
    if (measureIndex == totalMeasures - 1) {
      canvas.drawLine(Offset(barX - 6, topStaffY), Offset(barX - 6, baseLine1Y), linePaint..strokeWidth = 2.0);
      canvas.drawLine(Offset(barX, topStaffY), Offset(barX, baseLine1Y), linePaint..strokeWidth = 5.0);
    } else {
      canvas.drawLine(Offset(barX, topStaffY), Offset(barX, baseLine1Y), linePaint..strokeWidth = 3.0);
    }

    // Numeración del compás sobre la barra inicial
    _drawUnicodeText(canvas, "${measureIndex + 1}", leftMargin - 15, topStaffY - 14, 16, palette.textMutedColor);

    // 2. Dibujar la Clave (Sol o Fa)
    if (clef == InstrumentClef.bass) {
      // Clave de Fa (𝄢)
      _drawUnicodeText(canvas, "𝄢", 25, centerY - (staffSpacing * 0.1), 75, palette.musicalSymbolsColor);
    } else {
      // Clave de Sol (𝄞)
      _drawUnicodeText(canvas, "𝄞", 25, centerY + (staffSpacing * 0.5), 100, palette.musicalSymbolsColor);
    }

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
        double noteY = baseLine1Y - (step * (staffSpacing / 2));
        
        bool isFilled = note.durationTicks <= 4;
        bool hasStem = note.durationTicks < 16;
        bool stemGoesDown = step >= 4; // Línea 3 (centro) hacia arriba plica hacia abajo
        
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
        if (step <= -2) {
          for (int s = -2; s >= step; s -= 2) {
            double ledgerY = baseLine1Y - (s * (staffSpacing / 2));
            canvas.drawLine(Offset(noteCenterX - 18, ledgerY), Offset(noteCenterX + 18, ledgerY), targetPaintFill..strokeWidth = 2.0);
          }
        } else if (step >= 10) {
          for (int s = 10; s <= step; s += 2) {
            double ledgerY = baseLine1Y - (s * (staffSpacing / 2));
            canvas.drawLine(Offset(noteCenterX - 18, ledgerY), Offset(noteCenterX + 18, ledgerY), targetPaintFill..strokeWidth = 2.0);
          }
        }
      }
    }

    // 4. Cursor de Tiempo Analítico (Playhead con color de la paleta)
    if (currentSubTick >= 0) {
      final cursorPaint = Paint()..color = palette.playheadColor.withValues(alpha: 0.2);
      canvas.drawRect(Rect.fromLTWH(leftMargin + (currentSubTick * stepWidth), 0, stepWidth, size.height), cursorPaint);
      
      final playheadLinePaint = Paint()..color = palette.playheadColor..strokeWidth = 2.0;
      canvas.drawLine(
        Offset(leftMargin + (currentSubTick * stepWidth), 0),
        Offset(leftMargin + (currentSubTick * stepWidth), size.height),
        playheadLinePaint,
      );
    }

    // 5. Historial Dinámico de Evaluación
    history.forEach((tick, record) {
      double startX = leftMargin + (tick * stepWidth);
      Color feedbackColor = record.isCorrect 
          ? palette.correctPitchColor.withValues(alpha: 0.45) 
          : palette.errorPitchColor.withValues(alpha: 0.45);
      
      final histPaint = Paint()..color = feedbackColor;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(startX + 2, topStaffY, stepWidth - 4, baseLine1Y - topStaffY), const Radius.circular(4)), histPaint);
    });

    // 6. Afinación en Tiempo Real Sobre el Playhead
    if (currentSubTick >= 0 && liveNote != "--" && liveNote.isNotEmpty) {
      double currentPlayheadX = leftMargin + (currentSubTick * stepWidth) + (stepWidth / 2);
      int liveStep = _getNoteStep(liveNote);
      double liveY = baseLine1Y - (liveStep * (staffSpacing / 2));

      Color liveColor = liveCents.abs() <= 10.0 ? palette.correctPitchColor : palette.errorPitchColor;
      
      // Dibujar indicador estroboscópico en miniatura siguiendo la frecuencia
      final liveCirclePaint = Paint()..color = liveColor..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(currentPlayheadX, liveY), 7.0, liveCirclePaint);
      
      final livePulsePaint = Paint()..color = liveColor.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 3.0;
      canvas.drawCircle(Offset(currentPlayheadX, liveY), 12.0, livePulsePaint);
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
        oldDelegate.notes != notes ||
        oldDelegate.history != history ||
        oldDelegate.palette != palette ||
        oldDelegate.clef != clef;
  }
}
