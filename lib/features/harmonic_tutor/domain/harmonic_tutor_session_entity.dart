import 'harmonic_role_entity.dart';
import 'just_intonation_calculator.dart';

/// Immutable representation of an active Harmonic Tuning session.
class HarmonicTutorSessionEntity {
  final String rootNoteName;
  final double rootFrequency;
  final HarmonicChordType chordType;
  final HarmonicAnalysisResult? activeAnalysis;
  final bool isDroneActive;
  final bool isListening;

  const HarmonicTutorSessionEntity({
    this.rootNoteName = 'C4',
    this.rootFrequency = 261.63,
    this.chordType = HarmonicChordType.majorTriad,
    this.activeAnalysis,
    this.isDroneActive = false,
    this.isListening = false,
  });

  HarmonicTutorSessionEntity copyWith({
    String? rootNoteName,
    double? rootFrequency,
    HarmonicChordType? chordType,
    HarmonicAnalysisResult? activeAnalysis,
    bool? isDroneActive,
    bool? isListening,
  }) {
    return HarmonicTutorSessionEntity(
      rootNoteName: rootNoteName ?? this.rootNoteName,
      rootFrequency: rootFrequency ?? this.rootFrequency,
      chordType: chordType ?? this.chordType,
      activeAnalysis: activeAnalysis ?? this.activeAnalysis,
      isDroneActive: isDroneActive ?? this.isDroneActive,
      isListening: isListening ?? this.isListening,
    );
  }
}
