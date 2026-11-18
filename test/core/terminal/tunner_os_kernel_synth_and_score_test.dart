import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/terminal/domain/tunner_os_kernel.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/sheet_music/domain/score_playback_coordinator.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';

void main() {
  group('TunnerOsKernel Synth and Score Command Tests', () {
    late PolyphonicVoicePool voicePool;
    late ScorePlaybackCoordinator scoreCoordinator;
    late TunnerOsKernel kernel;

    setUp(() {
      voicePool = PolyphonicVoicePool(maxPolyphony: 8);
      scoreCoordinator = ScorePlaybackCoordinator(voicePool: voicePool, initialBpm: 120.0);

      final measure = MeasureEntity(
        index: 0,
        timeSignature: TimeSignature.commonTime44,
        notes: [
          HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4'),
        ],
      );
      scoreCoordinator.startPlayback(
        score: HierarchicalScore(title: 'CLI Score', measures: [measure]),
      );
      scoreCoordinator.stopPlayback();

      kernel = TunnerOsKernel(
        synthVoicePool: voicePool,
        scorePlaybackCoordinator: scoreCoordinator,
      );
    });

    tearDown(() {
      scoreCoordinator.dispose();
    });

    test('synth status returns report with active voices and ADSR parameters', () async {
      final res = await kernel.execute('synth status');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('SINTETIZADOR POLIFÓNICO SMuFL'));
      expect(res.message, contains('Forma de Onda'));
      expect(res.message, contains('Ataque (A)'));
    });

    test('synth wave switches waveform dynamically', () async {
      var res = await kernel.execute('synth wave saw');
      expect(res.isSuccess, isTrue);
      expect(voicePool.waveform, SynthWaveform.sawtooth);

      res = await kernel.execute('synth wave pulse');
      expect(res.isSuccess, isTrue);
      expect(voicePool.waveform, SynthWaveform.pulse);

      res = await kernel.execute('synth wave tri');
      expect(res.isSuccess, isTrue);
      expect(voicePool.waveform, SynthWaveform.triangle);
    });

    test('synth adsr updates ADSR parameters', () async {
      final res = await kernel.execute('synth adsr 25 120 0.55 300');
      expect(res.isSuccess, isTrue);
      expect(voicePool.attackSeconds, closeTo(0.025, 0.001));
      expect(voicePool.decaySeconds, closeTo(0.120, 0.001));
      expect(voicePool.sustainLevel, closeTo(0.55, 0.001));
      expect(voicePool.releaseSeconds, closeTo(0.300, 0.001));
    });

    test('synth note triggers voice and synth panic silences it', () async {
      expect(voicePool.activeVoiceCount, 0);

      final resNote = await kernel.execute('synth note Do4 0.9');
      expect(resNote.isSuccess, isTrue);
      expect(voicePool.activeVoiceCount, 1);

      final resPanic = await kernel.execute('synth panic');
      expect(resPanic.isSuccess, isTrue);
      expect(voicePool.activeVoiceCount, 0);
    });

    test('score commands control score playback coordinator', () async {
      var res = await kernel.execute('score play');
      expect(res.isSuccess, isTrue);
      expect(scoreCoordinator.isPlaying, isTrue);

      res = await kernel.execute('score bpm 140');
      expect(res.isSuccess, isTrue);
      expect(scoreCoordinator.bpm, closeTo(140.0, 0.1));

      res = await kernel.execute('score pause');
      expect(res.isSuccess, isTrue);
      expect(scoreCoordinator.isPlaying, isFalse);

      res = await kernel.execute('score stop');
      expect(res.isSuccess, isTrue);
      expect(scoreCoordinator.isPlaying, isFalse);
      expect(scoreCoordinator.currentMeasureIndex, 0);
    });
  });
}
