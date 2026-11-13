import 'dart:math' as math;
import 'dart:typed_data';

/// Pure Dart algorithmic engine for estimating musical tempo (BPM) from raw PCM audio buffers.
///
/// Employs an Onset Energy Flux function coupled with temporal autocorrelation within the
/// canonical club and classical dance range [60.0, 180.0] BPM.
class BpmBeatTrackerEngine {
  final int sampleRate;
  final int windowSize;
  final int hopSize;

  const BpmBeatTrackerEngine({
    this.sampleRate = 44100,
    this.windowSize = 1024,
    this.hopSize = 512,
  });

  /// Convenience static estimation method.
  static double estimateBpm({
    required Float32List samples,
    int sampleRate = 44100,
  }) {
    return BpmBeatTrackerEngine(sampleRate: sampleRate).estimate(samples);
  }

  /// Estimates the dominant tempo (BPM) from the supplied mono or single-channel audio buffer.
  ///
  /// Returns a value clamped within [60.0, 180.0] BPM. If the buffer is unvoiced or
  /// contains insufficient temporal energy, returns fallback tempo 120.0 BPM.
  double estimate(Float32List buffer) {
    if (buffer.length < sampleRate) {
      // Less than 1 second of audio: insufficient for reliable beat estimation
      return 120.0;
    }

    // 1. Compute Windowed Energy Envelope
    final numFrames = (buffer.length - windowSize) ~/ hopSize;
    if (numFrames < 4) return 120.0;

    final energy = Float64List(numFrames);
    for (int m = 0; m < numFrames; m++) {
      final offset = m * hopSize;
      double sumSquares = 0.0;
      for (int k = 0; k < windowSize; k++) {
        final val = buffer[offset + k];
        sumSquares += val * val;
      }
      energy[m] = math.sqrt(sumSquares / windowSize);
    }

    // 2. Compute Onset Detection Curve (Half-Wave Rectified First Difference)
    final onsets = Float64List(numFrames);
    double maxOnset = 0.0;
    for (int m = 1; m < numFrames; m++) {
      final diff = energy[m] - energy[m - 1];
      final onsetVal = diff > 0.0 ? diff : 0.0;
      onsets[m] = onsetVal;
      if (onsetVal > maxOnset) maxOnset = onsetVal;
    }

    if (maxOnset < 0.001) {
      // Signal contains no perceptible transients (near-silence or continuous sine)
      return 120.0;
    }

    // 3. Autocorrelation over the plausible tempo range [60, 180] BPM
    final frameRate = sampleRate / hopSize; // frames per second
    final minLag = (frameRate * 60.0 / 180.0).round(); // ~180 BPM
    final maxLag = (frameRate * 60.0 / 60.0).round(); // ~60 BPM

    if (maxLag >= numFrames) {
      return 120.0;
    }

    double bestCorrelation = -1.0;
    int bestLag = (frameRate * 60.0 / 120.0).round();

    for (int lag = minLag; lag <= maxLag; lag++) {
      double correlation = 0.0;
      final limit = numFrames - lag;
      for (int m = 0; m < limit; m++) {
        correlation += onsets[m] * onsets[m + lag];
      }
      if (correlation > bestCorrelation) {
        bestCorrelation = correlation;
        bestLag = lag;
      }
    }

    if (bestLag <= 0) return 120.0;

    final estimatedBpm = (frameRate * 60.0) / bestLag;
    return estimatedBpm.clamp(60.0, 180.0);
  }
}
