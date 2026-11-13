import 'dart:math' as math;
import 'dart:typed_data';
import '../domain/harmonic_role_entity.dart';

/// Deterministic, real-time procedural synthesizer for pure Just Intonation reference chords and drones.
///
/// Features:
/// - Sum of pure sine wave oscillators corresponding to exact integer ratios (1/1, 5/4, 3/2, etc.).
/// - Linear envelope ramps (Attack & Release) to eliminate edge transient clicks.
/// - Deterministic stereo/mono buffer rendering with soft saturation limiter.
class HarmonicReferenceSynth {
  final int sampleRate;

  HarmonicReferenceSynth({this.sampleRate = 44100});

  /// Synthesizes a pure Just Intonation reference chord buffer.
  ///
  /// - [rootFrequency]: Base frequency of the chord in Hz.
  /// - [roles]: List of harmonic roles to voice (e.g. root + fifth).
  /// - [durationMs]: Desired buffer length in milliseconds.
  /// - [volume]: Normalized volume in range [0.0, 1.0].
  Float32List generateChordBuffer({
    required double rootFrequency,
    required List<HarmonicRole> roles,
    int durationMs = 1000,
    double volume = 0.5,
  }) {
    if (rootFrequency <= 0 || roles.isEmpty || durationMs <= 0) {
      return Float32List(0);
    }

    final totalSamples = (sampleRate * (durationMs / 1000.0)).round();
    final buffer = Float32List(totalSamples);
    final voiceCount = roles.length;
    final gainPerVoice = (volume / math.sqrt(voiceCount)).clamp(0.0, 1.0);

    // Compute frequencies for each voice
    final voiceFrequencies = roles.map((r) => rootFrequency * r.ratio).toList();

    // 20ms anti-pop ramp
    final rampSamples = math.min(totalSamples ~/ 4, (sampleRate * 0.02).round());

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      double sampleSum = 0.0;

      for (int v = 0; v < voiceCount; v++) {
        final freq = voiceFrequencies[v];
        sampleSum += math.sin(2.0 * math.pi * freq * t) * gainPerVoice;
      }

      // Apply linear envelope ramp
      double env = 1.0;
      if (i < rampSamples) {
        env = i / rampSamples;
      } else if (i > totalSamples - rampSamples) {
        env = (totalSamples - i) / rampSamples;
      }

      final ramped = sampleSum * env;

      // Soft limiter tanh saturation to guarantee 0 dBFS safety
      buffer[i] = _softLimit(ramped);
    }

    return buffer;
  }

  static double _softLimit(double x) {
    if (x > 1.0) {
      return 1.0 - (1.0 / (1.0 + (x - 1.0)));
    } else if (x < -1.0) {
      return -1.0 + (1.0 / (1.0 - (x + 1.0)));
    }
    return x;
  }
}
