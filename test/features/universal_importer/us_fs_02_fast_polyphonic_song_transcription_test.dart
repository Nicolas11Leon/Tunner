import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/transcription/domain/audio_to_score_transcription_engine.dart';
import 'package:tunner/features/universal_importer/data/universal_score_importer_service.dart';

Uint8List _encodePcm16MonoWav(Float64List samples, {int sampleRate = 44100}) {
  final dataSize = samples.length * 2;
  final totalSize = 44 + dataSize;
  final bytes = Uint8List(totalSize);
  final header = ByteData.sublistView(bytes);

  // 'RIFF'
  bytes[0] = 0x52;
  bytes[1] = 0x49;
  bytes[2] = 0x46;
  bytes[3] = 0x46;
  header.setUint32(4, totalSize - 8, Endian.little);
  // 'WAVE'
  bytes[8] = 0x57;
  bytes[9] = 0x41;
  bytes[10] = 0x56;
  bytes[11] = 0x45;
  // 'fmt '
  bytes[12] = 0x66;
  bytes[13] = 0x6D;
  bytes[14] = 0x74;
  bytes[15] = 0x20;
  header.setUint32(16, 16, Endian.little); // PCM chunk size
  header.setUint16(20, 1, Endian.little); // PCM integer
  header.setUint16(22, 1, Endian.little); // Mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  // 'data'
  bytes[36] = 0x64;
  bytes[37] = 0x61;
  bytes[38] = 0x74;
  bytes[39] = 0x61;
  header.setUint32(40, dataSize, Endian.little);

  for (int i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    final intVal = (clamped * 32767.0).round().clamp(-32768, 32767);
    header.setInt16(44 + i * 2, intVal, Endian.little);
  }

  return bytes;
}

Uint8List _buildPolyphonicSongWav({
  required int durationSeconds,
  int sampleRate = 44100,
}) {
  final totalSamples = durationSeconds * sampleRate;
  final samples = Float64List(totalSamples);
  final rng = math.Random(42);

  const leadFreqs = [440.0, 493.88, 523.25, 587.33, 659.25];
  const bassFreqs = [110.0, 123.47, 130.81, 146.83];

  for (int i = 0; i < totalSamples; i++) {
    final t = i / sampleRate;
    final sec = i ~/ sampleRate;
    final leadHz = leadFreqs[sec % leadFreqs.length];
    final bassHz = bassFreqs[(sec ~/ 2) % bassFreqs.length];

    // Mezcla polifónica: voz/melodía + acorde armónico + bajo + percusión rítmica
    final lead = 0.30 * math.sin(2.0 * math.pi * leadHz * t);
    final chordThird = 0.20 * math.sin(2.0 * math.pi * (leadHz * 1.25) * t);
    final chordFifth = 0.20 * math.sin(2.0 * math.pi * (leadHz * 1.5) * t);
    final bass = 0.22 * math.sin(2.0 * math.pi * bassHz * t);

    // Golpe percusivo determinista cada 0.5 s (120 BPM)
    final beatPhase = t % 0.5;
    final percussion = beatPhase < 0.04 ? (0.25 * (rng.nextDouble() * 2.0 - 1.0)) : 0.0;

    samples[i] = lead + chordThird + chordFifth + bass + percussion;
  }

  return _encodePcm16MonoWav(samples, sampleRate: sampleRate);
}

void main() {
  group('US-FS-02: Motor de Transcripción Rápida Polifónico-Tolerante con 4 Stems', () {
    const importer = UniversalScoreImporterService();

    test(
      'transcribe un WAV polifónico de 60 segundos (2,646,000 muestras) en < 800 ms con notas reales y 4 stems',
      () async {
        final wavBytes = _buildPolyphonicSongWav(durationSeconds: 60, sampleRate: 44100);

        final stopwatch = Stopwatch()..start();
        final result = await importer.parseScoreData(
          bytes: wavBytes,
          fileName: 'cancion_polifonica_larga.wav',
        );
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(800),
          reason: 'La transcripción acotada a <= 480 ventanas debe completarse en < 800 ms '
              '(tomó ${stopwatch.elapsedMilliseconds} ms).',
        );
        expect(result.format, equals('AudioWAV'));
        expect(result.totalNotes, greaterThan(0));
        expect(result.totalMeasures, greaterThanOrEqualTo(1));

        final pkg = result.package;
        expect(pkg.tracks.length, equals(4));
        expect(pkg.stemScores.isNotEmpty, isTrue);
        expect(pkg.stemScores.length, equals(4));
        expect(pkg.composer, equals('Transcripción Automática Tunner'));
      },
    );

    test(
      'activa el extractor de respaldo ZCR-RMS cuando MPM rechaza todas las ventanas en mezcla densa',
      () {
        const strictEngine = AudioToScoreTranscriptionEngine(
          minClarity: 0.99, // Fuerza rechazo en MPM sobre mezcla polifónica + ruido
        );
        final wavBytes = _buildPolyphonicSongWav(durationSeconds: 4, sampleRate: 44100);

        final score = strictEngine.transcribeAudioFile(
          audioBytes: wavBytes,
          title: 'Mezcla Densa',
          bpm: 120,
        );

        final pitchedNotes = score.measures
            .expand((m) => m.notes)
            .where((n) => !n.isRest)
            .toList();
        expect(pitchedNotes, isNotEmpty);
      },
    );

    test('preserva silencios puros sin inventar notas fantasmas', () {
      final silentSamples = Float64List(44100 * 2);
      final silentWav = _encodePcm16MonoWav(silentSamples, sampleRate: 44100);

      final result = importer.transcribeAudioToScoreResult(
        bytes: silentWav,
        fileName: 'silencio.wav',
      );

      expect(result.totalNotes, equals(0));
      expect(result.package.tracks.length, equals(4));
    });

    test('mantiene precisión exacta de tono puro (La4 = 440 Hz) con minClarity = 0.32', () {
      const sampleRate = 44100;
      final samples = Float64List(sampleRate * 2);
      for (int i = 0; i < samples.length; i++) {
        samples[i] = 0.7 * math.sin(2.0 * math.pi * 440.0 * (i / sampleRate));
      }
      final toneWav = _encodePcm16MonoWav(samples, sampleRate: sampleRate);

      final result = importer.transcribeAudioToScoreResult(
        bytes: toneWav,
        fileName: 'la4_puro.wav',
        bpm: 128,
        timeSignature: TimeSignature.commonTime44,
      );

      final pitchedNotes = result.package.score.measures
          .expand((m) => m.notes)
          .where((n) => !n.isRest)
          .toList();

      expect(pitchedNotes, isNotEmpty);
      expect(pitchedNotes.first.noteName, equals('La4'));
      expect(result.package.defaultBpm, equals(128));
      expect(result.package.score.baseBpm, equals(128));
      expect(result.package.tracks.length, equals(4));
      expect(result.package.stemScores.length, equals(4));
    });
  });
}
