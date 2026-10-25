import 'note_evaluation_entity.dart';

/// Tendencia temporal general de la interpretación del músico.
enum RhythmTendency {
  stable('Estable', 'Pulso rítmico centrado y consistente'),
  rushing('Apresurado (Rushing)', 'Tendencia a anticipar el ataque de las figuras'),
  dragging('Retrasado (Dragging)', 'Tendencia a demorar el ataque de las figuras');

  final String title;
  final String description;

  const RhythmTendency(this.title, this.description);
}

/// Calificación de estudio estilo conservatorio.
enum PerformanceGrade {
  s('S', 'Virtuoso', 'Dominio magistral de afinación, tempo y sostenimiento'),
  a('A', 'Excelente', 'Gran precisión tonal y musicalidad'),
  b('B', 'Competente', 'Buen ritmo con detalles menores en afinación o duración'),
  c('C', 'En Desarrollo', 'Comprensión correcta, requiere estabilizar embocadura y pulso'),
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

/// Informe analítico exhaustivo y multidimensional de una sesión de práctica.
class PracticeReportEntity {
  final String songTitle;
  final String instrumentName;
  final DateTime timestamp;
  final int totalNotes;
  final int hitNotes;
  
  // 1. Afinación (Pitch)
  final double pitchAccuracyPercentage;  // e.g. 96.4%
  final double averageCentsDeviation;    // e.g. 2.4 cents
  
  // 2. Tempo & Pulso (Timing)
  final double rhythmAccuracyPercentage; // e.g. 89.1%
  final double averageTimingDeltaMs;     // e.g. -14.2 ms (rushing) o +18.0 ms (dragging)
  final RhythmTendency rhythmTendency;
  final String rhythmTendencyDescription;

  // 3. Duración de Figuras (Sustain)
  final double sustainAccuracyPercentage; // e.g. 91.5%

  // Puntaje Global Ponderado
  final double overallScore; // 0.0 - 100.0
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
    this.instrumentName = 'Instrumento Estándar',
    required this.timestamp,
    required this.totalNotes,
    required this.hitNotes,
    required this.pitchAccuracyPercentage,
    required this.averageCentsDeviation,
    required this.rhythmAccuracyPercentage,
    this.averageTimingDeltaMs = 0.0,
    this.rhythmTendency = RhythmTendency.stable,
    this.rhythmTendencyDescription = 'Pulso rítmico centrado y consistente',
    this.sustainAccuracyPercentage = 100.0,
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
