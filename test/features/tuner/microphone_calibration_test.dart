import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/tuner/domain/microphone_calibration_models.dart';
import 'package:tunner/features/tuner/domain/signal_conditioning_filter.dart';

void main() {
  group('MicrophoneCalibrationProfile Model & JSON Tests', () {
    test('default calibration profile has sensible conservatory defaults', () {
      const profile = MicrophoneCalibrationProfile();
      expect(profile.digitalGain, equals(1.0));
      expect(profile.noiseGateThreshold, equals(0.005));
      expect(profile.enableDcBlocker, isTrue);
      expect(profile.deviceId, isEmpty);
      expect(profile.measuredNoiseFloorRms, equals(0.002));
    });

    test('serializes and deserializes accurately through JSON map', () {
      const profile = MicrophoneCalibrationProfile(
        digitalGain: 2.5,
        noiseGateThreshold: 0.012,
        enableDcBlocker: false,
        deviceId: 'usb_audio_mic_in',
        measuredNoiseFloorRms: 0.007,
      );

      final json = profile.toJson();
      final restored = MicrophoneCalibrationProfile.fromJson(json);

      expect(restored.digitalGain, equals(2.5));
      expect(restored.noiseGateThreshold, equals(0.012));
      expect(restored.enableDcBlocker, isFalse);
      expect(restored.deviceId, equals('usb_audio_mic_in'));
      expect(restored.measuredNoiseFloorRms, equals(0.007));
    });

    test('copyWith updates specified properties while preserving others', () {
      const profile = MicrophoneCalibrationProfile();
      final updated = profile.copyWith(digitalGain: 1.8, noiseGateThreshold: 0.015);

      expect(updated.digitalGain, equals(1.8));
      expect(updated.noiseGateThreshold, equals(0.015));
      expect(updated.enableDcBlocker, isTrue); // Inmutable preservado
    });
  });

  group('SignalConditioningFilter: DC-Blocker IIR Tests', () {
    test('eliminates constant DC offset bias from signal', () {
      final filter = SignalConditioningFilter();
      // A 44.1 kHz con polo en 0.99786 (tau ~ 467 muestras = 10.5 ms),
      // tras 5 constantes de tiempo (~2500 muestras = 55 ms) el escalón decae a cero (< 0.003)
      const length = 3000;
      final dcShiftedSignal = Float64List(length);

      // Señal con un DC-offset constante de +0.40
      for (int i = 0; i < length; i++) {
        dcShiftedSignal[i] = 0.40;
      }

      final filtered = filter.conditionSamples(
        dcShiftedSignal,
        gain: 1.0,
        enableDcBlocker: true,
      );

      // Tras converger, el valor DC debe decaer prácticamente a 0.0
      expect(filtered.last.abs(), lessThan(0.005));
    });

    test('preserves alternating AC musical frequencies without attenuation', () {
      final filter = SignalConditioningFilter();
      const sampleRate = 44100;
      const freq = 440.0; // A4
      const durationSamples = 1000;
      final sineWave = Float64List(durationSamples);

      for (int i = 0; i < durationSamples; i++) {
        sineWave[i] = 0.5 * math.sin(2.0 * math.pi * freq * (i / sampleRate));
      }

      final filtered = filter.conditionSamples(
        sineWave,
        gain: 1.0,
        enableDcBlocker: true,
      );

      // La amplitud de la onda senoidal a 440 Hz debe mantenerse cercana a 0.5
      double peak = 0.0;
      for (int i = 500; i < durationSamples; i++) {
        if (filtered[i].abs() > peak) peak = filtered[i].abs();
      }
      expect(peak, closeTo(0.50, 0.02));
    });

    test('applies digital gain multiplier correctly', () {
      final filter = SignalConditioningFilter();
      final input = Float64List.fromList([0.1, 0.2, -0.1, -0.2]);

      final amplified = filter.conditionSamples(
        input,
        gain: 2.0,
        enableDcBlocker: false,
      );

      expect(amplified[0], closeTo(0.2, 0.0001));
      expect(amplified[1], closeTo(0.4, 0.0001));
      expect(amplified[2], closeTo(-0.2, 0.0001));
      expect(amplified[3], closeTo(-0.4, 0.0001));
    });

    test('soft limiter activates gracefully when signal exceeds 1.0', () {
      final filter = SignalConditioningFilter();
      final hugeSignal = Float64List.fromList([5.0]);

      final saturated = filter.conditionSamples(
        hugeSignal,
        gain: 1.0,
        enableDcBlocker: false,
      );

      // No sobrepasa bruscamente sino que satura suavemente
      expect(saturated[0], lessThan(1.2));
      expect(saturated[0], greaterThan(1.0));
    });
  });

  group('SignalConditioningFilter: NoiseFloorProfiler Tests', () {
    test('analyzes noise frames and calculates realistic adaptive gate', () {
      final frames = <Float64List>[];

      // Simular 10 frames con ruido blanco gaussiano suave (RMS ~0.004)
      final rng = math.Random(42);
      for (int f = 0; f < 10; f++) {
        final frame = Float64List(256);
        for (int i = 0; i < 256; i++) {
          frame[i] = (rng.nextDouble() - 0.5) * 0.015; // Rango [-0.0075..0.0075]
        }
        frames.add(frame);
      }

      final report = SignalConditioningFilter.analyzeNoiseFrames(frames);

      expect(report.totalFramesAnalyzed, equals(10));
      expect(report.meanRms, greaterThan(0.001));
      expect(report.meanRms, lessThan(0.010));
      expect(report.recommendedNoiseGate, greaterThan(report.meanRms));
      expect(report.recommendedNoiseGate, greaterThanOrEqualTo(0.003));
    });

    test('handles empty frame collection safely with fallback', () {
      final report = SignalConditioningFilter.analyzeNoiseFrames([]);
      expect(report.totalFramesAnalyzed, equals(0));
      expect(report.recommendedNoiseGate, equals(0.005));
    });
  });
}
