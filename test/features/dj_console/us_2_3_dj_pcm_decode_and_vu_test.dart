import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/domain/pcm_wav_synthesizer.dart';
import 'package:tunner/features/dj_console/domain/bpm_beat_tracker_engine.dart';
import 'package:tunner/features/dj_console/domain/dj_harmonic_camelot_engine.dart';
import 'package:tunner/features/dj_console/domain/dj_transition_sfx_synthesizer.dart';
import 'package:tunner/features/dj_console/domain/pcm_wav_decoder.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';

void main() {
  group('US-2.3 DJ PCM Decode, BPM/Camelot Detection & Real VU Tests', () {
    test('PcmWavDecoder decodes 16-bit PCM WAV bytes into normalized Float32List', () {
      final wavBytes = PcmWavSynthesizer.generateSineToneWav(
        frequency: 440.0,
        durationSeconds: 0.1,
        sampleRate: 44100,
      );
      expect(wavBytes.isNotEmpty, isTrue);

      final pcmSamples = PcmWavDecoder.decodeWavToFloat32(wavBytes);
      expect(pcmSamples.isNotEmpty, isTrue);
      expect(pcmSamples.length, equals(4410)); // 0.1s * 44100 samples/s

      // Values must be within normalized [-1.0, 1.0] bounds
      for (final sample in pcmSamples) {
        expect(sample, inInclusiveRange(-1.0, 1.0));
      }

      // Corrupted / empty headers return empty Float32List safely
      expect(PcmWavDecoder.decodeWavToFloat32(Uint8List(20)).isEmpty, isTrue);
      expect(PcmWavDecoder.decodeWavToFloat32(Uint8List(0)).isEmpty, isTrue);
    });

    test('BpmBeatTrackerEngine and Camelot Engine extract acoustic metadata from decoded PCM', () {
      const sampleRate = 44100;
      const targetBpm = 120.0;
      const durationSeconds = 3;
      final totalSamples = sampleRate * durationSeconds;
      final samples = Float32List(totalSamples);
      final beatInterval = (sampleRate * 60.0 / targetBpm).round();

      for (int i = 0; i < totalSamples; i++) {
        final beatPos = i % beatInterval;
        if (beatPos < 500) {
          samples[i] = (1.0 - beatPos / 500.0);
        }
      }

      final detectedBpm = BpmBeatTrackerEngine.estimateBpm(
        samples: samples,
        sampleRate: sampleRate,
      );
      expect(detectedBpm, inInclusiveRange(118.0, 122.0));

      final detectedKey = DjHarmonicCamelotEngine.estimateCamelotKeyFromSamples(
        samples,
        sampleRate: sampleRate,
      );
      expect(detectedKey.code.isNotEmpty, isTrue);

      final spectralWaveform = DjTransitionSfxSynthesizer.computeSpectralWaveformSummary(
        samples,
        sampleRate: sampleRate,
      );
      expect(spectralWaveform.isNotEmpty, isTrue);
    });

    test('DjConsoleViewModel.getVuLevel computes real RMS level of current audio window', () {
      final vm = DjConsoleViewModel();

      // Deck A stopped: VU is 0.0
      expect(vm.getVuLevel('A'), equals(0.0));

      // Start Deck A
      vm.togglePlay('A');
      expect(vm.deckA.isPlaying, isTrue);

      // VU level should be active (> 0.0) reflecting real RMS of the groove
      final activeVu = vm.getVuLevel('A');
      expect(activeVu, greaterThan(0.0));
      expect(activeVu, lessThanOrEqualTo(1.2));

      // Mute all bands with kill switches: VU drops to zero
      vm.toggleEqKill('A', 'low');
      vm.toggleEqKill('A', 'mid');
      vm.toggleEqKill('A', 'high');
      expect(vm.getVuLevel('A'), equals(0.0));

      vm.dispose();
    });
  });
}
