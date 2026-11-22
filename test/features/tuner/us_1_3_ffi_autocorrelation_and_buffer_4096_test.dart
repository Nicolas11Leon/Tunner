import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/ffi/i_native_dsp_bridge.dart';
import 'package:tunner/features/tuner/domain/mcleod_pitch_method.dart';
import 'package:tunner/features/tuner/domain/microphone_calibration_models.dart';
import 'package:tunner/features/tuner/domain/signal_conditioning_filter.dart';
import 'package:tunner/features/tuner/domain/temperament_engine.dart';

class _FakeNativeDspBridge implements INativeDspBridge {
  bool autoCorrelateCalled = false;

  @override
  bool get isNativeAvailable => true;

  @override
  String get engineName => 'Fake Native C99 SIMD';

  @override
  void applyGain(Float32List buffer, double gain) {
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] *= gain;
    }
  }

  @override
  void vectorSum(Float32List a, Float32List b, Float32List out) {
    for (int i = 0; i < out.length; i++) {
      out[i] = a[i] + b[i];
    }
  }

  @override
  void autoCorrelate(Float32List input, Float32List output) {
    autoCorrelateCalled = true;
    final length = input.length;
    for (int lag = 0; lag < output.length; lag++) {
      double sum = 0.0;
      final limit = length - lag;
      for (int i = 0; i < limit; i++) {
        sum += input[i] * input[i + lag];
      }
      output[lag] = sum;
    }
  }
}

void main() {
  group('US-1.3 FFI Autocorrelation, 4096 Buffer for A0, Anchor A4 & DC Offset', () {
    test('computeNsdf O(N) energy prefix sums accurately computes NSDF and matches periodic peak', () {
      const sampleRate = 44100;
      const f0 = 440.0;
      final n = 2048;
      final samples = Float64List(n);
      for (int i = 0; i < n; i++) {
        samples[i] = math.sin(2 * math.pi * f0 * i / sampleRate);
      }

      final maxLag = (sampleRate / 100.0).ceil();
      final nsdf = McleodPitchMethod.computeNsdf(samples, maxLag);

      expect(nsdf[0], equals(1.0));
      // First periodic peak should occur at tau = round(44100 / 440) = 100
      final expectedLag = (sampleRate / f0).round();
      expect(nsdf[expectedLag], closeTo(1.0, 0.05));
    });

    test('computeNsdf delegates cross-correlation to INativeDspBridge when native is available', () {
      final fakeBridge = _FakeNativeDspBridge();
      const sampleRate = 44100;
      const f0 = 220.0;
      final n = 1024;
      final samples = Float64List(n);
      for (int i = 0; i < n; i++) {
        samples[i] = math.sin(2 * math.pi * f0 * i / sampleRate);
      }

      final nsdf = McleodPitchMethod.computeNsdf(samples, 300, bridge: fakeBridge);
      expect(fakeBridge.autoCorrelateCalled, isTrue);
      expect(nsdf[0], equals(1.0));
      expect(nsdf[(sampleRate / f0).round()], closeTo(1.0, 0.05));
    });

    test('estimatePitch accurately detects sub-bass A0 (27.5 Hz) with 4096 samples buffer', () {
      const sampleRate = 44100;
      const a0Freq = 27.5;
      const n = 4096;
      final samples = Float64List(n);
      for (int i = 0; i < n; i++) {
        samples[i] = math.sin(2 * math.pi * a0Freq * i / sampleRate);
      }

      const mpm = McleodPitchMethod(minPitchHz: 25.0);
      final result = mpm.estimatePitch(samples, sampleRate: sampleRate);

      expect(result.pitched, isTrue);
      expect(result.pitchHz, closeTo(27.5, 0.3));
      expect(result.clarity, greaterThan(0.85));
    });

    test('SignalConditioningFilter subtracts calibratedDcOffset from raw samples', () {
      final filter = SignalConditioningFilter();
      filter.calibratedDcOffset = 0.15;

      final input = Float64List.fromList([0.15, 0.25, -0.05]);
      final conditioned = filter.conditionSamples(input, enableDcBlocker: false);

      expect(conditioned[0], closeTo(0.0, 1e-4));
      expect(conditioned[1], closeTo(0.10, 1e-4));
      expect(conditioned[2], closeTo(-0.20, 1e-4));
    });

    test('TemperamentEngine anchors A4 to exactly a4Ref (440.0 Hz) across historical temperaments', () {
      const engine = TemperamentEngine();
      final historicalTemperaments = TemperamentEngine.allTemperaments
          .where((t) => t.id != 'equal')
          .toList();

      for (final temperament in historicalTemperaments) {
        final a4Target = engine.getTargetFrequency(
          midiNumber: 69, // A4
          temperament: temperament,
          a4Ref: 440.0,
          anchorA4: true,
        );
        expect(
          a4Target,
          closeTo(440.0, 0.001),
          reason: 'Temperament ${temperament.name} should anchor A4 strictly to 440.0 Hz',
        );
      }
    });

    test('MicrophoneCalibrationProfile serializes and deserializes calibratedDcOffset correctly', () {
      const profile = MicrophoneCalibrationProfile(
        digitalGain: 1.5,
        calibratedDcOffset: 0.042,
      );
      final json = profile.toJson();
      expect(json['calibratedDcOffset'], equals(0.042));

      final restored = MicrophoneCalibrationProfile.fromJson(json);
      expect(restored.calibratedDcOffset, equals(0.042));
      expect(restored.digitalGain, equals(1.5));
    });
  });
}
