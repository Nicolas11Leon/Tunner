import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/chord_analyzer/domain/chord_entity.dart';
import 'package:tunner/features/chord_analyzer/domain/chroma_vector_calculator.dart';
import 'package:tunner/features/chord_analyzer/domain/polyphonic_chord_recognizer.dart';

List<double> generatePolyphonicTone({
  required List<double> frequencies,
  int sampleCount = 2048,
  double sampleRate = 44100.0,
}) {
  final samples = List<double>.filled(sampleCount, 0.0);
  for (int i = 0; i < sampleCount; i++) {
    double sum = 0.0;
    for (final freq in frequencies) {
      sum += math.sin(2.0 * math.pi * freq * i / sampleRate);
    }
    samples[i] = sum / frequencies.length;
  }
  return samples;
}

void main() {
  group('ChordEntity Domain Tests', () {
    test('Correctly maps root note and symbols for major and minor chords', () {
      final chordC = ChordEntity(
        rootNoteIndex: 0,
        quality: ChordQuality.major,
        confidence: 0.95,
        chromaVector: List.filled(12, 0.0),
        notes: const ['Do', 'Mi', 'Sol'],
      );

      expect(chordC.symbol, equals('C'));
      expect(chordC.displayName, equals('Do Mayor'));
      expect(chordC.rootNameSpanish, equals('Do'));
      expect(chordC.rootNameInternational, equals('C'));
      expect(chordC.formula, equals('1 - 3 - 5'));
      expect(chordC.isRecognized, isTrue);

      final chordAm = ChordEntity(
        rootNoteIndex: 9,
        quality: ChordQuality.minor,
        confidence: 0.88,
        chromaVector: List.filled(12, 0.0),
        notes: const ['La', 'Do', 'Mi'],
      );

      expect(chordAm.symbol, equals('Am'));
      expect(chordAm.displayName, equals('La Menor'));
      expect(chordAm.formula, equals('1 - b3 - 5'));
    });

    test('ChordEntity.none represents absence of detected chord', () {
      final none = ChordEntity.none;
      expect(none.isRecognized, isFalse);
      expect(none.symbol, equals('--'));
      expect(none.displayName, equals('Sin acorde detectado'));
      expect(none.notes, isEmpty);
    });

    test('Chord qualities define accurate semitone intervals and formulas', () {
      expect(ChordQuality.major.intervalsInSemitones, equals([0, 4, 7]));
      expect(ChordQuality.minor.intervalsInSemitones, equals([0, 3, 7]));
      expect(ChordQuality.dominant7.intervalsInSemitones, equals([0, 4, 7, 10]));
      expect(ChordQuality.major7.intervalsInSemitones, equals([0, 4, 7, 11]));
      expect(ChordQuality.minor7.intervalsInSemitones, equals([0, 3, 7, 10]));
      expect(ChordQuality.diminished.intervalsInSemitones, equals([0, 3, 6]));
      expect(ChordQuality.augmented.intervalsInSemitones, equals([0, 4, 8]));
      expect(ChordQuality.sus4.intervalsInSemitones, equals([0, 5, 7]));
      expect(ChordQuality.sus2.intervalsInSemitones, equals([0, 2, 7]));
    });
  });

  group('ChromaVectorCalculator Domain Tests', () {
    const calculator = ChromaVectorCalculator();

    test('Rejects pure silence and returns zero vector', () {
      final silence = List<double>.filled(1024, 0.0);
      final chroma = calculator.calculateFromSamples(samples: silence);

      expect(chroma.length, equals(12));
      for (final v in chroma) {
        expect(v, equals(0.0));
      }
    });

    test('Identifies pitch classes for synthetic C Major triad (C4, E4, G4)', () {
      // C4 = 261.63 Hz, E4 = 329.63 Hz, G4 = 392.00 Hz
      final samples = generatePolyphonicTone(
        frequencies: [261.63, 329.63, 392.00],
      );

      final chroma = calculator.calculateFromSamples(samples: samples);

      // C = 0, E = 4, G = 7
      expect(chroma[0], greaterThan(0.2));
      expect(chroma[4], greaterThan(0.2));
      expect(chroma[7], greaterThan(0.2));

      // D (2), F (5), B (11) should be lower
      expect(chroma[0], greaterThan(chroma[2]));
      expect(chroma[4], greaterThan(chroma[5]));
    });

    test('calculateFromFrequencies projects harmonic peaks directly', () {
      // Map with A4 (440 Hz) and E5 (659.25 Hz)
      final chroma = calculator.calculateFromFrequencies(
        frequencyAmplitudes: {440.0: 1.0, 659.25: 0.8},
      );

      // A = 9, E = 4
      expect(chroma[9], greaterThan(0.5));
      expect(chroma[4], greaterThan(0.4));
    });
  });

  group('PolyphonicChordRecognizer Domain Tests', () {
    late PolyphonicChordRecognizer recognizer;

    setUp(() {
      recognizer = PolyphonicChordRecognizer();
    });

    test('Accurately identifies synthetic C Major triad (C-E-G)', () {
      final samples = generatePolyphonicTone(
        frequencies: [261.63, 329.63, 392.00],
      );

      final chord = recognizer.identifyFromSamples(samples: samples);

      expect(chord.isRecognized, isTrue);
      expect(chord.rootNoteIndex, equals(0)); // C / Do
      expect(chord.quality, equals(ChordQuality.major));
      expect(chord.symbol, equals('C'));
      expect(chord.confidence, greaterThan(0.70));
    });

    test('Accurately identifies synthetic A Minor triad (A-C-E)', () {
      // A3 = 220.00 Hz, C4 = 261.63 Hz, E4 = 329.63 Hz
      final samples = generatePolyphonicTone(
        frequencies: [220.00, 261.63, 329.63],
        sampleCount: 4096,
      );

      final chord = recognizer.identifyFromSamples(samples: samples);

      expect(chord.isRecognized, isTrue);
      expect(chord.rootNoteIndex, equals(9)); // A / La
      expect(chord.quality, equals(ChordQuality.minor));
      expect(chord.symbol, equals('Am'));
      expect(chord.displayName, equals('La Menor'));
    });

    test('Accurately identifies G Dominant 7th (G-B-D-F)', () {
      // G3 = 196.00 Hz, B3 = 246.94 Hz, D4 = 293.66 Hz, F4 = 349.23 Hz
      final samples = generatePolyphonicTone(
        frequencies: [196.00, 246.94, 293.66, 349.23],
        sampleCount: 4096,
      );

      final chord = recognizer.identifyFromSamples(samples: samples);

      expect(chord.isRecognized, isTrue);
      expect(chord.rootNoteIndex, equals(7)); // G / Sol
      expect(chord.quality, equals(ChordQuality.dominant7));
      expect(chord.symbol, equals('G7'));
    });

    test('Returns ChordEntity.none when samples are silent', () {
      final silence = List<double>.filled(1024, 0.0);
      final chord = recognizer.identifyFromSamples(samples: silence);

      expect(chord.isRecognized, isFalse);
      expect(chord, equals(ChordEntity.none));
    });

    test('reset clears internal detection history', () {
      recognizer.reset();
      expect(recognizer.identifyFromChroma(List.filled(12, 0.0)), equals(ChordEntity.none));
    });
  });
}
