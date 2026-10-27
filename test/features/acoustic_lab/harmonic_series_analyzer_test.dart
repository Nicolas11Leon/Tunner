import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/acoustic_lab/domain/harmonic_series_analyzer.dart';

void main() {
  group('HarmonicSeriesAnalyzer Tests', () {
    const analyzer = HarmonicSeriesAnalyzer(maxHarmonics: 8);

    test('Returns empty result when fundamental is non-positive or sub-acoustic', () {
      final res0 = analyzer.analyze(fundamentalHz: 0.0);
      expect(res0.harmonics, isEmpty);
      expect(res0.spectralCentroidHz, equals(0.0));

      final resSub = analyzer.analyze(fundamentalHz: 15.0);
      expect(resSub.harmonics, isEmpty);
    });

    test('Generates 8 harmonics with exact integer multiples of fundamental frequency', () {
      final result = analyzer.analyze(fundamentalHz: 440.0);

      expect(result.harmonics.length, equals(8));
      expect(result.harmonics[0].harmonicNumber, equals(1));
      expect(result.harmonics[0].frequencyHz, equals(440.0));
      expect(result.harmonics[0].intervalLabel, contains("Fundamental"));

      expect(result.harmonics[1].harmonicNumber, equals(2));
      expect(result.harmonics[1].frequencyHz, equals(880.0));

      expect(result.harmonics[2].harmonicNumber, equals(3));
      expect(result.harmonics[2].frequencyHz, equals(1320.0));

      expect(result.harmonics[7].harmonicNumber, equals(8));
      expect(result.harmonics[7].frequencyHz, equals(3520.0));
    });

    test('Calculates low THD for pure sine wave', () {
      const sampleRate = 44100.0;
      const numSamples = 1024;
      const f0 = 440.0;

      // Generar onda senoidal pura a 440 Hz
      final samples = List.generate(numSamples, (i) {
        return math.sin(2.0 * math.pi * f0 * i / sampleRate);
      });

      final result = analyzer.analyze(
        fundamentalHz: f0,
        samples: samples,
        sampleRate: sampleRate,
      );

      expect(result.harmonics.length, equals(8));
      expect(result.harmonics.first.relativeAmplitude, greaterThan(0.9));
      // En onda pura, los armónicos 2 a 8 son despreciables
      expect(result.totalHarmonicDistortionPercent, lessThan(8.0));
      expect(result.timbreClassification, contains("Puro"));
    });

    test('Calculates higher THD and brighter centroid for rich harmonic wave', () {
      const sampleRate = 44100.0;
      const numSamples = 1024;
      const f0 = 440.0;

      // Generar onda rica en armónicos (fundamental + 2do + 3er armónico prominentes)
      final samples = List.generate(numSamples, (i) {
        final t = i / sampleRate;
        return 0.6 * math.sin(2.0 * math.pi * f0 * t) +
            0.4 * math.sin(2.0 * math.pi * (2 * f0) * t) +
            0.3 * math.sin(2.0 * math.pi * (3 * f0) * t);
      });

      final result = analyzer.analyze(
        fundamentalHz: f0,
        samples: samples,
        sampleRate: sampleRate,
      );

      expect(result.totalHarmonicDistortionPercent, greaterThan(25.0));
      expect(result.spectralCentroidHz, greaterThan(f0));
    });
  });
}
