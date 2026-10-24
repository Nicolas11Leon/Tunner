import 'package:tunner/features/sheet_music/domain/score_tree.dart';

/// Categorización rítmica del ataque de la nota respecto al pulso esperado.
enum NoteTimingCategory {
  onTime,
  early,
  late,
  missed,
}

/// Evaluación cuantitativa individual de una nota en el pentagrama.
class NoteEvaluationEntity {
  final HierarchicalNote expectedNote;
  final String detectedNoteName;
  final double detectedFrequency;
  final double centsDeviation;
  final NoteTimingCategory timingCategory;
  final int timingDeltaMs;
  final bool isPitchAccurate;
  final double pitchScore;   // 0.0 a 100.0
  final double rhythmScore;  // 0.0 a 100.0
  final double overallScore; // Ponderado 0.0 a 100.0

  const NoteEvaluationEntity({
    required this.expectedNote,
    required this.detectedNoteName,
    required this.detectedFrequency,
    required this.centsDeviation,
    required this.timingCategory,
    required this.timingDeltaMs,
    required this.isPitchAccurate,
    required this.pitchScore,
    required this.rhythmScore,
    required this.overallScore,
  });

  bool get isHit => isPitchAccurate && timingCategory != NoteTimingCategory.missed;
}
