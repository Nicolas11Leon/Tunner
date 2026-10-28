import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/guided_lessons/domain/guided_lesson_entity.dart';
import 'package:tunner/features/guided_lessons/domain/curated_guided_lessons.dart';
import 'package:tunner/features/guided_lessons/domain/guided_lesson_evaluator.dart';

void main() {
  group('GuidedLessonEntity & CuratedLessons Domain Tests', () {
    test('CuratedGuidedLessons contains all 4 canonical lessons with valid steps', () {
      final lessons = CuratedGuidedLessons.all;
      expect(lessons.length, 4);

      for (final lesson in lessons) {
        expect(lesson.id, isNotEmpty);
        expect(lesson.title, isNotEmpty);
        expect(lesson.steps, isNotEmpty);
        expect(lesson.totalSteps, greaterThanOrEqualTo(3));
      }
    });

    test('GuidedLessonProgressEntity calculates progress ratios correctly', () {
      final lesson = CuratedGuidedLessons.all.first;
      final step = lesson.initialStep;
      expect(step.targetDurationSeconds, greaterThan(0));

      // 1.25 segundos de 2.5 segundos = 50%
      final progress = GuidedLessonProgressEntity(
        lesson: lesson,
        currentStepIndex: 0,
        sustainedSeconds: 1.25,
        isStepComplete: false,
        isLessonComplete: false,
      );

      expect(progress.stepProgressRatio, closeTo(0.50, 0.01));
      // Paso 0 al 50% de 3 pasos = 0.5 / 3 = ~16.6%
      expect(progress.overallLessonProgressRatio, closeTo(0.5 / 3.0, 0.01));
    });
  });

  group('GuidedLessonEvaluator Acoustic Logic Tests', () {
    late GuidedLessonEvaluator evaluator;
    late GuidedLessonEntity testLesson;

    setUp(() {
      evaluator = GuidedLessonEvaluator();
      testLesson = const GuidedLessonEntity(
        id: 'test_lesson',
        title: 'Lección de Prueba',
        description: 'Prueba de evaluador',
        category: GuidedLessonCategory.fundamentals,
        difficulty: 'Principiante',
        steps: [
          GuidedLessonStepEntity(
            stepIndex: 0,
            instruction: 'Toca La4',
            targetNoteName: 'La4',
            targetFrequencyHz: 440.0,
            targetDurationSeconds: 1.0,
            toleranceCents: 10.0,
            feedbackTip: 'Tip 1',
          ),
          GuidedLessonStepEntity(
            stepIndex: 1,
            instruction: 'Toca Si4',
            targetNoteName: 'Si4',
            targetFrequencyHz: 493.88,
            targetDurationSeconds: 1.0,
            toleranceCents: 10.0,
            feedbackTip: 'Tip 2',
          ),
        ],
      );
    });

    test('startLesson initializes session at step 0 with 0 sustained seconds', () {
      final progress = evaluator.startLesson(testLesson);
      expect(progress.currentStepIndex, 0);
      expect(progress.sustainedSeconds, 0.0);
      expect(progress.isStepComplete, isFalse);
      expect(progress.isLessonComplete, isFalse);
      expect(evaluator.hasActiveLesson, isTrue);
    });

    test('evaluateSample ignores silence and invalid pitch', () {
      evaluator.startLesson(testLesson);

      final p = evaluator.evaluateSample(
        frequencyHz: 0.0,
        cents: 0.0,
        detectedNoteName: '--',
        deltaSeconds: 0.1,
      );

      expect(p?.sustainedSeconds, 0.0);
    });

    test('evaluateSample rejects wrong note', () {
      evaluator.startLesson(testLesson);

      // Target is La4 (A4), detected is Do4 (C4)
      final p = evaluator.evaluateSample(
        frequencyHz: 261.63,
        cents: 0.0,
        detectedNoteName: 'Do4',
        deltaSeconds: 0.2,
      );

      expect(p?.sustainedSeconds, 0.0);
    });

    test('evaluateSample rejects out-of-tune note exceeding tolerance', () {
      evaluator.startLesson(testLesson);

      // Tolerance is 10.0 cents. Cents is 18.0.
      final p = evaluator.evaluateSample(
        frequencyHz: 444.0,
        cents: 18.0,
        detectedNoteName: 'La4',
        deltaSeconds: 0.2,
      );

      expect(p?.sustainedSeconds, 0.0);
    });

    test('evaluateSample accumulates sustained time for target note in tune', () {
      evaluator.startLesson(testLesson);

      // La4 in tune (cents: +2.0)
      final p1 = evaluator.evaluateSample(
        frequencyHz: 440.5,
        cents: 2.0,
        detectedNoteName: 'La4',
        deltaSeconds: 0.4,
      );

      expect(p1?.sustainedSeconds, closeTo(0.4, 0.001));
      expect(p1?.isStepComplete, isFalse);

      final p2 = evaluator.evaluateSample(
        frequencyHz: 440.2,
        cents: 1.0,
        detectedNoteName: 'A4', // Equivalencia Solfege / Cifrado
        deltaSeconds: 0.4,
      );

      expect(p2?.sustainedSeconds, closeTo(0.8, 0.001));
    });

    test('Completes step and advances to step 1 when target duration reached', () {
      evaluator.startLesson(testLesson);

      // Target duration is 1.0s. Send 1.1s total.
      evaluator.evaluateSample(
        frequencyHz: 440.0,
        cents: 0.0,
        detectedNoteName: 'La4',
        deltaSeconds: 0.6,
      );

      final p = evaluator.evaluateSample(
        frequencyHz: 440.0,
        cents: 0.0,
        detectedNoteName: 'La4',
        deltaSeconds: 0.5,
      );

      // Paso 0 completado -> avanza a paso 1
      expect(p?.currentStepIndex, 1);
      expect(p?.sustainedSeconds, 0.0);
      expect(p?.isStepComplete, isTrue);
      expect(p?.isLessonComplete, isFalse);
    });

    test('Completes lesson when final step is fulfilled', () {
      evaluator.startLesson(testLesson);

      // Completar Paso 0 (1.0s de La4)
      evaluator.evaluateSample(
        frequencyHz: 440.0,
        cents: 0.0,
        detectedNoteName: 'La4',
        deltaSeconds: 1.1,
      );

      // Completar Paso 1 (1.0s de Si4)
      final pFinal = evaluator.evaluateSample(
        frequencyHz: 493.88,
        cents: 0.0,
        detectedNoteName: 'Si4',
        deltaSeconds: 1.1,
      );

      expect(pFinal?.isLessonComplete, isTrue);
      expect(pFinal?.isStepComplete, isTrue);
      expect(evaluator.hasActiveLesson, isFalse);
    });

    test('jumpToStep navigates step index accurately', () {
      evaluator.startLesson(testLesson);
      final p = evaluator.jumpToStep(1);
      expect(p?.currentStepIndex, 1);
      expect(p?.sustainedSeconds, 0.0);
    });
  });
}
