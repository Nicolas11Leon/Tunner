/// Quantized beat fractions supported by the Pro DJ Auto-Loop engine.
const List<double> kSupportedLoopBeatFractions = [
  0.03125, // 1/32 beat
  0.0625,  // 1/16 beat
  0.125,   // 1/8 beat
  0.25,    // 1/4 beat
  0.5,     // 1/2 beat
  1.0,     // 1 beat
  2.0,     // 2 beats
  4.0,     // 4 beats (1 bar)
  8.0,     // 8 beats (2 bars)
  16.0,    // 16 beats (4 bars)
];

/// Pure Dart quantized Auto-Loop, Beat Jump, and Slip Mode timeline engine.
class DjLoopAndSlipEngine {
  DjLoopAndSlipEngine._();

  /// Computes exact loop duration in milliseconds for [beats] at [effectiveBpm].
  ///
  /// Formula: T_loop = beats * (60000 / effectiveBpm).
  /// Clamped to a minimum of 15 ms to prevent audio buffer oscillation.
  static int computeLoopDurationMs({
    required double beats,
    required double effectiveBpm,
  }) {
    if (effectiveBpm <= 0) return 500;
    final rawMs = (beats * (60000.0 / effectiveBpm)).round();
    return rawMs.clamp(15, 60000);
  }

  /// Quantizes a millisecond position to the nearest beat boundary.
  static int quantizeToNearestBeatMs({
    required int positionMs,
    required double effectiveBpm,
  }) {
    if (effectiveBpm <= 0) return positionMs;
    final beatMs = 60000.0 / effectiveBpm;
    final beatIndex = (positionMs / beatMs).round();
    return (beatIndex * beatMs).round().clamp(0, 36000000);
  }

  /// Halves the current beat fraction down to the 1/32 beat floor.
  static double halveBeats(double currentBeats) {
    final halved = currentBeats / 2.0;
    return halved < 0.03125 ? 0.03125 : halved;
  }

  /// Doubles the current beat fraction up to the 16-beat ceiling.
  static double doubleBeats(double currentBeats) {
    final doubled = currentBeats * 2.0;
    return doubled > 16.0 ? 16.0 : doubled;
  }

  /// Computes the target position after a quantized Beat Jump of [beatDelta] beats.
  static int computeBeatJumpPositionMs({
    required int currentPositionMs,
    required double beatDelta,
    required double effectiveBpm,
    required int durationMs,
  }) {
    if (effectiveBpm <= 0 || durationMs <= 0) return currentPositionMs;
    final deltaMs = (beatDelta * (60000.0 / effectiveBpm)).round();
    return (currentPositionMs + deltaMs).clamp(0, durationMs);
  }

  /// Wraps playhead inside [loopStartMs, loopEndMs) when looping is active.
  static int wrapLoopPosition({
    required int nextPositionMs,
    required int loopStartMs,
    required int loopEndMs,
  }) {
    final loopLen = loopEndMs - loopStartMs;
    if (loopLen <= 0) return nextPositionMs;
    if (nextPositionMs >= loopEndMs) {
      final overflow = (nextPositionMs - loopStartMs) % loopLen;
      return loopStartMs + overflow;
    }
    if (nextPositionMs < loopStartMs) {
      return loopStartMs;
    }
    return nextPositionMs;
  }

  /// Formats a beat fraction into clean DJ hardware notation (e.g. '1/4', '4').
  static String formatBeatLabel(double beats) {
    if (beats >= 1.0) return '${beats.toInt()}';
    final denom = (1.0 / beats).round();
    return '1/$denom';
  }
}
