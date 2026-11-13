import 'dart:math' as math;

/// Immutable representation of a single virtual DJ deck player.
class DjDeckEntity {
  final String deckId; // 'A' or 'B'
  final String trackTitle;
  final String artist;
  final String? audioPath;

  /// Base tempo of the loaded track in beats per minute.
  final double bpm;

  /// Track total duration in milliseconds.
  final int durationMs;

  /// Playhead position in milliseconds.
  final int currentPositionMs;

  /// Whether the deck is actively playing.
  final bool isPlaying;

  /// Whether the deck is in momentary cue audition mode.
  final bool isCueActive;

  /// Active cue point in milliseconds.
  final int cuePositionMs;

  /// Playback speed multiplier (e.g. 1.0 = normal, 1.08 = +8%).
  final double pitchMultiplier;

  /// Whether tempo sync lock is enabled.
  final bool isSyncActive;

  /// Linear channel volume (0.0 to 1.0).
  final double volume;

  /// Equalizer band gains (0.0 to 1.5, 1.0 is unity gain).
  final double gainLow;
  final double gainMid;
  final double gainHigh;

  /// EQ kill switches (24 dB/oct isolation).
  final bool isKillLow;
  final bool isKillMid;
  final bool isKillHigh;

  /// Registered Hot Cue points (index 1..4 -> positionMs).
  final Map<int, int> hotCues;

  /// Active loop state.
  final bool isLoopActive;
  final int loopStartMs;
  final int loopEndMs;

  const DjDeckEntity({
    required this.deckId,
    this.trackTitle = 'Sin Pista',
    this.artist = 'Desconocido',
    this.audioPath,
    this.bpm = 120.0,
    this.durationMs = 180000, // 3 minutes default demo
    this.currentPositionMs = 0,
    this.isPlaying = false,
    this.isCueActive = false,
    this.cuePositionMs = 0,
    this.pitchMultiplier = 1.0,
    this.isSyncActive = false,
    this.volume = 1.0,
    this.gainLow = 1.0,
    this.gainMid = 1.0,
    this.gainHigh = 1.0,
    this.isKillLow = false,
    this.isKillMid = false,
    this.isKillHigh = false,
    this.hotCues = const {},
    this.isLoopActive = false,
    this.loopStartMs = 0,
    this.loopEndMs = 0,
  });

  /// Effective playback tempo after pitch alteration.
  double get effectiveBpm => bpm * pitchMultiplier;

  /// Pitch offset expressed in cents: 1200 * log2(pitchMultiplier).
  double get centsOffset => pitchMultiplier > 0 ? (1200.0 * (math.log(pitchMultiplier) / math.ln2)) : 0.0;

  /// Pitch percentage offset relative to original (e.g. +4.5%, -2.0%).
  double get pitchPercentage => (pitchMultiplier - 1.0) * 100.0;

  /// Effective low band gain considering kill switch.
  double get effectiveGainLow => isKillLow ? 0.0 : gainLow;

  /// Effective mid band gain considering kill switch.
  double get effectiveGainMid => isKillMid ? 0.0 : gainMid;

  /// Effective high band gain considering kill switch.
  double get effectiveGainHigh => isKillHigh ? 0.0 : gainHigh;

  /// Progress fraction in range [0.0, 1.0].
  double get progressFraction => durationMs > 0 ? (currentPositionMs / durationMs).clamp(0.0, 1.0) : 0.0;

  DjDeckEntity copyWith({
    String? trackTitle,
    String? artist,
    String? audioPath,
    double? bpm,
    int? durationMs,
    int? currentPositionMs,
    bool? isPlaying,
    bool? isCueActive,
    int? cuePositionMs,
    double? pitchMultiplier,
    bool? isSyncActive,
    double? volume,
    double? gainLow,
    double? gainMid,
    double? gainHigh,
    bool? isKillLow,
    bool? isKillMid,
    bool? isKillHigh,
    Map<int, int>? hotCues,
    bool? isLoopActive,
    int? loopStartMs,
    int? loopEndMs,
  }) {
    return DjDeckEntity(
      deckId: deckId,
      trackTitle: trackTitle ?? this.trackTitle,
      artist: artist ?? this.artist,
      audioPath: audioPath ?? this.audioPath,
      bpm: bpm ?? this.bpm,
      durationMs: durationMs ?? this.durationMs,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      isPlaying: isPlaying ?? this.isPlaying,
      isCueActive: isCueActive ?? this.isCueActive,
      cuePositionMs: cuePositionMs ?? this.cuePositionMs,
      pitchMultiplier: pitchMultiplier ?? this.pitchMultiplier,
      isSyncActive: isSyncActive ?? this.isSyncActive,
      volume: volume ?? this.volume,
      gainLow: gainLow ?? this.gainLow,
      gainMid: gainMid ?? this.gainMid,
      gainHigh: gainHigh ?? this.gainHigh,
      isKillLow: isKillLow ?? this.isKillLow,
      isKillMid: isKillMid ?? this.isKillMid,
      isKillHigh: isKillHigh ?? this.isKillHigh,
      hotCues: hotCues ?? this.hotCues,
      isLoopActive: isLoopActive ?? this.isLoopActive,
      loopStartMs: loopStartMs ?? this.loopStartMs,
      loopEndMs: loopEndMs ?? this.loopEndMs,
    );
  }
}
