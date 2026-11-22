import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/acoustic_lab/domain/harmonic_series_analyzer.dart';
import 'package:tunner/features/tuner/presentation/tuner_viewmodel.dart';
import '../../helpers/studio_test_fakes.dart';

void main() {
  group('US-1.1 Real PCM Streaming & Harmonic Analysis Hardening', () {
    late TunerViewModel viewModel;
    late StudioFakePitchDetectorService fakePitchService;

    setUp(() {
      fakePitchService = StudioFakePitchDetectorService();
      viewModel = TunerViewModel(
        pitchService: fakePitchService,
      );
    });

    test('TunerViewModel updates latestAudioSamples and lastClarity from pitch service callbacks', () {
      expect(viewModel.latestAudioSamples, isNull);
      expect(viewModel.lastClarity, equals(0.0));

      final testWindow = List.generate(512, (i) => math.sin(2 * math.pi * 440.0 * i / 44100.0));
      fakePitchService.onAudioWindowCaptured?.call(testWindow);
      expect(viewModel.latestAudioSamples, equals(testWindow));

      fakePitchService.onClarityDetected?.call(0.92);
      expect(viewModel.lastClarity, equals(0.92));
    });

    test('HarmonicSeriesAnalyzer strictly rejects null or insufficient samples', () {
      const analyzer = HarmonicSeriesAnalyzer(maxHarmonics: 8);

      final emptyResult = analyzer.analyze(fundamentalHz: 440.0, samples: null);
      expect(emptyResult.harmonics, isEmpty);
      expect(emptyResult.spectralCentroidHz, equals(0.0));
      expect(emptyResult.totalHarmonicDistortionPercent, equals(0.0));

      final shortResult = analyzer.analyze(fundamentalHz: 440.0, samples: [0.1, 0.2]);
      expect(shortResult.harmonics, isEmpty);
    });

    test('HarmonicSeriesAnalyzer applies Hann window and computes pure harmonic spectrum accurately', () {
      const analyzer = HarmonicSeriesAnalyzer(maxHarmonics: 8);
      const sampleRate = 44100.0;
      const f0 = 440.0;
      final samples = List.generate(1024, (i) => math.sin(2 * math.pi * f0 * i / sampleRate));

      final result = analyzer.analyze(
        fundamentalHz: f0,
        samples: samples,
        sampleRate: sampleRate,
      );

      expect(result.harmonics.length, equals(8));
      expect(result.harmonics.first.relativeAmplitude, greaterThan(0.95));
      expect(result.totalHarmonicDistortionPercent, lessThan(8.0));
      expect(result.timbreClassification, contains('Puro'));
    });
  });
}
