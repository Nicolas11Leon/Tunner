import 'musical_interval.dart';

/// Pregunta inmutable que define un ejercicio de reconocimiento de intervalos auditivos.
class EarTrainingQuestion {
  final String id;
  final String baseNoteName;
  final double baseFrequencyHz;
  final double targetFrequencyHz;
  final MusicalInterval targetInterval;
  final bool isAscending;
  final List<MusicalInterval> options;
  final int correctOptionIndex;

  const EarTrainingQuestion({
    required this.id,
    required this.baseNoteName,
    required this.baseFrequencyHz,
    required this.targetFrequencyHz,
    required this.targetInterval,
    required this.isAscending,
    required this.options,
    required this.correctOptionIndex,
  });

  /// Retorna la opción correcta a partir del índice.
  MusicalInterval get correctInterval => options[correctOptionIndex];
}

/// Nivel de maestría y calificación acústica de una respuesta.
enum PerformanceGrade {
  /// Precisión legendaria (desvío < 5 cents o respuesta inmediata < 1.5s).
  sGrade('S', 'Maestría de Conservatorio (Precisión Absoluta)'),

  /// Excelente precisión (desvío < 15 cents o respuesta < 3s).
  aGrade('A', 'Excelente Discriminación Auditiva'),

  /// Buena aproximación (desvío < 30 cents o respuesta < 5s).
  bGrade('B', 'Buena Respuesta (Afinación en Progreso)'),

  /// Aceptable o fuera de afinación.
  cGrade('C', 'Revisar Afinación / Repetir Estímulo'),

  /// Error de intervalo o desvío mayor a 50 cents.
  fGrade('F', 'Intervalo Incorrecto');

  final String letter;
  final String description;

  const PerformanceGrade(this.letter, this.description);
}

/// Resultado de la evaluación de una respuesta del estudiante.
class EarTrainingAnswerResult {
  final bool isCorrect;
  final MusicalInterval selectedInterval;
  final MusicalInterval targetInterval;
  final double centsDeviation;
  final int responseTimeMs;
  final int scoreAwarded;
  final PerformanceGrade grade;
  final String feedbackMessage;

  const EarTrainingAnswerResult({
    required this.isCorrect,
    required this.selectedInterval,
    required this.targetInterval,
    required this.centsDeviation,
    required this.responseTimeMs,
    required this.scoreAwarded,
    required this.grade,
    required this.feedbackMessage,
  });

  /// Factory helper para calcular la calificación y puntaje según tiempo y exactitud.
  factory EarTrainingAnswerResult.evaluate({
    required MusicalInterval selected,
    required MusicalInterval target,
    required double centsDeviation,
    required int responseTimeMs,
    required int currentStreak,
  }) {
    final isCorrect = selected == target;

    if (!isCorrect) {
      return EarTrainingAnswerResult(
        isCorrect: false,
        selectedInterval: selected,
        targetInterval: target,
        centsDeviation: centsDeviation,
        responseTimeMs: responseTimeMs,
        scoreAwarded: 0,
        grade: PerformanceGrade.fGrade,
        feedbackMessage:
            'Respuesta incorrecta. Seleccionaste ${selected.displayName} (${selected.shortName}), pero el intervalo era ${target.displayName} (${target.shortName}).',
      );
    }

    // Cálculo de calificación según desvío absoluto en cents
    final absCents = centsDeviation.abs();
    PerformanceGrade grade;
    int baseScore;

    if (absCents <= 5.0 && responseTimeMs <= 2500) {
      grade = PerformanceGrade.sGrade;
      baseScore = 150;
    } else if (absCents <= 15.0 && responseTimeMs <= 4000) {
      grade = PerformanceGrade.aGrade;
      baseScore = 120;
    } else if (absCents <= 30.0) {
      grade = PerformanceGrade.bGrade;
      baseScore = 90;
    } else {
      grade = PerformanceGrade.cGrade;
      baseScore = 60;
    }

    // Bonus por racha de aciertos consecutivos (streak multiplier)
    final streakBonus = currentStreak > 1 ? (currentStreak * 10) : 0;
    final totalScore = baseScore + streakBonus;

    final feedback = absCents < 5.0
        ? '¡Perfecto! Desvío imperceptible (${centsDeviation.toStringAsFixed(1)} cents) en ${(responseTimeMs / 1000).toStringAsFixed(2)}s.'
        : '¡Correcto! ${target.displayName}. Desvío de ${centsDeviation.toStringAsFixed(1)} cents.';

    return EarTrainingAnswerResult(
      isCorrect: true,
      selectedInterval: selected,
      targetInterval: target,
      centsDeviation: centsDeviation,
      responseTimeMs: responseTimeMs,
      scoreAwarded: totalScore,
      grade: grade,
      feedbackMessage: feedback,
    );
  }
}
