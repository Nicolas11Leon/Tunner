import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_deck_entity.dart';
import 'package:tunner/features/dj_console/domain/memory_dj_deck_audio_player.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';

void main() {
  group('US-2.2 DJ Trim Gain, Key Sync & Split-Cue Tests', () {
    late DjConsoleViewModel viewModel;
    late MemoryDjDeckAudioPlayer mockPlayer;

    setUp(() {
      mockPlayer = MemoryDjDeckAudioPlayer();
      viewModel = DjConsoleViewModel(
        deckAudioPlayer: mockPlayer,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('DjDeckEntity calculates accurate trimDb from trim linear multiplier', () {
      const unityDeck = DjDeckEntity(deckId: 'A', trim: 1.0);
      expect(unityDeck.trimDb, closeTo(0.0, 0.01));

      const boostDeck = DjDeckEntity(deckId: 'A', trim: 2.0);
      expect(boostDeck.trimDb, closeTo(6.02, 0.05));

      const cutDeck = DjDeckEntity(deckId: 'A', trim: 0.5);
      expect(cutDeck.trimDb, closeTo(-6.02, 0.05));

      const zeroDeck = DjDeckEntity(deckId: 'A', trim: 0.0);
      expect(zeroDeck.trimDb, equals(-60.0));
    });

    test('setTrim updates orchestrator, effective gains and deckAudioPlayer volume', () {
      // Default trim is 1.0 (0.0 dB)
      expect(viewModel.deckA.trim, equals(1.0));

      // Boost Deck A to +6 dB (trim = 2.0)
      viewModel.setTrim('A', 2.0);
      expect(viewModel.deckA.trim, equals(2.0));
      expect(viewModel.deckA.trimDb, closeTo(6.02, 0.05));

      // Attenuate to -inf dB (trim = 0.0)
      viewModel.setTrim('A', 0.0);
      expect(viewModel.deckA.trim, equals(0.0));
      expect(viewModel.orchestrator.getEffectiveGains().effectiveGainA, equals(0.0));
      expect(viewModel.orchestrator.deckAGain, equals(0.0));
    });

    test('syncKey computes Camelot semitone shift and updates deck playback rate', () {
      // Setup Deck A at Camelot 8A and Deck B at 11A
      viewModel.orchestrator.loadTrack(
        'A',
        title: 'Track A',
        artist: 'Artist A',
        bpm: 120.0,
        durationMs: 180000,
        camelotKey: '8A',
      );
      viewModel.orchestrator.loadTrack(
        'B',
        title: 'Track B',
        artist: 'Artist B',
        bpm: 120.0,
        durationMs: 180000,
        camelotKey: '11A',
      );

      // Key Lock enabled: rate follows pitchMultiplier (1.0), semitones shifted
      viewModel.syncKey('B');
      expect(viewModel.deckB.pitchSemitonesShift, isNot(equals(0)));
      expect(viewModel.deckB.effectivePlaybackRate, closeTo(1.0, 0.01));

      // Key Lock disabled: effective playback rate shifts with pitch ratio
      viewModel.toggleKeyLock('B');
      expect(viewModel.deckB.isKeyLockEnabled, isFalse);
      expect(viewModel.deckB.effectivePlaybackRate, isNot(closeTo(1.0, 0.001)));
    });

    test('generateSplitCueChunk encodes interleaved master in L and cue in R', () {
      viewModel.toggleSplitCue();
      expect(viewModel.cueMonitor.isSplitCueActive, isTrue);

      viewModel.toggleCueMonitor('A');
      expect(viewModel.cueMonitor.cueDeckA, isTrue);

      final sliceA = Float32List(100);
      sliceA.fillRange(0, 100, 0.5);
      final sliceB = Float32List(100);

      final splitCue = viewModel.generateSplitCueChunk(sliceA: sliceA, sliceB: sliceB);
      expect(splitCue.length, equals(200)); // 100 frames * 2 channels

      // Master in Left channel (even indices) and Cue PFL in Right channel (odd indices)
      for (int i = 0; i < 100; i++) {
        expect(splitCue[i * 2 + 1], greaterThan(0.0)); // Cue present in right ear
      }
    });

    test('executeAction synchronizes deck audio player on transport and pitch actions', () {
      // Play/Pause Deck A
      viewModel.executeAction(DjAction.deckAPlayPause);
      expect(mockPlayer.isDeckPlaying('A'), isTrue);

      viewModel.executeAction(DjAction.deckAPlayPause);
      expect(mockPlayer.isDeckPlaying('A'), isFalse);

      // Pitch adjustment syncs playback rate
      viewModel.executeAction(DjAction.deckAPitchUp);
      expect(mockPlayer.playbackRateA, greaterThan(1.0));

      viewModel.executeAction(DjAction.deckAPitchDown);
      expect(mockPlayer.playbackRateA, closeTo(1.0, 0.05));
    });
  });
}
