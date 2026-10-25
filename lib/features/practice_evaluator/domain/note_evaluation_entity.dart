import 'package:tunner/features/sheet_music/domain/score_tree.dart';

/// Categorización rítmica del ataque de la nota respecto al pulso esperado.
enum NoteTimingCategory {
  onTime,
  early,
  late,
  missed,
}

/// Evaluación cuantitativa individual multidimensional de una nota en el pentagrama.
class NoteEvaluationEntity {
  final HierarchicalNote expectedNote;
  final String soundingExpectedNoteName; // Nota física esperada tras transposición
  final String detectedNoteName;
  final double detectedFrequency;
  final double centsDeviation;
  final NoteTimingCategory timingCategory;
  final int timingDeltaMs; // Desfase temporal en ms (negativo: adelantado, positivo: retrasado)
  final double sustainRatioPercentage; // Porcentaje de duración sostenida (0 a 100%)
  final bool isPitchAccurate;
  final double pitchScore;   // 0.0 a 100.0
  final double rhythmScore;  // 0.0 a 100.0
  final double sustainScore; // 0.0 a 100.0
  final double overallScore; // Ponderado 0.0 a 100.0

  const NoteEvaluationEntity({
    required this.expectedNote,
    required this.soundingExpectedNoteName,
    required this.detectedNoteName,
    required this.detectedFrequency,
    required this.centsDeviation,
    required this.timingCategory,
    required this.timingDeltaMs,
    required this.sustainRatioPercentage,
    required this.isPitchAccurate,
    required this.pitchScore,
    required this.rhythmScore,
    required this.sustainScore,
    required this.overallScore,
  });

  bool get isHit => isPitchAccurate && timingCategory != NoteTimingCategory.missed;
}
