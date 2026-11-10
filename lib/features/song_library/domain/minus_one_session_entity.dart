import '../../practice_evaluator/domain/note_evaluation_entity.dart';

/// Entidad de dominio pura que representa una sesion de practica con ensamble virtual "Minus-One".
class MinusOneSessionEntity {
  /// Identificador de la obra o ejercicio polifonico.
  final String songId;

  /// Identificador de la pista que interpreta el estudiante (la pista que se silencia o audita).
  final String userTrackId;

  /// True si el modo de ensamble Minus-One se encuentra activo.
  final bool isMinusOneActive;

  /// True si la pista del instrumento del usuario esta totalmente en silencio.
  final bool isMutedUserTrack;

  /// Ganancia de la pista de usuario cuando se utiliza como referencia auditiva atenuada (0.0 = silencio total).
  final double guideTrackVolume;

  /// Lista cronologica de notas evaluadas en tiempo real durante la ejecucion acustica.
  final List<NoteEvaluationEntity> evaluations;

  const MinusOneSessionEntity({
    required this.songId,
    required this.userTrackId,
    this.isMinusOneActive = true,
    this.isMutedUserTrack = true,
    this.guideTrackVolume = 0.0,
    this.evaluations = const [],
  });

  /// Total de notas evaluadas hasta el momento.
  int get totalNotesEvaluated => evaluations.length;

  /// Total de notas ejecutadas con exito en tono y tiempo (hits).
  int get hitNotesCount => evaluations.where((e) => e.isHit).length;

  /// Porcentaje de acierto global (0.0 a 100.0).
  double get accuracyPercentage {
    if (evaluations.isEmpty) return 0.0;
    return (hitNotesCount / evaluations.length) * 100.0;
  }

  /// Desviacion media absoluta en cents de la afinacion.
  double get averageCentsDeviation {
    if (evaluations.isEmpty) return 0.0;
    final sum = evaluations.fold<double>(0.0, (acc, e) => acc + e.centsDeviation.abs());
    return sum / evaluations.length;
  }

  /// Cantidad de ataques adelantados (Rushing).
  int get rushingCount =>
      evaluations.where((e) => e.timingCategory == NoteTimingCategory.early).length;

  /// Cantidad de ataques retrasados (Dragging).
  int get draggingCount =>
      evaluations.where((e) => e.timingCategory == NoteTimingCategory.late).length;

  /// Cantidad de ataques exactos (In-Pocket / On-Time).
  int get onTimeCount =>
      evaluations.where((e) => e.timingCategory == NoteTimingCategory.onTime).length;

  /// Puntaje consolidado ponderado (0.0 a 100.0).
  double get overallScore {
    if (evaluations.isEmpty) return 0.0;
    final sum = evaluations.fold<double>(0.0, (acc, e) => acc + e.overallScore);
    return (sum / evaluations.length).clamp(0.0, 100.0);
  }

  /// Calificacion pedagogica formal de la sesion (S, A, B, C, D).
  String get sessionGrade {
    final score = overallScore;
    if (score >= 95.0) return 'S';
    if (score >= 85.0) return 'A';
    if (score >= 75.0) return 'B';
    if (score >= 60.0) return 'C';
    return 'D';
  }

  MinusOneSessionEntity copyWith({
    String? songId,
    String? userTrackId,
    bool? isMinusOneActive,
    bool? isMutedUserTrack,
    double? guideTrackVolume,
    List<NoteEvaluationEntity>? evaluations,
  }) {
    return MinusOneSessionEntity(
      songId: songId ?? this.songId,
      userTrackId: userTrackId ?? this.userTrackId,
      isMinusOneActive: isMinusOneActive ?? this.isMinusOneActive,
      isMutedUserTrack: isMutedUserTrack ?? this.isMutedUserTrack,
      guideTrackVolume: (guideTrackVolume ?? this.guideTrackVolume).clamp(0.0, 1.0),
      evaluations: evaluations ?? this.evaluations,
    );
  }
}
