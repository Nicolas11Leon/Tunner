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

  const OmrRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
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
      // Si no hay pentagramas claros, intentar extraer notas por posición relativa simple
      return _buildFallbackScore(rects, title, bpm, timeSignature);
    }

    final measures = <MeasureEntity>[];
    int measureIndex = 0;

    for (final staff in staves) {
      // 2. Detectar barras de compás verticales que intersectan este pentagrama
      final barlines = _detectBarlinesForStaff(lines, staff);

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

      // 3. Asociar cabezas de nota geométricas a cada compás
      for (final bar in barRanges) {
        final notesInBar = _findNotesInStaffRegion(
          rects: rects,
          staff: staff,
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
              )
            ],
    );
  }

  /// Agrupa líneas horizontales en pentagramas de 5 líneas paralelas equidistantes.
  List<StaffSystem> _detectStaffSystems(List<OmrLine> lines) {
    // Filtrar líneas horizontales con longitud suficiente para un pentagrama (>= 100 pt)
    final hLines = lines.where((l) => l.isHorizontal && l.length >= 80.0).toList();
    if (hLines.length < 5) return const [];

    // Ordenar verticalmente por coordenada Y media
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

      // Verificar que el espaciado sea razonable para partituras impresas (3 a 40 pt)
      // y que la variación entre líneas sea mínima (< 2.5 pt)
      bool isEquidistant = avgSpacing >= 3.0 && avgSpacing <= 40.0;
      for (final sp in spacings) {
        if ((sp - avgSpacing).abs() > 2.5) {
          isEquidistant = false;
          break;
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
        i += 5; // Avanzar al siguiente sistema
      } else {
        i++;
      }
    }

    return staves;
  }

  /// Detecta las barras de compás verticales dentro del rango de un pentagrama.
  List<double> _detectBarlinesForStaff(List<OmrLine> lines, StaffSystem staff) {
    final vLines = lines.where((l) {
      if (!l.isVertical) return false;
      // Verificar si la línea vertical se encuentra en el rango vertical del pentagrama
      final overlap = math.min(l.maxY, staff.topY) - math.max(l.minY, staff.bottomY);
      return overlap >= staff.height * 0.70;
    }).toList();

    // Ordenar de izquierda a derecha
    vLines.sort((a, b) => a.midX.compareTo(b.midX));

    final barlineX = <double>[];
    for (final vl in vLines) {
      if (vl.midX > staff.startX + 10.0 && vl.midX < staff.endX - 10.0) {
        // Evitar duplicados cercanos (< 10 pt)
        if (barlineX.isEmpty || (vl.midX - barlineX.last).abs() > 10.0) {
          barlineX.add(vl.midX);
        }
      }
    }

    return barlineX;
  }

  /// Encuentra y mapea notas dentro de una región horizontal específica del pentagrama.
  List<HierarchicalNote> _findNotesInStaffRegion({
    required List<OmrRect> rects,
    required StaffSystem staff,
    required double startX,
    required double endX,
    required int maxTicks,
  }) {
    // Filtrar elementos con dimensiones acordes a cabezas de nota
    final minDim = staff.staffSpace * 0.4;
    final maxDim = staff.staffSpace * 2.5;

    final candidates = rects.where((r) {
      final inX = r.centerX >= startX && r.centerX < endX;
      final inY = r.centerY >= (staff.bottomY - staff.staffSpace * 2.5) &&
          r.centerY <= (staff.topY + staff.staffSpace * 2.5);
      final hasSize = r.width >= minDim && r.width <= maxDim &&
          r.height >= minDim && r.height <= maxDim;
      return inX && inY && hasSize;
    }).toList();

    if (candidates.isEmpty) {
      return [
        HierarchicalNote.rest(startTick: 0, durationTicks: maxTicks),
      ];
    }

    // Ordenar de izquierda a derecha (secuencia temporal)
    candidates.sort((a, b) => a.centerX.compareTo(b.centerX));

    final notes = <HierarchicalNote>[];
    int count = candidates.length;
    int durationPerNote = (maxTicks / count).floor().clamp(1, 16);
    if (durationPerNote != 1 && durationPerNote != 2 && durationPerNote != 4 &&
        durationPerNote != 8 && durationPerNote != 16) {
      durationPerNote = (durationPerNote <= 3) ? 2 : 4;
    }

    int currentTick = 0;
    for (int i = 0; i < count; i++) {
      final c = candidates[i];
      final noteName = _mapYToSolfegeNote(c.centerY, staff);

      notes.add(HierarchicalNote.note(
        startTick: currentTick,
        durationTicks: durationPerNote,
        noteName: noteName,
      ));

      currentTick += durationPerNote;
      if (currentTick >= maxTicks) break;
    }

    // Rellenar compás con silencio si resta espacio
    if (currentTick < maxTicks) {
      notes.add(HierarchicalNote.rest(
        startTick: currentTick,
        durationTicks: maxTicks - currentTick,
      ));
    }

    return notes;
  }

  /// Mapea la coordenada Y al nombre silábico de nota en Clave de Sol (G Clef).
  String _mapYToSolfegeNote(double y, StaffSystem staff) {
    // Delta relativo en semi-espacios (cada salto de medio staffSpace es un grado diatónico)
    final deltaHalfSpaces = ((y - staff.bottomY) / (staff.staffSpace / 2.0)).round();

    // Tabla diatónica en clave de Sol relativa a la primera línea (Mi4 = 0)
    const diatonicScale = [
      'Do4',  // -2 (Línea adicional inferior)
      'Re4',  // -1 (Espacio inferior)
      'Mi4',  //  0 (Primera línea inferior)
      'Fa4',  //  1 (Primer espacio)
      'Sol4', //  2 (Segunda línea)
      'La4',  //  3 (Segundo espacio)
      'Si4',  //  4 (Tercera línea central)
      'Do5',  //  5 (Tercer espacio)
      'Re5',  //  6 (Cuarta línea)
      'Mi5',  //  7 (Cuarto espacio)
      'Fa5',  //  8 (Quinta línea superior)
      'Sol5', //  9 (Espacio superior)
      'La5',  // 10 (Línea adicional superior)
    ];

    final index = (deltaHalfSpaces + 2).clamp(0, diatonicScale.length - 1);
    return diatonicScale[index];
  }

  /// Construcción heurística de respaldo cuando no se detectan pentagramas completos.
  HierarchicalScore _buildFallbackScore(
    List<OmrRect> rects,
    String title,
    int bpm,
    TimeSignature timeSignature,
  ) {
    if (rects.isEmpty) {
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

    rects.sort((a, b) => a.centerX.compareTo(b.centerX));
    final notes = <HierarchicalNote>[];
    int currentTick = 0;
    int duration = (timeSignature.totalTicks ~/ rects.length).clamp(2, 4);

    for (final _ in rects) {
      notes.add(HierarchicalNote.note(
        startTick: currentTick,
        durationTicks: duration,
        noteName: 'Sol4',
      ));
      currentTick += duration;
      if (currentTick >= timeSignature.totalTicks) break;
    }

    if (currentTick < timeSignature.totalTicks) {
      notes.add(HierarchicalNote.rest(
        startTick: currentTick,
        durationTicks: timeSignature.totalTicks - currentTick,
      ));
    }

    return HierarchicalScore(
      title: title,
      baseBpm: bpm,
      measures: [
        MeasureEntity(
          index: 0,
          timeSignature: timeSignature,
          notes: notes,
        ),
      ],
    );
  }
}
