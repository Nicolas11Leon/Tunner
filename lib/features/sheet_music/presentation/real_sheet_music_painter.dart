import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../instrument/domain/instrument_profile_entity.dart';
import '../domain/score_tree.dart';
import 'smufl/smufl_glyph_path_engine.dart';

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
/// figuras, silencios, armaduras, claves (Sol y Fa), playhead dinámico y retroalimentación de afinación en vivo
/// utilizando la especificación canónica tipográfica SMuFL (Standard Music Font Layout).
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
  final int? selectedNoteIndex;

  final SmuflGlyphPathEngine _smuflEngine;

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
    this.selectedNoteIndex,
    SmuflGlyphPathEngine? smuflEngine,
  }) : _smuflEngine = smuflEngine ?? const SmuflGlyphPathEngine();

  /// Calcula el offset de semiespacio de la nota respecto a la línea 1 del pentagrama.
  /// Línea 1 = 0, Línea 2 = 2, Línea 3 (centro) = 4, Línea 4 = 6, Línea 5 = 8.
  int getNoteStep(String note) {
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

  /// Retorna el índice de la nota ubicada en las coordenadas [localOffset], o null si no se tocó ninguna.
  int? findNoteIndexAtOffset(Offset localOffset, Size size) {
    final double leftMargin = 75.0;
    final double rightMargin = 20.0;
    final double playAreaWidth = size.width - leftMargin - rightMargin;
    final int totalMeasureTicks = timeSignature.totalTicks;
    final double stepWidth = playAreaWidth / totalMeasureTicks;

    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      final double startX = leftMargin + (note.startTick * stepWidth);
      final double endX = startX + (note.durationTicks * stepWidth);

      if (localOffset.dx >= startX && localOffset.dx <= endX) {
        return i;
      }
    }
    return null;
  }

  void _drawUnicodeText(Canvas canvas, String text, double x, double y, double size, Color color, {FontWeight weight = FontWeight.w600}) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight, fontFamily: 'monospace')),
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
    double centerLine3Y = baseLine1Y - (2 * staffSpacing);

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
    _drawUnicodeText(canvas, "${measureIndex + 1}", leftMargin - 15, topStaffY - 14, 15, palette.textMutedColor);

    // 2. Dibujar la Clave SMuFL Vectorial (Sol o Fa)
    if (clef == InstrumentClef.bass) {
      // Clave de Fa anclada en la línea 4
      final line4Y = baseLine1Y - (3 * staffSpacing);
      _smuflEngine.drawFClef(
        canvas,
        anchorLine4: Offset(28, line4Y),
        staffSpace: staffSpacing,
        color: palette.musicalSymbolsColor,
      );
    } else {
      // Clave de Sol anclada en la línea 2
      final line2Y = baseLine1Y - (1 * staffSpacing);
      _smuflEngine.drawGClef(
        canvas,
        anchorLine2: Offset(28, line2Y),
        staffSpace: staffSpacing,
        color: palette.musicalSymbolsColor,
      );
    }

    // Indicador numérico de Métrica / Compás (e.g. 4/4, 3/4, 6/8)
    _drawUnicodeText(canvas, "${timeSignature.numerator}", 55, centerY - (staffSpacing * 0.8), 22, palette.musicalSymbolsColor, weight: FontWeight.w800);
    _drawUnicodeText(canvas, "${timeSignature.denominator}", 55, centerY + (staffSpacing * 0.8), 22, palette.musicalSymbolsColor, weight: FontWeight.w800);

    // Conteo de entrada gigante
    if (isCountingIn) {
      final textPainter = TextPainter(
        text: TextSpan(text: "$countInBeat", style: TextStyle(color: palette.secondaryAccent, fontSize: 120, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return;
    }

    // 3. Dibujar las Figuras Musicales con SMuFL Vectorial
    for (int idx = 0; idx < notes.length; idx++) {
      final note = notes[idx];
      double startX = leftMargin + (note.startTick * stepWidth);
      double noteCenterX = startX + (stepWidth / 2);
      final isSelected = selectedNoteIndex == idx;

      // Resalte visual si la nota está seleccionada o activa
      if (isSelected) {
        final highlightPaint = Paint()
          ..color = palette.secondaryAccent.withValues(alpha: 0.28)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(startX + 1, topStaffY - staffSpacing, (note.durationTicks * stepWidth) - 2, 6 * staffSpacing),
            const Radius.circular(6),
          ),
          highlightPaint,
        );
      }

      final noteColor = isSelected ? palette.secondaryAccent : palette.musicalSymbolsColor;

      if (note.isRest) {
        // Silencio vectorial SMuFL
        _smuflEngine.drawRest(
          canvas,
          centerLine3: Offset(noteCenterX, centerLine3Y),
          staffSpace: staffSpacing,
          durationTicks: note.durationTicks,
          color: noteColor,
        );
      } else {
        int step = getNoteStep(note.noteName);
        double noteY = baseLine1Y - (step * (staffSpacing / 2));

        bool isWhole = note.durationTicks >= 16;
        bool isHalf = note.durationTicks >= 8 && note.durationTicks < 16;
        bool hasStem = note.durationTicks < 16;
        bool stemGoesDown = step >= 4; // Línea 3 hacia arriba plica hacia abajo

        // Extraer alteración (# o b) si existe
        if (note.noteName.contains('#') || note.noteName.contains('♯')) {
          _smuflEngine.drawAccidental(
            canvas,
            center: Offset(noteCenterX - (staffSpacing * 0.95), noteY),
            staffSpace: staffSpacing,
            accidental: '#',
            color: noteColor,
          );
        } else if (note.noteName.contains('b') || note.noteName.contains('♭')) {
          _smuflEngine.drawAccidental(
            canvas,
            center: Offset(noteCenterX - (staffSpacing * 0.95), noteY),
            staffSpace: staffSpacing,
            accidental: 'b',
            color: noteColor,
          );
        }

        // Cabeza de la nota SMuFL
        _smuflEngine.drawNotehead(
          canvas,
          center: Offset(noteCenterX, noteY),
          staffSpace: staffSpacing,
          color: noteColor,
          isWhole: isWhole,
          isHalf: isHalf,
        );

        // Plica (Stem) SMuFL
        if (hasStem) {
          _smuflEngine.drawStem(
            canvas,
            noteCenter: Offset(noteCenterX, noteY),
            staffSpace: staffSpacing,
            isUp: !stemGoesDown,
            color: noteColor,
          );

          // Corchetes (Flags) SMuFL para corcheas y semicorcheas
          if (note.durationTicks <= 2) {
            final stemLength = staffSpacing * 3.5;
            final noteWidth = staffSpacing * 0.60;
            final stemTipX = !stemGoesDown ? (noteCenterX + noteWidth) : (noteCenterX - noteWidth);
            final stemTipY = !stemGoesDown ? (noteY - stemLength) : (noteY + stemLength);

            final flagCount = (note.durationTicks == 1) ? 2 : 1;
            _smuflEngine.drawFlag(
              canvas,
              stemTip: Offset(stemTipX, stemTipY),
              staffSpace: staffSpacing,
              isUp: !stemGoesDown,
              flagCount: flagCount,
              color: noteColor,
            );
          }
        }

        // Líneas adicionales SMuFL
        _smuflEngine.drawLedgerLines(
          canvas,
          noteCenter: Offset(noteCenterX, noteY),
          staffSpace: staffSpacing,
          stepFromLine1: step,
          color: noteColor,
        );
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
      int liveStep = getNoteStep(liveNote);
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
        oldDelegate.clef != clef ||
        oldDelegate.selectedNoteIndex != selectedNoteIndex;
  }
}
