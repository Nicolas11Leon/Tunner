import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/audio_device_matrix_entity.dart';
import 'package:tunner/core/audio/domain/studio_master_biquad_filter.dart';
import 'package:tunner/core/audio/domain/studio_master_dynamics_processor.dart';

void main() {
  group('StudioMasterBiquadFilter Tests (Épica 1 - UC-104)', () {
    test('lowShelf flat gain returns identical samples without distortion', () {
      final filter = StudioMasterBiquadFilter.lowShelf(gainDb: 0.0);
      final (yL, yR) = filter.processStereoSample(0.5, -0.5);
      expect(yL, closeTo(0.5, 0.0001));
      expect(yR, closeTo(-0.5, 0.0001));
    });

    test('lowShelf with positive gain amplifies low frequency sine wave', () {
      final flatFilter = StudioMasterBiquadFilter.lowShelf(frequency: 100.0, gainDb: 0.0);
      final boostFilter = StudioMasterBiquadFilter.lowShelf(frequency: 100.0, gainDb: 6.0);

      const sampleRate = 44100;
      const freq = 60.0; // Frecuencia dentro del rango del Low Shelf
      double flatEnergy = 0.0;
      double boostEnergy = 0.0;

      for (int i = 0; i < 500; i++) {
        final sample = math.sin(2.0 * math.pi * freq * i / sampleRate);
        final (fL, _) = flatFilter.processStereoSample(sample, sample);
        final (bL, _) = boostFilter.processStereoSample(sample, sample);

        // Omitir los primeros transitorios para medir estado estable
        if (i > 100) {
          flatEnergy += fL * fL;
          boostEnergy += bL * bL;
        }
      }

      expect(boostEnergy, greaterThan(flatEnergy * 1.5));
    });

    test('peaking bell filter boosts center frequency', () {
      final boostMid = StudioMasterBiquadFilter.peaking(frequency: 1000.0, gainDb: 6.0, q: 1.0);
      const sampleRate = 44100;
      const freq = 1000.0;

      double outEnergy = 0.0;
      double inEnergy = 0.0;

      for (int i = 0; i < 500; i++) {
        final sample = math.sin(2.0 * math.pi * freq * i / sampleRate);
        final (yL, _) = boostMid.processStereoSample(sample, sample);
        if (i > 100) {
          inEnergy += sample * sample;
          outEnergy += yL * yL;
        }
      }

      expect(outEnergy, greaterThan(inEnergy * 1.5));
    });

    test('highShelf filter attenuates high frequencies on cut', () {
      final cutHigh = StudioMasterBiquadFilter.highShelf(frequency: 8000.0, gainDb: -6.0);
      const sampleRate = 44100;
      const freq = 12000.0; // Frecuencia dentro del rango del High Shelf

      double inEnergy = 0.0;
      double outEnergy = 0.0;

      for (int i = 0; i < 500; i++) {
        final sample = math.sin(2.0 * math.pi * freq * i / sampleRate);
        final (yL, _) = cutHigh.processStereoSample(sample, sample);
        if (i > 100) {
          inEnergy += sample * sample;
          outEnergy += yL * yL;
        }
      }

      expect(outEnergy, lessThan(inEnergy * 0.7));
    });

    test('reset clears internal filter memory without NaN or infinity', () {
      final filter = StudioMasterBiquadFilter.peaking(frequency: 1000.0, gainDb: 6.0);
      filter.processStereoSample(1.0, 1.0);
      filter.reset();
      final (yL, yR) = filter.processStereoSample(0.0, 0.0);
      expect(yL, 0.0);
      expect(yR, 0.0);
    });
  });

  group('StudioMasterDynamicsProcessor Tests (Épica 1 - UC-104)', () {
    test('does not reduce gain when signal is below threshold', () {
      final compressor = StudioMasterDynamicsProcessor(
        thresholdDb: -6.0,
        ratio: 4.0,
      );

      // Señal a -20 dB (aprox 0.1 de amplitud lineal)
      const lowAmplitude = 0.1;
      for (int i = 0; i < 100; i++) {
        compressor.processStereoSample(lowAmplitude, lowAmplitude);
      }

      expect(compressor.currentGainReductionDb, closeTo(0.0, 0.01));
    });

    test('compresses and reduces gain when signal exceeds threshold', () {
      final compressor = StudioMasterDynamicsProcessor(
        thresholdDb: -10.0,
        ratio: 4.0,
        attackMs: 1.0,
        releaseMs: 50.0,
      );

      // Señal a 0 dB (1.0 de amplitud lineal), supera el umbral de -10 dB
      double lastL = 0.0;
      for (int i = 0; i < 200; i++) {
        final (yL, _) = compressor.processStereoSample(1.0, 1.0);
        lastL = yL;
      }

      expect(compressor.currentGainReductionDb, lessThan(-5.0));
      expect(lastL, lessThan(0.8));
    });

    test('reset clears compressor envelope memory', () {
      final compressor = StudioMasterDynamicsProcessor(
        thresholdDb: -10.0,
        ratio: 4.0,
      );

      compressor.processStereoSample(1.0, 1.0);
      compressor.reset();

      expect(compressor.currentGainReductionDb, 0.0);
    });
  });

  group('AudioDeviceMatrixEntity Mastering Parameters Serialization', () {
    test('preserves EQ and Dynamics settings in toJson and fromJson', () {
      final matrix = AudioDeviceMatrixEntity.defaultConfiguration().copyWith(
        eqLowDb: 3.5,
        eqMidDb: -2.0,
        eqHighDb: 4.0,
        isEqBypassed: true,
        compThresholdDb: -12.0,
        compRatio: 4.0,
        isCompBypassed: false,
        isMasterRecording: true,
      );

      final json = matrix.toJson();
      final restored = AudioDeviceMatrixEntity.fromJson(json);

      expect(restored.eqLowDb, 3.5);
      expect(restored.eqMidDb, -2.0);
      expect(restored.eqHighDb, 4.0);
      expect(restored.isEqBypassed, isTrue);
      expect(restored.compThresholdDb, -12.0);
      expect(restored.compRatio, 4.0);
      expect(restored.isCompBypassed, isFalse);
      expect(restored.isMasterRecording, isTrue);
    });

    test('defaultConfiguration provides 0 dB flat EQ and inactive recording', () {
      final def = AudioDeviceMatrixEntity.defaultConfiguration();
      expect(def.eqLowDb, 0.0);
      expect(def.eqMidDb, 0.0);
      expect(def.eqHighDb, 0.0);
      expect(def.isEqBypassed, isFalse);
      expect(def.compThresholdDb, 0.0);
      expect(def.compRatio, 2.0);
      expect(def.isCompBypassed, isFalse);
      expect(def.isMasterRecording, isFalse);
    });
  });
}
