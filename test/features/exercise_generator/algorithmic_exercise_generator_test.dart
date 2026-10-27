import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/exercise_generator/domain/algorithmic_exercise_generator.dart';

void main() {
  group('AlgorithmicExerciseGenerator Tests', () {
    const generator = AlgorithmicExerciseGenerator();

    test('Generates valid C Major scale with exact notes and balanced measures', () {
      final pkg = generator.generate(
        rootNote: 'Do4',
        type: ExerciseType.majorScale,
        rhythm: ExerciseRhythm.quarter,
        bpm: 100,
      );

      expect(pkg.title, contains('Do4'));
      expect(pkg.title, contains('Escala Mayor'));
      expect(pkg.defaultBpm, equals(100));

      // Verificar que todos los compases sean válidos (sumen 16 ticks)
      expect(pkg.score.measures.isNotEmpty, isTrue);
      for (final measure in pkg.score.measures) {
        expect(measure.isValidMeasure, isTrue);
      }

      // Primera nota debe ser Do4
      expect(pkg.score.measures.first.notes.first.noteName, equals('Do4'));
      expect(pkg.score.measures.first.notes.first.durationTicks, equals(4));

      // Segunda nota debe ser Re4
      expect(pkg.score.measures.first.notes[1].noteName, equals('Re4'));
    });

    test('Generates Major Arpeggio correctly', () {
      final pkg = generator.generate(
        rootNote: 'Do4',
        type: ExerciseType.majorArpeggio,
        rhythm: ExerciseRhythm.eighth,
      );

      expect(pkg.score.measures.isNotEmpty, isTrue);
      final allNotes = pkg.score.measures
          .expand((m) => m.notes)
          .where((n) => n.noteName != '--')
          .toList();

      expect(allNotes.map((n) => n.noteName).toList(), equals([
        'Do4',
        'Mi4',
        'Sol4',
        'Do5',
        'Sol4',
        'Mi4',
        'Do4',
      ]));
    });

    test('Generates Harmonic Minor scale with leading tone', () {
      final pkg = generator.generate(
        rootNote: 'La4',
        type: ExerciseType.harmonicMinorScale,
        rhythm: ExerciseRhythm.quarter,
      );

      final allNotes = pkg.score.measures
          .expand((m) => m.notes)
          .where((n) => n.noteName != '--')
          .map((n) => n.noteName)
          .toList();

      expect(allNotes.first, equals('La4'));
      // Escala armónica de La menor debe contener Sol#5 como sensible
      expect(allNotes.any((n) => n.startsWith('Sol#')), isTrue);
    });

    test('Generates Long Tones with whole notes (16 ticks)', () {
      final pkg = generator.generate(
        rootNote: 'Sol4',
        type: ExerciseType.longTones,
      );

      for (final measure in pkg.score.measures) {
        expect(measure.isValidMeasure, isTrue);
        expect(measure.notes.first.durationTicks, equals(16));
      }
    });

    test('Generates Thirds Intervals with correct sequence', () {
      final pkg = generator.generate(
        rootNote: 'Do4',
        type: ExerciseType.thirdsIntervals,
        rhythm: ExerciseRhythm.sixteenth,
      );

      expect(pkg.score.measures.isNotEmpty, isTrue);
      for (final m in pkg.score.measures) {
        expect(m.isValidMeasure, isTrue);
      }
    });
  });
}
