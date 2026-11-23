import 'dart:math' as math;
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
  final int keySignatureFifths;

  static final RegExp _digitsRegExp = RegExp(r'[-+]?\d+');
  static final RegExp _accidentalSuffixRegExp = RegExp(r'[#♭♯♮n]+$');
  static final RegExp _flatNoteRegExp = RegExp(
    r'^([A-Ga-g]|Do|Re|Mi|Fa|Sol|La|Si)b',
    caseSensitive: false,
  );
  static final RegExp _naturalNoteRegExp = RegExp(
    r'^([A-Ga-g]|Do|Re|Mi|Fa|Sol|La|Si)n',
    caseSensitive: false,
  );

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
    this.keySignatureFifths = 0,
    SmuflGlyphPathEngine? smuflEngine,
  }) : _smuflEngine = smuflEngine ?? const SmuflGlyphPathEngine();

  /// Calcula el offset de semiespacio de la nota respecto a la línea 1 del pentagrama.
  /// Línea 1 = 0, Línea 2 = 2, Línea 3 (centro) = 4, Línea 4 = 6, Línea 5 = 8.
  int getNoteStep(String note) {
    if (note.isEmpty || note == "--") return -100;
    String raw = note
        .replaceAll(_digitsRegExp, '')
        .replaceAll(_accidentalSuffixRegExp, '')
        .toLowerCase();
    if (raw.length > 1 && raw.endsWith('b')) {
      raw = raw.substring(0, raw.length - 1);
    }
    int octave = 4;
    final octaveMatch = _digitsRegExp.firstMatch(note);
    if (octaveMatch != null) {
      octave = int.tryParse(octaveMatch.group(0)!) ?? 4;
    }

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
    // En Clave de Do (alto): Línea 1 es Fa3 (3*7 + 3 = 24)
    final refStep = switch (clef) {
      InstrumentClef.bass => 18,
      InstrumentClef.alto => 24,
      InstrumentClef.treble => 30,
    };
    return absStep - refStep;
  }

  double _computeLeftMargin() {
    final int keyCount = keySignatureFifths.abs().clamp(0, 7);
    return keyCount == 0 ? 75.0 : 75.0 + (keyCount * 7.5);
  }

  /// Retorna el índice de la nota ubicada en las coordenadas [localOffset], o null si no se tocó ninguna.
  int? findNoteIndexAtOffset(Offset localOffset, Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return null;
    }
    final double leftMargin = _computeLeftMargin();
    final double rightMargin = 20.0;
    final double playAreaWidth = size.width - leftMargin - rightMargin;
    if (playAreaWidth <= 0) return null;
    final int totalMeasureTicks = math.max(1, timeSignature.totalTicks);
    final double stepWidth = playAreaWidth / totalMeasureTicks;

    final double staffCenterY = size.height / 2.0;
    final double staffSpacing = size.height / 14.0;
    final double line1Y = staffCenterY + (staffSpacing * 2.0);

    final matchingXIndices = <int>[];
    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      final double startX = leftMargin + (note.startTick * stepWidth);
      final double endX = startX + (note.durationTicks * stepWidth);

      if (localOffset.dx >= startX - 4.0 && localOffset.dx <= endX + 4.0) {
        matchingXIndices.add(i);
      }
    }

    if (matchingXIndices.isEmpty) return null;
    if (matchingXIndices.length == 1) return matchingXIndices.first;

    // Desambiguacion 2D vertical cuando existen multiples notas en la misma columna X
    int? closestIndex;
    double minDistance = double.infinity;

    for (final i in matchingXIndices) {
      final note = notes[i];
      final noteY = note.isRest
          ? staffCenterY
          : line1Y - (getNoteStep(note.noteName) * (staffSpacing / 2.0));
      final dy = (localOffset.dy - noteY).abs();

      if (dy < minDistance) {
        minDistance = dy;
        closestIndex = i;
      }
    }
    return closestIndex;
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
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    try {
      _paintScore(canvas, size);
    } finally {
      canvas.restore();
    }
  }

  void _paintScore(Canvas canvas, Size size) {
    final linePaint = Paint()..color = palette.staffLinesColor..strokeWidth = 2.0;

    final double leftMargin = _computeLeftMargin();
    final double rightMargin = 20.0;
    final double playAreaWidth = math.max(1.0, size.width - leftMargin - rightMargin);
    final int totalMeasureTicks = math.max(1, timeSignature.totalTicks);
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

    // 2. Dibujar la Clave SMuFL Vectorial (Sol, Fa o Do)
    if (clef == InstrumentClef.bass) {
      // Clave de Fa anclada en la línea 4
      final line4Y = baseLine1Y - (3 * staffSpacing);
      _smuflEngine.drawFClef(
        canvas,
        anchorLine4: Offset(26, line4Y),
        staffSpace: staffSpacing,
        color: palette.musicalSymbolsColor,
      );
    } else if (clef == InstrumentClef.alto) {
      // Clave de Do anclada en la línea 3
      final line3Y = baseLine1Y - (2 * staffSpacing);
      _smuflEngine.drawCClef(
        canvas,
        anchorLine: Offset(26, line3Y),
        staffSpace: staffSpacing,
        color: palette.musicalSymbolsColor,
      );
    } else {
      // Clave de Sol anclada en la línea 2
      final line2Y = baseLine1Y - (1 * staffSpacing);
      _smuflEngine.drawGClef(
        canvas,
        anchorLine2: Offset(26, line2Y),
        staffSpace: staffSpacing,
        color: palette.musicalSymbolsColor,
      );
    }

    // Armadura de clave (Key Signature)
    if (keySignatureFifths != 0) {
      final isSharps = keySignatureFifths > 0;
      final count = keySignatureFifths.abs().clamp(0, 7);
      final accidentalChar = isSharps ? '#' : 'b';

      // Posiciones de semitonos según la clave
      final trebleSharpSteps = [8, 5, 9, 6, 3, 7, 4]; // F5, C5, G5, D5, A4, E5, B4
      final trebleFlatSteps = [4, 7, 3, 6, 2, 5, 1]; // B4, E5, A4, D5, G4, C5, F4
      final bassSharpSteps = [6, 3, 7, 4, 1, 5, 2];
      final bassFlatSteps = [2, 5, 1, 4, 0, 3, -1];
      final altoSharpSteps = [7, 4, 8, 5, 2, 6, 3];
      final altoFlatSteps = [3, 6, 2, 5, 1, 4, 0];

      List<int> steps;
      if (clef == InstrumentClef.bass) {
        steps = isSharps ? bassSharpSteps : bassFlatSteps;
      } else if (clef == InstrumentClef.alto) {
        steps = isSharps ? altoSharpSteps : altoFlatSteps;
      } else {
        steps = isSharps ? trebleSharpSteps : trebleFlatSteps;
      }

      for (int i = 0; i < count; i++) {
        final double accX = 38.0 + (i * 7.5);
        final double accY = baseLine1Y - (steps[i] * (staffSpacing / 2.0));
        _smuflEngine.drawAccidental(
          canvas,
          center: Offset(accX, accY),
          staffSpace: staffSpacing,
          accidental: accidentalChar,
          color: palette.musicalSymbolsColor,
        );
      }
    }

    // Indicador numérico de Métrica / Compás (e.g. 4/4, 3/4, 6/8)
    final double timeSigX = 52.0 + (keySignatureFifths.abs().clamp(0, 7) * 7.5);
    _drawUnicodeText(canvas, "${timeSignature.numerator}", timeSigX, centerY - (staffSpacing * 0.8), 22, palette.musicalSymbolsColor, weight: FontWeight.w800);
    _drawUnicodeText(canvas, "${timeSignature.denominator}", timeSigX, centerY + (staffSpacing * 0.8), 22, palette.musicalSymbolsColor, weight: FontWeight.w800);

    // Conteo de entrada gigante
    if (isCountingIn) {
      final textPainter = TextPainter(
        text: TextSpan(text: "$countInBeat", style: TextStyle(color: palette.secondaryAccent, fontSize: 120, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return;
    }

    // Precomputar grupos de unión por barras (Beams) para corcheas y semicorcheas
    final beamedGroups = <List<int>>[];
    final Set<int> beamedIndices = {};
    List<int> currentGroup = [];

    for (int i = 0; i < notes.length; i++) {
      final n = notes[i];
      if (!n.isRest && n.durationTicks <= 2) {
        if (currentGroup.isEmpty) {
          currentGroup.add(i);
        } else {
          final prev = notes[currentGroup.last];
          final prevBeat = prev.startTick ~/ 4;
          final curBeat = n.startTick ~/ 4;
          if (curBeat == prevBeat && n.startTick == prev.startTick + prev.durationTicks) {
            currentGroup.add(i);
          } else {
            if (currentGroup.length >= 2) {
              beamedGroups.add(List.from(currentGroup));
            }
            currentGroup = [i];
          }
        }
      } else {
        if (currentGroup.length >= 2) {
          beamedGroups.add(List.from(currentGroup));
        }
        currentGroup = [];
      }
    }
    if (currentGroup.length >= 2) {
      beamedGroups.add(List.from(currentGroup));
    }
    for (final g in beamedGroups) {
      beamedIndices.addAll(g);
    }

    // Calcular direccion unificada de plica por grupo beamed
    final Map<int, bool> groupStemDown = {};
    for (final g in beamedGroups) {
      double avgStep = 0;
      for (final idx in g) {
        avgStep += getNoteStep(notes[idx].noteName);
      }
      avgStep /= g.length;
      final bool isDown = avgStep >= 4.0;
      for (final idx in g) {
        groupStemDown[idx] = isDown;
      }
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
        bool stemGoesDown = groupStemDown[idx] ?? (step >= 4);

        // Extraer alteración (#, b o n) si existe evitando falso positivo con nota en minuscula 'b4'
        final cleanNote = note.noteName.trim();
        final isSharp = cleanNote.contains('#') || cleanNote.contains('♯');
        final isFlat = !isSharp &&
            (cleanNote.contains('♭') || _flatNoteRegExp.hasMatch(cleanNote));
        final isNatural = !isSharp &&
            !isFlat &&
            (cleanNote.contains('♮') || _naturalNoteRegExp.hasMatch(cleanNote));

        if (isSharp) {
          _smuflEngine.drawAccidental(
            canvas,
            center: Offset(noteCenterX - (staffSpacing * 0.95), noteY),
            staffSpace: staffSpacing,
            accidental: '#',
            color: noteColor,
          );
        } else if (isFlat) {
          _smuflEngine.drawAccidental(
            canvas,
            center: Offset(noteCenterX - (staffSpacing * 0.95), noteY),
            staffSpace: staffSpacing,
            accidental: 'b',
            color: noteColor,
          );
        } else if (isNatural) {
          _smuflEngine.drawAccidental(
            canvas,
            center: Offset(noteCenterX - (staffSpacing * 0.95), noteY),
            staffSpace: staffSpacing,
            accidental: 'n',
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

        // Punto de prolongación (Augmentation dot) para notas con puntillo
        final isDotted = note.durationTicks == 12 || note.durationTicks == 6 || note.durationTicks == 3;
        if (isDotted) {
          final dotY = (step % 2 == 0) ? noteY - (staffSpacing * 0.28) : noteY;
          _smuflEngine.drawAugmentationDot(
            canvas,
            center: Offset(noteCenterX + (staffSpacing * 0.95), dotY),
            staffSpace: staffSpacing,
            color: noteColor,
          );
        }

        // Plica (Stem) SMuFL
        if (hasStem) {
          _smuflEngine.drawStem(
            canvas,
            noteCenter: Offset(noteCenterX, noteY),
            staffSpace: staffSpacing,
            isUp: !stemGoesDown,
            color: noteColor,
          );

          // Corchetes (Flags) SMuFL para corcheas y semicorcheas individuales (no unidas por barras)
          if (note.durationTicks <= 2 && !beamedIndices.contains(idx)) {
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

        // Ligadura de prolongación (Tie) si está enlazada a la siguiente nota
        if (note.isTied && idx + 1 < notes.length) {
          final nextNote = notes[idx + 1];
          final nextStartX = leftMargin + (nextNote.startTick * stepWidth);
          final nextCenterX = nextStartX + (stepWidth / 2);
          final nextStep = getNoteStep(nextNote.noteName);
          final nextY = baseLine1Y - (nextStep * (staffSpacing / 2));

          final tiePaint = Paint()
            ..color = noteColor
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;

          final tiePath = Path();
          final p1 = Offset(noteCenterX + staffSpacing * 0.45, noteY + staffSpacing * 0.4);
          final p2 = Offset(nextCenterX - staffSpacing * 0.45, nextY + staffSpacing * 0.4);
          final control = Offset((p1.dx + p2.dx) / 2.0, math.max(p1.dy, p2.dy) + staffSpacing * 0.8);

          tiePath.moveTo(p1.dx, p1.dy);
          tiePath.quadraticBezierTo(control.dx, control.dy, p2.dx, p2.dy);
          canvas.drawPath(tiePath, tiePaint);
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

    // Dibujar las barras de unión (Beams) para los grupos de corcheas/semicorcheas
    for (final group in beamedGroups) {
      if (group.isEmpty) continue;
      final firstIdx = group.first;
      final lastIdx = group.last;

      final firstNote = notes[firstIdx];
      final lastNote = notes[lastIdx];

      final firstStep = getNoteStep(firstNote.noteName);
      final lastStep = getNoteStep(lastNote.noteName);

      final firstNoteY = baseLine1Y - (firstStep * (staffSpacing / 2));
      final lastNoteY = baseLine1Y - (lastStep * (staffSpacing / 2));

      final firstCenterX = leftMargin + (firstNote.startTick * stepWidth) + (stepWidth / 2);
      final lastCenterX = leftMargin + (lastNote.startTick * stepWidth) + (stepWidth / 2);

      final firstStemGoesDown = groupStemDown[firstIdx] ?? (firstStep >= 4);
      final stemLength = staffSpacing * 3.5;
      final noteWidth = staffSpacing * 0.60;

      final firstStemTipX = !firstStemGoesDown ? (firstCenterX + noteWidth) : (firstCenterX - noteWidth);
      final firstStemTipY = !firstStemGoesDown ? (firstNoteY - stemLength) : (firstNoteY + stemLength);

      final lastStemTipX = !firstStemGoesDown ? (lastCenterX + noteWidth) : (lastCenterX - noteWidth);
      final lastStemTipY = !firstStemGoesDown ? (lastNoteY - stemLength) : (lastNoteY + stemLength);

      final beamPaint = Paint()
        ..color = palette.musicalSymbolsColor
        ..strokeWidth = math.max(3.2, staffSpacing * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;

      canvas.drawLine(Offset(firstStemTipX, firstStemTipY), Offset(lastStemTipX, lastStemTipY), beamPaint);

      // Barra secundaria para semicorcheas
      final has16th = group.any((i) => notes[i].durationTicks <= 1);
      if (has16th) {
        final subOffset = !firstStemGoesDown ? (staffSpacing * 0.45) : (-staffSpacing * 0.45);
        canvas.drawLine(
          Offset(firstStemTipX, firstStemTipY + subOffset),
          Offset(lastStemTipX, lastStemTipY + subOffset),
          beamPaint,
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
        oldDelegate.timeSignature != timeSignature ||
        oldDelegate.measureIndex != measureIndex ||
        oldDelegate.totalMeasures != totalMeasures ||
        oldDelegate.notes != notes ||
        oldDelegate.history != history ||
        oldDelegate.palette != palette ||
        oldDelegate.clef != clef ||
        oldDelegate.selectedNoteIndex != selectedNoteIndex ||
        oldDelegate.keySignatureFifths != keySignatureFifths;
  }
}
