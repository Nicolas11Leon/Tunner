import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/domain/pcm_wav_synthesizer.dart';
import 'package:tunner/features/mixer/domain/mixer_track_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
import 'package:tunner/features/transcription/domain/audio_to_score_transcription_engine.dart';
import 'package:tunner/features/transcription/domain/live_transcription_engine.dart';
import 'package:tunner/features/transcription/domain/polyphonic_transcription_engine.dart';
import 'package:tunner/features/universal_importer/data/universal_score_importer_service.dart';

SongPackage _emptyPackage({int bpm = 120, TimeSignature ts = TimeSignature.commonTime44}) {
  return SongPackage(
    id: 'test_pkg',
    title: 'Test Transcription',
    composer: 'Test',
    genre: MusicGenre.classical,
    difficulty: SongDifficulty.beginner,
    defaultBpm: bpm,
    score: HierarchicalScore(
      title: 'Test Transcription',
      baseBpm: bpm,
      measures: [
        MeasureEntity(index: 0, timeSignature: ts, notes: const []),
      ],
    ),
    tracks: const [
      AudioTrack(id: 'voice', title: 'Voz', instrumentIcon: 'voice'),
    ],
  );
}

Uint8List _buildFloat32Wav(Float32List samples, {int sampleRate = 44100}) {
  final pcmBytes = ByteData(samples.length * 4);
  for (int i = 0; i < samples.length; i++) {
    pcmBytes.setFloat32(i * 4, samples[i], Endian.little);
  }
  final header = ByteData(44);
  header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46);
  header.setUint32(4, 36 + pcmBytes.lengthInBytes, Endian.little);
  header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45);
  header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 3, Endian.little); // IEEE Float
  header.setUint16(22, 1, Endian.little); // Mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 4, Endian.little);
  header.setUint16(32, 4, Endian.little);
  header.setUint16(34, 32, Endian.little);
  header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61);
  header.setUint32(40, pcmBytes.lengthInBytes, Endian.little);

  final out = BytesBuilder(copy: false);
  out.add(header.buffer.asUint8List());
  out.add(pcmBytes.buffer.asUint8List());
  return out.toBytes();
}

void main() {
  group('US-4.4 Real Musical Clock, Rests and Multi-Bit WAV Transcription Tests', () {
    test('LiveTranscriptionEngine maps 500ms at 120 BPM (25 frames of 20ms) to 4 sub-ticks (quarter note), not 16', () {
      final engine = LiveTranscriptionEngine(minFramesForOnset: 2, defaultFrameDurationMs: 20.0);
      engine.start(initialPackage: _emptyPackage(bpm: 120));

      // 25 frames de 20ms = 500ms -> a 120 BPM (125ms/tick) son exactamente 4 ticks (negra)
      for (int i = 0; i < 25; i++) {
        engine.processPitchFrame(frequencyHz: 440.0, clarity: 0.95, noteName: 'A4');
      }

      // Silencio de 500ms (25 frames de 20ms) -> dispara cierre de A4 e inicia silencio
      for (int i = 0; i < 25; i++) {
        engine.processPitchFrame(frequencyHz: 0.0, clarity: 0.1, noteName: '--');
      }

      // Siguiente nota C5 por 500ms (consolida el silencio previo de 4 ticks)
      for (int i = 0; i < 25; i++) {
        engine.processPitchFrame(frequencyHz: 523.25, clarity: 0.95, noteName: 'C5');
      }

      final result = engine.stop()!;
      final notes = result.score.measures.first.notes;

      expect(notes.length, greaterThanOrEqualTo(3));
      expect(notes[0].noteName, equals('A4'));
      expect(notes[0].durationTicks, equals(4), reason: '500 ms a 120 BPM debe cuantizarse a negra (4 ticks)');

      expect(notes[1].isRest, isTrue, reason: 'La pausa de 500 ms debe insertarse como silencio');
      expect(notes[1].durationTicks, equals(4));

      expect(notes[2].noteName, equals('C5'));
      expect(notes[2].durationTicks, equals(4));
    });

    test('PolyphonicTranscriptionEngine splits chords crossing barline and inserts rests', () {
      final engine = PolyphonicTranscriptionEngine(minFramesForOnset: 2, defaultFrameDurationMs: 20.0);
      // Compas 3/4 (12 ticks), empezando en tick 10
      engine.start(
        initialPackage: _emptyPackage(bpm: 120, ts: TimeSignature.waltzTime34),
        startTick: 10,
      );

      // Acorde de 500ms = 4 ticks -> 2 ticks en compas 0 (10..12) y 2 ticks en compas 1 (0..2)
      for (int i = 0; i < 25; i++) {
        engine.processPolyphonicFrame(noteNames: ['C4', 'E4', 'G4'], energyRms: 0.3);
      }

      final result = engine.stop()!;
      expect(result.score.measures.length, greaterThanOrEqualTo(2));

      final m0Notes = result.score.measures[0].notes.where((n) => !n.isRest).toList();
      final m1Notes = result.score.measures[1].notes.where((n) => !n.isRest).toList();

      expect(m0Notes.length, equals(3));
      expect(m0Notes.every((n) => n.startTick == 10 && n.durationTicks == 2), isTrue);

      expect(m1Notes.length, equals(3));
      expect(m1Notes.every((n) => n.startTick == 0 && n.durationTicks == 2), isTrue);
    });

    test('AudioToScoreTranscriptionEngine decodes 32-bit IEEE Float WAV, detects 27.5 Hz A0 and respects TimeSignature', () {
      const sampleRate = 44100;
      const durationSec = 0.6;
      final totalSamples = (sampleRate * durationSec).round();
      final floatSamples = Float32List(totalSamples);

      // Generar onda senoidal pura de A0 = 27.5 Hz
      for (int i = 0; i < totalSamples; i++) {
        floatSamples[i] = 0.8 * math.sin(2.0 * math.pi * 27.5 * i / sampleRate);
      }

      final wavBytes = _buildFloat32Wav(floatSamples, sampleRate: sampleRate);
      const engine = AudioToScoreTranscriptionEngine(minClarity: 0.60);

      final score = engine.transcribeAudioFile(
        audioBytes: wavBytes,
        title: 'A0 Float32 Test',
        bpm: 120,
        timeSignature: TimeSignature.waltzTime34,
      );

      expect(score.measures, isNotEmpty);
      expect(score.measures.first.timeSignature.numerator, equals(3));
      expect(score.measures.first.timeSignature.denominator, equals(4));

      final pitchedNotes = score.measures.first.notes.where((n) => !n.isRest).toList();
      expect(pitchedNotes, isNotEmpty, reason: 'Debe detectar A0 = 27.5 Hz sin descartarlo');
      expect(pitchedNotes.first.noteName, equals('La0'));
    });

    test('AudioToScoreTranscriptionEngine also decodes standard 16-bit WAV via PcmWavSynthesizer', () {
      final wav16 = PcmWavSynthesizer.generateMusicalNoteWav(frequency: 440.0, durationMs: 500);
      const engine = AudioToScoreTranscriptionEngine();

      final score = engine.transcribeAudioFile(audioBytes: wav16, bpm: 120);
      final pitchedNotes = score.measures.first.notes.where((n) => !n.isRest).toList();
      expect(pitchedNotes, isNotEmpty);
      expect(pitchedNotes.first.noteName, equals('La4'));
    });

    test('LiveTranscriptionEngine soporta timestampMs y bpm override en start()', () {
      final engine = LiveTranscriptionEngine(minFramesForOnset: 2);
      engine.start(initialPackage: _emptyPackage(bpm: 120), bpm: 60);

      // A 60 BPM, 1 sub-tick = 250 ms; 1000 ms = 4 ticks (negra)
      engine.processPitchFrame(frequencyHz: 440.0, clarity: 0.95, noteName: 'La4', timestampMs: 1000.0);
      engine.processPitchFrame(frequencyHz: 440.0, clarity: 0.95, noteName: 'La4', timestampMs: 1500.0);
      engine.processPitchFrame(frequencyHz: 440.0, clarity: 0.95, noteName: 'La4', timestampMs: 2000.0);
      final finalPkg = engine.stop();

      expect(finalPkg, isNotNull);
      final notes = finalPkg!.score.measures.first.notes.where((n) => !n.isRest).toList();
      expect(notes, isNotEmpty);
      expect(notes.first.durationTicks, equals(4));

      // Verificar tambien PolyphonicTranscriptionEngine con bpm override = 60
      final polyEngine = PolyphonicTranscriptionEngine(minFramesForOnset: 2);
      polyEngine.start(initialPackage: _emptyPackage(bpm: 120), bpm: 60);
      polyEngine.processPolyphonicFrame(noteNames: const ['Do4', 'Mi4'], timestampMs: 1000.0);
      polyEngine.processPolyphonicFrame(noteNames: const ['Do4', 'Mi4'], timestampMs: 1500.0);
      polyEngine.processPolyphonicFrame(noteNames: const ['Do4', 'Mi4'], timestampMs: 2000.0);
      final polyPkg = polyEngine.stop();
      expect(polyPkg, isNotNull);
      final polyNotes = polyPkg!.score.measures.first.notes.where((n) => !n.isRest).toList();
      expect(polyNotes, isNotEmpty);
      expect(polyNotes.first.durationTicks, equals(4));
    });

    test('AudioToScoreTranscriptionEngine decodifica WAV 64-bit IEEE Float (0xFFFE extensible)', () {
      const sampleRate = 16000;
      const numSamples = 12000;
      final samples = List<double>.generate(
        numSamples,
        (i) => 0.7 * math.sin(2.0 * math.pi * 440.0 * i / sampleRate),
      );
      final dataSize = numSamples * 8;
      // WAVEFORMATEXTENSIBLE fmt chunk size = 40 (8 header + 40 body = 48)
      final totalBytes = 12 + 48 + 8 + dataSize;
      final bd = ByteData(totalBytes);
      bd.setUint8(0, 0x52); bd.setUint8(1, 0x49); bd.setUint8(2, 0x46); bd.setUint8(3, 0x46);
      bd.setUint32(4, totalBytes - 8, Endian.little);
      bd.setUint8(8, 0x57); bd.setUint8(9, 0x41); bd.setUint8(10, 0x56); bd.setUint8(11, 0x45);
      // fmt
      bd.setUint8(12, 0x66); bd.setUint8(13, 0x6D); bd.setUint8(14, 0x74); bd.setUint8(15, 0x20);
      bd.setUint32(16, 40, Endian.little);
      bd.setUint16(20, 0xFFFE, Endian.little); // WAVEFORMATEXTENSIBLE
      bd.setUint16(22, 1, Endian.little);
      bd.setUint32(24, sampleRate, Endian.little);
      bd.setUint32(28, sampleRate * 8, Endian.little);
      bd.setUint16(32, 8, Endian.little);
      bd.setUint16(34, 64, Endian.little); // 64-bit
      bd.setUint16(36, 22, Endian.little); // cbSize
      bd.setUint16(38, 64, Endian.little); // wValidBitsPerSample
      bd.setUint32(40, 4, Endian.little);  // dwChannelMask
      bd.setUint16(44, 3, Endian.little);  // SubFormat = 3 (IEEE Float)
      // data
      bd.setUint8(60, 0x64); bd.setUint8(61, 0x61); bd.setUint8(62, 0x74); bd.setUint8(63, 0x61);
      bd.setUint32(64, dataSize, Endian.little);
      for (int i = 0; i < numSamples; i++) {
        bd.setFloat64(68 + i * 8, samples[i], Endian.little);
      }

      const engine = AudioToScoreTranscriptionEngine();
      final score = engine.transcribeAudioFile(audioBytes: bd.buffer.asUint8List(), bpm: 120);
      final pitched = score.measures.first.notes.where((n) => !n.isRest).toList();
      expect(pitched, isNotEmpty);
      expect(pitched.first.noteName, equals('La4'));
    });

    test('UniversalScoreImporterService.transcribeAudioToScoreResult respeta timeSignature opcional', () {
      final wav16 = PcmWavSynthesizer.generateMusicalNoteWav(frequency: 440.0, durationMs: 500);
      const importer = UniversalScoreImporterService();
      final result = importer.transcribeAudioToScoreResult(
        bytes: wav16,
        fileName: 'valse_test.wav',
        bpm: 120,
        timeSignature: TimeSignature.waltzTime34,
      );
      expect(result.package.score.measures.first.timeSignature.numerator, 3);
      expect(result.package.score.measures.first.timeSignature.denominator, 4);
    });
  });
}
