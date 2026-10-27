import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/tuner/domain/mcleod_pitch_method.dart';

void main() {
  group('McleodPitchMethod Domain Tests', () {
    const sampleRate = 44100;
    const mpm = McleodPitchMethod();

    Float64List generateSineWave({
      required double frequency,
      required int length,
      double amplitude = 0.8,
      int sampleRate = 44100,
    }) {
      final buffer = Float64List(length);
      final omega = 2.0 * math.pi * frequency / sampleRate;
      for (int i = 0; i < length; i++) {
        buffer[i] = amplitude * math.sin(omega * i);
      }
      return buffer;
    }

    test('Converts PCM 16-bit little-endian bytes to normalized floats accurately', () {
      final bytes = Uint8List(4);
      final byteData = ByteData.sublistView(bytes);
      // Sample 0: +16384 (0.5)
      byteData.setInt16(0, 16384, Endian.little);
      // Sample 1: -32768 (-1.0)
      byteData.setInt16(2, -32768, Endian.little);

      final floats = McleodPitchMethod.convertPcm16BytesToFloats(bytes);
      expect(floats.length, equals(2));
      expect(floats[0], closeTo(0.5, 0.001));
      expect(floats[1], closeTo(-1.0, 0.001));
    });

    test('Rejects silence below the RMS noise gate threshold', () {
      final silenceBuffer = Float64List(2048); // All zeros
      final result = mpm.estimatePitch(silenceBuffer, sampleRate: sampleRate);

      expect(result.pitched, isFalse);
      expect(result.pitchHz, equals(0.0));
      expect(result.clarity, equals(0.0));
      expect(result.rms, equals(0.0));
    });

    test('Accurately estimates Concert Pitch A4 (440.0 Hz) with sub-cent precision', () {
      final buffer = generateSineWave(
        frequency: 440.0,
        length: 2048,
        amplitude: 0.75,
        sampleRate: sampleRate,
      );

      final result = mpm.estimatePitch(buffer, sampleRate: sampleRate);

      expect(result.pitched, isTrue);
      expect(result.pitchHz, closeTo(440.0, 0.5));
      expect(result.clarity, greaterThan(0.95));
      expect(result.rms, greaterThan(0.4));
    });

    test('Accurately estimates Middle C (C4, 261.63 Hz)', () {
      final buffer = generateSineWave(
        frequency: 261.63,
        length: 2048,
        amplitude: 0.7,
        sampleRate: sampleRate,
      );

      final result = mpm.estimatePitch(buffer, sampleRate: sampleRate);

      expect(result.pitched, isTrue);
      expect(result.pitchHz, closeTo(261.63, 0.5));
      expect(result.clarity, greaterThan(0.95));
    });

    test('Resists octave jumping when second harmonic has high energy', () {
      // Signal = Fundamental (440 Hz at 0.6) + Second Harmonic (880 Hz at 0.55)
      const length = 2048;
      final buffer = Float64List(length);
      final omega1 = 2.0 * math.pi * 440.0 / sampleRate;
      final omega2 = 2.0 * math.pi * 880.0 / sampleRate;

      for (int i = 0; i < length; i++) {
        buffer[i] = 0.6 * math.sin(omega1 * i) + 0.55 * math.sin(omega2 * i);
      }

      final result = mpm.estimatePitch(buffer, sampleRate: sampleRate);

      expect(result.pitched, isTrue);
      // MPM dynamic peak picking selects the fundamental (440 Hz) instead of jumping to 880 Hz
      expect(result.pitchHz, closeTo(440.0, 1.0));
      expect(result.clarity, greaterThan(0.8));
    });

    test('Processes raw PCM16 bytes directly via estimatePitchFromPcm16', () {
      const freq = 440.0;
      const length = 2048;
      final pcmBytes = Uint8List(length * 2);
      final byteData = ByteData.sublistView(pcmBytes);

      final omega = 2.0 * math.pi * freq / sampleRate;
      for (int i = 0; i < length; i++) {
        final sampleVal = (0.8 * math.sin(omega * i) * 32767.0).round().clamp(-32768, 32767);
        byteData.setInt16(i * 2, sampleVal, Endian.little);
      }

      final result = mpm.estimatePitchFromPcm16(pcmBytes, sampleRate: sampleRate);

      expect(result.pitched, isTrue);
      expect(result.pitchHz, closeTo(440.0, 0.5));
    });
  });
}
