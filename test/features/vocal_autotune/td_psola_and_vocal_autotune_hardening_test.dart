import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/vocal_autotune/domain/autotune_config_entity.dart';
import 'package:tunner/features/vocal_autotune/domain/td_psola_pitch_shifter.dart';
import 'package:tunner/features/vocal_autotune/domain/vocal_autotune_processor.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';

void main() {
  group('TD-PSOLA and Vocal AutoTune Hardening Tests', () {
    const shifter = TdPsolaPitchShifter();
    const sampleRate = 44100;

    test('shiftPitch preserves boundaries and limits output to [-1.0, 1.0]', () {
      const len = 2048;
      final sine = Float64List(len);
      const freq = 220.0;
      for (int i = 0; i < len; i++) {
        sine[i] = 0.7 * math.sin(2.0 * math.pi * freq * (i / sampleRate));
      }

      final shifted = shifter.shiftPitch(
        inputSamples: sine,
        pitchShiftRatio: 1.15, // shift up ~2 semitones
        detectedPitchHz: freq,
        sampleRate: sampleRate,
        leadVocalMix: 1.0,
      );

      expect(shifted.length, equals(len));
      for (final s in shifted) {
        expect(s, inInclusiveRange(-1.0, 1.0));
      }

      // Check boundary continuity: first sample should be smooth (near 0)
      expect(shifted[0].abs(), lessThan(0.2));
    });

    test('shiftPitch returns direct copy for negligible pitch shift ratio', () {
      final input = Float64List.fromList([0.1, 0.2, 0.3, 0.4]);
      final shifted = shifter.shiftPitch(
        inputSamples: input,
        pitchShiftRatio: 1.001,
        detectedPitchHz: 440.0,
        sampleRate: sampleRate,
      );
      expect(shifted, equals(input));
    });

    test('VocalAutoTuneProcessor processes audio block with smooth inertia', () {
      final processor = VocalAutoTuneProcessor(
        config: const AutoTuneConfigEntity(
          isEnabled: true,
          scaleType: VocalScaleType.major,
          scaleRoot: 0, // C
          retuneSpeedMs: 20.0,
        ),
      );

      const len = 1024;
      final sine = Float64List(len);
      for (int i = 0; i < len; i++) {
        sine[i] = 0.6 * math.sin(2.0 * math.pi * 445.0 * (i / sampleRate));
      }

      final out = processor.processAudioBlock(
        pcmSamples: sine,
        detectedPitchHz: 445.0,
        sampleRate: sampleRate,
        deltaSeconds: 0.02,
      );

      expect(out.length, equals(len));
      expect(out.any((s) => s.abs() > 0.0), isTrue);
    });

    test('VocalAutoTuneProcessor post-processes practice take preserving timestamps', () {
      final processor = VocalAutoTuneProcessor();

      final originalTake = PracticeTakeEntity(
        id: 'take_vocal_1',
        name: 'Vocal Take 1',
        timestamp: DateTime.now(),
        filePath: '/tmp/take1.wav',
        duration: const Duration(seconds: 2),
        waveformPeaks: const [0.1, 0.5, 0.2],
        spectralTrack: const [],
        pitchTrack: [
          const TimedPitchSample(
            timeMs: 0,
            frequencyHz: 443.0,
            centsDeviation: 12.0,
            targetNoteName: 'A4',
          ),
          const TimedPitchSample(
            timeMs: 100,
            frequencyHz: 442.0,
            centsDeviation: 8.0,
            targetNoteName: 'A4',
          ),
          const TimedPitchSample(
            timeMs: 200,
            frequencyHz: 0.0,
            centsDeviation: 0.0,
            targetNoteName: '--',
            isSilent: true,
          ),
        ],
      );

      final tunedTake = processor.processPracticeTake(take: originalTake);
      expect(tunedTake.id, startsWith('take_vocal_1_autotuned_'));
      expect(tunedTake.name, contains('AutoTuned'));
      expect(tunedTake.pitchTrack.length, equals(3));
      expect(tunedTake.pitchTrack[0].timeMs, equals(0));
      expect(tunedTake.pitchTrack[1].timeMs, equals(100));
      expect(tunedTake.pitchTrack[2].isSilent, isTrue);
    });
  });
}
