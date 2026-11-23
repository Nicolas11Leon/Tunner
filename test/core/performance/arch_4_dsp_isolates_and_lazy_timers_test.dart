import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/dj_console/domain/bpm_beat_tracker_engine.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_playback_coordinator.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_decomposer_service.dart';
import 'package:tunner/features/vocal_autotune/domain/vocal_autotune_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ARCH-4 DSP Isolates, Lazy Ticker & Monotonic Clock', () {
    test('DjConsoleViewModel starts with zero idle timers and activates ticker lazily on play/pause', () {
      final vm = DjConsoleViewModel();
      expect(vm.isTickerActive, isFalse);

      vm.executeAction(DjAction.deckAPlayPause);
      expect(vm.deckA.isPlaying, isTrue);
      expect(vm.isTickerActive, isTrue);

      vm.executeAction(DjAction.deckAPlayPause);
      expect(vm.deckA.isPlaying, isFalse);
      expect(vm.isTickerActive, isFalse);

      vm.dispose();
    });

    test('BpmBeatTrackerEngine.estimateBpmAsync runs in Isolate and returns valid BPM', () async {
      const sampleRate = 44100;
      const durationSec = 2;
      final samples = Float32List(sampleRate * durationSec);
      // Generate percussive 120 BPM impulses (every 0.5s)
      for (int beat = 0; beat < 4; beat++) {
        final start = beat * (sampleRate ~/ 2);
        for (int k = 0; k < 2000 && (start + k) < samples.length; k++) {
          samples[start + k] = math.sin(2 * math.pi * 110 * k / sampleRate) * (1.0 - k / 2000.0);
        }
      }

      final bpm = await BpmBeatTrackerEngine.estimateBpmAsync(
        samples: samples,
        sampleRate: sampleRate,
      );
      expect(bpm, inInclusiveRange(60.0, 180.0));
    });

    test('VocalAutoTuneProcessor.processPracticeTakeAsync runs in Isolate and produces tuned take', () async {
      final processor = VocalAutoTuneProcessor();
      final take = PracticeTakeEntity(
        id: 'take_1',
        name: 'Vocal Take 1',
        timestamp: DateTime(2026, 1, 1),
        duration: const Duration(seconds: 1),
        filePath: '/tmp/take_1.wav',
        pitchTrack: const [
          TimedPitchSample(
            timeMs: 0,
            frequencyHz: 445.0,
            centsDeviation: 19.5,
            targetNoteName: 'A4',
          ),
        ],
      );

      final tuned = await processor.processPracticeTakeAsync(take: take);
      expect(tuned.name, contains('AutoTuned'));
      expect(tuned.pitchTrack.length, equals(1));
    });

    test('SongDecomposerService.decomposeCustomScoreAsync runs in Isolate and builds stems', () async {
      final pkg = await SongDecomposerService.decomposeCustomScoreAsync(
        title: 'Isolate Etude',
        composer: 'Tunner',
        bpm: 120,
        timeSignature: TimeSignature.commonTime44,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4'),
              HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Mi4'),
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'Sol4'),
              HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: 'Do5'),
            ],
          ),
        ],
      );

      expect(pkg.title, equals('Isolate Etude'));
      expect(pkg.tracks.length, equals(4));
    });

    test('DjConsoleViewModel.loadTrackWithBeatTrackingAsync loads track off UI thread without starting idle ticker', () async {
      final vm = DjConsoleViewModel();
      final samples = Float32List(44100 * 2);

      final bpm = await vm.loadTrackWithBeatTrackingAsync(
        'A',
        title: 'Async Groove',
        artist: 'Isolate',
        audioSamples: samples,
      );

      expect(bpm, inInclusiveRange(60.0, 180.0));
      expect(vm.deckA.trackTitle, equals('Async Groove'));
      expect(vm.isTickerActive, isFalse);

      vm.dispose();
    });

    test('ScorePlaybackCoordinator advances ticks with monotonic Stopwatch clock and stops cleanly', () async {
      final pool = PolyphonicVoicePool();
      final coordinator = ScorePlaybackCoordinator(
        voicePool: pool,
        initialBpm: 240.0, // 1 sub-tick = 62.5 ms
      );

      final ticks = <(int, int)>[];
      coordinator.onTick = (measure, subTick) {
        ticks.add((measure, subTick));
      };

      final score = HierarchicalScore(
        title: 'Clock Test',
        baseBpm: 240,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4'),
            ],
          ),
        ],
      );

      coordinator.startPlayback(score: score);
      await Future<void>.delayed(const Duration(milliseconds: 160));
      coordinator.stopPlayback();

      expect(ticks.length, greaterThanOrEqualTo(2));
      expect(coordinator.isPlaying, isFalse);
      coordinator.dispose();
    });
  });
}
