import 'note_evaluation_entity.dart';

/// Calificación de estudio estilo conservatorio.
enum PerformanceGrade {
  s('S', 'Virtuoso', 'Dominio magistral de afinación y pulso'),
  a('A', 'Excelente', 'Gran precisión tonal y musicalidad'),
  b('B', 'Competente', 'Buen ritmo con detalles menores en afinación'),
  c('C', 'En Desarrollo', 'Comprensión correcta, requiere estabilizar embocadura'),
  d('D', 'Reintentar', 'Se recomienda practicar con Smart Wait a menor BPM');

  final String letter;
  final String title;
  final String description;

  const PerformanceGrade(this.letter, this.title, this.description);

  static PerformanceGrade fromScore(double score) {
    if (score >= 95.0) return PerformanceGrade.s;
    if (score >= 85.0) return PerformanceGrade.a;
    if (score >= 75.0) return PerformanceGrade.b;
    if (score >= 60.0) return PerformanceGrade.c;
    return PerformanceGrade.d;
  }
}

/// Informe analítico exhaustivo de una sesión de práctica o estudio de canción.
class PracticeReportEntity {
  final String songTitle;
  final DateTime timestamp;
  final int totalNotes;
  final int hitNotes;
  final double pitchAccuracyPercentage;  // e.g. 96.4%
  final double rhythmAccuracyPercentage; // e.g. 89.1%
  final double averageCentsDeviation;    // e.g. 2.4 cents
  final double overallScore;             // 0.0 - 100.0
  final PerformanceGrade grade;
  final List<NoteEvaluationEntity> evaluations;
  
  /// Desglose de precisión por nota (ej: {"Do4": 98.0, "Mi4": 74.5})
  final Map<String, double> noteAccuracyMap;
  
  /// Notas con menor precisión detectada que ameritan repaso
  final List<String> criticalNotes;
  
  /// Notas ejecutadas con máxima solidez
  final List<String> masteredNotes;

  /// Variación porcentual comparada con la sesión anterior (+3.4% mejora, -1.2% desvío)
  final double trendDeltaPercentage;
  final String trendAnalysisText;

  const PracticeReportEntity({
    required this.songTitle,
    required this.timestamp,
    required this.totalNotes,
    required this.hitNotes,
    required this.pitchAccuracyPercentage,
    required this.rhythmAccuracyPercentage,
    required this.averageCentsDeviation,
    required this.overallScore,
    required this.grade,
    required this.evaluations,
    required this.noteAccuracyMap,
    required this.criticalNotes,
    required this.masteredNotes,
    this.trendDeltaPercentage = 0.0,
    this.trendAnalysisText = 'Primera sesión registrada para esta obra',
  });
}
