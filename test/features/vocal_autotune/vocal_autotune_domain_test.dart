import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/vocal_autotune/domain/autotune_config_entity.dart';
import 'package:tunner/features/vocal_autotune/domain/scale_quantizer.dart';
import 'package:tunner/features/vocal_autotune/domain/td_psola_pitch_shifter.dart';
import 'package:tunner/features/vocal_autotune/domain/vocal_autotune_processor.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';

void main() {
  group('AutoTuneConfigEntity Domain Tests', () {
    test('Default configuration initializes with expected parameters', () {
      const config = AutoTuneConfigEntity();
      expect(config.isEnabled, isFalse);
      expect(config.scaleRoot, equals(0)); // Do
      expect(config.scaleType, equals(VocalScaleType.chromatic));
      expect(config.retuneSpeedMs, equals(25.0));
      expect(config.correctionAmount, equals(1.0));
      expect(config.formantPreservation, isTrue);
      expect(config.leadVocalMix, equals(1.0));
    });

    test('Scale intervals correctly determine allowed pitch classes', () {
      // Do Mayor: C, D, E, F, G, A, B -> [0, 2, 4, 5, 7, 9, 11]
      const cMajor = AutoTuneConfigEntity(
        scaleRoot: 0,
        scaleType: VocalScaleType.major,
      );
      expect(cMajor.isPitchClassAllowed(0), isTrue); // C
      expect(cMajor.isPitchClassAllowed(2), isTrue); // D
      expect(cMajor.isPitchClassAllowed(4), isTrue); // E
      expect(cMajor.isPitchClassAllowed(1), isFalse); // C# / Db
      expect(cMajor.isPitchClassAllowed(6), isFalse); // F#

      // La Menor Natural: A, B, C, D, E, F, G -> [9, 11, 0, 2, 4, 5, 7]
      const aMinor = AutoTuneConfigEntity(
        scaleRoot: 9,
        scaleType: VocalScaleType.naturalMinor,
      );
      expect(aMinor.isPitchClassAllowed(9), isTrue); // A
      expect(aMinor.isPitchClassAllowed(0), isTrue); // C
      expect(aMinor.isPitchClassAllowed(10), isFalse); // A#
    });

    test('Presets instantiate correctly with valid acoustic parameters', () {
      final hardTune = AutoTuneConfigEntity.hardTuneUrban(scaleRoot: 0);
      expect(hardTune.isEnabled, isTrue);
      expect(hardTune.retuneSpeedMs, equals(0.0));
      expect(hardTune.correctionAmount, equals(1.0));

      final natural = AutoTuneConfigEntity.naturalStudio(scaleRoot: 0);
      expect(natural.isEnabled, isTrue);
      expect(natural.retuneSpeedMs, equals(35.0));
      expect(natural.correctionAmount, equals(0.85));

      final doubler = AutoTuneConfigEntity.vocalDoubler(scaleRoot: 0);
      expect(doubler.leadVocalMix, equals(0.50));
    });

    test('Lossless JSON serialization and deserialization', () {
      final original = AutoTuneConfigEntity.smoothPop(scaleRoot: 2, scaleType: VocalScaleType.blues);
      final json = original.toJson();
      final restored = AutoTuneConfigEntity.fromJson(json);

      expect(restored.isEnabled, equals(original.isEnabled));
      expect(restored.scaleRoot, equals(original.scaleRoot));
      expect(restored.scaleType, equals(original.scaleType));
      expect(restored.retuneSpeedMs, equals(original.retuneSpeedMs));
      expect(restored.correctionAmount, equals(original.correctionAmount));
    });
  });

  group('ScaleQuantizer Math & Inertia Tests', () {
    late ScaleQuantizer quantizer;

    setUp(() {
      quantizer = ScaleQuantizer();
    });

    test('Rejects silence and sub-audible frequencies <= 20Hz', () {
      const config = AutoTuneConfigEntity(isEnabled: true);
      final res = quantizer.quantize(detectedPitchHz: 0.0, config: config);
      expect(res.isVoiced, isFalse);
      expect(res.pitchShiftRatio, equals(1.0));
    });

    test('Corrects slightly sharp A4 (445 Hz) to 440.0 Hz in chromatic scale', () {
      const config = AutoTuneConfigEntity(
        isEnabled: true,
        scaleType: VocalScaleType.chromatic,
        retuneSpeedMs: 0.0, // Instantáneo
      );

      final res = quantizer.quantize(detectedPitchHz: 445.0, config: config);
      expect(res.isVoiced, isTrue);
      expect(res.targetFrequencyHz, closeTo(440.0, 0.5));
      expect(res.pitchShiftRatio, closeTo(440.0 / 445.0, 0.001));
      expect(res.targetNoteName, contains('La'));
    });

    test('Snaps out-of-scale note to closest scale note in C Major', () {
      // D#4 (aprox 311.13 Hz) no está en C Mayor; debe cuantizar a D4 (293.66 Hz) o E4 (329.63 Hz)
      const config = AutoTuneConfigEntity(
        isEnabled: true,
        scaleRoot: 0,
        scaleType: VocalScaleType.major,
        retuneSpeedMs: 0.0,
      );

      final res = quantizer.quantize(detectedPitchHz: 311.13, config: config);
      expect(res.isVoiced, isTrue);
      final isE4orD4 = (res.targetFrequencyHz - 329.63).abs() < 5.0 || (res.targetFrequencyHz - 293.66).abs() < 5.0;
      expect(isE4orD4, isTrue);
    });

    test('Inertia smoothing transitions pitch ratio progressively when retuneSpeed > 0', () {
      const config = AutoTuneConfigEntity(
        isEnabled: true,
        scaleType: VocalScaleType.chromatic,
        retuneSpeedMs: 50.0, // Inercia moderada
      );

      // Frame 1: Salto brusco de afinación (446 Hz se desvía de A4 440 Hz)
      final res1 = quantizer.quantize(detectedPitchHz: 446.0, config: config, deltaSeconds: 0.01);
      final ratio1 = res1.pitchShiftRatio;

      // Frame 2: Mismo tono emitido, inercia avanza hacia el objetivo
      final res2 = quantizer.quantize(detectedPitchHz: 446.0, config: config, deltaSeconds: 0.01);
      final ratio2 = res2.pitchShiftRatio;

      // El ratio objetivo exacto es 440/446
      // Con inercia, ratio2 debe estar más cerca del objetivo que ratio1
      final targetRatio = 440.0 / 446.0;
      expect((ratio2 - targetRatio).abs(), lessThan((ratio1 - targetRatio).abs()));
    });
  });

  group('TdPsolaPitchShifter DSP Tests', () {
    const shifter = TdPsolaPitchShifter();

    test('Empty input returns empty buffer', () {
      final res = shifter.shiftPitch(
        inputSamples: Float64List(0),
        pitchShiftRatio: 1.05,
        detectedPitchHz: 440.0,
        sampleRate: 44100,
      );
      expect(res, isEmpty);
    });

    test('Bypass when shift ratio is approximately 1.0', () {
      final input = Float64List.fromList([0.1, 0.2, 0.3, 0.2, 0.1]);
      final res = shifter.shiftPitch(
        inputSamples: input,
        pitchShiftRatio: 1.001,
        detectedPitchHz: 440.0,
        sampleRate: 44100,
      );
      expect(res.length, equals(input.length));
      expect(res[1], closeTo(0.2, 1e-4));
    });

    test('Applies pitch shift to synthetic audio buffer without NaN or out-of-bounds', () {
      const sampleRate = 44100;
      const numSamples = 2048;
      final input = Float64List(numSamples);

      // Generar tono sinusoidal de 440 Hz
      for (int i = 0; i < numSamples; i++) {
        input[i] = math.sin(2.0 * math.pi * 440.0 * i / sampleRate) * 0.8;
      }

      // Desplazar tono hacia arriba (ratio 1.06 aprox +1 semitono)
      final output = shifter.shiftPitch(
        inputSamples: input,
        pitchShiftRatio: 1.05946,
        detectedPitchHz: 440.0,
        sampleRate: sampleRate,
        preserveFormants: true,
        leadVocalMix: 1.0,
      );

      expect(output.length, equals(input.length));
      for (final s in output) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
        expect(s, inInclusiveRange(-1.0, 1.0));
      }
    });
  });

  group('VocalAutoTuneProcessor Integration Tests', () {
    test('Disabled processor returns unmodified PCM buffer', () {
      final processor = VocalAutoTuneProcessor(
        config: const AutoTuneConfigEntity(isEnabled: false),
      );
      final pcm = Float64List.fromList([0.2, -0.4, 0.5]);
      final out = processor.processAudioBlock(
        pcmSamples: pcm,
        detectedPitchHz: 440.0,
        sampleRate: 44100,
      );
      expect(out, equals(pcm));
    });

    test('processPracticeTake quantizes take pitchTrack in post-production', () {
      final processor = VocalAutoTuneProcessor(
        config: AutoTuneConfigEntity.hardTuneUrban(
          scaleRoot: 0, // C Mayor
          scaleType: VocalScaleType.major,
        ),
      );

      final originalTake = PracticeTakeEntity(
        id: 'take_vocal_01',
        name: 'Voz Principal Toma 1',
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 4),
        filePath: '/tmp/test.wav',
        pitchTrack: const [
          TimedPitchSample(timeMs: 0, frequencyHz: 0.0, centsDeviation: 0.0, targetNoteName: '--', isSilent: true),
          TimedPitchSample(timeMs: 50, frequencyHz: 446.0, centsDeviation: 23.4, targetNoteName: 'La4', isSilent: false),
          TimedPitchSample(timeMs: 100, frequencyHz: 445.0, centsDeviation: 19.5, targetNoteName: 'La4', isSilent: false),
        ],
      );

      final tunedTake = processor.processPracticeTake(take: originalTake);

      expect(tunedTake.name, equals('Voz Principal Toma 1 (AutoTuned)'));
      expect(tunedTake.pitchTrack.length, equals(originalTake.pitchTrack.length));
      expect(tunedTake.pitchTrack.first.isSilent, isTrue);

      // En la muestra afinada, la frecuencia se ha alineado a A4 (440 Hz) y los cents residuales son 0 (Hard Tune)
      final sample2 = tunedTake.pitchTrack[1];
      expect(sample2.frequencyHz, closeTo(440.0, 1.0));
      expect(sample2.centsDeviation, closeTo(0.0, 0.1));
    });
  });
}
