import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';
import 'package:tunner/features/practice_recorder/domain/spectral_comparator_service.dart';

void main() {
  group('MultiTrackSessionEntity & PracticeTakeEntity Domain Tests', () {
    test('serializes and deserializes MultiTrackSessionEntity cleanly', () {
      final take1 = PracticeTakeEntity(
        id: 'take_1',
        name: 'Toma 1 (Afinación Base)',
        timestamp: DateTime(2026, 10, 28, 10, 0),
        duration: const Duration(seconds: 4),
        filePath: '/tmp/take1.wav',
        waveformPeaks: const [0.2, 0.5, 0.8, 0.4],
        pitchTrack: const [
          TimedPitchSample(timeMs: 0, frequencyHz: 440.0, centsDeviation: 8.5, targetNoteName: 'La4'),
          TimedPitchSample(timeMs: 50, frequencyHz: 441.0, centsDeviation: 12.0, targetNoteName: 'La4'),
        ],
        spectralTrack: const [
          TimedSpectralSample(timeMs: 0, spectralCentroidHz: 1200.0, thdPercent: 4.5, rmsEnergy: 0.2),
          TimedSpectralSample(timeMs: 50, spectralCentroidHz: 1250.0, thdPercent: 4.8, rmsEnergy: 0.25),
        ],
      );

      final session = MultiTrackSessionEntity(
        id: 'session_1',
        title: 'Sonata en Re Mayor - Compases 1 al 8',
        createdAt: DateTime(2026, 10, 28, 9, 30),
        bpm: 100,
        takes: [take1],
        selectedTakeAId: 'take_1',
      );

      final jsonStr = session.toJson();
      final restored = MultiTrackSessionEntity.fromJson(jsonStr);

      expect(restored.id, equals('session_1'));
      expect(restored.title, equals('Sonata en Re Mayor - Compases 1 al 8'));
      expect(restored.bpm, equals(100));
      expect(restored.takes.length, equals(1));
      expect(restored.takes.first.name, equals('Toma 1 (Afinación Base)'));
      expect(restored.takes.first.pitchTrack.length, equals(2));
      expect(restored.takes.first.pitchTrack.first.centsDeviation, equals(8.5));
      expect(restored.takes.first.spectralTrack.first.spectralCentroidHz, equals(1200.0));
      expect(restored.takeA?.id, equals('take_1'));
    });

    test('PracticeTakeEntity computes accurate averages ignoring silent samples', () {
      final take = PracticeTakeEntity(
        id: 'take_test',
        name: 'Toma Test',
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 2),
        filePath: '',
        pitchTrack: const [
          TimedPitchSample(timeMs: 0, frequencyHz: 440.0, centsDeviation: 10.0, targetNoteName: 'La4'),
          TimedPitchSample(timeMs: 100, frequencyHz: 0.0, centsDeviation: 0.0, targetNoteName: '--', isSilent: true),
          TimedPitchSample(timeMs: 200, frequencyHz: 440.0, centsDeviation: -20.0, targetNoteName: 'La4'),
        ],
        spectralTrack: const [
          TimedSpectralSample(timeMs: 0, spectralCentroidHz: 1000.0, thdPercent: 2.0, rmsEnergy: 0.1),
          TimedSpectralSample(timeMs: 100, spectralCentroidHz: 0.0, thdPercent: 0.0, rmsEnergy: 0.001), // Muted/noise
          TimedSpectralSample(timeMs: 200, spectralCentroidHz: 1200.0, thdPercent: 2.5, rmsEnergy: 0.15),
        ],
      );

      // Desviación media: (|10| + |-20|) / 2 = 15.0 cents
      expect(take.averagePitchDeviationCents, closeTo(15.0, 0.01));

      // Centroide medio: (1000 + 1200) / 2 = 1100.0 Hz
      expect(take.averageSpectralCentroidHz, closeTo(1100.0, 0.01));
    });
  });

  group('SpectralComparatorService Unit Tests', () {
    const comparator = SpectralComparatorService();

    test('accurately calculates intonation improvement and stability delta between Take A and Take B', () {
      final takeA = PracticeTakeEntity(
        id: 'take_a',
        name: 'Toma 1 (Inestable)',
        timestamp: DateTime(2026, 10, 28, 10, 0),
        duration: const Duration(milliseconds: 500),
        filePath: '',
        pitchTrack: const [
          TimedPitchSample(timeMs: 0, frequencyHz: 440.0, centsDeviation: 14.0, targetNoteName: 'La4'),
          TimedPitchSample(timeMs: 100, frequencyHz: 440.0, centsDeviation: -16.0, targetNoteName: 'La4'),
          TimedPitchSample(timeMs: 200, frequencyHz: 440.0, centsDeviation: 12.0, targetNoteName: 'La4'),
        ],
        spectralTrack: const [
          TimedSpectralSample(timeMs: 0, spectralCentroidHz: 1100.0, thdPercent: 3.0, rmsEnergy: 0.2),
          TimedSpectralSample(timeMs: 100, spectralCentroidHz: 1150.0, thdPercent: 3.2, rmsEnergy: 0.2),
          TimedSpectralSample(timeMs: 200, spectralCentroidHz: 1120.0, thdPercent: 3.1, rmsEnergy: 0.2),
        ],
      );

      final takeB = PracticeTakeEntity(
        id: 'take_b',
        name: 'Toma 2 (Corregida)',
        timestamp: DateTime(2026, 10, 28, 10, 5),
        duration: const Duration(milliseconds: 500),
        filePath: '',
        pitchTrack: const [
          TimedPitchSample(timeMs: 0, frequencyHz: 440.0, centsDeviation: 2.0, targetNoteName: 'La4'),
          TimedPitchSample(timeMs: 100, frequencyHz: 440.0, centsDeviation: -3.0, targetNoteName: 'La4'),
          TimedPitchSample(timeMs: 200, frequencyHz: 440.0, centsDeviation: 1.0, targetNoteName: 'La4'),
        ],
        spectralTrack: const [
          TimedSpectralSample(timeMs: 0, spectralCentroidHz: 1350.0, thdPercent: 2.1, rmsEnergy: 0.25),
          TimedSpectralSample(timeMs: 100, spectralCentroidHz: 1400.0, thdPercent: 2.0, rmsEnergy: 0.26),
          TimedSpectralSample(timeMs: 200, spectralCentroidHz: 1380.0, thdPercent: 2.2, rmsEnergy: 0.25),
        ],
      );

      final result = comparator.compareTakes(takeA, takeB, timeStepMs: 100);

      // Toma A desviación promedio: (14 + 16 + 12) / 3 = 14.0 cents
      expect(result.meanPitchDeviationA, closeTo(14.0, 0.01));

      // Toma B desviación promedio: (2 + 3 + 1) / 3 = 2.0 cents
      expect(result.meanPitchDeviationB, closeTo(2.0, 0.01));

      // Delta de estabilidad: 14.0 - 2.0 = +12.0 cents (mejora sustancial)
      expect(result.pitchStabilityDelta, closeTo(12.0, 0.01));

      // Afinación perfecta (+-5 cents): Toma A = 0%, Toma B = 100%
      expect(result.inTunePercentageA, equals(0.0));
      expect(result.inTunePercentageB, equals(100.0));

      // Brillo espectral: Toma A ~1123.3 Hz, Toma B ~1376.6 Hz -> Delta ~+253 Hz (más brillante)
      expect(result.centroidDeltaHz, greaterThan(200.0));

      // Diagnóstico pedagógico
      expect(result.pedagogicalSummary, contains('Mejora notable de afinación'));
      expect(result.pedagogicalSummary, contains('más brillante y proyectado'));

      // Puntos comparativos
      expect(result.comparisonPoints.isNotEmpty, isTrue);
      final firstPoint = result.comparisonPoints.first;
      expect(firstPoint.centsA, equals(14.0));
      expect(firstPoint.centsB, equals(2.0));
      expect(firstPoint.centsDelta, equals(12.0));
    });
  });
}
