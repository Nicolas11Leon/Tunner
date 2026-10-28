import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/transcription/domain/audio_to_score_transcription_engine.dart';

Uint8List _generateWavPcm16({
  required List<({double freqHz, double durationSec})> tones,
  int sampleRate = 44100,
}) {
  final totalSamples = tones.fold<int>(0, (sum, t) => sum + (t.durationSec * sampleRate).round());
  final dataSize = totalSamples * 2; // 16-bit mono = 2 bytes per sample
  final totalFileSize = 36 + dataSize;

  final bytes = Uint8List(44 + dataSize);
  final byteData = ByteData.sublistView(bytes);

  // RIFF header
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  byteData.setUint32(4, totalFileSize, Endian.little);
  bytes.setRange(8, 12, 'WAVE'.codeUnits);

  // fmt chunk
  bytes.setRange(12, 16, 'fmt '.codeUnits);
  byteData.setUint32(16, 16, Endian.little); // chunk size 16
  byteData.setUint16(20, 1, Endian.little); // PCM format 1
  byteData.setUint16(22, 1, Endian.little); // 1 channel (mono)
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  byteData.setUint16(32, 2, Endian.little); // block align
  byteData.setUint16(34, 16, Endian.little); // bits per sample

  // data chunk
  bytes.setRange(36, 40, 'data'.codeUnits);
  byteData.setUint32(40, dataSize, Endian.little);

  int sampleOffset = 0;
  for (final tone in tones) {
    final toneSamples = (tone.durationSec * sampleRate).round();
    final angularFreq = 2.0 * math.pi * tone.freqHz / sampleRate;

    for (int i = 0; i < toneSamples; i++) {
      final sampleFloat = (tone.freqHz > 0) ? math.sin(angularFreq * i) * 0.75 : 0.0;
      final sampleInt16 = (sampleFloat * 32767).clamp(-32768, 32767).toInt();
      byteData.setInt16(44 + (sampleOffset + i) * 2, sampleInt16, Endian.little);
    }
    sampleOffset += toneSamples;
  }

  return bytes;
}

void main() {
  group('AudioToScoreTranscriptionEngine Tests', () {
    const engine = AudioToScoreTranscriptionEngine(
      windowSize: 2048,
      hopSize: 512,
      minClarity: 0.60,
      silenceRms: 0.005,
    );

    test('Transcribes pure A4 (440 Hz) and C5 (523.25 Hz) tones into structured score', () {
      // 0.6 seconds of A4 (440 Hz), then 0.6 seconds of C5 (523.25 Hz) at 120 BPM
      final wavData = _generateWavPcm16(tones: [
        (freqHz: 440.0, durationSec: 0.6),
        (freqHz: 523.25, durationSec: 0.6),
      ]);

      final score = engine.transcribeAudioFile(
        audioBytes: wavData,
        title: 'Grabación de Estudio',
        bpm: 120,
      );

      expect(score.title, equals('Grabación de Estudio'));
      expect(score.measures, isNotEmpty);

      // Verify that pitched notes were detected
      final allNotes = score.measures.expand((m) => m.notes).toList();
      final pitchedNotes = allNotes.where((n) => !n.isRest).toList();

      expect(pitchedNotes.length, greaterThanOrEqualTo(2));
      // First detected pitch should be La4 (A4)
      expect(pitchedNotes.first.noteName, contains('La4'));
      // Second distinct pitch should be Do5 (C5)
      expect(pitchedNotes.any((n) => n.noteName.contains('Do5')), isTrue);
    });

    test('Empty audio buffer returns single empty measure', () {
      final score = engine.transcribeAudioFile(
        audioBytes: Uint8List(0),
        title: 'Vacio',
      );

      expect(score.measures.length, equals(1));
      expect(score.measures.first.notes.every((n) => n.isRest), isTrue);
    });

    test('Complete silence generates rest notes', () {
      final wavData = _generateWavPcm16(tones: [
        (freqHz: 0.0, durationSec: 0.5),
      ]);

      final score = engine.transcribeAudioFile(
        audioBytes: wavData,
        title: 'Silencio',
      );

      expect(score.measures, isNotEmpty);
      final allNotes = score.measures.expand((m) => m.notes).toList();
      // Should only contain rests or be empty
      expect(allNotes.every((n) => n.isRest), isTrue);
    });
  });
}
