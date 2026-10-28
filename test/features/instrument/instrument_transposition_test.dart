import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/instrument/domain/instrument_profile_entity.dart';
import 'package:tunner/features/instrument/data/instrument_transposition_service.dart';

void main() {
  group('InstrumentTranspositionService Tests', () {
    const transpositionService = InstrumentTranspositionService();

    test('Concert C (Flute, Violin) preserves written pitch and frequency', () {
      final sounding = transpositionService.getSoundingNote('Do4', InstrumentProfileEntity.flute);
      final freq = transpositionService.getSoundingFrequency('Do4', InstrumentProfileEntity.flute);

      expect(sounding, equals('Do4'));
      expect(freq, closeTo(261.63, 0.1));
    });

    test('Si♭ Instrument (Bb Trumpet, Clarinet) transposes written Do4 to sounding La#3/Sib3', () {
      final sounding = transpositionService.getSoundingNote('Do4', InstrumentProfileEntity.bbTrumpet);
      final freq = transpositionService.getSoundingFrequency('Do4', InstrumentProfileEntity.bbTrumpet);

      expect(sounding, equals('La#3'));
      // Frecuencia de Sib3 / La#3 = 233.08 Hz
      expect(freq, closeTo(233.08, 0.15));
    });

    test('Mi♭ Instrument (Eb Alto Sax) transposes written Do4 to sounding Re#3/Mib3', () {
      final sounding = transpositionService.getSoundingNote('Do4', InstrumentProfileEntity.ebAltoSax);
      final freq = transpositionService.getSoundingFrequency('Do4', InstrumentProfileEntity.ebAltoSax);

      expect(sounding, equals('Re#3'));
      // Frecuencia de Mib3 / Re#3 = 155.56 Hz
      expect(freq, closeTo(155.56, 0.15));
    });

    test('Fa Instrument (French Horn) transposes written Do4 to sounding Fa3', () {
      final sounding = transpositionService.getSoundingNote('Do4', InstrumentProfileEntity.fHorn);
      final freq = transpositionService.getSoundingFrequency('Do4', InstrumentProfileEntity.fHorn);

      expect(sounding, equals('Fa3'));
      // Frecuencia de Fa3 = 174.61 Hz
      expect(freq, closeTo(174.61, 0.15));
    });

    test('Piccolo transposes written Do4 to sounding Do5 (one octave up)', () {
      final sounding = transpositionService.getSoundingNote('Do4', InstrumentProfileEntity.piccolo);
      final freq = transpositionService.getSoundingFrequency('Do4', InstrumentProfileEntity.piccolo);

      expect(sounding, equals('Do5'));
      expect(freq, closeTo(523.25, 0.15));
    });

    test('Alto Flute in G transposes written Do4 to sounding Sol3 (-5 semitones)', () {
      final sounding = transpositionService.getSoundingNote('Do4', InstrumentProfileEntity.altoFlute);
      final freq = transpositionService.getSoundingFrequency('Do4', InstrumentProfileEntity.altoFlute);

      expect(sounding, equals('Sol3'));
      expect(freq, closeTo(196.0, 0.15));
    });

    test('Clarinet in A transposes written Do4 to sounding La3 (-3 semitones)', () {
      final sounding = transpositionService.getSoundingNote('Do4', InstrumentProfileEntity.aClarinet);
      final freq = transpositionService.getSoundingFrequency('Do4', InstrumentProfileEntity.aClarinet);

      expect(sounding, equals('La3'));
      expect(freq, closeTo(220.0, 0.15));
    });

    test('Guitar / Bass transposes written Do4 to sounding Do3 (one octave down)', () {
      final sounding = transpositionService.getSoundingNote('Do4', InstrumentProfileEntity.guitar);
      final freq = transpositionService.getSoundingFrequency('Do4', InstrumentProfileEntity.guitar);

      expect(sounding, equals('Do3'));
      // Frecuencia de Do3 = 130.81 Hz
      expect(freq, closeTo(130.81, 0.15));
    });

    test('getWrittenNote accurately recovers written notation from sounding pitch', () {
      final written = transpositionService.getWrittenNote('La#3', InstrumentProfileEntity.bbTrumpet);
      expect(written, equals('Do4'));
    });

    test('supports English notation (C4, Bb3, F#4) seamlessly', () {
      final sounding = transpositionService.getSoundingNote('C4', InstrumentProfileEntity.bbTrumpet);
      expect(sounding, equals('La#3'));

      final freq = transpositionService.getSoundingFrequency('A4', InstrumentProfileEntity.flute);
      expect(freq, closeTo(440.0, 0.1));
    });

    test('supports Unicode flat and sharp characters (♭ and ♯)', () {
      final sounding = transpositionService.getSoundingNote('Si♭3', InstrumentProfileEntity.flute);
      expect(sounding, equals('La#3'));

      final written = transpositionService.getWrittenNote('Si♭3', InstrumentProfileEntity.bbTrumpet);
      expect(written, equals('Do4'));
    });
  });
}
