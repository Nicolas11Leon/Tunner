/// Direction of an automated DJ crossfade transition.
enum AutomixDirection {
  deckAToDeckB,
  deckBToDeckA,
}

/// Pure Dart immutable state and DSP curve calculator for Smart Automix
/// featuring automatic Bass-Swap (prevents sub-bass phase collision).
class DjSmartAutomixEngine {
  final bool isActive;
  final AutomixDirection direction;
  final int durationBars; // 4, 8, or 16 bars
  final double progress; // [0.0, 1.0]
  final bool enableBassSwap;

  const DjSmartAutomixEngine({
    this.isActive = false,
    this.direction = AutomixDirection.deckAToDeckB,
    this.durationBars = 8,
    this.progress = 0.0,
    this.enableBassSwap = true,
  });

  /// Starts a new Automix transition in the specified direction.
  DjSmartAutomixEngine start({
    required AutomixDirection direction,
    int durationBars = 8,
    bool enableBassSwap = true,
  }) {
    return DjSmartAutomixEngine(
      isActive: true,
      direction: direction,
      durationBars: durationBars,
      progress: 0.0,
      enableBassSwap: enableBassSwap,
    );
  }

  /// Cancels Automix immediately (e.g. when DJ manually grabs the crossfader).
  DjSmartAutomixEngine cancel() {
    return DjSmartAutomixEngine(
      isActive: false,
      direction: direction,
      durationBars: durationBars,
      progress: progress,
      enableBassSwap: enableBassSwap,
    );
  }

  /// Advances transition progress given elapsed milliseconds and reference BPM.
  DjSmartAutomixEngine advance({
    required int elapsedMs,
    required double referenceBpm,
  }) {
    if (!isActive || referenceBpm <= 0) return this;

    // 1 bar in 4/4 = 4 beats
    final totalDurationMs = durationBars * 4.0 * (60000.0 / referenceBpm);
    final deltaProgress = elapsedMs / totalDurationMs;
    final nextProgress = (progress + deltaProgress).clamp(0.0, 1.0);

    return DjSmartAutomixEngine(
      isActive: nextProgress < 1.0,
      direction: direction,
      durationBars: durationBars,
      progress: nextProgress,
      enableBassSwap: enableBassSwap,
    );
  }

  /// Resulting crossfader position in [-1.0 (Deck A), +1.0 (Deck B)].
  double get crossfaderPosition {
    final p = progress.clamp(0.0, 1.0);
    if (direction == AutomixDirection.deckAToDeckB) {
      return -1.0 + (2.0 * p);
    } else {
      return 1.0 - (2.0 * p);
    }
  }

  /// Computed Low EQ gain for Deck A during Smart Bass-Swap transition.
  ///
  /// When crossing midpoint (p = 0.45..0.55), outgoing deck bass smoothly drops
  /// to 0.25 while incoming deck bass rises from 0.25 to 1.0, preventing mud.
  double get bassSwapGainLowA {
    if (!enableBassSwap) return 1.0;
    final p = progress.clamp(0.0, 1.0);
    if (direction == AutomixDirection.deckAToDeckB) {
      // Outgoing A: holds 1.0 until 0.45, drops to 0.25 by 0.55
      if (p <= 0.45) return 1.0;
      if (p >= 0.55) return 0.25;
      final t = (p - 0.45) / 0.10;
      return 1.0 - (0.75 * t);
    } else {
      // Incoming A: holds 0.25 until 0.45, rises to 1.0 by 0.55
      if (p <= 0.45) return 0.25;
      if (p >= 0.55) return 1.0;
      final t = (p - 0.45) / 0.10;
      return 0.25 + (0.75 * t);
    }
  }

  /// Computed Low EQ gain for Deck B during Smart Bass-Swap transition.
  double get bassSwapGainLowB {
    if (!enableBassSwap) return 1.0;
    final p = progress.clamp(0.0, 1.0);
    if (direction == AutomixDirection.deckAToDeckB) {
      // Incoming B
      if (p <= 0.45) return 0.25;
      if (p >= 0.55) return 1.0;
      final t = (p - 0.45) / 0.10;
      return 0.25 + (0.75 * t);
    } else {
      // Outgoing B
      if (p <= 0.45) return 1.0;
      if (p >= 0.55) return 0.25;
      final t = (p - 0.45) / 0.10;
      return 1.0 - (0.75 * t);
    }
  }
}
