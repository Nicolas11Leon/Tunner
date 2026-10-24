import 'dart:math';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import '../domain/i_practice_evaluator_service.dart';
import '../domain/note_evaluation_entity.dart';
import '../domain/practice_report_entity.dart';

/// Implementación canónica del evaluador pedagógico de práctica musical.
class PracticeEvaluatorService implements IPracticeEvaluatorService {
  const PracticeEvaluatorService();

  @override
  NoteEvaluationEntity evaluateNote({
    required HierarchicalNote expectedNote,
    required String detectedNoteName,
    required double detectedFrequency,
    required double detectedCents,
    required int timingDeltaMs,
    double toleranceCents = 15.0,
  }) {
    if (expectedNote.isRest) {
      final bool isSilent = detectedNoteName == '--' || detectedFrequency <= 0.0;
      return NoteEvaluationEntity(
        expectedNote: expectedNote,
        detectedNoteName: detectedNoteName,
        detectedFrequency: detectedFrequency,
        centsDeviation: detectedCents,
        timingCategory: isSilent ? NoteTimingCategory.onTime : NoteTimingCategory.early,
        timingDeltaMs: timingDeltaMs,
        isPitchAccurate: isSilent,
        pitchScore: isSilent ? 100.0 : 40.0,
        rhythmScore: isSilent ? 100.0 : 50.0,
        overallScore: isSilent ? 100.0 : 45.0,
      );
    }

    final bool isSilent = detectedNoteName == '--' || detectedFrequency <= 0.0;
    if (isSilent) {
      return NoteEvaluationEntity(
        expectedNote: expectedNote,
        detectedNoteName: '--',
        detectedFrequency: 0.0,
        centsDeviation: 0.0,
        timingCategory: NoteTimingCategory.missed,
        timingDeltaMs: timingDeltaMs,
        isPitchAccurate: false,
        pitchScore: 0.0,
        rhythmScore: 0.0,
        overallScore: 0.0,
      );
    }

    // Normalización de notas (ej: "Do4" == "do4")
    final bool noteMatches = expectedNote.noteName.trim().toLowerCase() ==
        detectedNoteName.trim().toLowerCase();

    final double centsAbs = detectedCents.abs();
    final bool isPitchAccurate = noteMatches && centsAbs <= toleranceCents;

    double pitchScore = 0.0;
    if (noteMatches) {
      // Si la nota coincide, el puntaje decae proporcionalmente al desvío de cents
      // 0 cents = 100%, 15 cents = 70%, 50 cents = 0%
      pitchScore = (100.0 - (centsAbs / 50.0) * 100.0).clamp(0.0, 100.0);
    }

    // Clasificación rítmica (ventana de tolerancia: +/- 80 ms)
    NoteTimingCategory timingCategory;
    double rhythmScore;
    final int absDelta = timingDeltaMs.abs();

    if (absDelta <= 80) {
      timingCategory = NoteTimingCategory.onTime;
      rhythmScore = 100.0;
    } else if (timingDeltaMs < -80) {
      timingCategory = NoteTimingCategory.early;
      rhythmScore = max(20.0, 100.0 - (absDelta - 80) * 0.4);
    } else {
      timingCategory = NoteTimingCategory.late;
      rhythmScore = max(20.0, 100.0 - (absDelta - 80) * 0.4);
    }

    final double overall = (pitchScore * 0.65) + (rhythmScore * 0.35);

    return NoteEvaluationEntity(
      expectedNote: expectedNote,
      detectedNoteName: detectedNoteName,
      detectedFrequency: detectedFrequency,
      centsDeviation: detectedCents,
      timingCategory: timingCategory,
      timingDeltaMs: timingDeltaMs,
      isPitchAccurate: isPitchAccurate,
      pitchScore: pitchScore,
      rhythmScore: rhythmScore,
      overallScore: overall,
    );
  }

  @override
  PracticeReportEntity generateReport({
    required String songTitle,
    required List<NoteEvaluationEntity> evaluations,
    PracticeReportEntity? previousSession,
  }) {
    if (evaluations.isEmpty) {
      return PracticeReportEntity(
        songTitle: songTitle,
        timestamp: DateTime.now(),
        totalNotes: 0,
        hitNotes: 0,
        pitchAccuracyPercentage: 0.0,
        rhythmAccuracyPercentage: 0.0,
        averageCentsDeviation: 0.0,
        overallScore: 0.0,
        grade: PerformanceGrade.d,
        evaluations: const [],
        noteAccuracyMap: const {},
        criticalNotes: const [],
        masteredNotes: const [],
        trendAnalysisText: 'Sin notas registradas en la sesión',
      );
    }

    final nonRestEvaluations = evaluations.where((e) => !e.expectedNote.isRest).toList();
    final int total = nonRestEvaluations.isNotEmpty ? nonRestEvaluations.length : evaluations.length;
    final activeList = nonRestEvaluations.isNotEmpty ? nonRestEvaluations : evaluations;

    int hits = 0;
    double sumPitchScore = 0.0;
    double sumRhythmScore = 0.0;
    double sumCentsDeviation = 0.0;
    int centsCount = 0;

    final Map<String, List<double>> noteScoresAccumulator = {};

    for (final eval in activeList) {
      if (eval.isHit) hits++;
      sumPitchScore += eval.pitchScore;
      sumRhythmScore += eval.rhythmScore;

      if (eval.detectedNoteName != '--') {
        sumCentsDeviation += eval.centsDeviation.abs();
        centsCount++;
      }

      final key = eval.expectedNote.noteName;
      if (key.isNotEmpty) {
        noteScoresAccumulator.putIfAbsent(key, () => []).add(eval.overallScore);
      }
    }

    final double pitchAccPct = total > 0 ? (sumPitchScore / total) : 0.0;
    final double rhythmAccPct = total > 0 ? (sumRhythmScore / total) : 0.0;
    final double avgCents = centsCount > 0 ? (sumCentsDeviation / centsCount) : 0.0;
    final double overallScore = (pitchAccPct * 0.65) + (rhythmAccPct * 0.35);

    // Desglose por nota
    final Map<String, double> noteAccuracyMap = {};
    final List<String> criticalNotes = [];
    final List<String> masteredNotes = [];

    noteScoresAccumulator.forEach((note, scores) {
      final double avg = scores.reduce((a, b) => a + b) / scores.length;
      noteAccuracyMap[note] = double.parse(avg.toStringAsFixed(1));
      if (avg < 70.0) {
        criticalNotes.add(note);
      } else if (avg >= 88.0) {
        masteredNotes.add(note);
      }
    });

    // Comparativa de tendencia con sesión anterior
    double trendDelta = 0.0;
    String trendText = 'Primera sesión registrada para esta obra';

    if (previousSession != null) {
      trendDelta = overallScore - previousSession.overallScore;
      final String deltaStr = '${trendDelta >= 0 ? '+' : ''}${trendDelta.toStringAsFixed(1)}%';
      if (trendDelta > 2.0) {
        trendText = '▲ Progreso notable ($deltaStr). Mayor estabilidad de afinación y pulso rítmico.';
      } else if (trendDelta < -2.0) {
        trendText = '▼ Desvío de $deltaStr vs. sesión previa. Se sugiere repasar pasajes complejos con Smart Wait.';
      } else {
        trendText = '● Rendimiento estable ($deltaStr). Afinación consistente respecto a la sesión anterior.';
      }
    }

    return PracticeReportEntity(
      songTitle: songTitle,
      timestamp: DateTime.now(),
      totalNotes: total,
      hitNotes: hits,
      pitchAccuracyPercentage: double.parse(pitchAccPct.toStringAsFixed(1)),
      rhythmAccuracyPercentage: double.parse(rhythmAccPct.toStringAsFixed(1)),
      averageCentsDeviation: double.parse(avgCents.toStringAsFixed(1)),
      overallScore: double.parse(overallScore.toStringAsFixed(1)),
      grade: PerformanceGrade.fromScore(overallScore),
      evaluations: evaluations,
      noteAccuracyMap: noteAccuracyMap,
      criticalNotes: criticalNotes,
      masteredNotes: masteredNotes,
      trendDeltaPercentage: double.parse(trendDelta.toStringAsFixed(1)),
      trendAnalysisText: trendText,
    );
  }
}
