import 'dart:math' as math;
import 'dj_harmonic_camelot_engine.dart';
import 'dj_stem_isolation_entity.dart';

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

  /// Preamplification TRIM level (0.0 to 2.0, unity 1.0 = 0 dB, 2.0 = +6.02 dB, 0.0 = -inf dB).
  final double trim;

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
  final double loopBeats;

  /// Pro Workstation: Real-time 4-Stem isolation state.
  final DjStemIsolationEntity stems;

  /// Pro Workstation: Detected Camelot Key ('1A'..'12B'), Key-Lock & Semitone shift.
  final String camelotKey;
  final bool isKeyLockEnabled;
  final int pitchSemitonesShift;

  /// Pro Workstation: Slip Mode phantom timeline pointer.
  final bool isSlipModeActive;
  final int slipPositionMs;

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
    this.trim = 1.0,
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
    this.loopBeats = 4.0,
    this.stems = const DjStemIsolationEntity(),
    this.camelotKey = '8A',
    this.isKeyLockEnabled = true,
    this.pitchSemitonesShift = 0,
    this.isSlipModeActive = false,
    this.slipPositionMs = 0,
  });

  /// Effective Camelot key after any semitone shift (or pitch shift when Key-Lock is off).
  CamelotKey get effectiveCamelotKey {
    final autoPitchSemitones = isKeyLockEnabled ? 0 : (centsOffset / 100.0).round();
    return DjHarmonicCamelotEngine.transpose(
      camelotKey,
      pitchSemitonesShift + autoPitchSemitones,
    );
  }

  /// Effective playback tempo after pitch alteration.
  double get effectiveBpm => bpm * pitchMultiplier;

  /// Effective gain level in decibels: 20 * log10(trim).
  /// 0.0 trim corresponds to -infinity dB (capped at -60 dB for UI display).
  double get trimDb => trim <= 0.001 ? -60.0 : 20.0 * (math.log(trim) / math.ln10);

  /// Effective playback rate accounting for pitch multiplier and key shifts when Key-Lock is disabled.
  double get effectivePlaybackRate =>
      pitchMultiplier * (isKeyLockEnabled ? 1.0 : math.pow(2.0, pitchSemitonesShift / 12.0));

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
    double? trim,
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
    double? loopBeats,
    DjStemIsolationEntity? stems,
    String? camelotKey,
    bool? isKeyLockEnabled,
    int? pitchSemitonesShift,
    bool? isSlipModeActive,
    int? slipPositionMs,
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
      trim: (trim ?? this.trim).clamp(0.0, 2.0),
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
      loopBeats: loopBeats ?? this.loopBeats,
      stems: stems ?? this.stems,
      camelotKey: camelotKey ?? this.camelotKey,
      isKeyLockEnabled: isKeyLockEnabled ?? this.isKeyLockEnabled,
      pitchSemitonesShift: (pitchSemitonesShift ?? this.pitchSemitonesShift).clamp(-6, 6),
      isSlipModeActive: isSlipModeActive ?? this.isSlipModeActive,
      slipPositionMs: slipPositionMs ?? this.slipPositionMs,
    );
  }
}
