import 'dart:math' as math;

/// Response curve used by the crossfader to blend Deck A and Deck B signals.
enum CrossfaderCurve {
  /// Equal-power curve based on trigonometric cosine/sine distribution.
  /// Preserves total acoustic RMS energy across the entire transition.
  equalPower,

  /// Linear attenuation curve. Useful for slow ambient crossfades.
  linear,

  /// Fast-cut sharp curve with near-instantaneous onset. Optimized for scratching.
  fastCut,
}

/// Pure Dart entity modeling crossfader position and stereo gain calculation.
class DjCrossfaderEntity {
  /// Position normalized in range [-1.0, 1.0].
  /// -1.0 = 100% Deck A, 0.0 = Center, +1.0 = 100% Deck B.
  final double position;

  /// Selected attenuation curve.
  final CrossfaderCurve curve;

  const DjCrossfaderEntity({
    this.position = 0.0,
    this.curve = CrossfaderCurve.equalPower,
  }) : assert(position >= -1.0 && position <= 1.0, 'Position must be in [-1.0, 1.0]');

  /// Computes the relative acoustic gains `(gainA, gainB)` for the current position and curve.
  /// Both gains are normalized within [0.0, 1.0].
  ({double gainA, double gainB}) calculateGains() {
    switch (curve) {
      case CrossfaderCurve.equalPower:
        // theta in [0, pi/2]
        final theta = (math.pi / 4.0) * (position + 1.0);
        final gA = math.cos(theta).clamp(0.0, 1.0);
        final gB = math.sin(theta).clamp(0.0, 1.0);
        return (gainA: gA, gainB: gB);

      case CrossfaderCurve.linear:
        final gA = ((1.0 - position) / 2.0).clamp(0.0, 1.0);
        final gB = ((1.0 + position) / 2.0).clamp(0.0, 1.0);
        return (gainA: gA, gainB: gB);

      case CrossfaderCurve.fastCut:
        // Cut with 5% deadzone around center and ultra-fast rise
        double gA;
        double gB;
        if (position <= 0.05) {
          gA = 1.0;
        } else {
          gA = math.max(0.0, 1.0 - (position - 0.05) / 0.95);
        }

        if (position >= -0.05) {
          gB = 1.0;
        } else {
          gB = math.max(0.0, 1.0 + (position + 0.05) / 0.95);
        }
        return (gainA: gA.clamp(0.0, 1.0), gainB: gB.clamp(0.0, 1.0));
    }
  }

  DjCrossfaderEntity copyWith({
    double? position,
    CrossfaderCurve? curve,
  }) {
    return DjCrossfaderEntity(
      position: (position ?? this.position).clamp(-1.0, 1.0),
      curve: curve ?? this.curve,
    );
  }
}
