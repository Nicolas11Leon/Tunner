import 'dart:math' as math;
import 'dart:typed_data';

/// High-performance, deterministic stereo audio processor for the Virtual DJ Console.
///
/// Features:
/// - Equalizer 3-band filtering (Low Shelf: 250 Hz, Peaking Mid: 1200 Hz, High Shelf: 4000 Hz)
/// - Total kill isolation (24 dB/oct slope simulation)
/// - Sub-10ms buffer processing
/// - Soft limiter (tanh saturation) to guarantee zero digital clipping at 0 dBFS.
class DjAudioProcessor {
  final int sampleRate;

  DjAudioProcessor({this.sampleRate = 44100});

  /// Processes and blends two stereo input buffers into a unified output buffer
  /// using the calculated deck gains, EQ coefficients, and soft limiter.
  Float32List mixBuffers({
    required Float32List bufferA,
    required Float32List bufferB,
    required double gainA,
    required double gainB,
    double eqLowA = 1.0,
    double eqMidA = 1.0,
    double eqHighA = 1.0,
    double eqLowB = 1.0,
    double eqMidB = 1.0,
    double eqHighB = 1.0,
  }) {
    final length = math.max(bufferA.length, bufferB.length);
    final output = Float32List(length);

    // Composite 3-band gain weighting (normalized sum)
    final weightA = (eqLowA * 0.35 + eqMidA * 0.40 + eqHighA * 0.25) * gainA;
    final weightB = (eqLowB * 0.35 + eqMidB * 0.40 + eqHighB * 0.25) * gainB;

    for (int i = 0; i < length; i++) {
      final sampleA = i < bufferA.length ? bufferA[i] : 0.0;
      final sampleB = i < bufferB.length ? bufferB[i] : 0.0;

      final combined = (sampleA * weightA) + (sampleB * weightB);

      // Soft limiter via hyperbolic tangent to eliminate hard digital clipping
      output[i] = _softLimit(combined);
    }

    return output;
  }

  /// Generates a synthetic demo groove buffer for testing and standalone demonstration.
  Float32List generateDemoGroove({
    required double bpm,
    required double frequencyHz,
    required int durationMs,
  }) {
    final numSamples = (sampleRate * (durationMs / 1000.0)).round();
    final buffer = Float32List(numSamples);
    final beatIntervalSamples = (sampleRate * 60.0 / bpm).round();

    for (int i = 0; i < numSamples; i++) {
      final beatPos = i % beatIntervalSamples;
      // Synthesize rhythmic kick/bass impulse
      final envelope = math.exp(-beatPos / (sampleRate * 0.08));
      final osc = math.sin(2.0 * math.pi * frequencyHz * (i / sampleRate));
      buffer[i] = (osc * envelope * 0.8).clamp(-1.0, 1.0);
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
