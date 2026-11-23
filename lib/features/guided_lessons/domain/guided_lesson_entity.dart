/// Categorías didácticas de las lecciones guiadas de práctica instrumental.
enum GuidedLessonCategory {
  fundamentals,
  longTones,
  intervals,
  scales,
  intonation,
}

extension GuidedLessonCategoryExtension on GuidedLessonCategory {
  String get displayName {
    switch (this) {
      case GuidedLessonCategory.fundamentals:
        return 'Fundamentos & Sonoridad';
      case GuidedLessonCategory.longTones:
        return 'Notas Largas & Estabilidad';
      case GuidedLessonCategory.intervals:
        return 'Saltos de Intervalos';
      case GuidedLessonCategory.scales:
        return 'Escalas & Patrones';
      case GuidedLessonCategory.intonation:
        return 'Afinación Fina de Pasajes';
    }
  }
}

/// Paso individual e inmutable dentro de una lección guiada de práctica.
class GuidedLessonStepEntity {
  final int stepIndex;
  final String instruction;
  final String targetNoteName;
  final double targetFrequencyHz;
  final double targetDurationSeconds;
  final double toleranceCents;
  final String feedbackTip;
  final String? writtenNoteName;

  const GuidedLessonStepEntity({
    required this.stepIndex,
    required this.instruction,
    required this.targetNoteName,
    required this.targetFrequencyHz,
    required this.targetDurationSeconds,
    this.toleranceCents = 10.0,
    required this.feedbackTip,
    this.writtenNoteName,
  });

  GuidedLessonStepEntity copyWith({
    int? stepIndex,
    String? instruction,
    String? targetNoteName,
    double? targetFrequencyHz,
    double? targetDurationSeconds,
    double? toleranceCents,
    String? feedbackTip,
    String? writtenNoteName,
  }) {
    return GuidedLessonStepEntity(
      stepIndex: stepIndex ?? this.stepIndex,
      instruction: instruction ?? this.instruction,
      targetNoteName: targetNoteName ?? this.targetNoteName,
      targetFrequencyHz: targetFrequencyHz ?? this.targetFrequencyHz,
      targetDurationSeconds: targetDurationSeconds ?? this.targetDurationSeconds,
      toleranceCents: toleranceCents ?? this.toleranceCents,
      feedbackTip: feedbackTip ?? this.feedbackTip,
      writtenNoteName: writtenNoteName ?? this.writtenNoteName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stepIndex': stepIndex,
      'instruction': instruction,
      'targetNoteName': targetNoteName,
      'targetFrequencyHz': targetFrequencyHz,
      'targetDurationSeconds': targetDurationSeconds,
      'toleranceCents': toleranceCents,
      'feedbackTip': feedbackTip,
      'writtenNoteName': writtenNoteName,
    };
  }

  factory GuidedLessonStepEntity.fromJson(Map<String, dynamic> json) {
    return GuidedLessonStepEntity(
      stepIndex: (json['stepIndex'] as num?)?.toInt() ?? 0,
      instruction: json['instruction'] as String? ?? '',
      targetNoteName: json['targetNoteName'] as String? ?? '--',
      targetFrequencyHz: (json['targetFrequencyHz'] as num?)?.toDouble() ?? 440.0,
      targetDurationSeconds: (json['targetDurationSeconds'] as num?)?.toDouble() ?? 2.0,
      toleranceCents: (json['toleranceCents'] as num?)?.toDouble() ?? 10.0,
      feedbackTip: json['feedbackTip'] as String? ?? '',
      writtenNoteName: json['writtenNoteName'] as String?,
    );
  }
}

/// Entidad que representa una lección completa estructurada por pasos pedagógicos.
class GuidedLessonEntity {
  final String id;
  final String title;
  final String description;
  final GuidedLessonCategory category;
  final String difficulty;
  final List<GuidedLessonStepEntity> steps;

  const GuidedLessonEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.steps,
  });

  int get totalSteps => steps.length;

  GuidedLessonStepEntity get initialStep =>
      steps.isNotEmpty ? steps.first : const GuidedLessonStepEntity(
        stepIndex: 0,
        instruction: 'Sin pasos definidos',
        targetNoteName: '--',
        targetFrequencyHz: 440.0,
        targetDurationSeconds: 2.0,
        feedbackTip: '',
      );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'difficulty': difficulty,
      'totalSteps': totalSteps,
      'steps': steps.map((s) => s.toJson()).toList(),
    };
  }

  factory GuidedLessonEntity.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category'] as String? ?? GuidedLessonCategory.fundamentals.name;
    final parsedCategory = GuidedLessonCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => GuidedLessonCategory.fundamentals,
    );
    final parsedSteps = (json['steps'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(GuidedLessonStepEntity.fromJson)
            .toList() ??
        const <GuidedLessonStepEntity>[];
    return GuidedLessonEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: parsedCategory,
      difficulty: json['difficulty'] as String? ?? 'Principiante',
      steps: parsedSteps,
    );
  }
}

/// Estado reactivo del progreso en tiempo real de una sesión de lección guiada.
class GuidedLessonProgressEntity {
  final GuidedLessonEntity lesson;
  final int currentStepIndex;
  final double sustainedSeconds;
  final bool isStepComplete;
  final bool isLessonComplete;
  final double totalAccumulatedAccuracy;
  final int successfulNotesCount;

  const GuidedLessonProgressEntity({
    required this.lesson,
    required this.currentStepIndex,
    required this.sustainedSeconds,
    required this.isStepComplete,
    required this.isLessonComplete,
    this.totalAccumulatedAccuracy = 1.0,
    this.successfulNotesCount = 0,
  });

  GuidedLessonStepEntity get currentStep {
    if (currentStepIndex >= 0 && currentStepIndex < lesson.steps.length) {
      return lesson.steps[currentStepIndex];
    }
    return lesson.initialStep;
  }

  /// Progreso de sostenimiento del paso actual de 0.0 a 1.0.
  double get stepProgressRatio {
    if (currentStep.targetDurationSeconds <= 0) return 1.0;
    return (sustainedSeconds / currentStep.targetDurationSeconds).clamp(0.0, 1.0);
  }

  /// Progreso general de la lección completa de 0.0 a 1.0.
  double get overallLessonProgressRatio {
    if (lesson.totalSteps == 0) return 1.0;
    final completedSteps = currentStepIndex + (isStepComplete ? 1 : stepProgressRatio);
    return (completedSteps / lesson.totalSteps).clamp(0.0, 1.0);
  }

  GuidedLessonProgressEntity copyWith({
    GuidedLessonEntity? lesson,
    int? currentStepIndex,
    double? sustainedSeconds,
    bool? isStepComplete,
    bool? isLessonComplete,
    double? totalAccumulatedAccuracy,
    int? successfulNotesCount,
  }) {
    return GuidedLessonProgressEntity(
      lesson: lesson ?? this.lesson,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      sustainedSeconds: sustainedSeconds ?? this.sustainedSeconds,
      isStepComplete: isStepComplete ?? this.isStepComplete,
      isLessonComplete: isLessonComplete ?? this.isLessonComplete,
      totalAccumulatedAccuracy: totalAccumulatedAccuracy ?? this.totalAccumulatedAccuracy,
      successfulNotesCount: successfulNotesCount ?? this.successfulNotesCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lesson': lesson.toJson(),
      'currentStepIndex': currentStepIndex,
      'sustainedSeconds': sustainedSeconds,
      'isStepComplete': isStepComplete,
      'isLessonComplete': isLessonComplete,
      'totalAccumulatedAccuracy': totalAccumulatedAccuracy,
      'successfulNotesCount': successfulNotesCount,
      'stepProgressRatio': stepProgressRatio,
      'overallLessonProgressRatio': overallLessonProgressRatio,
    };
  }
}
