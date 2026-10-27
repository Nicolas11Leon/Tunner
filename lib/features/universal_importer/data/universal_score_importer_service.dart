import 'dart:typed_data';
import '../domain/i_score_parser_service.dart';
import '../domain/parsed_score_result_entity.dart';
import 'musicxml_score_parser.dart';
import 'midi_score_parser.dart';

/// Servicio orquestador del dominio para ingesta y decodificación universal de partituras.
/// Inspecciona extensiones y firmas binarias para delegar al parser correspondiente.
class UniversalScoreImporterService implements IScoreParserService {
  final MusicXmlScoreParser _musicXmlParser;
  final MidiScoreParser _midiParser;

  const UniversalScoreImporterService({
    MusicXmlScoreParser musicXmlParser = const MusicXmlScoreParser(),
    MidiScoreParser midiParser = const MidiScoreParser(),
  })  : _musicXmlParser = musicXmlParser,
        _midiParser = midiParser;

  @override
  bool canParse(String fileName, Uint8List bytes) {
    return _musicXmlParser.canParse(fileName, bytes) || _midiParser.canParse(fileName, bytes);
  }

  @override
  Future<ParsedScoreResult> parseScoreData({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw const FormatException('El archivo provisto está vacío.');
    }

    if (_midiParser.canParse(fileName, bytes)) {
      return _midiParser.parseScoreData(bytes: bytes, fileName: fileName);
    }

    if (_musicXmlParser.canParse(fileName, bytes)) {
      return _musicXmlParser.parseScoreData(bytes: bytes, fileName: fileName);
    }

    // Si la extensión no coincide, intentar autodetección por contenido
    try {
      return await _musicXmlParser.parseScoreData(bytes: bytes, fileName: fileName);
    } catch (_) {
      try {
        return await _midiParser.parseScoreData(bytes: bytes, fileName: fileName);
      } catch (_) {
        throw FormatException(
          'Formato no reconocido para "$fileName". Tunner soporta MusicXML (.musicxml, .xml) y MIDI (.mid, .midi).',
        );
      }
    }
  }
}
