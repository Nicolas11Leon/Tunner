import 'dart:math' as math;

/// Categoría pedagógica del ejercicio de entrenamiento auditivo.
enum EarTrainingCategory {
  /// Discriminación de intervalos melódicos o armónicos.
  interval,

  /// Reconocimiento de tríadas, tétradas y tipos de acordes.
  chord,

  /// Discriminación microtonal (cuartos de tono, comas pitagóricas).
  microtone,

  /// Identificación de tono absoluto o frecuencia exacta.
  pitch,
}

/// Entidad inmutable que representa un ítem o concepto de entrenamiento auditivo
/// sujeto al algoritmo de repetición espaciada y curva de retención de Ebbinghaus.
class EarTrainingItemEntity {
  final String id;
  final String name;
  final EarTrainingCategory category;
  final double semitones;
  final double centsDeviation;

  /// Estabilidad de la memoria en días (S en la curva de Ebbinghaus).
  final double stabilityDays;

  /// Factor de facilidad (Ease Factor EF >= 1.30).
  final double easeFactor;

  /// Número de repasos exitosos consecutivos.
  final int repetitions;

  /// Número total de fallos acumulados (lapses).
  final int lapses;

  /// Número total de intentos evaluados.
  final int totalAttempts;

  /// Error promedio acumulado en cents.
  final double averageCentsError;

  /// Fecha y hora de la última revisión realizada.
  final DateTime? lastReviewDate;

  /// Fecha y hora calculada para el próximo repaso óptimo.
  final DateTime nextReviewDate;

  const EarTrainingItemEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.semitones,
    required this.centsDeviation,
    this.stabilityDays = 1.0,
    this.easeFactor = 2.50,
    this.repetitions = 0,
    this.lapses = 0,
    this.totalAttempts = 0,
    this.averageCentsError = 0.0,
    this.lastReviewDate,
    required this.nextReviewDate,
  })  : assert(stabilityDays > 0.0, 'La estabilidad debe ser un valor positivo'),
        assert(easeFactor >= 1.30, 'El factor de facilidad no debe ser menor a 1.30'),
        assert(repetitions >= 0, 'Las repeticiones deben ser no negativas'),
        assert(lapses >= 0, 'Los fallos deben ser no negativos'),
        assert(totalAttempts >= 0, 'El total de intentos debe ser no negativo');

  /// Calcula la probabilidad de retención cognitiva R(t) = exp(-t / S)
  /// en un momento temporal dado [now]. Retorna un valor en el rango (0.0, 1.0].
  double retentionAt(DateTime now) {
    if (lastReviewDate == null) {
      // Si nunca ha sido revisado, la retención es mínima para forzar el primer repaso
      return 0.10;
    }

    final durationSinceLastReview = now.difference(lastReviewDate!);
    final elapsedDays = durationSinceLastReview.inMicroseconds / (1000000.0 * 3600.0 * 24.0);

    if (elapsedDays <= 0.0) {
      return 1.0;
    }

    // Curva de Ebbinghaus: R(t) = e^(-t / S)
    final retention = math.exp(-elapsedDays / stabilityDays);
    return retention.clamp(0.0, 1.0);
  }

  /// Indica si el ítem requiere revisión inmediata frente a un umbral objetivo (por defecto 0.90).
  bool isDue(DateTime now, {double targetRetention = 0.90}) {
    if (lastReviewDate == null) return true;
    return retentionAt(now) <= targetRetention || now.isAfter(nextReviewDate);
  }

  /// Crea una copia inmutable actualizando únicamente los campos provistos.
  EarTrainingItemEntity copyWith({
    String? id,
    String? name,
    EarTrainingCategory? category,
    double? semitones,
    double? centsDeviation,
    double? stabilityDays,
    double? easeFactor,
    int? repetitions,
    int? lapses,
    int? totalAttempts,
    double? averageCentsError,
    DateTime? lastReviewDate,
    DateTime? nextReviewDate,
  }) {
    return EarTrainingItemEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      semitones: semitones ?? this.semitones,
      centsDeviation: centsDeviation ?? this.centsDeviation,
      stabilityDays: stabilityDays ?? this.stabilityDays,
      easeFactor: easeFactor ?? this.easeFactor,
      repetitions: repetitions ?? this.repetitions,
      lapses: lapses ?? this.lapses,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      averageCentsError: averageCentsError ?? this.averageCentsError,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EarTrainingItemEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          category == other.category &&
          semitones == other.semitones &&
          centsDeviation == other.centsDeviation &&
          stabilityDays == other.stabilityDays &&
          easeFactor == other.easeFactor &&
          repetitions == other.repetitions &&
          lapses == other.lapses &&
          totalAttempts == other.totalAttempts &&
          averageCentsError == other.averageCentsError &&
          lastReviewDate == other.lastReviewDate &&
          nextReviewDate == other.nextReviewDate;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        category,
        semitones,
        centsDeviation,
        stabilityDays,
        easeFactor,
        repetitions,
        lapses,
        totalAttempts,
        averageCentsError,
        lastReviewDate,
        nextReviewDate,
      );

  @override
  String toString() =>
      'EarTrainingItemEntity(id: $id, name: $name, stability: ${stabilityDays.toStringAsFixed(2)}d, '
      'EF: ${easeFactor.toStringAsFixed(2)}, reps: $repetitions)';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'semitones': semitones,
      'centsDeviation': centsDeviation,
      'stabilityDays': stabilityDays,
      'easeFactor': easeFactor,
      'repetitions': repetitions,
      'lapses': lapses,
      'totalAttempts': totalAttempts,
      'averageCentsError': averageCentsError,
      'lastReviewDate': lastReviewDate?.toIso8601String(),
      'nextReviewDate': nextReviewDate.toIso8601String(),
    };
  }

  factory EarTrainingItemEntity.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category'] as String? ?? EarTrainingCategory.interval.name;
    final parsedCategory = EarTrainingCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => EarTrainingCategory.interval,
    );
    return EarTrainingItemEntity(
      id: json['id'] as String? ?? 'unknown',
      name: json['name'] as String? ?? 'Ejercicio',
      category: parsedCategory,
      semitones: (json['semitones'] as num?)?.toDouble() ?? 0.0,
      centsDeviation: (json['centsDeviation'] as num?)?.toDouble() ?? 0.0,
      stabilityDays: (json['stabilityDays'] as num?)?.toDouble() ?? 1.0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.50,
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      lapses: (json['lapses'] as num?)?.toInt() ?? 0,
      totalAttempts: (json['totalAttempts'] as num?)?.toInt() ?? 0,
      averageCentsError: (json['averageCentsError'] as num?)?.toDouble() ?? 0.0,
      lastReviewDate: json['lastReviewDate'] != null
          ? DateTime.tryParse(json['lastReviewDate'] as String)
          : null,
      nextReviewDate: DateTime.tryParse(json['nextReviewDate'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
