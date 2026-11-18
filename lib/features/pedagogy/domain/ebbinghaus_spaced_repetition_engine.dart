import 'dart:math' as math;
import 'ear_training_item_entity.dart';
export 'ear_training_item_entity.dart';

/// Resultado detallado de la evaluación de una respuesta en el motor Ebbinghaus.
class EarTrainingEvaluationResult {
  final EarTrainingItemEntity updatedItem;
  final int qualityGrade;
  final double previousRetention;
  final double nextRetentionProjected;
  final double centsError;
  final double responseTimeSeconds;
  final String cognitiveFeedback;

  const EarTrainingEvaluationResult({
    required this.updatedItem,
    required this.qualityGrade,
    required this.previousRetention,
    required this.nextRetentionProjected,
    required this.centsError,
    required this.responseTimeSeconds,
    required this.cognitiveFeedback,
  });

  @override
  String toString() =>
      'EvaluationResult(item: ${updatedItem.id}, grade: $qualityGrade/5, '
      'stability: ${updatedItem.stabilityDays.toStringAsFixed(2)}d, '
      'feedback: $cognitiveFeedback)';
}

/// Motor de aprendizaje adaptativo de entrenamiento auditivo basado en la curva de Ebbinghaus
/// y el algoritmo continuo de repetición espaciada SM-2 adaptado a microcents.
class EbbinghausSpacedRepetitionEngine {
  final Map<String, EarTrainingItemEntity> _items = {};

  /// Inicializa el motor con un banco opcional de ejercicios. Si no se provee,
  /// se precarga el catálogo canónico estándar de conservatorio.
  EbbinghausSpacedRepetitionEngine({List<EarTrainingItemEntity>? initialItems}) {
    if (initialItems != null) {
      for (final item in initialItems) {
        _items[item.id] = item;
      }
    } else {
      _loadCanonicalExerciseBank();
    }
  }

  /// Retorna una lista no modificable de todos los ejercicios registrados.
  List<EarTrainingItemEntity> get allItems => List.unmodifiable(_items.values);

  /// Obtiene un ítem por su identificador único o `null` si no existe.
  EarTrainingItemEntity? getItem(String id) => _items[id];

  /// Agrega o reemplaza un ítem en el banco de ejercicios.
  void addItem(EarTrainingItemEntity item) {
    _items[item.id] = item;
  }

  /// Carga el catálogo pedagógico canónico que incluye todos los intervalos estándar,
  /// microtonos y acordes fundamentales.
  void _loadCanonicalExerciseBank() {
    final now = DateTime.now();

    final canonicalItems = <EarTrainingItemEntity>[
      EarTrainingItemEntity(
        id: 'interval_m2',
        name: 'Segunda Menor',
        category: EarTrainingCategory.interval,
        semitones: 1.0,
        centsDeviation: 100.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'interval_M2',
        name: 'Segunda Mayor',
        category: EarTrainingCategory.interval,
        semitones: 2.0,
        centsDeviation: 200.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'interval_m3',
        name: 'Tercera Menor',
        category: EarTrainingCategory.interval,
        semitones: 3.0,
        centsDeviation: 300.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'interval_M3',
        name: 'Tercera Mayor',
        category: EarTrainingCategory.interval,
        semitones: 4.0,
        centsDeviation: 400.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'interval_P4',
        name: 'Cuarta Justa',
        category: EarTrainingCategory.interval,
        semitones: 5.0,
        centsDeviation: 500.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'interval_TT',
        name: 'Tritono (Quinta Disminuida)',
        category: EarTrainingCategory.interval,
        semitones: 6.0,
        centsDeviation: 600.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'interval_P5',
        name: 'Quinta Justa',
        category: EarTrainingCategory.interval,
        semitones: 7.0,
        centsDeviation: 700.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'interval_m6',
        name: 'Sexta Menor',
        category: EarTrainingCategory.interval,
        semitones: 8.0,
        centsDeviation: 800.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'interval_M6',
        name: 'Sexta Mayor',
        category: EarTrainingCategory.interval,
        semitones: 9.0,
        centsDeviation: 900.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'interval_m7',
        name: 'Séptima Menor',
        category: EarTrainingCategory.interval,
        semitones: 10.0,
        centsDeviation: 1000.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'interval_M7',
        name: 'Séptima Mayor',
        category: EarTrainingCategory.interval,
        semitones: 11.0,
        centsDeviation: 1100.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'interval_P8',
        name: 'Octava Justa',
        category: EarTrainingCategory.interval,
        semitones: 12.0,
        centsDeviation: 1200.0,
        nextReviewDate: now,
      ),
      // Microtonos
      EarTrainingItemEntity(
        id: 'microtone_quarter_tone',
        name: 'Cuarto de Tono (Semitono Árabe)',
        category: EarTrainingCategory.microtone,
        semitones: 0.5,
        centsDeviation: 50.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'microtone_pythagorean_comma',
        name: 'Coma Pitagórica',
        category: EarTrainingCategory.microtone,
        semitones: 0.24,
        centsDeviation: 23.46,
        nextReviewDate: now,
      ),
      // Tríadas
      EarTrainingItemEntity(
        id: 'chord_triad_major',
        name: 'Tríada Mayor',
        category: EarTrainingCategory.chord,
        semitones: 4.0,
        centsDeviation: 400.0,
        nextReviewDate: now,
      ),
      EarTrainingItemEntity(
        id: 'chord_triad_minor',
        name: 'Tríada Menor',
        category: EarTrainingCategory.chord,
        semitones: 3.0,
        centsDeviation: 300.0,
        nextReviewDate: now,
      ),
    ];

    for (final item in canonicalItems) {
      _items[item.id] = item;
    }
  }

  /// Obtiene la lista de ejercicios que requieren revisión inmediata en un momento dado [now],
  /// ordenados de menor a mayor retención (mayor urgencia pedagógica primero).
  List<EarTrainingItemEntity> getDueItems({
    DateTime? now,
    double targetRetention = 0.90,
  }) {
    final referenceTime = now ?? DateTime.now();
    final due = _items.values.where((item) => item.isDue(referenceTime, targetRetention: targetRetention)).toList();

    due.sort((a, b) => a.retentionAt(referenceTime).compareTo(b.retentionAt(referenceTime)));
    return due;
  }

  /// Calcula la calificación de calidad q in [0, 5] en función de la corrección binaria,
  /// la desviación microtonal en cents y la latencia temporal de reconocimiento.
  int calculateQualityGrade({
    required bool isCorrect,
    required double centsError,
    required double responseTimeSeconds,
  }) {
    final absCents = centsError.abs();

    if (!isCorrect) {
      // Si la respuesta fue incorrecta pero el error es de un semitono o microtono cercano
      if (absCents <= 100.0) {
        return 2; // Error menor (cercanía armónica)
      } else if (absCents <= 200.0) {
        return 1; // Error moderado
      } else {
        return 0; // Fallo absoluto o confusión tonal
      }
    }

    // Respuesta correcta: ponderar por tiempo y afinación acústica
    if (absCents <= 5.0 && responseTimeSeconds <= 2.0) {
      return 5; // Reconocimiento instantáneo con afinación pura de conservatorio
    } else if (absCents <= 15.0 && responseTimeSeconds <= 4.0) {
      return 4; // Respuesta correcta con microvacilación aceptable
    } else {
      return 3; // Respuesta correcta pero con esfuerzo temporal o desviación microtonal
    }
  }

  /// Evalúa una respuesta del estudiante, actualiza la estabilidad y recalcula
  /// la fecha óptima del próximo repaso según la curva de retención de Ebbinghaus.
  EarTrainingEvaluationResult submitAnswer(
    String itemId, {
    required bool isCorrect,
    required double centsError,
    required double responseTimeSeconds,
    DateTime? timestamp,
  }) {
    final item = _items[itemId];
    if (item == null) {
      throw ArgumentError('No existe ningun ejercicio registrado con el ID: $itemId');
    }

    final now = timestamp ?? DateTime.now();
    final previousRetention = item.retentionAt(now);

    final q = calculateQualityGrade(
      isCorrect: isCorrect,
      centsError: centsError,
      responseTimeSeconds: responseTimeSeconds,
    );

    // 1. Modulación del factor de facilidad (Ease Factor):
    // EF' = max(1.30, EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
    final double deltaEf = 0.1 - (5 - q) * (0.08 + (5 - q) * 0.02);
    final double newEaseFactor = math.max(1.30, item.easeFactor + deltaEf);

    double newStabilityDays;
    int newRepetitions;
    int newLapses = item.lapses;
    DateTime nextReview;
    String feedback;

    if (q >= 3) {
      // Repaso exitoso
      newRepetitions = item.repetitions + 1;
      if (newRepetitions == 1) {
        newStabilityDays = 1.0;
      } else if (newRepetitions == 2) {
        newStabilityDays = 3.0;
      } else {
        newStabilityDays = item.stabilityDays * newEaseFactor;
      }

      // Intervalo óptimo de retención al 90%: t = -S * ln(0.90) ~= S * 0.10536 días
      // Para repaso espaciado estándar, la próxima revisión se fija en S días
      nextReview = now.add(Duration(microseconds: (newStabilityDays * 86400 * 1000000).round()));

      if (q == 5) {
        feedback = 'Consolidacion perfecta: afinacion pura y reflejo instantaneo.';
      } else if (q == 4) {
        feedback = 'Respuesta correcta y estable. Curva de memoria fortalecida.';
      } else {
        feedback = 'Acierto con vacilacion. Se reforzara en la siguiente sesion.';
      }
    } else {
      // Fallo pedagógico
      newRepetitions = 0;
      newLapses++;
      // Reducción drástica de estabilidad para forzar reaprendizaje
      newStabilityDays = math.max(0.15, item.stabilityDays * 0.35);
      // Repaso inmediato en minutos u horas (ej. 4 horas)
      final reviewHours = math.max(1.0, newStabilityDays * 24.0 * 0.25);
      nextReview = now.add(Duration(microseconds: (reviewHours * 3600 * 1000000).round()));
      feedback = 'Fallo en la identificacion. Reprogramado para refuerzo inmediato.';
    }

    final newAttempts = item.totalAttempts + 1;
    final newAverageCents = (item.averageCentsError * item.totalAttempts + centsError.abs()) / newAttempts;

    final updated = item.copyWith(
      stabilityDays: newStabilityDays,
      easeFactor: newEaseFactor,
      repetitions: newRepetitions,
      lapses: newLapses,
      totalAttempts: newAttempts,
      averageCentsError: newAverageCents,
      lastReviewDate: now,
      nextReviewDate: nextReview,
    );

    _items[itemId] = updated;

    final nextRetention = updated.retentionAt(now);

    return EarTrainingEvaluationResult(
      updatedItem: updated,
      qualityGrade: q,
      previousRetention: previousRetention,
      nextRetentionProjected: nextRetention,
      centsError: centsError,
      responseTimeSeconds: responseTimeSeconds,
      cognitiveFeedback: feedback,
    );
  }

  /// Calcula el promedio de retención de todos los ejercicios del catálogo en un momento dado [now].
  double overallRetentionAverage(DateTime now) {
    if (_items.isEmpty) return 1.0;
    double sum = 0.0;
    for (final item in _items.values) {
      sum += item.retentionAt(now);
    }
    return sum / _items.length;
  }

  /// Reinicia el catálogo cargando los ítems canónicos originales en estado virgen.
  void reset() {
    _items.clear();
    _loadCanonicalExerciseBank();
  }
}
