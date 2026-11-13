import 'dart:math' as math;

/// Discrete musical metric divisions for beat-synced delay.
enum DjDelayDivision {
  halfBeat(0.5, '1/2'),
  quarterBeat(0.25, '1/4'),
  eighthBeat(0.125, '1/8'),
  sixteenthBeat(0.0625, '1/16');

  final double factor;
  final String label;
  const DjDelayDivision(this.factor, this.label);

  static const DjDelayDivision half = DjDelayDivision.halfBeat;
  static const DjDelayDivision quarter = DjDelayDivision.quarterBeat;
  static const DjDelayDivision eighth = DjDelayDivision.eighthBeat;
  static const DjDelayDivision sixteenth = DjDelayDivision.sixteenthBeat;
}

/// Pure Dart immutable representation of channel performance effects (Dual Bipolar Filter & Beat Delay).
class DjChannelFxEntity {
  /// Bipolar filter position in range [-1.0, 1.0].
  /// -1.0 = Max Low-Pass (muffled bass cut), 0.0 = Neutral Bypass, +1.0 = Max High-Pass (bass cut).
  final double filterPosition;

  /// Whether the beat-synced delay unit is currently engaged.
  final bool isDelayActive;

  /// Delay metric division relative to 1 beat.
  final DjDelayDivision delayDivision;

  /// Delay feedback coefficient in range [0.0, 0.8].
  final double delayFeedback;

  /// Delay wet mix amount in range [0.0, 1.0].
  final double delayDryWet;

  const DjChannelFxEntity({
    this.filterPosition = 0.0,
    this.isDelayActive = false,
    this.delayDivision = DjDelayDivision.quarterBeat,
    this.delayFeedback = 0.40,
    this.delayDryWet = 0.35,
  }) : assert(filterPosition >= -1.0 && filterPosition <= 1.0, 'Filter position must be in [-1.0, 1.0]');

  /// Computes the effective cutoff frequency in Hertz according to the bipolar position.
  ///
  /// Neutral (0.0): Returns 20000.0 (indicating filter bypass).
  /// Low-Pass (< 0.0): 20000 Hz down to 60 Hz.
  /// High-Pass (> 0.0): 20 Hz up to 12000 Hz.
  double get cutoffFrequencyHz {
    if (filterPosition.abs() < 0.001) return 20000.0; // Bypass

    if (filterPosition < 0.0) {
      // Low-Pass mode: k in [-1.0, 0.0)
      // fc(k) = 20000 * 10^(2.52 * k) -> at k = -1.0, fc ≈ 60 Hz; at k = 0, fc = 20000 Hz.
      final exponent = 2.52 * filterPosition;
      return (20000.0 * math.pow(10.0, exponent)).clamp(60.0, 20000.0);
    } else {
      // High-Pass mode: k in (0.0, 1.0]
      // fc(k) = 20 * 10^(2.78 * k) -> at k = 0, fc = 20 Hz; at k = 1.0, fc ≈ 12000 Hz.
      final exponent = 2.78 * filterPosition;
      return (20.0 * math.pow(10.0, exponent)).clamp(20.0, 12000.0);
    }
  }

  bool get isLowPassMode => filterPosition < -0.001;
  bool get isHighPassMode => filterPosition > 0.001;

  /// Calculates the exact number of delay samples based on active tempo (BPM) and sample rate.
  int calculateDelaySamples({required double bpm, int sampleRate = 44100}) {
    final effectiveBpm = bpm > 0 ? bpm : 120.0;
    final secondsPerBeat = 60.0 / effectiveBpm;
    final delaySeconds = secondsPerBeat * delayDivision.factor;
    return (delaySeconds * sampleRate).round();
  }

  /// Positional overload for convenience in DSP loops.
  int calculateDelaySamplesPositional(int sampleRate, double bpm) {
    return calculateDelaySamples(bpm: bpm, sampleRate: sampleRate);
  }

  DjChannelFxEntity copyWith({
    double? filterPosition,
    bool? isDelayActive,
    DjDelayDivision? delayDivision,
    double? delayFeedback,
    double? delayDryWet,
  }) {
    return DjChannelFxEntity(
      filterPosition: (filterPosition ?? this.filterPosition).clamp(-1.0, 1.0),
      isDelayActive: isDelayActive ?? this.isDelayActive,
      delayDivision: delayDivision ?? this.delayDivision,
      delayFeedback: (delayFeedback ?? this.delayFeedback).clamp(0.0, 0.8),
      delayDryWet: (delayDryWet ?? this.delayDryWet).clamp(0.0, 1.0),
    );
  }
}
