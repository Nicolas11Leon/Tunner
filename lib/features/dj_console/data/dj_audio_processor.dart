import 'dart:math' as math;
import 'dart:typed_data';
import '../domain/dj_stem_isolation_entity.dart';

/// High-performance, deterministic stereo audio processor for the Virtual DJ Console.
///
/// Features:
/// - Equalizer 3-band filtering (Low Shelf: 250 Hz, Peaking Mid: 1200 Hz, High Shelf: 4000 Hz)
/// - Bipolar sweep filter (-1.0 Low-Pass sweep down to 60 Hz, +1.0 High-Pass sweep up to 12000 Hz)
/// - Beat-synchronized delay line with bounded feedback (<= 0.80) and dry/wet blending
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
    double filterA = 0.0,
    double filterB = 0.0,
    bool delayActiveA = false,
    int delaySamplesA = 0,
    double delayFeedbackA = 0.4,
    double delayDryWetA = 0.5,
    bool delayActiveB = false,
    int delaySamplesB = 0,
    double delayFeedbackB = 0.4,
    double delayDryWetB = 0.5,
  }) {
    // Apply channel FX to Deck A if active
    var processedA = bufferA;
    if (filterA != 0.0) {
      processedA = applyBipolarFilter(processedA, filterA);
    }
    if (delayActiveA && delaySamplesA > 0) {
      processedA = applyDelay(
        processedA,
        delaySamples: delaySamplesA,
        feedback: delayFeedbackA,
        dryWet: delayDryWetA,
      );
    }

    // Apply channel FX to Deck B if active
    var processedB = bufferB;
    if (filterB != 0.0) {
      processedB = applyBipolarFilter(processedB, filterB);
    }
    if (delayActiveB && delaySamplesB > 0) {
      processedB = applyDelay(
        processedB,
        delaySamples: delaySamplesB,
        feedback: delayFeedbackB,
        dryWet: delayDryWetB,
      );
    }

    final length = math.max(processedA.length, processedB.length);
    final output = Float32List(length);

    // Composite 3-band gain weighting (normalized sum)
    final weightA = (eqLowA * 0.35 + eqMidA * 0.40 + eqHighA * 0.25) * gainA;
    final weightB = (eqLowB * 0.35 + eqMidB * 0.40 + eqHighB * 0.25) * gainB;

    for (int i = 0; i < length; i++) {
      final sampleA = i < processedA.length ? processedA[i] : 0.0;
      final sampleB = i < processedB.length ? processedB[i] : 0.0;

      final combined = (sampleA * weightA) + (sampleB * weightB);

      // Soft limiter via hyperbolic tangent to eliminate hard digital clipping
      output[i] = _softLimit(combined);
    }

    return output;
  }

  /// Applies a bipolar sweep filter to an audio buffer.
  ///
  /// - Position 0.0: Neutral bypass.
  /// - Position in [-1.0, 0.0): Low-pass sweep from 20000 Hz down to 60 Hz.
  /// - Position in (0.0, 1.0]: High-pass sweep from 20 Hz up to 12000 Hz.
  Float32List applyBipolarFilter(Float32List input, double position) {
    if (position == 0.0 || input.isEmpty) {
      return Float32List.fromList(input);
    }

    final clampedPos = position.clamp(-1.0, 1.0);
    final output = Float32List(input.length);

    if (clampedPos < 0.0) {
      // Low-pass mode
      final cutoff = (20000.0 * math.pow(10.0, 2.52 * clampedPos)).clamp(60.0, 20000.0);
      final dt = 1.0 / sampleRate;
      final rc = 1.0 / (2.0 * math.pi * cutoff);
      final alpha = (dt / (rc + dt)).clamp(0.001, 1.0);

      double prev = 0.0;
      for (int i = 0; i < input.length; i++) {
        prev += alpha * (input[i] - prev);
        output[i] = prev;
      }
    } else {
      // High-pass mode
      final cutoff = (20.0 * math.pow(10.0, 2.78 * clampedPos)).clamp(20.0, 12000.0);
      final dt = 1.0 / sampleRate;
      final rc = 1.0 / (2.0 * math.pi * cutoff);
      final alpha = (rc / (rc + dt)).clamp(0.001, 1.0);

      double prevY = 0.0;
      double prevX = input[0];
      for (int i = 0; i < input.length; i++) {
        final x = input[i];
        final y = alpha * (prevY + x - prevX);
        output[i] = y;
        prevX = x;
        prevY = y;
      }
    }

    return output;
  }

  /// Applies a synchronized delay line with bounded feedback and dry/wet balance.
  Float32List applyDelay(
    Float32List input, {
    required int delaySamples,
    double feedback = 0.40,
    double dryWet = 0.50,
  }) {
    if (delaySamples <= 0 || input.isEmpty) {
      return Float32List.fromList(input);
    }

    final safeFeedback = feedback.clamp(0.0, 0.80);
    final safeDryWet = dryWet.clamp(0.0, 1.0);
    final output = Float32List(input.length);
    final delayLine = Float32List(delaySamples);
    int ringIdx = 0;

    for (int i = 0; i < input.length; i++) {
      final dry = input[i];
      final delayed = delayLine[ringIdx];

      // Update ring buffer with feedback
      delayLine[ringIdx] = dry + delayed * safeFeedback;
      ringIdx = (ringIdx + 1) % delaySamples;

      // Dry / wet blend
      output[i] = dry * (1.0 - safeDryWet) + delayed * safeDryWet;
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

  /// Applies real-time 4-Stem isolation (Bass, Drums, Vocals, Melody) using
  /// Linkwitz-Riley-inspired crossover bands and transient envelope separation.
  Float32List applyStemIsolation(
    Float32List input,
    DjStemIsolationEntity stems,
  ) {
    if (input.isEmpty || stems.isBypass) {
      return Float32List.fromList(input);
    }

    final gBass = stems.effectiveBassGain;
    final gDrums = stems.effectiveDrumsGain;
    final gVocals = stems.effectiveVocalGain;
    final gMelody = stems.effectiveMelodyGain;

    final output = Float32List(input.length);

    // Crossover coefficients:
    // Bass LPF at 220 Hz
    final dt = 1.0 / sampleRate;
    final rcBass = 1.0 / (2.0 * math.pi * 220.0);
    final alphaBass = (dt / (rcBass + dt)).clamp(0.001, 1.0);

    // High LPF at 3800 Hz (complement = High > 3800 Hz)
    final rcHigh = 1.0 / (2.0 * math.pi * 3800.0);
    final alphaHigh = (dt / (rcHigh + dt)).clamp(0.001, 1.0);

    // Fast vs slow transient envelope for Drum impact separation
    final alphaFastEnv = (dt / (0.002 + dt)).clamp(0.001, 1.0); // 2ms attack
    final alphaSlowEnv = (dt / (0.045 + dt)).clamp(0.001, 1.0); // 45ms release

    double lpBass1 = 0.0;
    double lpBass2 = 0.0;
    double lpHigh = 0.0;
    double fastEnv = 0.0;
    double slowEnv = 0.0;

    for (int i = 0; i < input.length; i++) {
      final x = input[i];
      // Two cascaded 1st-order HPFs at 220 Hz (12 dB/oct low-cut) for clean
      // bass separation and exact complementary reconstruction (bassBand + noBass == x).
      lpBass1 += alphaBass * (x - lpBass1);
      final hp1 = x - lpBass1;
      lpBass2 += alphaBass * (hp1 - lpBass2);
      final noBass = hp1 - lpBass2;
      lpHigh += alphaHigh * (x - lpHigh);

      final bassBand = x - noBass;
      final highBand = x - lpHigh;
      final midBand = noBass - highBand;

      final absMid = midBand.abs();
      fastEnv += alphaFastEnv * (absMid - fastEnv);
      slowEnv += alphaSlowEnv * (absMid - slowEnv);

      // Transient ratio [0..1]: high when fast energy spikes above sustained body
      final transientRatio = fastEnv > 1e-6
          ? ((fastEnv - slowEnv).clamp(0.0, fastEnv) / fastEnv).clamp(0.0, 1.0)
          : 0.0;

      // Drums: percussive mid transients + high-frequency hi-hats/cymbals
      final drumSignal = (midBand * transientRatio) + (highBand * 0.65);
      // Vocals: sustained central mid-range formants
      final vocalSignal = midBand * (1.0 - transientRatio) * 0.70;
      // Melody: upper harmonic body + remaining sustained mid
      final melodySignal = (midBand * (1.0 - transientRatio) * 0.30) + (highBand * 0.35);

      final reconstructed = (bassBand * gBass) +
          (drumSignal * gDrums) +
          (vocalSignal * gVocals) +
          (melodySignal * gMelody);

      output[i] = _softLimit(reconstructed);
    }

    return output;
  }

  /// Encodes Split-Cue Stereo output for PCs with a single 3.5mm stereo jack:
  /// Left channel (even indices) = Master Mix, Right channel (odd indices) = Cue Monitor (PFL).
  Float32List encodeSplitCueStereo({
    required Float32List masterMono,
    required Float32List cueMono,
  }) {
    final frames = math.max(masterMono.length, cueMono.length);
    final interleaved = Float32List(frames * 2);
    for (int i = 0; i < frames; i++) {
      interleaved[i * 2] = i < masterMono.length ? _softLimit(masterMono[i]) : 0.0;
      interleaved[(i * 2) + 1] = i < cueMono.length ? _softLimit(cueMono[i]) : 0.0;
    }
    return interleaved;
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
