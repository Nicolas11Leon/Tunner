import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/domain/pcm_wav_synthesizer.dart';

void main() {
  group('PcmWavSynthesizer Domain Unit Tests', () {
    test('buildWavHeader creates canonical 44-byte RIFF/WAVE header', () {
      const pcmBytesCount = 2000;
      final headerBytes = PcmWavSynthesizer.buildWavHeader(
        pcmDataBytes: pcmBytesCount,
        sampleRate: 44100,
        channels: 1,
        bitsPerSample: 16,
      );

      expect(headerBytes.length, 44);

      final bd = ByteData.sublistView(headerBytes);
      // "RIFF"
      expect(String.fromCharCodes(headerBytes.sublist(0, 4)), 'RIFF');
      // File size - 8 = 36 + 2000 = 2036
      expect(bd.getUint32(4, Endian.little), 36 + pcmBytesCount);
      // "WAVE"
      expect(String.fromCharCodes(headerBytes.sublist(8, 12)), 'WAVE');
      // "fmt "
      expect(String.fromCharCodes(headerBytes.sublist(12, 16)), 'fmt ');
      // Subchunk1Size = 16
      expect(bd.getUint32(16, Endian.little), 16);
      // AudioFormat = 1 (PCM)
      expect(bd.getUint16(20, Endian.little), 1);
      // NumChannels = 1
      expect(bd.getUint16(22, Endian.little), 1);
      // SampleRate = 44100
      expect(bd.getUint32(24, Endian.little), 44100);
      // ByteRate = 44100 * 1 * 2 = 88200
      expect(bd.getUint32(28, Endian.little), 88200);
      // BlockAlign = 2
      expect(bd.getUint16(32, Endian.little), 2);
      // BitsPerSample = 16
      expect(bd.getUint16(34, Endian.little), 16);
      // "data"
      expect(String.fromCharCodes(headerBytes.sublist(36, 40)), 'data');
      // Data size = 2000
      expect(bd.getUint32(40, Endian.little), pcmBytesCount);
    });

    test('generateMetronomeClickWav differentiates downbeat and off-beat durations', () {
      final downbeatWav = PcmWavSynthesizer.generateMetronomeClickWav(isDownbeat: true);
      final offbeatWav = PcmWavSynthesizer.generateMetronomeClickWav(isDownbeat: false);

      expect(downbeatWav.length, greaterThan(44));
      expect(offbeatWav.length, greaterThan(44));

      // Downbeat is 25ms, offbeat is 18ms -> downbeat buffer must be strictly larger
      expect(downbeatWav.length, greaterThan(offbeatWav.length));

      // 44100 * 0.025 = 1102.5 -> 1103 samples * 2 bytes = 2206 bytes + 44 = 2250 bytes
      expect(downbeatWav.length, 44 + (44100 * 0.025).round() * 2);
      // 44100 * 0.018 = 793.8 -> 794 samples * 2 bytes = 1588 bytes + 44 = 1632 bytes
      expect(offbeatWav.length, 44 + (44100 * 0.018).round() * 2);
    });

    test('generateSineToneWav synthesizes valid sine wave without clipping', () {
      final toneWav = PcmWavSynthesizer.generateSineToneWav(
        frequency: 440.0,
        durationSeconds: 0.1, // 100 ms
        sampleRate: 44100,
      );

      final expectedSamples = (44100 * 0.1).round();
      expect(toneWav.length, 44 + expectedSamples * 2);

      // Verify samples are non-zero and within 16-bit range
      final bd = ByteData.sublistView(toneWav, 44);
      int nonZeroCount = 0;
      for (int i = 0; i < expectedSamples; i++) {
        final sample = bd.getInt16(i * 2, Endian.little);
        expect(sample, inInclusiveRange(-32768, 32767));
        if (sample.abs() > 100) nonZeroCount++;
      }
      expect(nonZeroCount, greaterThan(expectedSamples ~/ 2));
    });

    test('generateSineToneWav supports all historical tuning frequencies', () {
      final freqs = [415.0, 432.0, 440.0, 442.0, 444.0, 466.0];
      for (final f in freqs) {
        final wav = PcmWavSynthesizer.generateSineToneWav(frequency: f, durationSeconds: 0.05);
        expect(wav.length, greaterThan(44));
        expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      }
    });

    test('generateMusicalNoteWav creates valid ADSR harmonic note buffer', () {
      const durationMs = 250;
      final noteWav = PcmWavSynthesizer.generateMusicalNoteWav(
        frequency: 440.0,
        durationMs: durationMs,
        sampleRate: 44100,
      );

      final expectedSamples = (44100 * (durationMs / 1000.0)).round();
      expect(noteWav.length, 44 + expectedSamples * 2);
      expect(String.fromCharCodes(noteWav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(noteWav.sublist(8, 12)), 'WAVE');

      // Check audio samples are non-clipped and oscillate
      final bd = ByteData.sublistView(noteWav, 44);
      int positiveCount = 0;
      int negativeCount = 0;
      for (int i = 0; i < expectedSamples; i++) {
        final sample = bd.getInt16(i * 2, Endian.little);
        expect(sample, inInclusiveRange(-32768, 32767));
        if (sample > 500) positiveCount++;
        if (sample < -500) negativeCount++;
      }
      expect(positiveCount, greaterThan(expectedSamples ~/ 4));
      expect(negativeCount, greaterThan(expectedSamples ~/ 4));
    });
  });
}
