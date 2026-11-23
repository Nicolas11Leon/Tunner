import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../mixer/domain/mixer_track_entity.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../domain/i_score_parser_service.dart';
import '../domain/parsed_score_result_entity.dart';
import '../domain/vector_omr_engine.dart';

class _PdfPoint {
  final double x;
  final double y;

  const _PdfPoint(this.x, this.y);

  double distanceTo(_PdfPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

class _PdfMatrix {
  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;

  const _PdfMatrix(this.a, this.b, this.c, this.d, this.e, this.f);

  static const _PdfMatrix identity = _PdfMatrix(1.0, 0.0, 0.0, 1.0, 0.0, 0.0);

  _PdfPoint transform(double x, double y) {
    return _PdfPoint(
      a * x + c * y + e,
      b * x + d * y + f,
    );
  }

  /// Pre-multiplica `this * other` conforme a ISO 32000-1 (`M_new * CTM`).
  _PdfMatrix multiply(_PdfMatrix other) {
    return _PdfMatrix(
      a * other.a + b * other.c,
      a * other.b + b * other.d,
      c * other.a + d * other.c,
      c * other.b + d * other.d,
      e * other.a + f * other.c + other.e,
      e * other.b + f * other.d + other.f,
    );
  }
}

class _PdfSubpath {
  final _PdfPoint startPoint;
  _PdfPoint currentPoint;
  final bool isRect;
  bool isClosed;
  bool hasCurve = false;

  double minX;
  double maxX;
  double minY;
  double maxY;

  final List<OmrLine> lineSegments = [];

  _PdfSubpath(
    this.startPoint, {
    this.isRect = false,
    this.isClosed = false,
  })  : currentPoint = startPoint,
        minX = startPoint.x,
        maxX = startPoint.x,
        minY = startPoint.y,
        maxY = startPoint.y;

  void includePoint(double x, double y) {
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }

  void addLineTo(_PdfPoint end) {
    lineSegments.add(OmrLine(x1: currentPoint.x, y1: currentPoint.y, x2: end.x, y2: end.y));
    includePoint(end.x, end.y);
    currentPoint = end;
  }

  void addCubicTo(_PdfPoint p1, _PdfPoint p2, _PdfPoint p3) {
    hasCurve = true;
    final p0 = currentPoint;
    _updateCubicBounds1D(p0.x, p1.x, p2.x, p3.x, (val) {
      if (val < minX) minX = val;
      if (val > maxX) maxX = val;
    });
    _updateCubicBounds1D(p0.y, p1.y, p2.y, p3.y, (val) {
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    });
    currentPoint = p3;
  }

  void close() {
    if (!isClosed && !hasCurve && !isRect && currentPoint.distanceTo(startPoint) > 0.01) {
      lineSegments.add(
        OmrLine(x1: currentPoint.x, y1: currentPoint.y, x2: startPoint.x, y2: startPoint.y),
      );
    }
    isClosed = true;
    currentPoint = startPoint;
  }

  static void _updateCubicBounds1D(
    double p0,
    double p1,
    double p2,
    double p3,
    void Function(double val) onExtremum,
  ) {
    onExtremum(p0);
    onExtremum(p3);

    final v0 = p1 - p0;
    final v1 = p2 - p1;
    final v2 = p3 - p2;
    final a = v0 - 2.0 * v1 + v2;
    final b = v1 - v0;
    final c = v0;

    double eval(double t) {
      final mt = 1.0 - t;
      return mt * mt * mt * p0 +
          3.0 * mt * mt * t * p1 +
          3.0 * mt * t * t * p2 +
          t * t * t * p3;
    }

    if (a.abs() < 1e-9) {
      if (b.abs() > 1e-9) {
        final t = -c / (2.0 * b);
        if (t > 0.0 && t < 1.0) onExtremum(eval(t));
      }
      return;
    }

    final disc = b * b - a * c;
    if (disc >= 0.0) {
      final sqrtDisc = math.sqrt(disc);
      final t1 = (-b + sqrtDisc) / a;
      final t2 = (-b - sqrtDisc) / a;
      if (t1 > 0.0 && t1 < 1.0) onExtremum(eval(t1));
      if (t2 > 0.0 && t2 < 1.0) onExtremum(eval(t2));
    }
  }
}

/// Decodificador especializado para partituras en formato PDF mediante Reconocimiento Óptico Vectorial (Vector OMR).
/// 100% Offline, sin dependencias nativas externas.
/// Extrae flujos de dibujo gráficos vectoriales (q, Q, cm, m, l, re, c, v, y, h, S, s, f, F, B)
/// de objetos PDF, descomprime flujos FlateDecode (ZLib) y delega a [VectorOmrEngine]
/// para reconstruir pentagramas, compases y notas musicales en un [HierarchicalScore].
class PdfScoreParser implements IScoreParserService {
  final VectorOmrEngine _omrEngine;

  const PdfScoreParser({
    VectorOmrEngine omrEngine = const VectorOmrEngine(),
  }) : _omrEngine = omrEngine;

  @override
  bool canParse(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return true;
    }
    // Firma binaria estándar de archivo PDF (%PDF- en bytes 0x25, 0x50, 0x44, 0x46)
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return true;
    }
    return false;
  }

  @override
  Future<ParsedScoreResult> parseScoreData({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw const FormatException('El archivo PDF provisto está vacío.');
    }

    // Validar cabecera PDF en los primeros 1024 bytes
    final headerSlice = bytes.take(1024).toList();
    final headerStr = latin1.decode(headerSlice, allowInvalid: true);
    if (!headerStr.contains('%PDF-')) {
      throw const FormatException('El archivo no cuenta con una cabecera PDF válida (%PDF-).');
    }

    final warnings = <String>[];
    final title = _extractPdfTitle(headerStr, fileName);

    // 1. Extraer flujos de contenido gráfico (descomprimiendo FlateDecode si aplica)
    final drawingStreams = _extractDrawingStreams(bytes, warnings);

    // 2. Procesar cada página/stream por separado para no colapsar coordenadas multipágina
    final allMeasures = <MeasureEntity>[];
    int nextMeasureIdx = 0;
    int detectedBpm = 120;
    bool anyPrimitives = false;

    for (final streamText in drawingStreams) {
      final pageLines = <OmrLine>[];
      final pageRects = <OmrRect>[];
      _parseGraphicOperators(streamText, pageLines, pageRects);
      if (pageLines.isEmpty && pageRects.isEmpty) continue;
      anyPrimitives = true;

      try {
        final pageScore = _omrEngine.processGeometricElements(
          lines: pageLines,
          rects: pageRects,
          title: title,
        );
        detectedBpm = pageScore.baseBpm;
        for (final m in pageScore.measures) {
          allMeasures.add(m.copyWith(index: nextMeasureIdx++));
        }
      } on FormatException catch (e) {
        warnings.add(e.message);
      }
    }

    if (!anyPrimitives) {
      throw const FormatException(
        'No se encontraron instrucciones gráficas vectoriales ni pentagramas válidos en el PDF.',
      );
    }

    if (allMeasures.isEmpty) {
      throw const FormatException(
        'El documento PDF no contiene pentagramas vectoriales válidos de 5 líneas.',
      );
    }

    // 3. Consolidar partitura multipágina real
    final score = HierarchicalScore(
      title: title,
      baseBpm: detectedBpm,
      measures: allMeasures,
    );

    int totalNotes = 0;
    for (final m in score.measures) {
      totalNotes += m.notes.where((n) => !n.isRest).length;
    }

    // 4. Empaquetar resultado en estructura SongPackage canónica
    final pkg = SongPackage(
      id: 'omr_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      composer: 'Transcripción PDF (OMR)',
      genre: MusicGenre.classical,
      difficulty: SongDifficulty.intermediate,
      defaultBpm: score.baseBpm,
      score: score,
      tracks: const [
        AudioTrack(
          id: 'track_omr_score',
          title: 'Partitura OMR',
          instrumentIcon: 'music_note',
          volume: 1.0,
          isMuted: false,
          isSolo: false,
        ),
      ],
    );

    return ParsedScoreResult(
      package: pkg,
      format: 'PDF (Vector OMR)',
      totalMeasures: score.measures.length,
      totalNotes: totalNotes,
      warnings: warnings,
    );
  }

  /// Extrae el título del documento a partir de metadatos PDF o del nombre de archivo.
  String _extractPdfTitle(String headerSample, String fileName) {
    final titleMatch = RegExp(r'/Title\s*\(([^)]+)\)').firstMatch(headerSample);
    if (titleMatch != null) {
      final raw = titleMatch.group(1)?.trim();
      if (raw != null && raw.isNotEmpty) {
        return raw;
      }
    }

    final dotIndex = fileName.lastIndexOf('.');
    final base = (dotIndex > 0) ? fileName.substring(0, dotIndex) : fileName;
    final clean = base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    return clean.isNotEmpty ? clean : 'Partitura PDF';
  }

  /// Extrae y descomprime todos los flujos de contenido (stream ... endstream) del documento.
  List<String> _extractDrawingStreams(Uint8List bytes, List<String> warnings) {
    final streams = <String>[];
    final length = bytes.length;
    int cursor = 0;

    final streamMarker = [0x73, 0x74, 0x72, 0x65, 0x61, 0x6D]; // "stream"
    final endStreamMarker = [0x65, 0x6E, 0x64, 0x73, 0x74, 0x72, 0x65, 0x61, 0x6D]; // "endstream"

    while (cursor < length - 10) {
      final streamPos = _indexOfBytes(bytes, streamMarker, cursor);
      if (streamPos == -1) break;

      int dataStart = streamPos + 6;
      if (dataStart < length && bytes[dataStart] == 0x0D) {
        dataStart++;
      }
      if (dataStart < length && bytes[dataStart] == 0x0A) {
        dataStart++;
      }

      final endStreamPos = _indexOfBytes(bytes, endStreamMarker, dataStart);
      if (endStreamPos == -1) break;

      int dataEnd = endStreamPos;
      if (dataEnd > dataStart && bytes[dataEnd - 1] == 0x0A) {
        dataEnd--;
        if (dataEnd > dataStart && bytes[dataEnd - 1] == 0x0D) {
          dataEnd--;
        }
      }

      final dictStart = (streamPos > 512) ? streamPos - 512 : 0;
      final dictText = latin1.decode(bytes.sublist(dictStart, streamPos), allowInvalid: true);
      final isFlate = dictText.contains('/FlateDecode');

      final rawStreamBytes = bytes.sublist(dataStart, dataEnd);

      if (isFlate) {
        try {
          const int maxPdfStreamBytes = 32 * 1024 * 1024;
          final decompressed = ZLibDecoder().decodeBytes(rawStreamBytes);
          if (decompressed.length > maxPdfStreamBytes) {
            throw const FormatException('Stream PDF FlateDecode supera la cuota maxima segura.');
          }
          streams.add(latin1.decode(decompressed, allowInvalid: true));
        } catch (e) {
          if (e is FormatException) rethrow;
          streams.add(latin1.decode(rawStreamBytes, allowInvalid: true));
        }
      } else {
        streams.add(latin1.decode(rawStreamBytes, allowInvalid: true));
      }

      cursor = endStreamPos + 9;
    }

    if (streams.isEmpty) {
      streams.add(latin1.decode(bytes, allowInvalid: true));
    }

    return streams;
  }

  /// Encuentra la primera ocurrencia de un patrón de bytes en una secuencia.
  int _indexOfBytes(Uint8List source, List<int> pattern, int start) {
    if (pattern.isEmpty || start + pattern.length > source.length) return -1;
    final maxIndex = source.length - pattern.length;
    for (int i = start; i <= maxIndex; i++) {
      bool match = true;
      for (int k = 0; k < pattern.length; k++) {
        if (source[i + k] != pattern[k]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  /// Tokeniza un flujo de contenido PDF ignorando comentarios, literales de cadena `(...)`
  /// y bloques de diccionario/hexadecimal para evitar falsos operadores gráficos.
  List<String> _tokenizePdfStream(String streamText) {
    final tokens = <String>[];
    final len = streamText.length;
    int i = 0;

    bool isWhitespace(int code) => code <= 0x20;
    bool isDelimiter(int code) =>
        code == 0x28 || // (
        code == 0x29 || // )
        code == 0x3C || // <
        code == 0x3E || // >
        code == 0x5B || // [
        code == 0x5D || // ]
        code == 0x7B || // {
        code == 0x7D || // }
        code == 0x2F || // /
        code == 0x25; // %

    while (i < len) {
      final code = streamText.codeUnitAt(i);
      if (isWhitespace(code)) {
        i++;
        continue;
      }

      // Comentario PDF (% ... fin de línea)
      if (code == 0x25) {
        while (i < len && streamText.codeUnitAt(i) != 0x0A && streamText.codeUnitAt(i) != 0x0D) {
          i++;
        }
        continue;
      }

      // Cadena literal (...)
      if (code == 0x28) {
        int depth = 1;
        i++;
        while (i < len && depth > 0) {
          final c = streamText.codeUnitAt(i);
          if (c == 0x5C) {
            i += 2; // backslash escape
            continue;
          }
          if (c == 0x28) depth++;
          if (c == 0x29) depth--;
          i++;
        }
        continue;
      }

      // Cadenas hexadecimales <...> o diccionarios <<...>>
      if (code == 0x3C) {
        if (i + 1 < len && streamText.codeUnitAt(i + 1) == 0x3C) {
          i += 2;
          int dictDepth = 1;
          while (i < len && dictDepth > 0) {
            if (i + 1 < len &&
                streamText.codeUnitAt(i) == 0x3C &&
                streamText.codeUnitAt(i + 1) == 0x3C) {
              dictDepth++;
              i += 2;
            } else if (i + 1 < len &&
                streamText.codeUnitAt(i) == 0x3E &&
                streamText.codeUnitAt(i + 1) == 0x3E) {
              dictDepth--;
              i += 2;
            } else {
              i++;
            }
          }
        } else {
          i++;
          while (i < len && streamText.codeUnitAt(i) != 0x3E) {
            i++;
          }
          if (i < len) i++;
        }
        continue;
      }

      // Arreglos [...] o llaves {...}
      if (code == 0x5B || code == 0x5D || code == 0x7B || code == 0x7D) {
        tokens.add(streamText[i]);
        i++;
        continue;
      }

      // Nombres (/F1) u operadores/números regulares
      final start = i;
      if (code == 0x2F) i++;
      while (i < len) {
        final c = streamText.codeUnitAt(i);
        if (isWhitespace(c) || isDelimiter(c)) break;
        i++;
      }
      tokens.add(streamText.substring(start, i));
    }

    return tokens;
  }

  /// Tokeniza e interpreta operadores gráficos vectoriales en el flujo PDF,
  /// manteniendo la pila CTM (q, Q, cm) y el estado de subpaths Bezier cerrados (S/s vs f/F/B).
  void _parseGraphicOperators(String streamText, List<OmrLine> lines, List<OmrRect> rects) {
    final tokens = _tokenizePdfStream(streamText);
    final numStack = <double>[];
    final matrixStack = <_PdfMatrix>[];
    _PdfMatrix ctm = _PdfMatrix.identity;

    final subpaths = <_PdfSubpath>[];
    _PdfSubpath? currentSubpath;
    bool inTextObject = false;

    for (final token in tokens) {
      if (token.isEmpty) continue;

      if (token == 'BT') {
        inTextObject = true;
        numStack.clear();
        continue;
      }
      if (token == 'ET') {
        inTextObject = false;
        numStack.clear();
        continue;
      }
      if (inTextObject) {
        continue;
      }

      final numVal = double.tryParse(token);
      if (numVal != null) {
        numStack.add(numVal);
        continue;
      }

      switch (token) {
        case 'q': // gsave
          matrixStack.add(ctm);
          numStack.clear();
          break;

        case 'Q': // grestore
          if (matrixStack.isNotEmpty) {
            ctm = matrixStack.removeLast();
          }
          numStack.clear();
          break;

        case 'cm': // concat matrix (a b c d e f cm)
          if (numStack.length >= 6) {
            final f = numStack.removeLast();
            final e = numStack.removeLast();
            final d = numStack.removeLast();
            final c = numStack.removeLast();
            final b = numStack.removeLast();
            final a = numStack.removeLast();
            ctm = _PdfMatrix(a, b, c, d, e, f).multiply(ctm);
          }
          numStack.clear();
          break;

        case 'm': // moveto (x y m)
          if (numStack.length >= 2) {
            final y = numStack.removeLast();
            final x = numStack.removeLast();
            final pt = ctm.transform(x, y);
            currentSubpath = _PdfSubpath(pt);
            subpaths.add(currentSubpath);
          }
          numStack.clear();
          break;

        case 'l': // lineto (x y l)
          if (numStack.length >= 2) {
            final y = numStack.removeLast();
            final x = numStack.removeLast();
            final pt = ctm.transform(x, y);
            currentSubpath ??= _PdfSubpath(ctm.transform(0.0, 0.0));
            if (!subpaths.contains(currentSubpath)) {
              subpaths.add(currentSubpath);
            }
            currentSubpath.addLineTo(pt);
          }
          numStack.clear();
          break;

        case 'c': // curveto (x1 y1 x2 y2 x3 y3 c)
          if (numStack.length >= 6) {
            final y3 = numStack.removeLast();
            final x3 = numStack.removeLast();
            final y2 = numStack.removeLast();
            final x2 = numStack.removeLast();
            final y1 = numStack.removeLast();
            final x1 = numStack.removeLast();

            final p1 = ctm.transform(x1, y1);
            final p2 = ctm.transform(x2, y2);
            final p3 = ctm.transform(x3, y3);
            currentSubpath ??= _PdfSubpath(ctm.transform(0.0, 0.0));
            if (!subpaths.contains(currentSubpath)) {
              subpaths.add(currentSubpath);
            }
            currentSubpath.addCubicTo(p1, p2, p3);
          }
          numStack.clear();
          break;

        case 'v': // curveto con primer punto de control igual al punto actual (x2 y2 x3 y3 v)
          if (numStack.length >= 4) {
            final y3 = numStack.removeLast();
            final x3 = numStack.removeLast();
            final y2 = numStack.removeLast();
            final x2 = numStack.removeLast();

            currentSubpath ??= _PdfSubpath(ctm.transform(0.0, 0.0));
            if (!subpaths.contains(currentSubpath)) {
              subpaths.add(currentSubpath);
            }
            final p1 = currentSubpath.currentPoint;
            final p2 = ctm.transform(x2, y2);
            final p3 = ctm.transform(x3, y3);
            currentSubpath.addCubicTo(p1, p2, p3);
          }
          numStack.clear();
          break;

        case 'y': // curveto con segundo punto de control igual al punto final (x1 y1 x3 y3 y)
          if (numStack.length >= 4) {
            final y3 = numStack.removeLast();
            final x3 = numStack.removeLast();
            final y1 = numStack.removeLast();
            final x1 = numStack.removeLast();

            currentSubpath ??= _PdfSubpath(ctm.transform(0.0, 0.0));
            if (!subpaths.contains(currentSubpath)) {
              subpaths.add(currentSubpath);
            }
            final p1 = ctm.transform(x1, y1);
            final p3 = ctm.transform(x3, y3);
            currentSubpath.addCubicTo(p1, p3, p3);
          }
          numStack.clear();
          break;

        case 're': // rectangle (x y w h re)
          if (numStack.length >= 4) {
            final h = numStack.removeLast();
            final w = numStack.removeLast();
            final y = numStack.removeLast();
            final x = numStack.removeLast();

            final p0 = ctm.transform(x, y);
            final p1 = ctm.transform(x + w, y);
            final p2 = ctm.transform(x + w, y + h);
            final p3 = ctm.transform(x, y + h);

            final rectSubpath = _PdfSubpath(p0, isRect: true, isClosed: true);
            rectSubpath.includePoint(p1.x, p1.y);
            rectSubpath.includePoint(p2.x, p2.y);
            rectSubpath.includePoint(p3.x, p3.y);
            subpaths.add(rectSubpath);
            currentSubpath = rectSubpath;
          }
          numStack.clear();
          break;

        case 'h': // closepath
          currentSubpath?.close();
          numStack.clear();
          break;

        case 'S': // stroke
          _flushSubpaths(
            subpaths: subpaths,
            lines: lines,
            rects: rects,
            isFilled: false,
            closeAll: false,
          );
          currentSubpath = null;
          numStack.clear();
          break;

        case 's': // closepath and stroke
          _flushSubpaths(
            subpaths: subpaths,
            lines: lines,
            rects: rects,
            isFilled: false,
            closeAll: true,
          );
          currentSubpath = null;
          numStack.clear();
          break;

        case 'f': // fill
        case 'F': // fill (compatibilidad)
        case 'f*': // eofill
        case 'B': // fill and stroke
        case 'B*': // eofill and stroke
          _flushSubpaths(
            subpaths: subpaths,
            lines: lines,
            rects: rects,
            isFilled: true,
            closeAll: false,
          );
          currentSubpath = null;
          numStack.clear();
          break;

        case 'b': // closepath, fill and stroke
        case 'b*': // closepath, eofill and stroke
          _flushSubpaths(
            subpaths: subpaths,
            lines: lines,
            rects: rects,
            isFilled: true,
            closeAll: true,
          );
          currentSubpath = null;
          numStack.clear();
          break;

        case 'n': // end path without stroke or fill (ej. clipping path W n)
          subpaths.clear();
          currentSubpath = null;
          numStack.clear();
          break;

        default:
          // Cualquier otro operador gráfico consume sus operandos numéricos
          numStack.clear();
          break;
      }
    }

    // Respaldo para flujos sintéticos que omitan operador final de pintado
    if (subpaths.isNotEmpty) {
      _flushSubpaths(
        subpaths: subpaths,
        lines: lines,
        rects: rects,
        isFilled: true,
        closeAll: false,
      );
    }
  }

  /// Emite líneas y cajas delimitadoras [OmrRect] a partir de los subpaths pendientes.
  void _flushSubpaths({
    required List<_PdfSubpath> subpaths,
    required List<OmrLine> lines,
    required List<OmrRect> rects,
    required bool isFilled,
    required bool closeAll,
  }) {
    final curveCandidates = <({int index, _PdfSubpath subpath, double w, double h})>[];

    for (int i = 0; i < subpaths.length; i++) {
      final sp = subpaths[i];

      if (sp.isRect) {
        final w = sp.maxX - sp.minX;
        final h = sp.maxY - sp.minY;
        rects.add(OmrRect(x: sp.minX, y: sp.minY, width: w, height: h, isFilled: isFilled));

        if (h <= 3.0 && w >= 40.0) {
          final midY = (sp.minY + sp.maxY) / 2.0;
          lines.add(OmrLine(x1: sp.minX, y1: midY, x2: sp.maxX, y2: midY));
        } else if (w <= 3.0 && h >= 15.0) {
          final midX = (sp.minX + sp.maxX) / 2.0;
          lines.add(OmrLine(x1: midX, y1: sp.minY, x2: midX, y2: sp.maxY));
        } else if (h <= 4.5 && w >= 12.0) {
          final midY = (sp.minY + sp.maxY) / 2.0;
          lines.add(OmrLine(x1: sp.minX, y1: midY, x2: sp.maxX, y2: midY));
        }
        continue;
      }

      if (closeAll || sp.isClosed) {
        sp.close();
      }

      lines.addAll(sp.lineSegments);

      if (sp.hasCurve) {
        final isClosedCurve = sp.isClosed ||
            closeAll ||
            isFilled ||
            sp.currentPoint.distanceTo(sp.startPoint) <= 1.5;

        if (isClosedCurve) {
          final w = sp.maxX - sp.minX;
          final h = sp.maxY - sp.minY;
          if (w >= 3.0 && w <= 25.0 && h >= 3.0 && h <= 25.0) {
            curveCandidates.add((index: i, subpath: sp, w: w, h: h));
          }
        }
      }
    }

    // Detectar si un trazado relleno contiene un anillo interior hueco (contorno + agujero)
    final skippedHoleIndices = <int>{};
    final hollowOverrideIndices = <int>{};
    if (isFilled && curveCandidates.length >= 2) {
      for (final outer in curveCandidates) {
        for (final inner in curveCandidates) {
          if (outer.index == inner.index) continue;
          final contains = inner.subpath.minX > outer.subpath.minX &&
              inner.subpath.maxX < outer.subpath.maxX &&
              inner.subpath.minY > outer.subpath.minY &&
              inner.subpath.maxY < outer.subpath.maxY;
          if (contains) {
            hollowOverrideIndices.add(outer.index);
            skippedHoleIndices.add(inner.index);
          }
        }
      }
    }

    for (final c in curveCandidates) {
      if (skippedHoleIndices.contains(c.index)) continue;
      final effectiveFilled = hollowOverrideIndices.contains(c.index) ? false : isFilled;
      rects.add(
        OmrRect(
          x: c.subpath.minX,
          y: c.subpath.minY,
          width: c.w,
          height: c.h,
          isFilled: effectiveFilled,
        ),
      );
    }

    subpaths.clear();
  }
}
