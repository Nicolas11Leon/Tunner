import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/domain/note_entity.dart';

void main() {
  group('NoteEntity Acoustic Math and Boundaries', () {
    test('Standard Concert Pitch A4 at 440 Hz produces La4 with 0 cents deviation', () {
      final note = NoteEntity.fromFrequency(440.0);
      expect(note.name, equals('La4'));
      expect(note.cents.abs(), lessThan(0.01));
    });

    test('Middle C (C4) at 261.63 Hz produces Do4 with minimal cents deviation', () {
      final note = NoteEntity.fromFrequency(261.63);
      expect(note.name, equals('Do4'));
      expect(note.cents.abs(), lessThan(1.0));
    });

    test('Deep guitar bass E2 at 82.41 Hz produces Mi2', () {
      final note = NoteEntity.fromFrequency(82.41);
      expect(note.name, equals('Mi2'));
      expect(note.cents.abs(), lessThan(1.0));
    });

    test('Sub-bass A0 at 27.50 Hz produces La0', () {
      final note = NoteEntity.fromFrequency(27.50);
      expect(note.name, equals('La0'));
      expect(note.cents.abs(), lessThan(1.0));
    });

    test('High soprano/piccolo C7 at 2093.00 Hz produces Do7', () {
      final note = NoteEntity.fromFrequency(2093.00);
      expect(note.name, equals('Do7'));
      expect(note.cents.abs(), lessThan(1.0));
    });

    test('Slightly sharp A4 (445 Hz) produces positive cents', () {
      final note = NoteEntity.fromFrequency(445.0);
      expect(note.name, equals('La4'));
      expect(note.cents, greaterThan(0.0));
      expect(note.cents, lessThan(50.0));
    });

    test('Slightly flat A4 (435 Hz) produces negative cents', () {
      final note = NoteEntity.fromFrequency(435.0);
      expect(note.name, equals('La4'));
      expect(note.cents, lessThan(0.0));
      expect(note.cents, greaterThan(-50.0));
    });

    test('Invalid or zero frequency returns placeholder note "--"', () {
      final noteZero = NoteEntity.fromFrequency(0.0);
      expect(noteZero.name, equals('--'));
      expect(noteZero.cents, equals(0.0));

      final noteNegative = NoteEntity.fromFrequency(-100.0);
      expect(noteNegative.name, equals('--'));

      final noteNaN = NoteEntity.fromFrequency(double.nan);
      expect(noteNaN.name, equals('--'));
    });
  });
}
