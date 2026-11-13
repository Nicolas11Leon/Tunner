import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/data/dj_audio_processor.dart';
import 'package:tunner/features/dj_console/data/dj_mix_wav_encoder.dart';
import 'package:tunner/features/dj_console/domain/bpm_beat_tracker_engine.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_channel_fx_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_live_mix_recorder_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_performance_orchestrator.dart';

void main() {
  group('BpmBeatTrackerEngine Algorithmic Tests', () {
    test('Estimates BPM from synthetic rhythm with high precision', () {
      const sampleRate = 44100;
      const targetBpm = 120.0;
      const durationSeconds = 3;
      final totalSamples = sampleRate * durationSeconds;
      final samples = Float32List(totalSamples);
      final beatInterval = (sampleRate * 60.0 / targetBpm).round();

      for (int i = 0; i < totalSamples; i++) {
        final beatPos = i % beatInterval;
        if (beatPos < 500) {
          // Sharp rhythmic impulse
          samples[i] = math.exp(-beatPos / 100.0).toDouble();
        }
      }

      final estimated = BpmBeatTrackerEngine.estimateBpm(
        samples: samples,
        sampleRate: sampleRate,
      );

      // Estimated tempo should be within +/- 2 BPM
      expect(estimated, inInclusiveRange(118.0, 122.0));
    });

    test('Returns default 120.0 BPM on silent or empty audio', () {
      final empty = Float32List(0);
      expect(BpmBeatTrackerEngine.estimateBpm(samples: empty), 120.0);

      final silence = Float32List(44100);
      expect(BpmBeatTrackerEngine.estimateBpm(samples: silence), 120.0);
    });
  });

  group('DjChannelFxEntity Acoustic Parameters', () {
    test('Neutral filter position (0.0) yields bypass with full band', () {
      const fx = DjChannelFxEntity();
      expect(fx.filterPosition, 0.0);
      expect(fx.cutoffFrequencyHz, 20000.0);
      expect(fx.isLowPassMode, isFalse);
      expect(fx.isHighPassMode, isFalse);
    });

    test('Bipolar sweep down (-1.0) activates LPF mode down to 60 Hz', () {
      const fx = DjChannelFxEntity(filterPosition: -1.0);
      expect(fx.isLowPassMode, isTrue);
      expect(fx.isHighPassMode, isFalse);
      expect(fx.cutoffFrequencyHz, closeTo(60.0, 5.0));
    });

    test('Bipolar sweep up (+1.0) activates HPF mode up to 12000 Hz', () {
      const fx = DjChannelFxEntity(filterPosition: 1.0);
      expect(fx.isHighPassMode, isTrue);
      expect(fx.isLowPassMode, isFalse);
      expect(fx.cutoffFrequencyHz, closeTo(12000.0, 50.0));
    });

    test('Quantized delay calculates exact samples synchronized to BPM', () {
      const fxQuarter = DjChannelFxEntity(delayDivision: DjDelayDivision.quarterBeat);
      // At 120 BPM, 1 beat = 0.5s. Quarter note = 0.5 * 0.25 = 0.125s -> 0.125 * 44100 = 5512.5 -> 5512
      final samples = fxQuarter.calculateDelaySamples(bpm: 120.0, sampleRate: 44100);
      expect(samples, 5513);

      const fxEighth = DjChannelFxEntity(delayDivision: DjDelayDivision.eighthBeat);
      final samplesEighth = fxEighth.calculateDelaySamples(bpm: 120.0, sampleRate: 44100);
      expect(samplesEighth, 2756);
    });

    test('Clamps feedback to 0.80 to prevent destructive acoustic oscillation', () {
      final fx = const DjChannelFxEntity().copyWith(delayFeedback: 0.99);
      expect(fx.delayFeedback, 0.80);
    });
  });

  group('DjLiveMixRecorderEntity Tests', () {
    test('Accurately tracks recording session state, chunks, and duration', () {
      var recorder = const DjLiveMixRecorderEntity();
      expect(recorder.isRecording, isFalse);

      recorder = recorder.start(1000);
      expect(recorder.isRecording, isTrue);
      expect(recorder.startTimeMs, 1000);

      final chunk1 = Float32List(1000);
      final chunk2 = Float32List(2000);
      recorder = recorder.appendChunk(chunk1, 2000);
      recorder = recorder.appendChunk(chunk2, 3500);

      expect(recorder.totalChunks, 2);
      expect(recorder.totalRecordedSamples, 3000);
      expect(recorder.durationSeconds, 2); // (3500 - 1000) / 1000 = 2

      final consolidated = recorder.consolidateChunks();
      expect(consolidated.length, 3000);

      recorder = recorder.stop();
      expect(recorder.isRecording, isFalse);

      recorder = recorder.clear();
      expect(recorder.totalChunks, 0);
      expect(recorder.totalRecordedSamples, 0);
    });
  });

  group('DjMixWavEncoder Serialization Tests', () {
    test('Encodes audio buffer to standard 16-bit PCM RIFF WAVE header', () {
      final samples = Float32List(100);
      final bytes = DjMixWavEncoder.encode(samples: samples, sampleRate: 44100, numChannels: 2);

      // Total header (44 bytes) + data (100 * 2 bytes = 200 bytes) = 244 bytes
      expect(bytes.length, 244);

      // Verify "RIFF"
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      // Verify "WAVE"
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      // Verify "fmt "
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
      // Verify "data"
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    });
  });

  group('DjAudioProcessor DSP & FX Processing Tests', () {
    final processor = DjAudioProcessor(sampleRate: 44100);

    test('applyBipolarFilter runs without numeric exceptions or NaN', () {
      final input = processor.generateDemoGroove(bpm: 120.0, frequencyHz: 60.0, durationMs: 100);
      final lpf = processor.applyBipolarFilter(input, -0.8);
      expect(lpf.length, input.length);
      expect(lpf.every((s) => !s.isNaN && !s.isInfinite), isTrue);

      final hpf = processor.applyBipolarFilter(input, 0.8);
      expect(hpf.length, input.length);
      expect(hpf.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });

    test('applyDelay blends dry and wet signals deterministically', () {
      final input = processor.generateDemoGroove(bpm: 120.0, frequencyHz: 60.0, durationMs: 100);
      final delayed = processor.applyDelay(input, delaySamples: 500, feedback: 0.5, dryWet: 0.5);
      expect(delayed.length, input.length);
      expect(delayed.every((s) => !s.isNaN && !s.isInfinite), isTrue);
    });
  });

  group('DjPerformanceOrchestrator Extended Actions', () {
    test('Executes filter, delay, and recording actions via executeAction', () {
      final orchestrator = DjPerformanceOrchestrator();

      // Deck A filter
      orchestrator.executeAction(DjAction.deckAFilterSweepRight);
      expect(orchestrator.fxA.filterPosition, closeTo(0.1, 0.001));

      orchestrator.executeAction(DjAction.deckAFilterSweepLeft);
      expect(orchestrator.fxA.filterPosition, closeTo(0.0, 0.001));

      orchestrator.executeAction(DjAction.deckAFilterReset);
      expect(orchestrator.fxA.filterPosition, 0.0);

      // Deck A delay
      expect(orchestrator.fxA.isDelayActive, isFalse);
      orchestrator.executeAction(DjAction.deckAToggleDelay);
      expect(orchestrator.fxA.isDelayActive, isTrue);

      // Deck B delay
      expect(orchestrator.fxB.isDelayActive, isFalse);
      orchestrator.executeAction(DjAction.deckBToggleDelay);
      expect(orchestrator.fxB.isDelayActive, isTrue);

      // Live recording toggle
      expect(orchestrator.recorder.isRecording, isFalse);
      orchestrator.executeAction(DjAction.toggleMixRecording);
      expect(orchestrator.recorder.isRecording, isTrue);
      orchestrator.executeAction(DjAction.toggleMixRecording);
      expect(orchestrator.recorder.isRecording, isFalse);
    });
  });
}
