import 'dart:math' as math;
import '../../sheet_music/domain/score_tree.dart';

/// Segmento de línea geométrico en coordenadas bidimensionales de página.
class OmrLine {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const OmrLine({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  bool get isHorizontal => (y2 - y1).abs() <= 2.0;
  bool get isVertical => (x2 - x1).abs() <= 2.0;
  double get length => math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
  double get minX => math.min(x1, x2);
  double get maxX => math.max(x1, x2);
  double get minY => math.min(y1, y2);
  double get maxY => math.max(y1, y2);
  double get midY => (y1 + y2) / 2.0;
  double get midX => (x1 + x2) / 2.0;
}

/// Elemento geométrico rectangular o delimitador de glifo/cabeza de nota.
class OmrRect {
  final double x;
  final double y;
  final double width;
  final double height;
  final bool isFilled;

  const OmrRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.isFilled = true,
  });

  double get centerX => x + width / 2.0;
  double get centerY => y + height / 2.0;
}

/// Sistema de pentagrama reconocido compuesto por 5 líneas paralelas equidistantes.
class StaffSystem {
  final List<double> lineY; // Ordenadas de menor a mayor (inferior a superior)
  final double staffSpace;
  final double startX;
  final double endX;

  const StaffSystem({
    required this.lineY,
    required this.staffSpace,
    required this.startX,
    required this.endX,
  });

  double get bottomY => lineY.first;
  double get topY => lineY.last;
  double get height => topY - bottomY;
}

/// Motor de Reconocimiento Óptico de Partituras Vectorial (Vector OMR).
/// Analiza primitivas geométricas extraídas de documentos PDF y construye
/// un [HierarchicalScore] estructurado determinísticamente en memoria.
class VectorOmrEngine {
  const VectorOmrEngine();

  /// Procesa una colección de líneas y rectángulos geométricos para generar una partitura.
  /// Lanza [FormatException] si existen primitivas sin ningún pentagrama vectorial válido.
  HierarchicalScore processGeometricElements({
    required List<OmrLine> lines,
    required List<OmrRect> rects,
    String title = 'Partitura PDF Reconocida',
    int bpm = 120,
    TimeSignature timeSignature = TimeSignature.commonTime44,
  }) {
    if (lines.isEmpty && rects.isEmpty) {
      return HierarchicalScore(
        title: title,
        baseBpm: bpm,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: timeSignature,
            notes: [
              HierarchicalNote.rest(startTick: 0, durationTicks: timeSignature.totalTicks),
            ],
          ),
        ],
      );
    }

    // 1. Detectar sistemas de pentagramas agrupando 5 líneas paralelas equidistantes
    final staves = _detectStaffSystems(lines);
    if (staves.isEmpty) {
      throw const FormatException(
        'No se detectaron pentagramas vectoriales válidos de 5 líneas equidistantes.',
      );
    }

    final measures = <MeasureEntity>[];
    int measureIndex = 0;

    for (int sIdx = 0; sIdx < staves.length; sIdx++) {
      final staff = staves[sIdx];
      final aboveStaff = sIdx > 0 ? staves[sIdx - 1] : null;
      final belowStaff = sIdx + 1 < staves.length ? staves[sIdx + 1] : null;

      // 2. Detectar barras de compás verticales que cubren todo el pentagrama (sin confundir plicas)
      final barlines = _detectBarlinesForStaff(lines, rects, staff);

      // Crear rangos de compases divididos por las barras verticales
      final barRanges = <({double startX, double endX})>[];
      double currentX = staff.startX;

      for (final barline in barlines) {
        if (barline > currentX + 30.0) {
          barRanges.add((startX: currentX, endX: barline));
          currentX = barline;
        }
      }
      if (staff.endX > currentX + 30.0) {
        barRanges.add((startX: currentX, endX: staff.endX));
      }

      // Si no se detectaron barras verticales, asumir 4 compases de ancho uniforme
      if (barRanges.isEmpty) {
        final totalWidth = staff.endX - staff.startX;
        final step = totalWidth / 4.0;
        for (int i = 0; i < 4; i++) {
          barRanges.add((
            startX: staff.startX + i * step,
            endX: staff.startX + (i + 1) * step,
          ));
        }
      }

      // 3. Asociar cabezas de nota geométricas, plicas y corchetes/barras a cada compás
      for (final bar in barRanges) {
        final notesInBar = _findNotesInStaffRegion(
          rects: rects,
          lines: lines,
          staff: staff,
          aboveStaff: aboveStaff,
          belowStaff: belowStaff,
          barlineXs: barlines,
          startX: bar.startX,
          endX: bar.endX,
          maxTicks: timeSignature.totalTicks,
        );

        measures.add(MeasureEntity(
          index: measureIndex++,
          timeSignature: timeSignature,
          notes: notesInBar,
        ));
      }
    }

    return HierarchicalScore(
      title: title,
      baseBpm: bpm,
      measures: measures.isNotEmpty
          ? measures
          : [
              MeasureEntity(
                index: 0,
                timeSignature: timeSignature,
                notes: [
                  HierarchicalNote.rest(startTick: 0, durationTicks: timeSignature.totalTicks),
                ],
              ),
            ],
    );
  }

  /// Agrupa líneas horizontales en pentagramas de 5 líneas paralelas equidistantes.
  List<StaffSystem> _detectStaffSystems(List<OmrLine> lines) {
    final hLines = lines.where((l) => l.isHorizontal && l.length >= 80.0).toList();
    if (hLines.length < 5) return const [];

    hLines.sort((a, b) => a.midY.compareTo(b.midY));

    final staves = <StaffSystem>[];
    int i = 0;

    while (i <= hLines.length - 5) {
      final candidateLines = hLines.sublist(i, i + 5);
      final yCoords = candidateLines.map((l) => l.midY).toList();

      final spacings = <double>[];
      for (int k = 0; k < 4; k++) {
        spacings.add(yCoords[k + 1] - yCoords[k]);
      }

      final avgSpacing = spacings.reduce((a, b) => a + b) / 4.0;

      // Espaciado típico de pentagramas impresos (3 a 40 pt) con desviación mínima (< 2.5 pt)
      bool isEquidistant = avgSpacing >= 3.0 && avgSpacing <= 40.0;
      if (isEquidistant) {
        for (final sp in spacings) {
          if ((sp - avgSpacing).abs() > 2.5) {
            isEquidistant = false;
            break;
          }
        }
      }

      // Verificar alineación y longitud consistente de las 5 líneas para evitar vigas aisladas
      if (isEquidistant) {
        final minLen = candidateLines.map((l) => l.length).reduce(math.min);
        final maxLen = candidateLines.map((l) => l.length).reduce(math.max);
        final minStartX = candidateLines.map((l) => l.minX).reduce(math.min);
        final maxStartX = candidateLines.map((l) => l.minX).reduce(math.max);
        if (minLen < maxLen * 0.80 || (maxStartX - minStartX) > maxLen * 0.20) {
          isEquidistant = false;
        }
      }

      if (isEquidistant) {
        final startX = candidateLines.map((l) => l.minX).reduce(math.min);
        final endX = candidateLines.map((l) => l.maxX).reduce(math.max);

        staves.add(StaffSystem(
          lineY: yCoords,
          staffSpace: avgSpacing,
          startX: startX,
          endX: endX,
        ));
        i += 5;
      } else {
        i++;
      }
    }

    // Ordenar sistemas de arriba hacia abajo (mayor Y a menor Y en espacio vectorial PDF)
    staves.sort((a, b) => b.bottomY.compareTo(a.bottomY));

    return staves;
  }

  /// Detecta las barras de compás verticales dentro del rango de un pentagrama.
  List<double> _detectBarlinesForStaff(
    List<OmrLine> lines,
    List<OmrRect> rects,
    StaffSystem staff,
  ) {
    final tol = math.max(2.0, staff.staffSpace * 0.25);

    final vLines = lines.where((l) {
      if (!l.isVertical) return false;
      final spansFullStaff = l.minY <= (staff.bottomY + tol) && l.maxY >= (staff.topY - tol);
      if (!spansFullStaff) return false;

      // Excluir plicas verticales adheridas a una cabeza de nota
      final isStemOfNote = rects.any((r) {
        final nearX = (l.midX - r.centerX).abs() <= (r.width * 0.75 + 2.0);
        if (!nearX) return false;
        return (l.minY - r.centerY).abs() <= staff.staffSpace * 0.4 ||
            (l.maxY - r.centerY).abs() <= staff.staffSpace * 0.4;
      });
      return !isStemOfNote;
    }).toList();

    vLines.sort((a, b) => a.midX.compareTo(b.midX));

    final barlineX = <double>[];
    for (final vl in vLines) {
      if (vl.midX > staff.startX + 10.0 && vl.midX < staff.endX - 10.0) {
        if (barlineX.isEmpty || (vl.midX - barlineX.last).abs() > 10.0) {
          barlineX.add(vl.midX);
        }
      }
    }

    return barlineX;
  }

  /// Encuentra y mapea notas dentro de una región horizontal específica del pentagrama,
  /// infiriendo su duración real (16, 8, 4, 2, 1 ticks) y altura diatónica sin tope fijo.
  List<HierarchicalNote> _findNotesInStaffRegion({
    required List<OmrRect> rects,
    required List<OmrLine> lines,
    required StaffSystem staff,
    StaffSystem? aboveStaff,
    StaffSystem? belowStaff,
    required List<double> barlineXs,
    required double startX,
    required double endX,
    required int maxTicks,
  }) {
    final minDim = staff.staffSpace * 0.4;
    final maxDim = staff.staffSpace * 2.5;
    final maxVerticalReach = staff.staffSpace * 5.0;

    final lowerYLimit = belowStaff != null
        ? math.max(staff.bottomY - maxVerticalReach, (staff.bottomY + belowStaff.topY) / 2.0)
        : staff.bottomY - maxVerticalReach;
    final upperYLimit = aboveStaff != null
        ? math.min(staff.topY + maxVerticalReach, (staff.topY + aboveStaff.bottomY) / 2.0)
        : staff.topY + maxVerticalReach;

    final candidates = rects.where((r) {
      final inX = r.centerX >= startX && r.centerX < endX;
      final inY = r.centerY >= lowerYLimit && r.centerY <= upperYLimit;
      final hasSize = r.width >= minDim && r.width <= maxDim &&
          r.height >= minDim && r.height <= maxDim;
      // Filtrar barras planas de silencio (redonda/blanca) con relación ancho/alto > 2.2
      final aspectRatio = r.height > 0 ? (r.width / r.height) : 99.0;
      final isNotFlatRest = aspectRatio <= 2.2 && r.height >= (staff.staffSpace * 0.45);
      return inX && inY && hasSize && isNotFlatRest;
    }).toList();

    if (candidates.isEmpty) {
      return [
        HierarchicalNote.rest(startTick: 0, durationTicks: maxTicks),
      ];
    }

    candidates.sort((a, b) => a.centerX.compareTo(b.centerX));

    // Pre-filtrar líneas candidatas a plicas y corchetes/barras en la vecindad del compás
    final marginX = staff.staffSpace * 2.5;
    final regionLines = lines.where((l) {
      if (l.maxX < startX - marginX || l.minX > endX + marginX) return false;
      if (l.maxY < lowerYLimit - staff.staffSpace * 5.0 ||
          l.minY > upperYLimit + staff.staffSpace * 5.0) {
        return false;
      }
      if (l.isHorizontal && l.length >= 40.0) {
        final onStaffLine = staff.lineY.any((ly) => (l.midY - ly).abs() <= 1.5);
        if (onStaffLine) return false;
      }
      if (l.isVertical) {
        final tol = math.max(2.0, staff.staffSpace * 0.25);
        final spansStaff = l.minY <= (staff.bottomY + tol) && l.maxY >= (staff.topY - tol);
        final atBarline = barlineXs.any((bx) => (l.midX - bx).abs() <= 2.5) ||
            (l.midX - staff.startX).abs() <= 2.5 ||
            (l.midX - staff.endX).abs() <= 2.5;
        if (spansStaff && atBarline) return false;
      }
      return true;
    }).toList();

    final stemLines = regionLines
        .where((l) => l.isVertical && l.length >= staff.staffSpace * 1.6)
        .toList();
    final flagOrBeamLines = regionLines
        .where((l) => !l.isVertical && l.length >= staff.staffSpace * 0.4)
        .toList();

    final notes = <HierarchicalNote>[];
    int currentTick = 0;

    for (int i = 0; i < candidates.length; i++) {
      if (currentTick >= maxTicks) break;

      final c = candidates[i];
      final noteName = _mapYToSolfegeNote(c.centerY, staff);
      final inferredDuration = _inferNoteDurationTicks(
        notehead: c,
        stemLines: stemLines,
        flagOrBeamLines: flagOrBeamLines,
        staff: staff,
      );
      final effectiveDuration = math.min(inferredDuration, maxTicks - currentTick);

      notes.add(HierarchicalNote.note(
        startTick: currentTick,
        durationTicks: effectiveDuration,
        noteName: noteName,
      ));

      currentTick += effectiveDuration;
    }

    if (currentTick < maxTicks) {
      notes.add(HierarchicalNote.rest(
        startTick: currentTick,
        durationTicks: maxTicks - currentTick,
      ));
    }

    return notes;
  }

  /// Infiere la duración en ticks (16, 8, 4, 2, 1) a partir del relleno de cabeza,
  /// presencia de plica vertical y número de corchetes/barras adheridos a la punta.
  int _inferNoteDurationTicks({
    required OmrRect notehead,
    required List<OmrLine> stemLines,
    required List<OmrLine> flagOrBeamLines,
    required StaffSystem staff,
  }) {
    final stem = _findAttachedStem(notehead: notehead, stemLines: stemLines, staff: staff);

    if (!notehead.isFilled) {
      return (stem == null) ? 16 : 8;
    }

    if (stem == null) {
      return 4;
    }

    final attachmentCount = _countStemTipAttachments(
      notehead: notehead,
      stem: stem,
      flagOrBeamLines: flagOrBeamLines,
      staff: staff,
    );

    if (attachmentCount >= 2) return 1;
    if (attachmentCount == 1) return 2;
    return 4;
  }

  /// Busca la plica vertical adherida al borde izquierdo o derecho de [notehead].
  OmrLine? _findAttachedStem({
    required OmrRect notehead,
    required List<OmrLine> stemLines,
    required StaffSystem staff,
  }) {
    final stemTolX = math.max(2.5, staff.staffSpace * 0.4);
    final stemTolY = staff.staffSpace * 0.85;
    final minStemReach = staff.staffSpace * 1.4;

    OmrLine? bestStem;
    double bestScore = double.infinity;

    for (final l in stemLines) {
      if (l.midX < notehead.x - stemTolX || l.midX > notehead.x + notehead.width + stemTolX) {
        continue;
      }

      final isUp = (l.minY - notehead.centerY).abs() <= stemTolY &&
          l.maxY > notehead.centerY + minStemReach;
      final isDown = (l.maxY - notehead.centerY).abs() <= stemTolY &&
          l.minY < notehead.centerY - minStemReach;
      if (!isUp && !isDown) continue;

      double xOutsideBox = 0.0;
      if (l.midX < notehead.x) {
        xOutsideBox = notehead.x - l.midX;
      } else if (l.midX > notehead.x + notehead.width) {
        xOutsideBox = l.midX - (notehead.x + notehead.width);
      }

      final anchorDeltaY = math.min(
        (l.minY - notehead.centerY).abs(),
        (l.maxY - notehead.centerY).abs(),
      );
      final score = (xOutsideBox * 3.0) + anchorDeltaY;

      if (score < bestScore) {
        bestScore = score;
        bestStem = l;
      }
    }

    return bestStem;
  }

  /// Cuenta corchetes (flags) y barras (beams) distintos en la punta de [stem].
  int _countStemTipAttachments({
    required OmrRect notehead,
    required OmrLine stem,
    required List<OmrLine> flagOrBeamLines,
    required StaffSystem staff,
  }) {
    final stemX = stem.midX;
    final isStemUp = (stem.maxY - notehead.centerY).abs() > (notehead.centerY - stem.minY).abs();
    final stemTipY = isStemUp ? stem.maxY : stem.minY;
    final stemLen = stem.length;
    final tipWindow = math.max(staff.staffSpace * 1.6, stemLen * 0.48);
    final minDistFromNotehead = stemLen * 0.42;
    final beamSpanThreshold = staff.staffSpace * 1.4;

    final matchedAnchorsY = <double>[];

    for (final seg in flagOrBeamLines) {
      final horizSpan = seg.maxX - seg.minX;
      final isLongBeam = horizSpan >= beamSpanThreshold &&
          seg.minX <= stemX + 2.0 &&
          seg.maxX >= stemX - 2.0;

      double anchorY;
      if (isLongBeam) {
        final dx = seg.x2 - seg.x1;
        if (dx.abs() < 1e-6) {
          anchorY = seg.midY;
        } else {
          final t = ((stemX - seg.x1) / dx).clamp(0.0, 1.0);
          anchorY = seg.y1 + t * (seg.y2 - seg.y1);
        }
      } else {
        // Corchete corto: su extremo anclado debe tocar la plica sin ser el retorno de otro trazo
        final d1X = (seg.x1 - stemX).abs();
        final d2X = (seg.x2 - stemX).abs();
        final nearIsP1 = d1X <= d2X;
        final nearDistX = nearIsP1 ? d1X : d2X;
        if (nearDistX > 1.2) continue;

        final nearX = nearIsP1 ? seg.x1 : seg.x2;
        final nearY = nearIsP1 ? seg.y1 : seg.y2;
        final farX = nearIsP1 ? seg.x2 : seg.x1;
        final farY = nearIsP1 ? seg.y2 : seg.y1;

        final isReturnLeg = flagOrBeamLines.any((other) {
          if (identical(other, seg)) return false;
          final connectsFarToP1 = ((other.x1 - farX).abs() <= 0.8 && (other.y1 - farY).abs() <= 0.8 &&
              (other.x2 - stemX).abs() < nearDistX);
          final connectsFarToP2 = ((other.x2 - farX).abs() <= 0.8 && (other.y2 - farY).abs() <= 0.8 &&
              (other.x1 - stemX).abs() < nearDistX);
          return connectsFarToP1 || connectsFarToP2;
        });
        if (isReturnLeg) continue;

        // Exigir extensión horizontal efectiva desde la plica
        if ((farX - nearX).abs() < staff.staffSpace * 0.35) continue;
        anchorY = nearY;
      }

      if ((anchorY - stemTipY).abs() <= tipWindow &&
          (anchorY - notehead.centerY).abs() >= minDistFromNotehead) {
        matchedAnchorsY.add(anchorY);
      }
    }

    if (matchedAnchorsY.isEmpty) return 0;

    // Agrupar ordenadas cercanas (ej. bordes superior/inferior de una misma barra gruesa)
    matchedAnchorsY.sort();
    final clusterTol = staff.staffSpace * 0.5;
    int clusters = 1;
    double lastClusterY = matchedAnchorsY.first;

    for (int i = 1; i < matchedAnchorsY.length; i++) {
      if ((matchedAnchorsY[i] - lastClusterY).abs() > clusterTol) {
        clusters++;
        lastClusterY = matchedAnchorsY[i];
      }
    }

    return clusters;
  }

  /// Mapea la coordenada Y al nombre silábico de nota en Clave de Sol (G Clef)
  /// mediante aritmética diatónica modular sin límite fijo de notas.
  String _mapYToSolfegeNote(double y, StaffSystem staff) {
    final deltaHalfSpaces = ((y - staff.bottomY) / (staff.staffSpace / 2.0)).round();
    const solfegeNames = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];

    // Mi4 (primera línea inferior del pentagrama) equivale a octava 4, grado 2 -> 4 * 7 + 2 = 30.
    const int e4AbsStep = (4 * 7) + 2;
    final int noteAbsStep = e4AbsStep + deltaHalfSpaces;
    final int octave = (noteAbsStep / 7).floor();
    final int stepInOctave = noteAbsStep - (octave * 7);

    return '${solfegeNames[stepInOctave]}$octave';
  }
}
