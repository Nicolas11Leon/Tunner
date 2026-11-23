import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/domain/dj_mix_wav_encoder.dart';
import 'package:tunner/features/practice_recorder/domain/offline_practice_take_analyzer.dart';
import 'package:tunner/features/practice_recorder/domain/spectral_comparator_service.dart';

Uint8List _synthesizeSineWav({
  required double frequencyHz,
  int sampleRate = 44100,
  double durationSeconds = 1.0,
  double amplitude = 0.5,
}) {
  final count = (sampleRate * durationSeconds).round();
  final samples = Float32List(count);
  for (int i = 0; i < count; i++) {
    samples[i] = amplitude * math.sin(2.0 * math.pi * frequencyHz * (i / sampleRate));
  }
  return DjMixWavEncoder.encode(
    samples: samples,
    sampleRate: sampleRate,
    numChannels: 1,
  );
}

void main() {
  group('OfflinePracticeTakeAnalyzer', () {
    const analyzer = OfflinePracticeTakeAnalyzer();

    test('decodes WAV via OfflineWavDecoder and extracts duration, RMS, peak, and A4 pitch contour', () {
      final wavBytes = _synthesizeSineWav(
        frequencyHz: 440.0,
        sampleRate: 44100,
        durationSeconds: 1.0,
        amplitude: 0.5,
      );

      final report = analyzer.analyzeWavBytesDetailed(
        wavBytes,
        takeId: 'take_a4',
        takeName: 'Toma A4 Pura',
        filePath: '/tmp/take_a4.wav',
      );

      expect(report.sampleRate, equals(44100));
      expect(report.channels, equals(1));
      expect(report.durationMs, closeTo(1000, 10));
      // Sine wave of amplitude 0.5 has RMS = 0.5 / sqrt(2) ~= 0.3535
      expect(report.rms, closeTo(0.5 / math.sqrt2, 0.01));
      expect(report.peak, closeTo(0.5, 0.01));

      final take = report.take;
      expect(take.id, equals('take_a4'));
      expect(take.duration.inMilliseconds, closeTo(1000, 10));
      expect(take.waveformPeaks.length, equals(64));
      expect(take.pitchTrack, isNotEmpty);
      expect(take.spectralTrack, isNotEmpty);

      final voiced = take.pitchTrack.where((p) => !p.isSilent).toList();
      expect(voiced, isNotEmpty);
      for (final sample in voiced) {
        expect(sample.frequencyHz, closeTo(440.0, 2.5));
        expect(sample.targetNoteName, equals('A4'));
        expect(sample.centsDeviation.abs(), lessThan(10.0));
      }

      expect(take.averageSpectralCentroidHz, closeTo(440.0, 60.0));
      expect(report.toJson()['takeId'], equals('take_a4'));
    });

    test('integrates with SpectralComparatorService and serializes SpectralComparisonResult to/from JSON', () {
      final wavSharp = _synthesizeSineWav(frequencyHz: 446.0, durationSeconds: 0.8);
      final wavInTune = _synthesizeSineWav(frequencyHz: 440.0, durationSeconds: 0.8);

      final takeA = analyzer.analyzeWavBytes(
        wavSharp,
        takeId: 'take_a',
        takeName: 'Toma 1 (Alta)',
      );
      final takeB = analyzer.analyzeWavBytes(
        wavInTune,
        takeId: 'take_b',
        takeName: 'Toma 2 (Afinada)',
      );

      const comparator = SpectralComparatorService();
      final result = comparator.compareTakes(takeA, takeB);

      expect(result.meanPitchDeviationA, greaterThan(result.meanPitchDeviationB));
      expect(result.pitchStabilityDelta, greaterThan(10.0));
      expect(result.inTunePercentageB, greaterThan(80.0));

      // JSON round-trip with points
      final fullJson = result.toJson();
      final restored = SpectralComparisonResult.fromJson(fullJson);
      expect(restored.takeAId, equals('take_a'));
      expect(restored.takeBId, equals('take_b'));
      expect(restored.pitchStabilityDelta, closeTo(result.pitchStabilityDelta, 1e-6));
      expect(restored.comparisonPoints.length, equals(result.comparisonPoints.length));

      // Compact JSON without points (for LLM token efficiency)
      final compactMap = result.toMap(includePoints: false);
      expect(compactMap.containsKey('comparisonPoints'), isFalse);
      expect(compactMap['comparisonPointsCount'], equals(result.comparisonPoints.length));
    });
  });
}
