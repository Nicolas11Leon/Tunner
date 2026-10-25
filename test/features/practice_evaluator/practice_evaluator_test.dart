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
        sustainRatio: 1.0,
      );

      expect(result.isPitchAccurate, isTrue);
      expect(result.isHit, isTrue);
      expect(result.pitchScore, closeTo(100.0, 0.1));
      expect(result.timingCategory, equals(NoteTimingCategory.onTime));
      expect(result.sustainScore, closeTo(100.0, 0.1));
      expect(result.overallScore, closeTo(100.0, 0.1));
    });

    test('Transposed sounding note match correctly awards points for transposed instruments', () {
      // Para trompeta en Bb, un Do4 escrito exige captar un Sib3 / La#3 sonando
      final result = evaluator.evaluateNote(
        expectedNote: testNoteDo4,
        soundingExpectedNoteName: 'La#3',
        detectedNoteName: 'La#3',
        detectedFrequency: 233.08,
        detectedCents: 0.0,
        timingDeltaMs: 0,
        sustainRatio: 1.0,
      );

      expect(result.isPitchAccurate, isTrue);
      expect(result.isHit, isTrue);
      expect(result.soundingExpectedNoteName, equals('La#3'));
      expect(result.pitchScore, closeTo(100.0, 0.1));
    });

    test('Short sustain duration penalizes sustainScore proportionally', () {
      final result = evaluator.evaluateNote(
        expectedNote: testNoteDo4,
        detectedNoteName: 'Do4',
        detectedFrequency: 261.63,
        detectedCents: 0.0,
        timingDeltaMs: 0,
        sustainRatio: 0.5, // 50% de la duración esperada
      );

      expect(result.sustainRatioPercentage, closeTo(50.0, 0.1));
      expect(result.sustainScore, closeTo(50.0, 0.1));
      // Overall = 100*0.45 + 100*0.30 + 50*0.25 = 45 + 30 + 12.5 = 87.5
      expect(result.overallScore, closeTo(87.5, 0.1));
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

    test('generateReport detects Rushing tendency when average timing delta is negative', () {
      final rushingEvals = [
        evaluator.evaluateNote(
          expectedNote: testNoteDo4,
          detectedNoteName: 'Do4',
          detectedFrequency: 261.63,
          detectedCents: 0.0,
          timingDeltaMs: -45, // -45 ms adelanto
        ),
        evaluator.evaluateNote(
          expectedNote: testNoteMi4,
          detectedNoteName: 'Mi4',
          detectedFrequency: 329.63,
          detectedCents: 0.0,
          timingDeltaMs: -35, // -35 ms adelanto
        ),
      ];

      final report = evaluator.generateReport(
        songTitle: 'Estudio de Tempo',
        instrumentName: 'Trompeta en Si♭',
        evaluations: rushingEvals,
      );

      expect(report.rhythmTendency, equals(RhythmTendency.rushing));
      expect(report.rhythmTendencyDescription, contains('apresurar'));
    });

    test('generateReport detects Dragging tendency when average timing delta is positive', () {
      final draggingEvals = [
        evaluator.evaluateNote(
          expectedNote: testNoteDo4,
          detectedNoteName: 'Do4',
          detectedFrequency: 261.63,
          detectedCents: 0.0,
          timingDeltaMs: 50, // +50 ms retraso
        ),
        evaluator.evaluateNote(
          expectedNote: testNoteMi4,
          detectedNoteName: 'Mi4',
          detectedFrequency: 329.63,
          detectedCents: 0.0,
          timingDeltaMs: 40, // +40 ms retraso
        ),
      ];

      final report = evaluator.generateReport(
        songTitle: 'Estudio de Tempo',
        instrumentName: 'Saxofón Alto en Mi♭',
        evaluations: draggingEvals,
      );

      expect(report.rhythmTendency, equals(RhythmTendency.dragging));
      expect(report.rhythmTendencyDescription, contains('retrasar'));
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
