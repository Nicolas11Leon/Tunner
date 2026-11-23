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

  Map<String, dynamic> toMap() => toJson();

  Map<String, dynamic> toJson() {
    return {
      'expectedNote': {
        'startTick': expectedNote.startTick,
        'durationTicks': expectedNote.durationTicks,
        'noteName': expectedNote.noteName,
        'isRest': expectedNote.isRest,
        'isTied': expectedNote.isTied,
        'voice': expectedNote.voice,
        'staff': expectedNote.staff,
      },
      'soundingExpectedNoteName': soundingExpectedNoteName,
      'detectedNoteName': detectedNoteName,
      'detectedFrequency': detectedFrequency,
      'centsDeviation': centsDeviation,
      'timingCategory': timingCategory.name,
      'timingDeltaMs': timingDeltaMs,
      'sustainRatioPercentage': sustainRatioPercentage,
      'isPitchAccurate': isPitchAccurate,
      'pitchScore': pitchScore,
      'rhythmScore': rhythmScore,
      'sustainScore': sustainScore,
      'overallScore': overallScore,
      'isHit': isHit,
    };
  }

  factory NoteEvaluationEntity.fromMap(Map<String, dynamic> map) =>
      NoteEvaluationEntity.fromJson(map);

  factory NoteEvaluationEntity.fromJson(Map<String, dynamic> json) {
    final noteMap = json['expectedNote'] as Map<String, dynamic>? ?? const {};
    final expectedNote = HierarchicalNote(
      startTick: (noteMap['startTick'] as num?)?.toInt() ?? 0,
      durationTicks: (noteMap['durationTicks'] as num?)?.toInt() ?? 4,
      noteName: noteMap['noteName'] as String? ?? '',
      isRest: noteMap['isRest'] as bool? ?? false,
      isTied: noteMap['isTied'] as bool? ?? false,
      voice: (noteMap['voice'] as num?)?.toInt() ?? 1,
      staff: (noteMap['staff'] as num?)?.toInt() ?? 1,
    );

    final timingName = json['timingCategory'] as String? ?? NoteTimingCategory.missed.name;
    final timingCategory = NoteTimingCategory.values.firstWhere(
      (c) => c.name == timingName,
      orElse: () => NoteTimingCategory.missed,
    );

    return NoteEvaluationEntity(
      expectedNote: expectedNote,
      soundingExpectedNoteName: json['soundingExpectedNoteName'] as String? ?? '',
      detectedNoteName: json['detectedNoteName'] as String? ?? '',
      detectedFrequency: (json['detectedFrequency'] as num?)?.toDouble() ?? 0.0,
      centsDeviation: (json['centsDeviation'] as num?)?.toDouble() ?? 0.0,
      timingCategory: timingCategory,
      timingDeltaMs: (json['timingDeltaMs'] as num?)?.toInt() ?? 0,
      sustainRatioPercentage: (json['sustainRatioPercentage'] as num?)?.toDouble() ?? 0.0,
      isPitchAccurate: json['isPitchAccurate'] as bool? ?? false,
      pitchScore: (json['pitchScore'] as num?)?.toDouble() ?? 0.0,
      rhythmScore: (json['rhythmScore'] as num?)?.toDouble() ?? 0.0,
      sustainScore: (json['sustainScore'] as num?)?.toDouble() ?? 0.0,
      overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
