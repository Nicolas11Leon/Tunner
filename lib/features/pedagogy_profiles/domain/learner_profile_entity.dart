/// Tipos de perfiles de aprendizaje soportados en la arquitectura de Tunner.
enum LearnerProfileType {
  childPlayful,
  adultDeliberate,
  conservatoryMastery,
  custom,
}

/// Estilos de retroalimentación formativa y diagnóstica.
enum FeedbackStyle {
  /// Metáforas visuales, refuerzo positivo incondicional y estímulo sin frustración.
  playfulEncouraging,

  /// Enfoque andragógico: explicación biomecánica, causa física del desvío y mentalidad de crecimiento.
  constructiveBiomechanical,

  /// Rigor de conservatorio: valores microtonales exactos, THD y tolerancias de orquesta.
  strictMicrotonal,
}

/// Nivel de densidad visual e información acústica expuesta al usuario.
enum VisualDensityLevel {
  /// Interfaz despejada, símbolos grandes y cero fórmulas complejas que saturen la memoria de trabajo.
  minimalPlayful,

  /// Interfaz balanceada de práctica deliberada, libre de distracciones y con datos esenciales.
  focusedAndragogic,

  /// Consola completa de conservatorio: FFT, serie armónica, jitter, pentagrama vectorial y comparador.
  fullObservatory,
}

/// Entidad inmutable que encapsula la configuración pedagógica adaptativa para el usuario.
class LearnerProfileEntity {
  final LearnerProfileType type;
  final String title;
  final String description;
  final double centsTolerance;
  final FeedbackStyle feedbackStyle;
  final VisualDensityLevel visualDensity;
  final bool enableSmartWait;
  final bool enableScaffoldingFadeOut;

  const LearnerProfileEntity({
    required this.type,
    required this.title,
    required this.description,
    required this.centsTolerance,
    required this.feedbackStyle,
    required this.visualDensity,
    this.enableSmartWait = true,
    this.enableScaffoldingFadeOut = false,
  });

  /// Preset para niños y primera infancia: exploración lúdica, alta tolerancia y andamiaje visual.
  factory LearnerProfileEntity.child() => const LearnerProfileEntity(
        type: LearnerProfileType.childPlayful,
        title: 'Modo Infantil y Lúdico',
        description:
            'Exploración sonora sin frustración. Tolerancia amplia de afinación (+-25c), '
            'metáforas amables y andamiaje progresivo para el desarrollo de la audiación.',
        centsTolerance: 25.0,
        feedbackStyle: FeedbackStyle.playfulEncouraging,
        visualDensity: VisualDensityLevel.minimalPlayful,
        enableSmartWait: true,
        enableScaffoldingFadeOut: true,
      );

  /// Preset andragógico para adultos autodidactas: práctica deliberada, baja carga cognitiva y pautas biomecánicas.
  factory LearnerProfileEntity.adult() => const LearnerProfileEntity(
        type: LearnerProfileType.adultDeliberate,
        title: 'Modo Adulto (Práctica Deliberada)',
        description:
            'Diseño andragógico centrado en la resolución de problemas. Carga cognitiva reducida, '
            'tolerancia moderada (+-10c) y diagnósticos constructivos de apoyo diafragmático.',
        centsTolerance: 10.0,
        feedbackStyle: FeedbackStyle.constructiveBiomechanical,
        visualDensity: VisualDensityLevel.focusedAndragogic,
        enableSmartWait: true,
        enableScaffoldingFadeOut: false,
      );

  /// Preset de conservatorio y concierto: máximo rigor acústico microtonal.
  factory LearnerProfileEntity.conservatory() => const LearnerProfileEntity(
        type: LearnerProfileType.conservatoryMastery,
        title: 'Modo Conservatorio y Maestría',
        description:
            'Estación acústica profesional con tolerancia estricta de conservatorio (+-5c), '
            'análisis de 8 armónicos FFT, centroide espectral y métricas de jitter en tiempo real.',
        centsTolerance: 5.0,
        feedbackStyle: FeedbackStyle.strictMicrotonal,
        visualDensity: VisualDensityLevel.fullObservatory,
        enableSmartWait: false,
        enableScaffoldingFadeOut: false,
      );

  LearnerProfileEntity copyWith({
    LearnerProfileType? type,
    String? title,
    String? description,
    double? centsTolerance,
    FeedbackStyle? feedbackStyle,
    VisualDensityLevel? visualDensity,
    bool? enableSmartWait,
    bool? enableScaffoldingFadeOut,
  }) {
    return LearnerProfileEntity(
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      centsTolerance: centsTolerance ?? this.centsTolerance,
      feedbackStyle: feedbackStyle ?? this.feedbackStyle,
      visualDensity: visualDensity ?? this.visualDensity,
      enableSmartWait: enableSmartWait ?? this.enableSmartWait,
      enableScaffoldingFadeOut:
          enableScaffoldingFadeOut ?? this.enableScaffoldingFadeOut,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'description': description,
        'centsTolerance': centsTolerance,
        'feedbackStyle': feedbackStyle.name,
        'visualDensity': visualDensity.name,
        'enableSmartWait': enableSmartWait,
        'enableScaffoldingFadeOut': enableScaffoldingFadeOut,
      };

  factory LearnerProfileEntity.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'adultDeliberate';
    final profileType = LearnerProfileType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => LearnerProfileType.adultDeliberate,
    );

    final feedbackName = json['feedbackStyle'] as String? ?? 'constructiveBiomechanical';
    final style = FeedbackStyle.values.firstWhere(
      (e) => e.name == feedbackName,
      orElse: () => FeedbackStyle.constructiveBiomechanical,
    );

    final densityName = json['visualDensity'] as String? ?? 'focusedAndragogic';
    final density = VisualDensityLevel.values.firstWhere(
      (e) => e.name == densityName,
      orElse: () => VisualDensityLevel.focusedAndragogic,
    );

    return LearnerProfileEntity(
      type: profileType,
      title: json['title'] as String? ?? 'Perfil Personalizado',
      description: json['description'] as String? ?? '',
      centsTolerance: (json['centsTolerance'] as num?)?.toDouble() ?? 10.0,
      feedbackStyle: style,
      visualDensity: density,
      enableSmartWait: json['enableSmartWait'] as bool? ?? true,
      enableScaffoldingFadeOut: json['enableScaffoldingFadeOut'] as bool? ?? false,
    );
  }
}
