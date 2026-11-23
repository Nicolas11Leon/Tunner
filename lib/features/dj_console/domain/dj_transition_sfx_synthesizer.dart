import 'dart:math' as math;
import 'dart:typed_data';
import 'dj_sampler_bank_entity.dart';

/// Represents 3-band spectral energy (Low=Red, Mid=Green, High=Blue) for a waveform slice.
class SpectralWaveformBucket {
  final double lowEnergy;  // [0.0, 1.0] -> Red channel
  final double midEnergy;  // [0.0, 1.0] -> Green channel
  final double highEnergy; // [0.0, 1.0] -> Blue/Cyan channel

  const SpectralWaveformBucket({
    required this.lowEnergy,
    required this.midEnergy,
    required this.highEnergy,
  });

  double get peakAmplitude => math.max(lowEnergy, math.max(midEnergy, highEnergy));
}

/// Procedural 100% offline synthesizer for the 8-Pad Club Sampler and
/// 3-band RGB spectral waveform analyzer.
class DjTransitionSfxSynthesizer {
  DjTransitionSfxSynthesizer._();

  /// Generates deterministic PCM audio samples for the requested Sampler pad.
  static Float32List generatePadBuffer(
    DjSamplerPadType pad, {
    int sampleRate = 44100,
  }) {
    switch (pad) {
      case DjSamplerPadType.whiteNoiseRiser:
        return _synthesizeWhiteNoiseRiser(sampleRate);
      case DjSamplerPadType.subBassDrop:
        return _synthesizeSubBassDrop(sampleRate);
      case DjSamplerPadType.clubAirhorn:
        return _synthesizeClubAirhorn(sampleRate);
      case DjSamplerPadType.laserDubSiren:
        return _synthesizeLaserSiren(sampleRate);
      case DjSamplerPadType.vinylBrake:
        return _synthesizePitchDropSweep(sampleRate, startHz: 440.0, endHz: 35.0, durationMs: 650);
      case DjSamplerPadType.backspin:
        return _synthesizePitchDropSweep(sampleRate, startHz: 180.0, endHz: 1200.0, durationMs: 450);
      case DjSamplerPadType.stadiumImpact:
        return _synthesizeSubBassDrop(sampleRate, startHz: 140.0, endHz: 32.0, durationMs: 900);
      case DjSamplerPadType.vocalStutter:
        return _synthesizeVocalStutter(sampleRate);
    }
  }

  /// Extracts [buckets] 3-band RGB spectral buckets from raw PCM samples
  /// for 60/120 FPS parallel waveform rendering.
  static List<SpectralWaveformBucket> computeSpectralWaveformSummary(
    Float32List samples, {
    int buckets = 96,
    int sampleRate = 44100,
  }) {
    if (samples.isEmpty || buckets <= 0) {
      return List<SpectralWaveformBucket>.generate(
        math.max(1, buckets),
        (_) => const SpectralWaveformBucket(lowEnergy: 0.1, midEnergy: 0.1, highEnergy: 0.1),
      );
    }

    final result = <SpectralWaveformBucket>[];
    final step = math.max(1, samples.length ~/ buckets);

    final dt = 1.0 / sampleRate;
    final alphaLow = (dt / ((1.0 / (2.0 * math.pi * 220.0)) + dt)).clamp(0.001, 1.0);
    final alphaHigh = (dt / ((1.0 / (2.0 * math.pi * 3800.0)) + dt)).clamp(0.001, 1.0);

    double lpLow = 0.0;
    double lpHigh = 0.0;

    for (int b = 0; b < buckets; b++) {
      final start = b * step;
      final end = math.min(samples.length, start + step);
      if (start >= samples.length) {
        result.add(const SpectralWaveformBucket(lowEnergy: 0.0, midEnergy: 0.0, highEnergy: 0.0));
        continue;
      }

      double maxLow = 0.0;
      double maxMid = 0.0;
      double maxHigh = 0.0;

      for (int i = start; i < end; i++) {
        final x = samples[i];
        lpLow += alphaLow * (x - lpLow);
        lpHigh += alphaHigh * (x - lpHigh);

        final low = lpLow.abs();
        final high = (x - lpHigh).abs();
        final mid = (lpHigh - lpLow).abs();

        if (low > maxLow) maxLow = low;
        if (mid > maxMid) maxMid = mid;
        if (high > maxHigh) maxHigh = high;
      }

      result.add(
        SpectralWaveformBucket(
          lowEnergy: maxLow.clamp(0.0, 1.0),
          midEnergy: maxMid.clamp(0.0, 1.0),
          highEnergy: maxHigh.clamp(0.0, 1.0),
        ),
      );
    }

    return result;
  }

  /// Generates a deterministic visual waveform preview from track BPM when no file is loaded.
  static List<SpectralWaveformBucket> generateSyntheticTrackWaveform({
    required double bpm,
    int buckets = 96,
  }) {
    return List<SpectralWaveformBucket>.generate(buckets, (i) {
      final phase = (i / buckets) * 16.0; // 4 bars
      final isDownbeat = (i % 6 == 0);
      final low = isDownbeat ? 0.92 : (0.30 + 0.25 * math.sin(phase * math.pi).abs());
      final mid = 0.35 + 0.45 * math.cos(phase * 0.75 * math.pi).abs();
      final high = (i % 3 == 0) ? 0.78 : 0.22;
      return SpectralWaveformBucket(
        lowEnergy: low.clamp(0.0, 1.0),
        midEnergy: mid.clamp(0.0, 1.0),
        highEnergy: high.clamp(0.0, 1.0),
      );
    });
  }

  static Float32List _synthesizeWhiteNoiseRiser(int sampleRate) {
    final len = (sampleRate * 1.2).round();
    final out = Float32List(len);
    final rng = math.Random(42);
    double lp = 0.0;
    for (int i = 0; i < len; i++) {
      final t = i / len;
      final noise = (rng.nextDouble() * 2.0) - 1.0;
      final alpha = (0.02 + (0.75 * t * t)).clamp(0.01, 0.95);
      lp += alpha * (noise - lp);
      final env = t * 0.85;
      out[i] = (lp * env).clamp(-1.0, 1.0);
    }
    return out;
  }

  static Float32List _synthesizeSubBassDrop(
    int sampleRate, {
    double startHz = 95.0,
    double endHz = 28.0,
    int durationMs = 1000,
  }) {
    final len = (sampleRate * (durationMs / 1000.0)).round();
    final out = Float32List(len);
    double phase = 0.0;
    for (int i = 0; i < len; i++) {
      final t = i / len;
      final freq = startHz * math.pow(endHz / startHz, t);
      phase += (2.0 * math.pi * freq) / sampleRate;
      final env = math.exp(-3.0 * t);
      out[i] = (math.sin(phase) * env * 0.95).clamp(-1.0, 1.0);
    }
    return out;
  }

  static Float32List _synthesizeClubAirhorn(int sampleRate) {
    final len = (sampleRate * 0.55).round();
    final out = Float32List(len);
    const f1 = 440.0;
    const f2 = 554.37; // Major 3rd
    const f3 = 659.25; // Perfect 5th
    for (int i = 0; i < len; i++) {
      final t = i / sampleRate;
      final s1 = math.sin(2.0 * math.pi * f1 * t);
      final s2 = math.sin(2.0 * math.pi * f2 * t);
      final s3 = math.sin(2.0 * math.pi * f3 * t);
      final env = i > len * 0.85 ? (1.0 - ((i - len * 0.85) / (len * 0.15))) : 1.0;
      out[i] = (((s1 + s2 + s3) / 3.0) * env * 0.85).clamp(-1.0, 1.0);
    }
    return out;
  }

  static Float32List _synthesizeLaserSiren(int sampleRate) {
    final len = (sampleRate * 0.75).round();
    final out = Float32List(len);
    double phase = 0.0;
    for (int i = 0; i < len; i++) {
      final t = i / sampleRate;
      final lfo = math.sin(2.0 * math.pi * 12.0 * t);
      final freq = 650.0 + (320.0 * lfo);
      phase += (2.0 * math.pi * freq) / sampleRate;
      final env = 1.0 - (i / len);
      out[i] = (math.sin(phase) * env * 0.75).clamp(-1.0, 1.0);
    }
    return out;
  }

  static Float32List _synthesizePitchDropSweep(
    int sampleRate, {
    required double startHz,
    required double endHz,
    required int durationMs,
  }) {
    final len = (sampleRate * (durationMs / 1000.0)).round();
    final out = Float32List(len);
    double phase = 0.0;
    for (int i = 0; i < len; i++) {
      final t = i / len;
      final freq = startHz + (endHz - startHz) * t;
      phase += (2.0 * math.pi * freq) / sampleRate;
      final env = math.sin(math.pi * t);
      out[i] = (math.sin(phase) * env * 0.8).clamp(-1.0, 1.0);
    }
    return out;
  }

  static Float32List _synthesizeVocalStutter(int sampleRate) {
    final len = (sampleRate * 0.5).round();
    final out = Float32List(len);
    final gatePeriod = (sampleRate / 16.0).round();
    for (int i = 0; i < len; i++) {
      final t = i / sampleRate;
      final gate = (i % gatePeriod) < (gatePeriod * 0.55) ? 1.0 : 0.05;
      final osc = math.sin(2.0 * math.pi * 523.25 * t) * 0.6 +
          math.sin(2.0 * math.pi * 1046.5 * t) * 0.4;
      out[i] = (osc * gate * 0.8).clamp(-1.0, 1.0);
    }
    return out;
  }
}
