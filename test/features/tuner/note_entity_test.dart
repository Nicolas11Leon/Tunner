import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/tuner/domain/note_entity.dart';

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

    test('frequencyForNote correctly maps note names to exact frequencies', () {
      expect(NoteEntity.frequencyForNote('La4'), closeTo(440.0, 0.01));
      expect(NoteEntity.frequencyForNote('Do4'), closeTo(261.63, 0.05));
      expect(NoteEntity.frequencyForNote('Mi4'), closeTo(329.63, 0.05));
      expect(NoteEntity.frequencyForNote('Mi2'), closeTo(82.41, 0.05));
      expect(NoteEntity.frequencyForNote('La0'), closeTo(27.50, 0.05));
      expect(NoteEntity.frequencyForNote('--'), equals(0.0));
      expect(NoteEntity.frequencyForNote(''), equals(0.0));
      expect(NoteEntity.frequencyForNote('Invalida'), equals(0.0));
    });

    test('Custom A4 calibration (432 Hz Verdi Pitch) calculates 0 cents for 432 Hz', () {
      final note = NoteEntity.fromFrequency(432.0, a4Ref: 432.0);
      expect(note.name, equals('La4'));
      expect(note.cents.abs(), lessThan(0.01));
    });

    test('Custom A4 calibration (442 Hz Symphony Pitch) calculates 0 cents for 442 Hz', () {
      final note = NoteEntity.fromFrequency(442.0, a4Ref: 442.0);
      expect(note.name, equals('La4'));
      expect(note.cents.abs(), lessThan(0.01));

      // Comparado con 440 Hz estándar, 442 Hz en estándar 440 tiene desvío positivo (+7.85 cents)
      final noteAt440Ref = NoteEntity.fromFrequency(442.0, a4Ref: 440.0);
      expect(noteAt440Ref.cents, closeTo(7.85, 0.1));
    });

    test('Baroque A4 calibration (415 Hz) calculates 0 cents for 415 Hz', () {
      final note = NoteEntity.fromFrequency(415.0, a4Ref: 415.0);
      expect(note.name, equals('La4'));
      expect(note.cents.abs(), lessThan(0.01));
    });

    test('frequencyForNote respects custom a4Ref calibration', () {
      expect(NoteEntity.frequencyForNote('La4', a4Ref: 432.0), closeTo(432.0, 0.01));
      expect(NoteEntity.frequencyForNote('La4', a4Ref: 442.0), closeTo(442.0, 0.01));
      expect(NoteEntity.frequencyForNote('La4', a4Ref: 415.0), closeTo(415.0, 0.01));
    });
  });
}
