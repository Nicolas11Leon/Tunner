import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../mixer/domain/mixer_track_entity.dart';
import '../../sheet_music/domain/score_tree.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../domain/i_score_parser_service.dart';
import '../domain/parsed_score_result_entity.dart';
import '../domain/vector_omr_engine.dart';

/// Decodificador especializado para partituras en formato PDF mediante Reconocimiento Óptico Vectorial (Vector OMR).
/// 100% Offline, sin dependencias nativas externas.
/// Extrae flujos de dibujo gráficos vectoriales (m, l, re, c) de objetos PDF,
/// descomprime flujos FlateDecode (ZLib) y delega a [VectorOmrEngine] para reconstruir
/// pentagramas, compases y notas musicales en un [HierarchicalScore].
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

    // 2. Extraer primitivas geométricas de líneas y rectángulos a partir de los operadores de dibujo
    final lines = <OmrLine>[];
    final rects = <OmrRect>[];

    for (final streamText in drawingStreams) {
      _parseGraphicOperators(streamText, lines, rects);
    }

    if (lines.isEmpty && rects.isEmpty) {
      warnings.add('No se encontraron instrucciones gráficas vectoriales en los flujos del PDF.');
    }

    // 3. Procesar las primitivas geométricas con el motor Vector OMR
    final score = _omrEngine.processGeometricElements(
      lines: lines,
      rects: rects,
      title: title,
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
    // Búsqueda de metadato /Title (...)
    final titleMatch = RegExp(r'/Title\s*\(([^)]+)\)').firstMatch(headerSample);
    if (titleMatch != null) {
      final raw = titleMatch.group(1)?.trim();
      if (raw != null && raw.isNotEmpty) {
        return raw;
      }
    }

    // Nombre base de archivo limpio
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

    // Firmas ASCII para localizar streams
    final streamMarker = [0x73, 0x74, 0x72, 0x65, 0x61, 0x6D]; // "stream"
    final endStreamMarker = [0x65, 0x6E, 0x64, 0x73, 0x74, 0x72, 0x65, 0x61, 0x6D]; // "endstream"

    while (cursor < length - 10) {
      final streamPos = _indexOfBytes(bytes, streamMarker, cursor);
      if (streamPos == -1) break;

      // Buscar el inicio de los datos del stream (después de \r\n o \n)
      int dataStart = streamPos + 6;
      if (dataStart < length && bytes[dataStart] == 0x0D) {
        dataStart++;
      }
      if (dataStart < length && bytes[dataStart] == 0x0A) {
        dataStart++;
      }

      final endStreamPos = _indexOfBytes(bytes, endStreamMarker, dataStart);
      if (endStreamPos == -1) break;

      // Ajustar fin para remover salto de línea previo a endstream si existe
      int dataEnd = endStreamPos;
      if (dataEnd > dataStart && bytes[dataEnd - 1] == 0x0A) {
        dataEnd--;
        if (dataEnd > dataStart && bytes[dataEnd - 1] == 0x0D) {
          dataEnd--;
        }
      }

      // Inspeccionar diccionario previo (hasta 512 bytes antes) para detectar compresión FlateDecode
      final dictStart = (streamPos > 512) ? streamPos - 512 : 0;
      final dictText = latin1.decode(bytes.sublist(dictStart, streamPos), allowInvalid: true);
      final isFlate = dictText.contains('/FlateDecode');

      final rawStreamBytes = bytes.sublist(dataStart, dataEnd);

      if (isFlate) {
        try {
          final decompressed = ZLibDecoder().decodeBytes(rawStreamBytes);
          streams.add(latin1.decode(decompressed, allowInvalid: true));
        } catch (_) {
          // Si falla zlib, intentar interpretarlo como texto plano
          streams.add(latin1.decode(rawStreamBytes, allowInvalid: true));
        }
      } else {
        streams.add(latin1.decode(rawStreamBytes, allowInvalid: true));
      }

      cursor = endStreamPos + 9;
    }

    // Si no se encontraron bloques stream/endstream formales, intentar decodificar el cuerpo completo
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

  /// Tokeniza e interpreta operadores gráficos vectoriales en el texto del flujo PDF.
  void _parseGraphicOperators(String streamText, List<OmrLine> lines, List<OmrRect> rects) {
    final tokens = streamText.split(RegExp(r'\s+'));
    final numStack = <double>[];
    double currentX = 0.0;
    double currentY = 0.0;

    for (final token in tokens) {
      if (token.isEmpty) continue;

      final numVal = double.tryParse(token);
      if (numVal != null) {
        numStack.add(numVal);
        continue;
      }

      // Operadores de dibujo vectorial
      switch (token) {
        case 'm': // moveto (x y m)
          if (numStack.length >= 2) {
            currentY = numStack.removeLast();
            currentX = numStack.removeLast();
          }
          numStack.clear();
          break;

        case 'l': // lineto (x y l)
          if (numStack.length >= 2) {
            final y = numStack.removeLast();
            final x = numStack.removeLast();
            lines.add(OmrLine(x1: currentX, y1: currentY, x2: x, y2: y));
            currentX = x;
            currentY = y;
          }
          numStack.clear();
          break;

        case 're': // rect (x y w h re)
          if (numStack.length >= 4) {
            final h = numStack.removeLast();
            final w = numStack.removeLast();
            final y = numStack.removeLast();
            final x = numStack.removeLast();

            final absW = w.abs();
            final absH = h.abs();
            final rect = OmrRect(x: x, y: y, width: absW, height: absH);
            rects.add(rect);

            // Reconocer líneas de pentagrama dibujadas como rectángulos delgados horizontales
            if (absH <= 3.0 && absW >= 40.0) {
              lines.add(OmrLine(x1: x, y1: y, x2: x + absW, y2: y));
            }
            // Reconocer barras de compás dibujadas como rectángulos delgados verticales
            else if (absW <= 3.0 && absH >= 20.0) {
              lines.add(OmrLine(x1: x, y1: y, x2: x, y2: y + absH));
            }
          }
          numStack.clear();
          break;

        case 'c': // curveto (x1 y1 x2 y2 x3 y3 c)
          if (numStack.length >= 6) {
            final y3 = numStack.removeLast();
            final x3 = numStack.removeLast();
            numStack.removeLast(); // y2
            numStack.removeLast(); // x2
            numStack.removeLast(); // y1
            numStack.removeLast(); // x1

            // Tratar pequeñas curvas como cabezas de notas delimitadas
            final minX = currentX < x3 ? currentX : x3;
            final minY = currentY < y3 ? currentY : y3;
            final spanW = (x3 - currentX).abs();
            final spanH = (y3 - currentY).abs();

            if (spanW >= 3.0 && spanW <= 25.0 && spanH >= 3.0 && spanH <= 25.0) {
              rects.add(OmrRect(x: minX, y: minY, width: spanW, height: spanH));
            }

            currentX = x3;
            currentY = y3;
          }
          numStack.clear();
          break;

        case 'h': // closepath
        case 'S': // stroke
        case 's': // close and stroke
        case 'f': // fill
        case 'F': // fill
        case 'f*': // eofill
        case 'B': // fill and stroke
        case 'b': // close, fill and stroke
        case 'n': // end path without stroke/fill
        case 'q': // gsave
        case 'Q': // grestore
          numStack.clear();
          break;

        default:
          // Operadores desconocidos o identificadores: limpiar la pila si no es número
          if (token.length > 2) {
            numStack.clear();
          }
          break;
      }
    }
  }
}
