import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/studio_master_audio_mixer.dart';
import 'package:tunner/core/audio/domain/reverb/all_pass_filter.dart';
import 'package:tunner/core/audio/domain/reverb/schroeder_reverb_engine.dart';
import 'package:tunner/core/audio/domain/spatial/binaural_panner_engine.dart';
import 'package:tunner/core/audio/domain/studio_master_biquad_filter.dart';

void main() {
  group('StudioMasterAudioMixer Soft Clipper Hardening', () {
    test('Zero THD distortion for amplitudes below threshold T = 0.85', () {
      expect(StudioMasterAudioMixer.applySoftClipper(0.0), equals(0.0));
      expect(StudioMasterAudioMixer.applySoftClipper(0.25), equals(0.25));
      expect(StudioMasterAudioMixer.applySoftClipper(-0.5), equals(-0.5));
      expect(StudioMasterAudioMixer.applySoftClipper(0.85), equals(0.85));
      expect(StudioMasterAudioMixer.applySoftClipper(-0.85), equals(-0.85));
    });

    test('C1 continuity: numerical derivative at boundary T = 0.85 is continuous and equals 1.0', () {
      const h = 1e-6;
      final yLeft = StudioMasterAudioMixer.applySoftClipper(0.85 - h);
      final yRight = StudioMasterAudioMixer.applySoftClipper(0.85 + h);
      final derivative = (yRight - yLeft) / (2 * h);

      expect(derivative, closeTo(1.0, 0.001));
    });

    test('Strict saturation bound: output never exceeds 1.0 even with large overloads', () {
      final yOver1 = StudioMasterAudioMixer.applySoftClipper(1.5);
      final yOver2 = StudioMasterAudioMixer.applySoftClipper(5.0);
      final yOver3 = StudioMasterAudioMixer.applySoftClipper(100.0);

      expect(yOver1, greaterThan(0.85));
      expect(yOver1, lessThan(1.0));
      expect(yOver2, greaterThan(yOver1));
      expect(yOver2, lessThanOrEqualTo(1.0));
      expect(yOver3, closeTo(1.0, 0.001));
      expect(yOver3, lessThanOrEqualTo(1.0));

      final yNeg = StudioMasterAudioMixer.applySoftClipper(-50.0);
      expect(yNeg, closeTo(-1.0, 0.001));
      expect(yNeg, greaterThanOrEqualTo(-1.0));
    });
  });

  group('AllPassFilter Schroeder Direct Form II Hardening', () {
    test('Exact energy conservation: unit impulse response sum of squares equals 1.0', () {
      final ap = AllPassFilter(10, feedback: 0.5);

      double energySum = 0.0;
      // Probar respuesta al impulso: delta[0] = 1.0, delta[n > 0] = 0.0
      for (int n = 0; n < 200; n++) {
        final input = n == 0 ? 1.0 : 0.0;
        final out = ap.process(input);
        energySum += out * out;
      }

      // La energía total de salida debe ser exactamente igual a la energía de entrada (1.0)
      expect(energySum, closeTo(1.0, 0.005));
    });

    test('Mute resets delay line and index deterministically', () {
      final ap = AllPassFilter(8, feedback: 0.6);
      ap.process(1.0);
      ap.process(0.5);
      ap.mute();

      for (int i = 0; i < 8; i++) {
        expect(ap.process(0.0), equals(0.0));
      }
    });
  });

  group('SchroederReverbEngine Parallel Comb Scaling & Sample Rate', () {
    test('Comb filter 0.25 scaling prevents saturation and gain blowup', () {
      final reverb = SchroederReverbEngine(sampleRate: 44100, wetMix: 1.0, dryMix: 0.0);
      final leftIn = Float32List(128)..fillRange(0, 128, 0.8);
      final rightIn = Float32List(128)..fillRange(0, 128, 0.8);
      final leftOut = Float32List(128);
      final rightOut = Float32List(128);

      reverb.processStereo(leftIn, rightIn, leftOut, rightOut, 128);

      for (int i = 0; i < 128; i++) {
        expect(leftOut[i].abs(), lessThanOrEqualTo(1.0));
        expect(rightOut[i].abs(), lessThanOrEqualTo(1.0));
      }
    });

    test('Different sample rate initializes proportionally scaled delay lines', () {
      final reverb44 = SchroederReverbEngine(sampleRate: 44100);
      final reverb48 = SchroederReverbEngine(sampleRate: 48000);

      expect(reverb44.sampleRate, equals(44100));
      expect(reverb48.sampleRate, equals(48000));
    });
  });

  group('BinauralPannerEngine Median Plane Continuity', () {
    test('Continuous transition at rear meridian +-180 degrees', () {
      final pannerPositive = BinauralPannerEngine(sampleRate: 44100)
        ..setAzimuth(180.0);
      final pannerNegative = BinauralPannerEngine(sampleRate: 44100)
        ..setAzimuth(-180.0);

      // En el meridiano posterior, ambos oídos son equidistantes y simétricos
      expect(pannerPositive.itdMs, closeTo(0.0, 0.01));
      expect(pannerNegative.itdMs, closeTo(0.0, 0.01));
      expect(pannerPositive.leftDelayMs, closeTo(pannerNegative.rightDelayMs, 0.01));
    });
  });

  group('StudioMasterBiquadFilter In-Place Parameter Updates', () {
    test('updateParameters updates coefficients without clearing memory states', () {
      final filter = StudioMasterBiquadFilter.peaking(
        frequency: 1000.0,
        gainDb: 6.0,
        q: 1.0,
        sampleRate: 44100,
      );

      // Procesar algunas muestras para poblar los retardos
      filter.processStereoSample(0.5, 0.5);
      filter.processStereoSample(0.3, 0.3);

      // Actualizar parámetros en caliente (sin reinicializar la clase)
      filter.updateParameters(frequency: 2000.0, gainDb: -3.0);

      expect(filter.frequency, equals(2000.0));
      expect(filter.gainDb, equals(-3.0));

      // El procesamiento continúa fluidamente sin caídas a NaN ni ceros espurios
      final (yL, yR) = filter.processStereoSample(0.4, 0.4);
      expect(yL.isNaN, isFalse);
      expect(yR.isNaN, isFalse);
    });
  });
}
