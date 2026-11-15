/// Discrete audio stem channels for real-time DJ performance isolation.
enum DjStemType {
  vocals,
  drums,
  bass,
  melody,
}

/// Immutable state representing 4-Stem real-time isolation and gains for a DJ deck.
///
/// Allows instant mashups, acapellas, and instrumental drops without pre-split audio files.
class DjStemIsolationEntity {
  final double vocalGain;
  final double drumsGain;
  final double bassGain;
  final double melodyGain;

  final bool isVocalMuted;
  final bool isDrumsMuted;
  final bool isBassMuted;
  final bool isMelodyMuted;

  const DjStemIsolationEntity({
    this.vocalGain = 1.0,
    this.drumsGain = 1.0,
    this.bassGain = 1.0,
    this.melodyGain = 1.0,
    this.isVocalMuted = false,
    this.isDrumsMuted = false,
    this.isBassMuted = false,
    this.isMelodyMuted = false,
  });

  /// Effective linear gain for vocals after mute state.
  double get effectiveVocalGain => isVocalMuted ? 0.0 : vocalGain.clamp(0.0, 1.0);

  /// Effective linear gain for drums after mute state.
  double get effectiveDrumsGain => isDrumsMuted ? 0.0 : drumsGain.clamp(0.0, 1.0);

  /// Effective linear gain for bass after mute state.
  double get effectiveBassGain => isBassMuted ? 0.0 : bassGain.clamp(0.0, 1.0);

  /// Effective linear gain for melody/harmony after mute state.
  double get effectiveMelodyGain => isMelodyMuted ? 0.0 : melodyGain.clamp(0.0, 1.0);

  /// Returns true if all 4 stems are unmuted and at full unity gain.
  bool get isBypass =>
      !isVocalMuted &&
      !isDrumsMuted &&
      !isBassMuted &&
      !isMelodyMuted &&
      (vocalGain - 1.0).abs() < 0.001 &&
      (drumsGain - 1.0).abs() < 0.001 &&
      (bassGain - 1.0).abs() < 0.001 &&
      (melodyGain - 1.0).abs() < 0.001;

  /// Checks whether a specific stem type is currently muted.
  bool isMuted(DjStemType type) {
    switch (type) {
      case DjStemType.vocals:
        return isVocalMuted;
      case DjStemType.drums:
        return isDrumsMuted;
      case DjStemType.bass:
        return isBassMuted;
      case DjStemType.melody:
        return isMelodyMuted;
    }
  }

  /// Toggles mute state for the requested stem type.
  DjStemIsolationEntity toggleMute(DjStemType type) {
    switch (type) {
      case DjStemType.vocals:
        return copyWith(isVocalMuted: !isVocalMuted);
      case DjStemType.drums:
        return copyWith(isDrumsMuted: !isDrumsMuted);
      case DjStemType.bass:
        return copyWith(isBassMuted: !isBassMuted);
      case DjStemType.melody:
        return copyWith(isMelodyMuted: !isMelodyMuted);
    }
  }

  /// Preset: Instant Acapella (Vocals only, instrumental stems muted).
  DjStemIsolationEntity isolateAcapella() {
    return copyWith(
      isVocalMuted: false,
      isDrumsMuted: true,
      isBassMuted: true,
      isMelodyMuted: true,
    );
  }

  /// Preset: Instant Instrumental (Vocals muted, rhythm and melody active).
  DjStemIsolationEntity isolateInstrumental() {
    return copyWith(
      isVocalMuted: true,
      isDrumsMuted: false,
      isBassMuted: false,
      isMelodyMuted: false,
    );
  }

  /// Preset: Rhythm Tool (Drums and Bass only).
  DjStemIsolationEntity isolateRhythm() {
    return copyWith(
      isVocalMuted: true,
      isDrumsMuted: false,
      isBassMuted: false,
      isMelodyMuted: true,
    );
  }

  /// Resets all 4 stems to unity gain and unmuted state.
  DjStemIsolationEntity resetAll() => const DjStemIsolationEntity();

  DjStemIsolationEntity copyWith({
    double? vocalGain,
    double? drumsGain,
    double? bassGain,
    double? melodyGain,
    bool? isVocalMuted,
    bool? isDrumsMuted,
    bool? isBassMuted,
    bool? isMelodyMuted,
  }) {
    return DjStemIsolationEntity(
      vocalGain: vocalGain ?? this.vocalGain,
      drumsGain: drumsGain ?? this.drumsGain,
      bassGain: bassGain ?? this.bassGain,
      melodyGain: melodyGain ?? this.melodyGain,
      isVocalMuted: isVocalMuted ?? this.isVocalMuted,
      isDrumsMuted: isDrumsMuted ?? this.isDrumsMuted,
      isBassMuted: isBassMuted ?? this.isBassMuted,
      isMelodyMuted: isMelodyMuted ?? this.isMelodyMuted,
    );
  }
}
