import 'dart:convert';
import 'dart:typed_data';
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';

/// Serializador canónico en Pure Dart de partituras al estándar internacional PDF (ISO 32000-1).
/// 100% Offline, sin dependencias nativas o externas propietarias.
/// Compila cualquier [HierarchicalScore] en un documento PDF vectorial imprimible estructurado
/// en sistemas de pentagramas de 5 líneas, claves, métricas, figuras rítmicas, plicas direccionales
/// y silencios, con soporte de paginación A4 dinámica.
class CanonicalPdfExporter {
  // Constantes de dimensiones estándar A4 (puntos tipográficos PostScript: 72 pt = 1 pulgada)
  static const double pageWidth = 595.28;
  static const double pageHeight = 841.89;
  static const double marginLeft = 45.0;
  static const double marginRight = 45.0;
  static const double marginTop = 50.0;
  static const double marginBottom = 50.0;

  // Parámetros de notación musical
  static const double staffSpace = 8.0;
  static const double staffHeight = staffSpace * 4.0; // 32.0 pt (5 líneas)
  static const double systemGap = 65.0;
  static const int measuresPerSystem = 4;

  const CanonicalPdfExporter();

  /// Exporta un [SongPackage] a un array de bytes binarios que representa un documento PDF válido.
  Uint8List exportToPdf(SongPackage package) {
    return exportScore(
      score: package.score,
      title: package.title,
      composer: package.composer,
    );
  }

  /// Exporta un [HierarchicalScore] a formato PDF vectorial.
  Uint8List exportScore({
    required HierarchicalScore score,
    String title = 'Partitura Tunner',
    String composer = 'Tunner Music Studio',
  }) {
    final measures = score.measures;
    final totalMeasures = measures.isNotEmpty ? measures.length : 1;
    final totalSystems = (totalMeasures + measuresPerSystem - 1) ~/ measuresPerSystem;

    // Calcular capacidad por página
    final usableHeight = pageHeight - marginTop - marginBottom - 70.0; // Espacio tras encabezado
    final systemStep = staffHeight + systemGap; // 97.0 pt
    final systemsPerPage = (usableHeight / systemStep).floor().clamp(1, 6);

    final totalPages = (totalSystems + systemsPerPage - 1) ~/ systemsPerPage;

    final pageContents = <String>[];

    for (int p = 0; p < totalPages; p++) {
      final pageBuffer = StringBuffer();
      final isFirstPage = (p == 0);

      // 1. Encabezado de página
      if (isFirstPage) {
        _renderPageHeader(pageBuffer, title: title, composer: composer, bpm: score.baseBpm);
      }

      final startSystemIndex = p * systemsPerPage;
      final endSystemIndex = ((p + 1) * systemsPerPage < totalSystems)
          ? (p + 1) * systemsPerPage
          : totalSystems;

      double systemTopY = isFirstPage ? (pageHeight - marginTop - 85.0) : (pageHeight - marginTop - 30.0);

      for (int s = startSystemIndex; s < endSystemIndex; s++) {
        final startMeasureIdx = s * measuresPerSystem;
        final endMeasureIdx = (startMeasureIdx + measuresPerSystem < totalMeasures)
            ? startMeasureIdx + measuresPerSystem
            : totalMeasures;

        final systemMeasures = measures.isNotEmpty
            ? measures.sublist(startMeasureIdx, endMeasureIdx)
            : <MeasureEntity>[];

        final isLastSystem = (s == totalSystems - 1);

        _renderStaffSystem(
          pageBuffer,
          systemIndex: s,
          systemTopY: systemTopY,
          measures: systemMeasures,
          isFirstSystem: (s == 0),
          isLastSystem: isLastSystem,
        );

        systemTopY -= systemStep;
      }

      // Pie de página con numeración
      _renderPageFooter(pageBuffer, pageNumber: p + 1, totalPages: totalPages);

      pageContents.add(pageBuffer.toString());
    }

    return _buildPdfDocument(pageContents, title: title, composer: composer);
  }

  /// Dibuja el encabezado formal de la partitura (Título, Compositor, Tempo).
  void _renderPageHeader(
    StringBuffer buf, {
    required String title,
    required String composer,
    required int bpm,
  }) {
    final cleanTitle = _sanitizePdfText(title);
    final cleanComposer = _sanitizePdfText(composer);

    // Título Principal Centrado
    buf.writeln('BT');
    buf.writeln('/F1 20 Tf');
    buf.writeln('1 0 0 1 ${pageWidth / 2} ${pageHeight - marginTop - 15.0} Tm');
    buf.writeln('($cleanTitle) Tj');
    buf.writeln('ET');

    // Compositor / Autor alineado a la derecha
    buf.writeln('BT');
    buf.writeln('/F2 10 Tf');
    buf.writeln('1 0 0 1 ${pageWidth - marginRight - 140.0} ${pageHeight - marginTop - 38.0} Tm');
    buf.writeln('($cleanComposer) Tj');
    buf.writeln('ET');

    // Marca de Tempo / Metrónomo
    buf.writeln('BT');
    buf.writeln('/F1 11 Tf');
    buf.writeln('1 0 0 1 $marginLeft ${pageHeight - marginTop - 58.0} Tm');
    buf.writeln('(Tempo: q = $bpm BPM) Tj');
    buf.writeln('ET');
  }

  /// Dibuja un sistema completo de pentagramas de 5 líneas con clave, métrica y notas.
  void _renderStaffSystem(
    StringBuffer buf, {
    required int systemIndex,
    required double systemTopY,
    required List<MeasureEntity> measures,
    required bool isFirstSystem,
    required bool isLastSystem,
  }) {
    final systemWidth = pageWidth - marginLeft - marginRight;
    final staffBottomY = systemTopY - staffHeight;

    // 1. Trazar las 5 líneas paralelas del pentagrama
    buf.writeln('0.6 w'); // Grosor estándar de línea de pentagrama
    buf.writeln('0 0 0 RG'); // Color negro para trazos
    buf.writeln('0 0 0 rg'); // Color negro para rellenos

    for (int i = 0; i < 5; i++) {
      final y = staffBottomY + (i * staffSpace);
      buf.writeln('$marginLeft $y m ${marginLeft + systemWidth} $y l S');
    }

    // 2. Barra de inicio vertical del sistema
    buf.writeln('1.2 w');
    buf.writeln('$marginLeft $staffBottomY m $marginLeft $systemTopY l S');

    // 3. Clave de Sol estilizada (Treble Clef)
    _renderTrebleClef(buf, x: marginLeft + 8.0, bottomY: staffBottomY);

    double currentX = marginLeft + 35.0;

    // 4. Métrica de Compás (Time Signature 4/4) en el primer sistema
    if (isFirstSystem) {
      _renderTimeSignature(buf, x: currentX, bottomY: staffBottomY);
      currentX += 28.0;
    }

    final remainingWidth = (marginLeft + systemWidth) - currentX;
    final measureCount = measures.isNotEmpty ? measures.length : measuresPerSystem;
    final measureWidth = remainingWidth / measureCount;

    // 5. Renderizar compases del sistema
    for (int m = 0; m < measureCount; m++) {
      final measureX = currentX + (m * measureWidth);
      final measureEndX = measureX + measureWidth;

      final measureData = (m < measures.length) ? measures[m] : null;
      final notes = measureData?.notes ?? const <HierarchicalNote>[];

      if (notes.isEmpty) {
        // Silencio de redonda por defecto en compás vacío
        _renderWholeRest(buf, x: measureX + (measureWidth / 2), bottomY: staffBottomY);
      } else {
        _renderMeasureNotes(
          buf,
          notes: notes,
          measureStartX: measureX + 8.0,
          measureWidth: measureWidth - 16.0,
          bottomY: staffBottomY,
        );
      }

      // Barra divisoria del compás
      final isFinalBar = isLastSystem && (m == measureCount - 1);
      if (isFinalBar) {
        // Doble barra final (fina + gruesa)
        buf.writeln('0.8 w');
        buf.writeln('${measureEndX - 4.0} $staffBottomY m ${measureEndX - 4.0} $systemTopY l S');
        buf.writeln('3.0 w');
        buf.writeln('$measureEndX $staffBottomY m $measureEndX $systemTopY l S');
      } else {
        // Barra simple de compás
        buf.writeln('0.8 w');
        buf.writeln('$measureEndX $staffBottomY m $measureEndX $systemTopY l S');
      }
    }
  }

  /// Renderiza un glifo vectorial compacto para la Clave de Sol sobre la segunda línea (Sol4).
  void _renderTrebleClef(StringBuffer buf, {required double x, required double bottomY}) {
    buf.writeln('0.9 w');
    // Eje vertical y espiral envolvente
    final gLineY = bottomY + staffSpace; // Línea 2
    buf.writeln('$x ${bottomY - 4.0} m ${x + 2.0} ${bottomY + staffHeight + 8.0} l S');
    buf.writeln('${x + 2.0} ${bottomY + staffHeight + 8.0} m ${x + 8.0} ${bottomY + staffHeight + 2.0} l ${x - 2.0} $gLineY l S');
    // Cabeza espiral sobre la línea Sol
    buf.writeln('${x - 2.0} $gLineY m ${x + 6.0} $gLineY l ${x + 6.0} ${gLineY - 4.0} l $x ${gLineY - 4.0} l f');
  }

  /// Renderiza la indicación métrica 4/4 en el pentagrama.
  void _renderTimeSignature(StringBuffer buf, {required double x, required double bottomY}) {
    buf.writeln('BT');
    buf.writeln('/F1 14 Tf');
    // Numerador en la mitad superior
    buf.writeln('1 0 0 1 $x ${bottomY + (staffSpace * 2.2)} Tm');
    buf.writeln('(4) Tj');
    // Denominador en la mitad inferior
    buf.writeln('1 0 0 1 $x ${bottomY + (staffSpace * 0.4)} Tm');
    buf.writeln('(4) Tj');
    buf.writeln('ET');
  }

  /// Renderiza las notas y silencios de un compás con cálculo de alturas y líneas adicionales.
  void _renderMeasureNotes(
    StringBuffer buf, {
    required List<HierarchicalNote> notes,
    required double measureStartX,
    required double measureWidth,
    required double bottomY,
  }) {
    final noteCount = notes.length;
    final slotWidth = measureWidth / noteCount;

    for (int i = 0; i < noteCount; i++) {
      final note = notes[i];
      final noteX = measureStartX + (i * slotWidth) + (slotWidth * 0.2);

      if (note.isRest || note.noteName.isEmpty) {
        _renderRest(buf, ticks: note.durationTicks, x: noteX, bottomY: bottomY);
        continue;
      }

      final diatonicOffset = _diatonicStepsFromE4(note.noteName);
      final noteCenterY = bottomY + (diatonicOffset * (staffSpace / 2.0));

      // 1. Líneas adicionales (Ledger lines)
      _renderLedgerLines(buf, diatonicOffset: diatonicOffset, noteX: noteX, bottomY: bottomY);

      // 2. Cabeza de la nota (Notehead)
      final isHollow = (note.durationTicks >= 8); // Blanca (8 ticks) o Redonda (16 ticks)
      _renderNotehead(buf, x: noteX, y: noteCenterY, isHollow: isHollow);

      // 3. Plica (Stem) y Banderas (Flags)
      if (note.durationTicks < 16) {
        // Redonda no lleva plica
        final isStemUp = (diatonicOffset < 4); // Notas por debajo de la línea 3 (Si4)
        _renderStemAndFlags(
          buf,
          noteX: noteX,
          noteCenterY: noteCenterY,
          isStemUp: isStemUp,
          durationTicks: note.durationTicks,
        );
      }
    }
  }

  /// Dibuja la cabeza de nota mediante primitivas vectoriales (óvalo inclinado).
  void _renderNotehead(StringBuffer buf, {required double x, required double y, required bool isHollow}) {
    final rx = 4.8;
    final ry = 3.4;

    // Primitiva vectorial compatible con visores estándar e interoperable con OMR
    if (isHollow) {
      // Blanca / Redonda (Hueca)
      buf.writeln('1.2 w');
      buf.writeln('${x - rx} $y m');
      buf.writeln('${x - rx} ${y + ry} ${x + rx} ${y + ry} ${x + rx} $y c');
      buf.writeln('${x + rx} ${y - ry} ${x - rx} ${y - ry} ${x - rx} $y c s');
    } else {
      // Negra / Corchea / Semicorchea (Rellena)
      buf.writeln('${x - rx} $y m');
      buf.writeln('${x - rx} ${y + ry} ${x + rx} ${y + ry} ${x + rx} $y c');
      buf.writeln('${x + rx} ${y - ry} ${x - rx} ${y - ry} ${x - rx} $y c f');
    }

    // Marcador complementario de rectángulo acotado para reconocimiento estricto OMR
    buf.writeln('${x - 3.5} ${y - 3.0} 7.0 6.0 re f');
  }

  /// Dibuja la plica vertical y banderas para figuras de menor duración.
  void _renderStemAndFlags(
    StringBuffer buf, {
    required double noteX,
    required double noteCenterY,
    required bool isStemUp,
    required int durationTicks,
  }) {
    const stemLength = 28.0;
    buf.writeln('0.9 w');

    if (isStemUp) {
      final stemX = noteX + 4.5;
      final stemTopY = noteCenterY + stemLength;
      buf.writeln('$stemX $noteCenterY m $stemX $stemTopY l S');

      // Bandera para corchea (2 ticks) o semicorchea (1 tick)
      if (durationTicks <= 2) {
        buf.writeln('0.8 w');
        buf.writeln('$stemX $stemTopY m ${stemX + 7.0} ${stemTopY - 8.0} l ${stemX + 1.0} ${stemTopY - 14.0} l S');
      }
      if (durationTicks <= 1) {
        buf.writeln('$stemX ${stemTopY - 5.0} m ${stemX + 7.0} ${stemTopY - 13.0} l ${stemX + 1.0} ${stemTopY - 19.0} l S');
      }
    } else {
      final stemX = noteX - 4.5;
      final stemBottomY = noteCenterY - stemLength;
      buf.writeln('$stemX $noteCenterY m $stemX $stemBottomY l S');

      if (durationTicks <= 2) {
        buf.writeln('0.8 w');
        buf.writeln('$stemX $stemBottomY m ${stemX + 7.0} ${stemBottomY + 8.0} l ${stemX + 1.0} ${stemBottomY + 14.0} l S');
      }
      if (durationTicks <= 1) {
        buf.writeln('$stemX ${stemBottomY + 5.0} m ${stemX + 7.0} ${stemBottomY + 13.0} l ${stemX + 1.0} ${stemBottomY + 19.0} l S');
      }
    }
  }

  /// Traza líneas adicionales para notas que exceden los límites superior o inferior del pentagrama.
  void _renderLedgerLines(
    StringBuffer buf, {
    required int diatonicOffset,
    required double noteX,
    required double bottomY,
  }) {
    buf.writeln('0.8 w');
    // Líneas inferiores (Do4 / C4 diatonicOffset = -2, La3 diatonicOffset = -4)
    if (diatonicOffset <= -2) {
      for (int step = -2; step >= diatonicOffset; step -= 2) {
        final lineY = bottomY + (step * (staffSpace / 2.0));
        buf.writeln('${noteX - 8.0} $lineY m ${noteX + 8.0} $lineY l S');
      }
    }
    // Líneas superiores (La5 / A5 diatonicOffset = 10, Do6 diatonicOffset = 12)
    if (diatonicOffset >= 10) {
      for (int step = 10; step <= diatonicOffset; step += 2) {
        final lineY = bottomY + (step * (staffSpace / 2.0));
        buf.writeln('${noteX - 8.0} $lineY m ${noteX + 8.0} $lineY l S');
      }
    }
  }

  /// Dibuja silencios vectoriales proporcionales.
  void _renderRest(StringBuffer buf, {required int ticks, required double x, required double bottomY}) {
    if (ticks >= 16) {
      _renderWholeRest(buf, x: x, bottomY: bottomY);
    } else if (ticks >= 8) {
      _renderHalfRest(buf, x: x, bottomY: bottomY);
    } else {
      _renderQuarterRest(buf, x: x, bottomY: bottomY);
    }
  }

  /// Silencio de Redonda (colgado bajo la línea 4).
  void _renderWholeRest(StringBuffer buf, {required double x, required double bottomY}) {
    final y = bottomY + (staffSpace * 3.0) - 3.5;
    buf.writeln('${x - 5.0} $y 10.0 3.5 re f');
  }

  /// Silencio de Blanca (apoyado sobre la línea 3).
  void _renderHalfRest(StringBuffer buf, {required double x, required double bottomY}) {
    final y = bottomY + (staffSpace * 2.0);
    buf.writeln('${x - 5.0} $y 10.0 3.5 re f');
  }

  /// Silencio de Negra en zigzag vertical estilizado.
  void _renderQuarterRest(StringBuffer buf, {required double x, required double bottomY}) {
    final midY = bottomY + (staffSpace * 2.0);
    buf.writeln('1.2 w');
    buf.writeln('${x - 2.0} ${midY + 10.0} m ${x + 3.0} ${midY + 4.0} l ${x - 3.0} $midY l ${x + 2.0} ${midY - 6.0} l ${x - 1.0} ${midY - 10.0} l S');
  }

  /// Pie de página con numeración y marca de agua de software libre.
  void _renderPageFooter(StringBuffer buf, {required int pageNumber, required int totalPages}) {
    buf.writeln('BT');
    buf.writeln('/F2 9 Tf');
    buf.writeln('1 0 0 1 ${pageWidth / 2 - 40.0} $marginBottom Tm');
    buf.writeln('(Tunner - Pagina $pageNumber de $totalPages) Tj');
    buf.writeln('ET');
  }

  /// Calcula el número de pasos diatónicos de semiespacio respecto a Mi4 (Línea 1 = 0).
  int _diatonicStepsFromE4(String rawName) {
    String name = rawName.trim().toUpperCase();
    if (name.isEmpty) return 0;

    // Normalizar solfeo a clave anglosajona
    const solfegePrefixes = {
      'DO': 'C',
      'RE': 'D',
      'MI': 'E',
      'FA': 'F',
      'SOL': 'G',
      'LA': 'A',
      'SI': 'B',
    };

    String letter = 'E';
    for (final entry in solfegePrefixes.entries) {
      if (name.startsWith(entry.key)) {
        letter = entry.value;
        name = name.substring(entry.key.length);
        break;
      }
    }
    if (name.startsWith(RegExp(r'[A-G]'))) {
      letter = name[0];
      name = name.substring(1);
    }

    // Extraer octava
    final matchOctave = RegExp(r'\d+').firstMatch(name);
    final octave = (matchOctave != null) ? int.parse(matchOctave.group(0)!) : 4;

    const diatonicStepMap = {
      'C': 0,
      'D': 1,
      'E': 2,
      'F': 3,
      'G': 4,
      'A': 5,
      'B': 6,
    };

    final stepInOctave = diatonicStepMap[letter] ?? 2;
    // Mi4 (E4) es nuestro punto de referencia 0 (Línea 1):
    // E4 tiene stepInOctave = 2, octava = 4 -> valor absoluto = 4 * 7 + 2 = 30
    final noteAbsStep = (octave * 7) + stepInOctave;
    const e4AbsStep = (4 * 7) + 2; // 30

    return noteAbsStep - e4AbsStep;
  }

  /// Sanitiza cadenas de texto para literales seguros de cadenas en sintaxis PDF (...)
  String _sanitizePdfText(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  /// Compila la estructura completa de objetos PDF (ISO 32000-1) con tabla xref y trailer.
  Uint8List _buildPdfDocument(
    List<String> pageContents, {
    required String title,
    required String composer,
  }) {
    final pageCount = pageContents.length;
    final objects = <String>[];

    final cleanTitle = _sanitizePdfText(title);
    final cleanComposer = _sanitizePdfText(composer);

    // Objeto 1: Catalog
    objects.add('<<\n  /Type /Catalog\n  /Pages 2 0 R\n>>');

    // Objeto 2: Pages Dict (Kids) - Las páginas inician en el objeto 4 (4, 6, 8...)
    final kids = List.generate(pageCount, (i) => '${4 + (i * 2)} 0 R').join(' ');
    objects.add('<<\n  /Type /Pages\n  /Kids [$kids]\n  /Count $pageCount\n>>');

    // Objeto 3: Info Dictionary (dentro de los primeros 1024 bytes)
    objects.add(
      '<<\n'
      '  /Title ($cleanTitle)\n'
      '  /Author ($cleanComposer)\n'
      '  /Creator (Tunner Music Studio)\n'
      '  /Producer (Tunner Canonical PDF Exporter)\n'
      '>>',
    );

    // Generar pares Page (4, 6, 8...) y Contents (5, 7, 9...)
    for (int p = 0; p < pageCount; p++) {
      final pageObjIndex = 4 + (p * 2);
      final contentObjIndex = pageObjIndex + 1;
      final contentStr = pageContents[p];
      final contentBytes = utf8.encode(contentStr);

      // Page Object
      objects.add(
        '<<\n'
        '  /Type /Page\n'
        '  /Parent 2 0 R\n'
        '  /MediaBox [0 0 $pageWidth $pageHeight]\n'
        '  /Contents $contentObjIndex 0 R\n'
        '  /Resources <<\n'
        '    /Font <<\n'
        '      /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\n'
        '      /F2 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\n'
        '    >>\n'
        '  >>\n'
        '>>',
      );

      // Stream Contents Object
      objects.add(
        '<<\n  /Length ${contentBytes.length}\n>>\nstream\n$contentStr\nendstream',
      );
    }

    final totalObjects = objects.length;
    final buffer = BytesBuilder();

    // Cabecera estándar PDF 1.4 con bytes binarios de protección de transporte (> 127)
    final header = '%PDF-1.4\n%\xE2\xE3\xCF\xD3\n';
    buffer.add(latin1.encode(header));

    final offsets = <int>[];

    for (int i = 0; i < totalObjects; i++) {
      offsets.add(buffer.length);
      final objId = i + 1;
      final objText = '$objId 0 obj\n${objects[i]}\nendobj\n';
      buffer.add(utf8.encode(objText));
    }

    final startXref = buffer.length;

    // Tabla de referencias cruzadas (xref)
    final xrefBuf = StringBuffer();
    xrefBuf.writeln('xref');
    xrefBuf.writeln('0 ${totalObjects + 1}');
    xrefBuf.writeln('0000000000 65535 f ');

    for (int i = 0; i < totalObjects; i++) {
      final off = offsets[i].toString().padLeft(10, '0');
      xrefBuf.writeln('$off 00000 n ');
    }

    xrefBuf.writeln('trailer');
    xrefBuf.writeln('<<');
    xrefBuf.writeln('  /Size ${totalObjects + 1}');
    xrefBuf.writeln('  /Root 1 0 R');
    xrefBuf.writeln('  /Info 3 0 R');
    xrefBuf.writeln('>>');
    xrefBuf.writeln('startxref');
    xrefBuf.writeln('$startXref');
    xrefBuf.writeln('%%EOF');

    buffer.add(utf8.encode(xrefBuf.toString()));

    return buffer.toBytes();
  }
}
