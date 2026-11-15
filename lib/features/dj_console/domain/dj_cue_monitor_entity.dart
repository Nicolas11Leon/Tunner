/// Immutable state for DJ Headphone Pre-Listening (PFL) and PC Split-Cue routing.
///
/// Split-Cue routes Master Mix to the Left stereo channel and Cue (PFL) to the
/// Right stereo channel, enabling full headphone pre-cueing on laptops/PCs with
/// only a single 3.5mm stereo output jack.
class DjCueMonitorEntity {
  final bool cueDeckA;
  final bool cueDeckB;
  final bool isSplitCueActive;

  /// Blend between Cue (0.0) and Master (1.0) in the headphone monitor bus.
  final double cueMasterMix;

  const DjCueMonitorEntity({
    this.cueDeckA = false,
    this.cueDeckB = false,
    this.isSplitCueActive = false,
    this.cueMasterMix = 0.0,
  });

  DjCueMonitorEntity toggleCueA() => copyWith(cueDeckA: !cueDeckA);
  DjCueMonitorEntity toggleCueB() => copyWith(cueDeckB: !cueDeckB);
  DjCueMonitorEntity toggleSplitCue() => copyWith(isSplitCueActive: !isSplitCueActive);

  DjCueMonitorEntity copyWith({
    bool? cueDeckA,
    bool? cueDeckB,
    bool? isSplitCueActive,
    double? cueMasterMix,
  }) {
    return DjCueMonitorEntity(
      cueDeckA: cueDeckA ?? this.cueDeckA,
      cueDeckB: cueDeckB ?? this.cueDeckB,
      isSplitCueActive: isSplitCueActive ?? this.isSplitCueActive,
      cueMasterMix: (cueMasterMix ?? this.cueMasterMix).clamp(0.0, 1.0),
    );
  }
}
