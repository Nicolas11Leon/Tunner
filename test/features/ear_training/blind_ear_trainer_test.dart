import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/ear_training/domain/blind_ear_trainer_engine.dart';
import 'package:tunner/features/ear_training/domain/ear_training_exercise.dart';
import 'package:tunner/features/ear_training/domain/musical_interval.dart';

void main() {
  group('MusicalInterval Domain Entity Tests', () {
    test('Calculates equal temperament and just intonation ratios correctly', () {
      // Octava Justa (8J): ratio 2.0, 1200 cents
      final octave = MusicalInterval.perfectOctave;
      expect(octave.semitones, equals(12));
      expect(octave.equalTemperamentRatio, closeTo(2.0, 1e-4));
      expect(octave.justRatio, equals(2.0));
      expect(octave.equalTemperamentCents, equals(1200.0));
      expect(octave.justCents, equals(1200.0));

      // Quinta Justa (5J): ratio 3/2 = 1.5, 701.96 cents justos vs 700 temperados
      final fifth = MusicalInterval.perfectFifth;
      expect(fifth.semitones, equals(7));
      expect(fifth.justRatio, equals(1.5));
      expect(fifth.equalTemperamentCents, equals(700.0));
      expect(fifth.justCents, closeTo(701.96, 0.01));
      expect(fifth.centDifferenceJustVsEqual, closeTo(1.96, 0.01));

      // Tercera Mayor (3M): ratio 5/4 = 1.25, 386.31 cents justos vs 400 temperados
      final third = MusicalInterval.majorThird;
      expect(third.semitones, equals(4));
      expect(third.justRatio, equals(1.25));
      expect(third.centDifferenceJustVsEqual, closeTo(-13.69, 0.01));
    });

    test('Calculates target frequencies accurately', () {
      const baseA4 = 440.0;
      final fifth = MusicalInterval.perfectFifth;

      // Quinta ascendente temperada desde A4 (440 * 2^(7/12) ≈ 659.255 Hz)
      final targetET = fifth.calculateTargetFrequency(baseA4, ascending: true, useJustIntonation: false);
      expect(targetET, closeTo(659.255, 0.01));

      // Quinta ascendente justa desde A4 (440 * 1.5 = 660.0 Hz)
      final targetJust = fifth.calculateTargetFrequency(baseA4, ascending: true, useJustIntonation: true);
      expect(targetJust, closeTo(660.0, 0.01));

      // Quinta descendente temperada desde A4 (440 / 2^(7/12) ≈ 293.665 Hz -> D4)
      final targetDesc = fifth.calculateTargetFrequency(baseA4, ascending: false);
      expect(targetDesc, closeTo(293.665, 0.01));
    });

    test('Calculates cents deviation accurately', () {
      // Misma frecuencia = 0 cents
      expect(MusicalInterval.calculateCentsDeviation(440.0, 440.0), equals(0.0));

      // 1 octava arriba (880 vs 440) = 1200 cents
      expect(MusicalInterval.calculateCentsDeviation(880.0, 440.0), closeTo(1200.0, 1e-4));

      // Pequeña desafinación de 442.5 Hz vs 440.0 Hz ≈ +9.81 cents
      expect(MusicalInterval.calculateCentsDeviation(442.5, 440.0), closeTo(9.81, 0.1));
    });
  });

  group('BlindEarTrainerEngine Tests', () {
    late BlindEarTrainerEngine engine;

    setUp(() {
      engine = BlindEarTrainerEngine();
    });

    test('Generates questions with valid options and correct index', () {
      final q = engine.generateNextQuestion();
      expect(q.options.length, equals(4));
      expect(q.correctOptionIndex, inInclusiveRange(0, 3));
      expect(q.options[q.correctOptionIndex], equals(q.targetInterval));
      expect(q.baseFrequencyHz, inInclusiveRange(220.0, 440.0));
    });

    test('Evaluates correct and incorrect interval choices, updating streak and score', () {
      final q1 = engine.generateNextQuestion();
      final correctResult = engine.submitIntervalChoice(
        q1.targetInterval,
        responseTimeMs: 1200,
        centsDeviation: 2.1,
      );

      expect(correctResult.isCorrect, isTrue);
      expect(correctResult.grade, equals(PerformanceGrade.sGrade));
      expect(engine.currentStreak, equals(1));
      expect(engine.correctAnswersCount, equals(1));
      expect(engine.totalScore, greaterThan(0));

      // Segunda pregunta correcta incrementa racha
      final q2 = engine.generateNextQuestion();
      final secondCorrect = engine.submitIntervalChoice(
        q2.targetInterval,
        responseTimeMs: 2000,
        centsDeviation: 4.0,
      );
      expect(secondCorrect.isCorrect, isTrue);
      expect(engine.currentStreak, equals(2));
      expect(engine.bestStreak, equals(2));

      // Respuesta incorrecta rompe la racha
      final q3 = engine.generateNextQuestion();
      final wrongInterval = MusicalInterval.values.firstWhere((i) => i != q3.targetInterval);
      final wrongResult = engine.submitIntervalChoice(wrongInterval);

      expect(wrongResult.isCorrect, isFalse);
      expect(wrongResult.grade, equals(PerformanceGrade.fGrade));
      expect(engine.currentStreak, equals(0));
      expect(engine.bestStreak, equals(2));
      expect(engine.totalQuestionsAnswered, equals(3));
      expect(engine.accuracyPercentage, closeTo(66.66, 0.1));
    });

    test('Evaluates sung frequency accurately', () {
      final q = engine.generateNextQuestion();
      // Simular usuario cantando con solo 3 cents de desviación
      final sungHz = q.targetFrequencyHz * 1.00173; // ~3 cents arriba
      final result = engine.submitSungFrequency(sungHz, responseTimeMs: 1500);

      expect(result.isCorrect, isTrue);
      expect(result.centsDeviation, closeTo(3.0, 0.5));
    });

    test('Resets session cleanly', () {
      engine.generateNextQuestion();
      engine.submitIntervalChoice(MusicalInterval.unison);
      expect(engine.totalQuestionsAnswered, equals(1));

      engine.resetSession();
      expect(engine.totalQuestionsAnswered, equals(0));
      expect(engine.currentQuestion, isNull);
      expect(engine.currentStreak, equals(0));
      expect(engine.totalScore, equals(0));
    });
  });
}
