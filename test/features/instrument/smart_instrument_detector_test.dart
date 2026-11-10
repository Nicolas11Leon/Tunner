import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/instrument/domain/smart_instrument_detector.dart';

void main() {
  group('SmartInstrumentDetector Domain Tests', () {
    late SmartInstrumentDetector detector;

    setUp(() {
      detector = SmartInstrumentDetector();
    });

    test('Identifies Flute accurately from clean fundamental and minimal overtones', () {
      const fluteSig = AcousticSignature(
        fundamentalFrequencyHz: 440.0, // A4 (dentro de rango de flauta 261-2093 Hz)
        clarity: 0.96,
        overtoneAmplitudes: [1.0, 0.12, 0.04, 0.02, 0.01, 0.0, 0.0, 0.0],
        spectralCentroidHz: 720.0,
      );

      final match = detector.bestMatch(fluteSig, minimumConfidence: 0.80);

      expect(match, isNotNull);
      expect(match!.instrument.id, equals('flute'));
      expect(match.soundFontPatch, equals(73)); // GM Flute
      expect(match.confidence, greaterThanOrEqualTo(0.85));
      expect(match.detectionReason, contains('fundamental'));
    });

    test('Identifies Bb Clarinet from prominent odd overtones (H3/H5)', () {
      const clarinetSig = AcousticSignature(
        fundamentalFrequencyHz: 293.66, // D4
        clarity: 0.94,
        overtoneAmplitudes: [1.0, 0.06, 0.62, 0.04, 0.33, 0.02, 0.15, 0.01],
        spectralCentroidHz: 910.0,
      );

      final match = detector.bestMatch(clarinetSig, minimumConfidence: 0.80);

      expect(match, isNotNull);
      expect(match!.instrument.id, equals('bb_clarinet'));
      expect(match.soundFontPatch, equals(71)); // GM Clarinet
      expect(match.confidence, greaterThanOrEqualTo(0.85));
      expect(match.detectionReason, contains('impares'));
    });

    test('Identifies Bb Trumpet from rich brass overtones and high spectral centroid', () {
      const trumpetSig = AcousticSignature(
        fundamentalFrequencyHz: 466.16, // Bb4
        clarity: 0.95,
        overtoneAmplitudes: [1.0, 0.82, 0.68, 0.52, 0.38, 0.25, 0.16, 0.08],
        spectralCentroidHz: 1420.0,
      );

      final match = detector.bestMatch(trumpetSig, minimumConfidence: 0.80);

      expect(match, isNotNull);
      expect(match!.instrument.id, equals('bb_trumpet'));
      expect(match.soundFontPatch, equals(56)); // GM Trumpet
      expect(match.confidence, greaterThanOrEqualTo(0.85));
      expect(match.detectionReason, contains('brillante'));
    });

    test('Identifies Cello from low frequency range and rich string resonance', () {
      const celloSig = AcousticSignature(
        fundamentalFrequencyHz: 110.0, // A2 (Cuerda La del Cello)
        clarity: 0.92,
        overtoneAmplitudes: [1.0, 0.64, 0.44, 0.28, 0.16, 0.09, 0.05, 0.02],
        spectralCentroidHz: 540.0,
      );

      final match = detector.bestMatch(celloSig, minimumConfidence: 0.75);

      expect(match, isNotNull);
      expect(match!.instrument.id, equals('cello'));
      expect(match.soundFontPatch, equals(42)); // GM Cello
    });

    test('Discards signals with low clarity (unvoiced or background noise)', () {
      const noisySig = AcousticSignature(
        fundamentalFrequencyHz: 440.0,
        clarity: 0.45, // Por debajo del umbral de periodicidad (0.60)
        overtoneAmplitudes: [1.0, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2],
        spectralCentroidHz: 1200.0,
      );

      final candidates = detector.detectCandidates(noisySig);
      expect(candidates.isEmpty, isTrue);
      expect(detector.bestMatch(noisySig), isNull);
    });

    test('Returns ranked candidate list within limit', () {
      const sig = AcousticSignature(
        fundamentalFrequencyHz: 440.0,
        clarity: 0.90,
        overtoneAmplitudes: [1.0, 0.5, 0.3, 0.2, 0.1, 0.05, 0.02, 0.01],
        spectralCentroidHz: 850.0,
      );

      final list = detector.detectCandidates(sig, limit: 3);

      expect(list.length, lessThanOrEqualTo(3));
      expect(list.isNotEmpty, isTrue);
      // Orden descendente por confianza
      for (int i = 0; i < list.length - 1; i++) {
        expect(list[i].confidence, greaterThanOrEqualTo(list[i + 1].confidence));
      }
    });
  });
}
