import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/tuner/domain/temperament_engine.dart';

void main() {
  group('TemperamentEngine Mathematical and Domain Tests', () {
    const engine = TemperamentEngine();

    test('All 8 canonical temperaments are registered with 12 offsets each', () {
      expect(TemperamentEngine.allTemperaments.length, equals(8));
      for (final temp in TemperamentEngine.allTemperaments) {
        expect(temp.centsOffsets.length, equals(12));
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
      // En C Justo: Mi (índice 4) debe tener offset de -13.69 cents
      final miOffset = engine.getCentsOffset(noteIndex: 4, temperament: justTemp, rootKey: 0);
      expect(miOffset, closeTo(-13.69, 0.01));

      // Comprobar la frecuencia de E4 (MIDI 64) relativa a C4 (MIDI 60)
      // C4 en Equal con A4=440 es 261.625 Hz
      // En Just Intonation, E4 = C4 * (5/4) = 261.625 * 1.25 = 327.031 Hz
      // Frecuencia E4 en Equal es 440 * 2^(-7/12) = 329.627 Hz
      // Con -13.69 cents: 329.627 * 2^(-13.69/1200) = 327.031 Hz
      final c4Freq = engine.getTargetFrequency(midiNumber: 60, temperament: justTemp, a4Ref: 440.0, rootKey: 0);
      final e4Freq = engine.getTargetFrequency(midiNumber: 64, temperament: justTemp, a4Ref: 440.0, rootKey: 0);
      expect(e4Freq / c4Freq, closeTo(1.25, 0.001));
    });

    test('Circular key modulation shifts intervals relative to chosen root note', () {
      final justTemp = TemperamentEngine.getById('just_intonation');
      // Con tónica en Re (rootKey = 2):
      // La tercera mayor es Fa# (índice 6: 6 - 2 = 4 grados)
      final fSharpOffset = engine.getCentsOffset(noteIndex: 6, temperament: justTemp, rootKey: 2);
      expect(fSharpOffset, closeTo(-13.69, 0.01));

      // La tónica Re (índice 2) debe tener 0 offset
      final dOffset = engine.getCentsOffset(noteIndex: 2, temperament: justTemp, rootKey: 2);
      expect(dOffset, equals(0.0));
    });

    test('Pythagorean tuning produces pure 3:2 fifth (+1.96 cents offset from 700 cents equal)', () {
      final pythTemp = TemperamentEngine.getById('pythagorean');
      // Quinta de Do es Sol (índice 7)
      final solOffset = engine.getCentsOffset(noteIndex: 7, temperament: pythTemp, rootKey: 0);
      expect(solOffset, closeTo(1.96, 0.01));
    });

    test('calculateCentsDeviation accurately evaluates microtonal pitch error', () {
      // 440 vs 440 = 0 cents
      expect(engine.calculateCentsDeviation(detectedFrequency: 440.0, targetFrequency: 440.0), closeTo(0.0, 0.001));

      // 442.0 Hz contra 440.0 Hz = +7.85 cents
      expect(engine.calculateCentsDeviation(detectedFrequency: 442.0, targetFrequency: 440.0), closeTo(7.85, 0.01));

      // Cero o negativo retorna 0.0 de forma segura
      expect(engine.calculateCentsDeviation(detectedFrequency: 0.0, targetFrequency: 440.0), equals(0.0));
    });
  });
}
