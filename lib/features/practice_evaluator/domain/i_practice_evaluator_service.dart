import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'note_evaluation_entity.dart';
import 'practice_report_entity.dart';

/// Contrato abstracto para el evaluador pedagógico de práctica musical.
abstract class IPracticeEvaluatorService {
  /// Evalúa una nota ejecutada contra la nota esperada en la partitura.
  NoteEvaluationEntity evaluateNote({
    required HierarchicalNote expectedNote,
    required String detectedNoteName,
    required double detectedFrequency,
    required double detectedCents,
    required int timingDeltaMs,
    double toleranceCents = 15.0,
  });

  /// Compila la lista de evaluaciones en un reporte analítico con notas críticas y tendencias.
  PracticeReportEntity generateReport({
    required String songTitle,
    required List<NoteEvaluationEntity> evaluations,
    PracticeReportEntity? previousSession,
  });
}
