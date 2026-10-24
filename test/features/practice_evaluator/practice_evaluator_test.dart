import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/practice_evaluator/domain/note_evaluation_entity.dart';
import 'package:tunner/features/practice_evaluator/domain/practice_report_entity.dart';
import 'package:tunner/features/practice_evaluator/data/practice_evaluator_service.dart';

void main() {
  group('PracticeEvaluatorService Domain & Data Tests', () {
    const evaluator = PracticeEvaluatorService();

    final testNoteDo4 = HierarchicalNote.note(
      startTick: 0,
      durationTicks: 4,
      noteName: 'Do4',
    );

    final testNoteMi4 = HierarchicalNote.note(
      startTick: 4,
      durationTicks: 4,
      noteName: 'Mi4',
    );

    test('Exact match with 0 cents deviation yields 100 pitchScore and isHit', () {
      final result = evaluator.evaluateNote(
        expectedNote: testNoteDo4,
        detectedNoteName: 'Do4',
        detectedFrequency: 261.63,
        detectedCents: 0.0,
        timingDeltaMs: 10,
      );

      expect(result.isPitchAccurate, isTrue);
      expect(result.isHit, isTrue);
      expect(result.pitchScore, closeTo(100.0, 0.1));
      expect(result.timingCategory, equals(NoteTimingCategory.onTime));
      expect(result.overallScore, closeTo(100.0, 0.1));
    });

    test('Match within tolerance (10 cents) awards partial high score', () {
      final result = evaluator.evaluateNote(
        expectedNote: testNoteDo4,
        detectedNoteName: 'Do4',
        detectedFrequency: 263.0,
        detectedCents: 10.0,
        timingDeltaMs: 0,
        toleranceCents: 15.0,
      );

      expect(result.isPitchAccurate, isTrue);
      expect(result.isHit, isTrue);
      // 100 - (10 / 50 * 100) = 80.0
      expect(result.pitchScore, closeTo(80.0, 0.1));
    });

    test('Wrong note emitted yields 0 pitchScore and isPitchAccurate false', () {
      final result = evaluator.evaluateNote(
        expectedNote: testNoteDo4,
        detectedNoteName: 'Sol4',
        detectedFrequency: 392.0,
        detectedCents: 0.0,
        timingDeltaMs: 0,
      );

      expect(result.isPitchAccurate, isFalse);
      expect(result.isHit, isFalse);
      expect(result.pitchScore, equals(0.0));
    });

    test('Silence during expected note flags missed note', () {
      final result = evaluator.evaluateNote(
        expectedNote: testNoteDo4,
        detectedNoteName: '--',
        detectedFrequency: 0.0,
        detectedCents: 0.0,
        timingDeltaMs: 200,
      );

      expect(result.timingCategory, equals(NoteTimingCategory.missed));
      expect(result.isHit, isFalse);
      expect(result.overallScore, equals(0.0));
    });

    test('generateReport correctly classifies Virtuoso Grade S and mastered notes', () {
      final evaluations = [
        evaluator.evaluateNote(
          expectedNote: testNoteDo4,
          detectedNoteName: 'Do4',
          detectedFrequency: 261.63,
          detectedCents: 1.0,
          timingDeltaMs: 15,
        ),
        evaluator.evaluateNote(
          expectedNote: testNoteMi4,
          detectedNoteName: 'Mi4',
          detectedFrequency: 329.63,
          detectedCents: -2.0,
          timingDeltaMs: -10,
        ),
      ];

      final report = evaluator.generateReport(
        songTitle: 'Oda a la Alegría',
        evaluations: evaluations,
      );

      expect(report.totalNotes, equals(2));
      expect(report.hitNotes, equals(2));
      expect(report.grade, equals(PerformanceGrade.s));
      expect(report.masteredNotes, containsAll(['Do4', 'Mi4']));
      expect(report.criticalNotes, isEmpty);
    });

    test('generateReport detects trend progress (+delta) when compared to previous session', () {
      final session1Report = PracticeReportEntity(
        songTitle: 'Canon de Pachelbel',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        totalNotes: 2,
        hitNotes: 1,
        pitchAccuracyPercentage: 70.0,
        rhythmAccuracyPercentage: 70.0,
        averageCentsDeviation: 12.0,
        overallScore: 70.0,
        grade: PerformanceGrade.c,
        evaluations: const [],
        noteAccuracyMap: const {'Do4': 70.0},
        criticalNotes: const ['Do4'],
        masteredNotes: const [],
      );

      final session2Evals = [
        evaluator.evaluateNote(
          expectedNote: testNoteDo4,
          detectedNoteName: 'Do4',
          detectedFrequency: 261.63,
          detectedCents: 2.0,
          timingDeltaMs: 5,
        ),
      ];

      final session2Report = evaluator.generateReport(
        songTitle: 'Canon de Pachelbel',
        evaluations: session2Evals,
        previousSession: session1Report,
      );

      expect(session2Report.trendDeltaPercentage, greaterThan(15.0));
      expect(session2Report.trendAnalysisText, contains('Progreso notable'));
    });
  });
}
