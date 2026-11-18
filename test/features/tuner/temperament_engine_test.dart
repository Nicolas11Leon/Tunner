import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/tuner/domain/temperament_engine.dart';

void main() {
  group('TemperamentEngine Mathematical and Domain Tests', () {
    const engine = TemperamentEngine();

    test('All 11 canonical temperaments are registered with 12 offsets each', () {
      expect(TemperamentEngine.allTemperaments.length, equals(11));
      for (final temp in TemperamentEngine.allTemperaments) {
        expect(temp.centsOffsets.length, equals(12));
        expect(temp.id, isNotEmpty);
        expect(temp.name, isNotEmpty);
        expect(temp.historicalEra, isNotEmpty);
        expect(temp.description, isNotEmpty);
      }
    });

    test('Equal Temperament produces 0 cents offsets across all degrees', () {
      final equalTemp = TemperamentEngine.getById('equal');
      for (int i = 0; i < 12; i++) {
        expect(engine.getCentsOffset(noteIndex: i, temperament: equalTemp), equals(0.0));
      }
    });

    test('Concert Pitch A4 (MIDI 69) produces exactly 440 Hz in Equal Temperament', () {
      final equalTemp = TemperamentEngine.getById('equal');
      final freq = engine.getTargetFrequency(
        midiNumber: 69,
        temperament: equalTemp,
        a4Ref: 440.0,
      );
      expect(freq, closeTo(440.0, 0.001));
    });

    test('Just Intonation produces pure major third (5:4 ratio, -13.69 cents offset from equal)', () {
      final justTemp = TemperamentEngine.getById('just_intonation');
      final miOffset = engine.getCentsOffset(noteIndex: 4, temperament: justTemp, rootKey: 0);
      expect(miOffset, closeTo(-13.69, 0.01));

      final c4Freq = engine.getTargetFrequency(midiNumber: 60, temperament: justTemp, a4Ref: 440.0, rootKey: 0);
      final e4Freq = engine.getTargetFrequency(midiNumber: 64, temperament: justTemp, a4Ref: 440.0, rootKey: 0);
      expect(e4Freq / c4Freq, closeTo(1.25, 0.001));
    });

    test('Kirnberger I produces acoustically pure 5:4 major third and concentrated syntonic comma', () {
      final kirnI = TemperamentEngine.kirnbergerI;
      expect(kirnI.id, 'kirnberger_i');

      // 1. Tercera mayor pura C-E (grado 4): ratio 5:4 con -13.69 cents respecto a 12-TET
      final eOffset = engine.getCentsOffset(noteIndex: 4, temperament: kirnI, rootKey: 0);
      expect(eOffset, closeTo(-13.69, 0.01));

      final c4Freq = engine.getTargetFrequency(midiNumber: 60, temperament: kirnI, a4Ref: 440.0, rootKey: 0);
      final e4Freq = engine.getTargetFrequency(midiNumber: 64, temperament: kirnI, a4Ref: 440.0, rootKey: 0);
      expect(e4Freq / c4Freq, closeTo(1.25, 0.001));

      // 2. Quinta pura C-G (grado 7): +1.96 cents
      final gOffset = engine.getCentsOffset(noteIndex: 7, temperament: kirnI, rootKey: 0);
      expect(gOffset, closeTo(1.96, 0.01));

      // 3. Quinta con coma sintónica concentrada D-A:
      // Re (grado 2) = +3.91, La (grado 9) = -15.64
      final dOffset = engine.getCentsOffset(noteIndex: 2, temperament: kirnI, rootKey: 0);
      final aOffset = engine.getCentsOffset(noteIndex: 9, temperament: kirnI, rootKey: 0);
      expect(dOffset, closeTo(3.91, 0.01));
      expect(aOffset, closeTo(-15.64, 0.01));
      // Intervalo D-A: (900 - 15.64) - (200 + 3.91) = 680.45 cents (701.96 - 21.51)
      final daCents = (700.0 + (aOffset - dOffset));
      expect(daCents, closeTo(680.45, 0.05));
    });

    test('Werckmeister IV (Septenarius) correctly registers compensated fifths and degree offsets', () {
      final werckIV = TemperamentEngine.werckmeisterIV;
      expect(werckIV.id, 'werckmeister_iv');

      expect(engine.getCentsOffset(noteIndex: 0, temperament: werckIV), 0.0);
      expect(engine.getCentsOffset(noteIndex: 1, temperament: werckIV), -6.0); // C#
      expect(engine.getCentsOffset(noteIndex: 2, temperament: werckIV), -4.0); // D
      expect(engine.getCentsOffset(noteIndex: 4, temperament: werckIV), -8.0); // E
      expect(engine.getCentsOffset(noteIndex: 5, temperament: werckIV), 2.0); // F
      expect(engine.getCentsOffset(noteIndex: 6, temperament: werckIV), -10.0); // F#
      expect(engine.getCentsOffset(noteIndex: 7, temperament: werckIV), -4.0); // G
      expect(engine.getCentsOffset(noteIndex: 10, temperament: werckIV), 0.0); // Bb
      expect(engine.getCentsOffset(noteIndex: 11, temperament: werckIV), -8.0); // B
    });

    test('Neidhardt 1724 (Grosse Stadt) circulating temperament produces smooth progressive offsets', () {
      final neidhardt = TemperamentEngine.neidhardt1724;
      expect(neidhardt.id, 'neidhardt_1724');

      expect(engine.getCentsOffset(noteIndex: 0, temperament: neidhardt), 0.0);
      expect(engine.getCentsOffset(noteIndex: 1, temperament: neidhardt), closeTo(-7.82, 0.01));
      expect(engine.getCentsOffset(noteIndex: 2, temperament: neidhardt), closeTo(-3.91, 0.01));
      expect(engine.getCentsOffset(noteIndex: 4, temperament: neidhardt), closeTo(-7.82, 0.01));
      expect(engine.getCentsOffset(noteIndex: 5, temperament: neidhardt), closeTo(1.96, 0.01));
      expect(engine.getCentsOffset(noteIndex: 6, temperament: neidhardt), closeTo(-9.78, 0.01));
      expect(engine.getCentsOffset(noteIndex: 7, temperament: neidhardt), closeTo(-1.96, 0.01));
      expect(engine.getCentsOffset(noteIndex: 10, temperament: neidhardt), 0.0);
    });

    test('Circular key modulation shifts intervals relative to chosen root note', () {
      final justTemp = TemperamentEngine.getById('just_intonation');
      final fSharpOffset = engine.getCentsOffset(noteIndex: 6, temperament: justTemp, rootKey: 2);
      expect(fSharpOffset, closeTo(-13.69, 0.01));

      final dOffset = engine.getCentsOffset(noteIndex: 2, temperament: justTemp, rootKey: 2);
      expect(dOffset, equals(0.0));
    });

    test('Pythagorean tuning produces pure 3:2 fifth (+1.96 cents offset from 700 cents equal)', () {
      final pythTemp = TemperamentEngine.getById('pythagorean');
      final solOffset = engine.getCentsOffset(noteIndex: 7, temperament: pythTemp, rootKey: 0);
      expect(solOffset, closeTo(1.96, 0.01));
    });

    test('calculateCentsDeviation accurately evaluates microtonal pitch error', () {
      expect(engine.calculateCentsDeviation(detectedFrequency: 440.0, targetFrequency: 440.0), closeTo(0.0, 0.001));
      expect(engine.calculateCentsDeviation(detectedFrequency: 442.0, targetFrequency: 440.0), closeTo(7.85, 0.01));
      expect(engine.calculateCentsDeviation(detectedFrequency: 0.0, targetFrequency: 440.0), equals(0.0));
    });

    test('getById resolves all 11 canonical IDs and falls back safely to equal', () {
      const canonicalIds = [
        'equal',
        'pythagorean',
        'just_intonation',
        'meantone_quarter',
        'werckmeister_iii',
        'kirnberger_iii',
        'vallotti',
        'young_ii',
        'werckmeister_iv',
        'kirnberger_i',
        'neidhardt_1724',
      ];

      for (final id in canonicalIds) {
        final t = TemperamentEngine.getById(id);
        expect(t.id, id);
      }

      final fallback = TemperamentEngine.getById('invalid_id_xyz');
      expect(fallback.id, 'equal');
    });
  });
}
