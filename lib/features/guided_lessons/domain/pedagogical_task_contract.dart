import 'task_taxonomy_code.dart';

/// Estado de progreso y completitud de una tarea pedagógica.
enum TaskCompletionStatus {
  notStarted('not_started', 'Sin Iniciar', 'Pendiente de práctica'),
  inProgress('in_progress', 'En Progreso', 'Sesión iniciada'),
  completed('completed', 'Completada', 'Requisitos básicos cumplidos'),
  mastered('mastered', 'Dominada', 'Maestría con Grado S o A');

  final String id;
  final String displayName;
  final String description;

  const TaskCompletionStatus(this.id, this.displayName, this.description);
}

/// Nivel de maestría y calificación acústica/rítmica obtenida en la tarea.
enum TaskGrade {
  s('S', 'Maestría de Conservatorio (Precisión Absoluta)', 1.0),
  a('A', 'Excelente Rendimiento Técnico', 0.9),
  b('B', 'Buen Desempeño (En Progreso)', 0.75),
  c('C', 'Aceptable (Requiere Refuerzo)', 0.6),
  none('-', 'Sin Calificar', 0.0);

  final String letter;
  final String description;
  final double minimumAccuracyRatio;

  const TaskGrade(this.letter, this.description, this.minimumAccuracyRatio);
}

/// Paso elemental dentro de una tarea pedagógica.
class TaskStep {
  final int index;
  final String instruction;
  final String noteOrTarget;
  final double frequencyHz;
  final double targetDurationSeconds;
  final double toleranceCents;
  final String hint;

  const TaskStep({
    required this.index,
    required this.instruction,
    required this.noteOrTarget,
    required this.frequencyHz,
    required this.targetDurationSeconds,
    this.toleranceCents = 10.0,
    required this.hint,
  });

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'instruction': instruction,
      'noteOrTarget': noteOrTarget,
      'frequencyHz': frequencyHz,
      'targetDurationSeconds': targetDurationSeconds,
      'toleranceCents': toleranceCents,
      'hint': hint,
    };
  }

  factory TaskStep.fromJson(Map<String, dynamic> json) {
    return TaskStep(
      index: (json['index'] as num?)?.toInt() ?? 0,
      instruction: json['instruction'] as String? ?? '',
      noteOrTarget: json['noteOrTarget'] as String? ?? '',
      frequencyHz: (json['frequencyHz'] as num?)?.toDouble() ?? 440.0,
      targetDurationSeconds: (json['targetDurationSeconds'] as num?)?.toDouble() ?? 2.0,
      toleranceCents: (json['toleranceCents'] as num?)?.toDouble() ?? 10.0,
      hint: json['hint'] as String? ?? '',
    );
  }
}

/// Enlace declarativo de conexión entre puertos de herramientas en una tarea conjunta.
class TaskInterconnectionLink {
  final String sourcePortId;
  final String destinationPortId;
  final String? description;

  const TaskInterconnectionLink({
    required this.sourcePortId,
    required this.destinationPortId,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'sourcePortId': sourcePortId,
      'destinationPortId': destinationPortId,
      'description': description,
    };
  }

  factory TaskInterconnectionLink.fromJson(Map<String, dynamic> json) {
    return TaskInterconnectionLink(
      sourcePortId: json['sourcePortId'] as String? ?? '',
      destinationPortId: json['destinationPortId'] as String? ?? '',
      description: json['description'] as String?,
    );
  }
}

/// Contrato base inmutable para cualquier tarea pedagógica en Tunner.
///
/// Aplica los principios de Segregación de Interfaces y Sustitución de Liskov:
/// Cualquier tipo de tarea (intervalos, polirritmias, afinación, partituras)
/// implementa este contrato permitiendo manipulación e indexación polimórfica.
abstract class PedagogicalTaskEntity implements Comparable<PedagogicalTaskEntity> {
  TaskTaxonomyCode get code;
  String get title;
  String get description;
  int get estimatedDurationMinutes;
  List<TaskStep> get steps;
  List<String> get searchTags;
  TaskCompletionStatus get status;
  TaskGrade get bestGrade;
  String? get targetInstrumentId;
  List<String> get requiredToolIds;
  List<TaskInterconnectionLink> get interconnectionLinks;

  /// Indica si la tarea es una tarea conjunta que orquesta 3 o más herramientas en simultáneo.
  bool get isMultiTool => requiredToolIds.length >= 3;

  bool get isCompleted =>
      status == TaskCompletionStatus.completed || status == TaskCompletionStatus.mastered;

  int get totalSteps => steps.length;

  @override
  int compareTo(PedagogicalTaskEntity other) => code.compareTo(other.code);

  Map<String, dynamic> toJson() {
    return {
      'code': code.formatted,
      'title': title,
      'description': description,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'steps': steps.map((s) => s.toJson()).toList(),
      'searchTags': searchTags,
      'status': status.id,
      'bestGrade': bestGrade.letter,
      'targetInstrumentId': targetInstrumentId,
      'requiredToolIds': requiredToolIds,
      'interconnectionLinks': interconnectionLinks.map((l) => l.toJson()).toList(),
      'isMultiTool': isMultiTool,
      'isCompleted': isCompleted,
      'totalSteps': totalSteps,
    };
  }
}

/// Implementación concreta estándar inmutable de una tarea pedagógica.
class StandardPedagogicalTask extends PedagogicalTaskEntity {
  @override
  final TaskTaxonomyCode code;
  @override
  final String title;
  @override
  final String description;
  @override
  final int estimatedDurationMinutes;
  @override
  final List<TaskStep> steps;
  @override
  final List<String> searchTags;
  @override
  final TaskCompletionStatus status;
  @override
  final TaskGrade bestGrade;
  @override
  final String? targetInstrumentId;
  @override
  final List<String> requiredToolIds;
  @override
  final List<TaskInterconnectionLink> interconnectionLinks;

  StandardPedagogicalTask({
    required this.code,
    required this.title,
    required this.description,
    this.estimatedDurationMinutes = 5,
    this.steps = const [],
    this.searchTags = const [],
    this.status = TaskCompletionStatus.notStarted,
    this.bestGrade = TaskGrade.none,
    this.targetInstrumentId,
    this.requiredToolIds = const [],
    this.interconnectionLinks = const [],
  });

  StandardPedagogicalTask copyWith({
    TaskTaxonomyCode? code,
    String? title,
    String? description,
    int? estimatedDurationMinutes,
    List<TaskStep>? steps,
    List<String>? searchTags,
    TaskCompletionStatus? status,
    TaskGrade? bestGrade,
    String? targetInstrumentId,
    List<String>? requiredToolIds,
    List<TaskInterconnectionLink>? interconnectionLinks,
  }) {
    return StandardPedagogicalTask(
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      steps: steps ?? this.steps,
      searchTags: searchTags ?? this.searchTags,
      status: status ?? this.status,
      bestGrade: bestGrade ?? this.bestGrade,
      targetInstrumentId: targetInstrumentId ?? this.targetInstrumentId,
      requiredToolIds: requiredToolIds ?? this.requiredToolIds,
      interconnectionLinks: interconnectionLinks ?? this.interconnectionLinks,
    );
  }

  factory StandardPedagogicalTask.fromJson(Map<String, dynamic> json) {
    final codeStr = json['code'] as String? ?? 'EAR.01.INTV.001';
    final parsedCode = TaskTaxonomyCode.tryParse(codeStr) ??
        TaskTaxonomyCode.parse('EAR.01.INTV.001');

    final statusId = json['status'] as String? ?? TaskCompletionStatus.notStarted.id;
    final parsedStatus = TaskCompletionStatus.values.firstWhere(
      (s) => s.id == statusId || s.name == statusId,
      orElse: () => TaskCompletionStatus.notStarted,
    );

    final gradeStr = json['bestGrade'] as String? ?? TaskGrade.none.letter;
    final parsedGrade = TaskGrade.values.firstWhere(
      (g) => g.letter == gradeStr || g.name == gradeStr,
      orElse: () => TaskGrade.none,
    );

    final parsedSteps = (json['steps'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(TaskStep.fromJson)
            .toList() ??
        const <TaskStep>[];

    final parsedLinks = (json['interconnectionLinks'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(TaskInterconnectionLink.fromJson)
            .toList() ??
        const <TaskInterconnectionLink>[];

    return StandardPedagogicalTask(
      code: parsedCode,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      estimatedDurationMinutes: (json['estimatedDurationMinutes'] as num?)?.toInt() ?? 5,
      steps: parsedSteps,
      searchTags: (json['searchTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      status: parsedStatus,
      bestGrade: parsedGrade,
      targetInstrumentId: json['targetInstrumentId'] as String?,
      requiredToolIds: (json['requiredToolIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      interconnectionLinks: parsedLinks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StandardPedagogicalTask &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '[${code.formatted}] $title (${bestGrade.letter})';
}
