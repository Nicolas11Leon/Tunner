import 'dart:typed_data';
import '../../mixer/domain/mixer_track_entity.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../../transcription/domain/audio_to_score_transcription_engine.dart';
import '../domain/i_score_parser_service.dart';
import '../domain/parsed_score_result_entity.dart';
import 'abc_score_parser.dart';
import 'compressed_musicxml_parser.dart';
import 'midi_score_parser.dart';
import 'musicxml_score_parser.dart';

/// Servicio orquestador del dominio para ingesta y decodificación universal de música y partituras.
/// Inspecciona extensiones y firmas binarias para delegar al parser o transcriptor correspondiente:
/// - MusicXML (.musicxml, .xml)
/// - Compressed MusicXML (.mxl)
/// - MIDI (.mid, .midi)
/// - ABC Notation (.abc)
/// - Audio Digital (.wav) para transcripción offline a partitura
class UniversalScoreImporterService implements IScoreParserService {
  final MusicXmlScoreParser _musicXmlParser;
  final CompressedMusicXmlParser _compressedMusicXmlParser;
  final MidiScoreParser _midiParser;
  final AbcScoreParser _abcParser;
  final AudioToScoreTranscriptionEngine _audioTranscriber;

  const UniversalScoreImporterService({
    MusicXmlScoreParser musicXmlParser = const MusicXmlScoreParser(),
    CompressedMusicXmlParser? compressedMusicXmlParser,
    MidiScoreParser midiParser = const MidiScoreParser(),
    AbcScoreParser abcParser = const AbcScoreParser(),
    AudioToScoreTranscriptionEngine audioTranscriber = const AudioToScoreTranscriptionEngine(),
  })  : _musicXmlParser = musicXmlParser,
        _compressedMusicXmlParser = compressedMusicXmlParser ?? const CompressedMusicXmlParser(),
        _midiParser = midiParser,
        _abcParser = abcParser,
        _audioTranscriber = audioTranscriber;

  @override
  bool canParse(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    return _compressedMusicXmlParser.canParse(fileName, bytes) ||
        _abcParser.canParse(fileName, bytes) ||
        _midiParser.canParse(fileName, bytes) ||
        _musicXmlParser.canParse(fileName, bytes) ||
        lower.endsWith('.wav') ||
        _isWavHeader(bytes);
  }

  @override
  Future<ParsedScoreResult> parseScoreData({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw const FormatException('El archivo provisto está vacío.');
    }

    // 1. Compressed MusicXML (.mxl)
    if (_compressedMusicXmlParser.canParse(fileName, bytes)) {
      try {
        return await _compressedMusicXmlParser.parseScoreData(bytes: bytes, fileName: fileName);
      } catch (_) {
        // Continuar con otros parsers si falla
      }
    }

    // 2. MIDI (.mid, .midi)
    if (_midiParser.canParse(fileName, bytes)) {
      return _midiParser.parseScoreData(bytes: bytes, fileName: fileName);
    }

    // 3. ABC Notation (.abc)
    if (_abcParser.canParse(fileName, bytes)) {
      return _abcParser.parseScoreData(bytes: bytes, fileName: fileName);
    }

    // 4. MusicXML plano (.musicxml, .xml)
    if (_musicXmlParser.canParse(fileName, bytes)) {
      return _musicXmlParser.parseScoreData(bytes: bytes, fileName: fileName);
    }

    // 5. Audio Digital (WAV) para Transcripción Offline
    if (fileName.toLowerCase().endsWith('.wav') || _isWavHeader(bytes)) {
      return transcribeAudioToScoreResult(bytes: bytes, fileName: fileName);
    }

    // Autodetección heurística por contenido
    try {
      return await _musicXmlParser.parseScoreData(bytes: bytes, fileName: fileName);
    } catch (_) {
      try {
        return await _midiParser.parseScoreData(bytes: bytes, fileName: fileName);
      } catch (_) {
        try {
          return await _abcParser.parseScoreData(bytes: bytes, fileName: fileName);
        } catch (_) {
          throw FormatException(
            'Formato no reconocido para "$fileName". Tunner soporta MusicXML (.mxl, .musicxml, .xml), MIDI (.mid, .midi), ABC (.abc) y Audio WAV (.wav).',
          );
        }
      }
    }
  }

  /// Transcribe un archivo de audio directamente a un [ParsedScoreResult].
  ParsedScoreResult transcribeAudioToScoreResult({
    required Uint8List bytes,
    required String fileName,
    int bpm = 120,
  }) {
    final title = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    final score = _audioTranscriber.transcribeAudioFile(
      audioBytes: bytes,
      title: title,
      bpm: bpm,
    );

    int totalNotes = 0;
    for (final m in score.measures) {
      totalNotes += m.notes.where((n) => !n.isRest).length;
    }

    final track = AudioTrack(
      id: 'audio_transcribed_track',
      title: title,
      instrumentIcon: 'mic',
      volume: 1.0,
    );

    final pkg = SongPackage(
      id: 'transcribed_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      composer: 'Transcripción Automática Tunner',
      genre: MusicGenre.classical,
      difficulty: SongDifficulty.intermediate,
      defaultBpm: bpm,
      tracks: [track],
      score: score,
    );

    return ParsedScoreResult(
      package: pkg,
      format: 'AudioWAV',
      totalMeasures: score.measures.length,
      totalNotes: totalNotes,
      warnings: const ['Partitura transcrita automáticamente desde audio monofónico (MPM).'],
    );
  }

  bool _isWavHeader(Uint8List bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 && // 'RIFF'
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45; // 'WAVE'
  }
}
