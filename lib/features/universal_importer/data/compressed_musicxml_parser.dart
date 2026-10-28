import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../domain/i_score_parser_service.dart';
import '../domain/parsed_score_result_entity.dart';
import 'musicxml_score_parser.dart';

/// Decodificador especializado para partituras Compressed MusicXML (.mxl).
/// Descomprime contenedores ZIP en memoria y extrae el archivo raíz según META-INF/container.xml.
class CompressedMusicXmlParser implements IScoreParserService {
  final MusicXmlScoreParser _musicXmlParser;

  const CompressedMusicXmlParser({
    MusicXmlScoreParser musicXmlParser = const MusicXmlScoreParser(),
  }) : _musicXmlParser = musicXmlParser;

  @override
  bool canParse(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mxl')) {
      return true;
    }
    // Firma mágica de archivo ZIP: PK\x03\x04
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
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
      throw const FormatException('El archivo .mxl está vacío.');
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw FormatException('No se pudo descomprimir el archivo .mxl: $e');
    }

    // 1. Intentar localizar el manifiesto META-INF/container.xml
    String? rootFilePath;
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile != null) {
      try {
        final containerContent = utf8.decode(containerFile.content as List<int>);
        final doc = XmlDocument.parse(containerContent);
        final rootFiles = doc.findAllElements('rootfile');
        for (final rf in rootFiles) {
          final fullPath = rf.getAttribute('full-path');
          if (fullPath != null && fullPath.isNotEmpty) {
            rootFilePath = fullPath;
            break;
          }
        }
      } catch (_) {
        // Fallback a búsqueda heurística de archivo XML
      }
    }

    // 2. Si se obtuvo la ruta del archivo raíz, buscarlo en el archivo comprimido
    ArchiveFile? targetScoreFile;
    if (rootFilePath != null) {
      targetScoreFile = archive.findFile(rootFilePath);
    }

    // 3. Heurística de respaldo: primer archivo .xml o .musicxml que no esté en META-INF
    if (targetScoreFile == null) {
      for (final file in archive.files) {
        if (!file.name.startsWith('META-INF/') &&
            (file.name.toLowerCase().endsWith('.xml') ||
                file.name.toLowerCase().endsWith('.musicxml'))) {
          targetScoreFile = file;
          break;
        }
      }
    }

    if (targetScoreFile == null) {
      throw FormatException(
        'El archivo .mxl "$fileName" no contiene una partitura MusicXML válida.',
      );
    }

    final scoreBytes = Uint8List.fromList(targetScoreFile.content as List<int>);
    return _musicXmlParser.parseScoreData(
      bytes: scoreBytes,
      fileName: targetScoreFile.name,
    );
  }
}
