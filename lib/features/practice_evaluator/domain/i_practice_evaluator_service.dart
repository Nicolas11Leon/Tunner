import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import '../../practice_recorder/domain/practice_recording_entity.dart';
import 'note_evaluation_entity.dart';
import 'practice_report_entity.dart';

/// Contrato abstracto para el evaluador pedagógico multidimensional de práctica musical.
abstract class IPracticeEvaluatorService {
  /// Evalúa una nota ejecutada contra la nota esperada en la partitura considerando transposición.
  NoteEvaluationEntity evaluateNote({
    required HierarchicalNote expectedNote,
    String? soundingExpectedNoteName,
    required String detectedNoteName,
    required double detectedFrequency,
    required double detectedCents,
    required int timingDeltaMs,
    double sustainRatio = 1.0,
    double toleranceCents = 15.0,
  });

  /// Compila la lista de evaluaciones en un reporte analítico con notas críticas, tendencias y dimensiones.
  PracticeReportEntity generateReport({
    required String songTitle,
    String instrumentName = 'Instrumento Estándar',
    required List<NoteEvaluationEntity> evaluations,
    PracticeReportEntity? previousSession,
    PracticeRecordingEntity? recording,
  });
}
