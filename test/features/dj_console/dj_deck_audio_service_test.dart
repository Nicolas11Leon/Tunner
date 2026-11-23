import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/features/dj_console/data/dj_deck_audio_service.dart';
import 'package:tunner/features/dj_console/data/memory_dj_deck_audio_player.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DjDeckAudioService & MemoryDjDeckAudioPlayer Tests', () {
    test('MemoryDjDeckAudioPlayer accurately manages deck playback and volume states', () async {
      final player = MemoryDjDeckAudioPlayer();

      expect(player.isDeckPlaying('A'), isFalse);
      expect(player.isDeckPlaying('B'), isFalse);

      await player.playDeck('A');
      expect(player.isDeckPlaying('A'), isTrue);
      expect(player.isDeckPlaying('B'), isFalse);

      await player.pauseDeck('A');
      expect(player.isDeckPlaying('A'), isFalse);

      await player.setDeckVolume('A', 0.75);
      expect(player.volumeA, closeTo(0.75, 0.001));

      await player.setDeckPlaybackRate('B', 1.08);
      expect(player.playbackRateB, closeTo(1.08, 0.001));

      await player.seekDeck('A', const Duration(milliseconds: 1500));
      expect(player.positionA.inMilliseconds, equals(1500));

      final testBytes = Uint8List.fromList([1, 2, 3, 4]);
      await player.loadDeckTrack('A', wavBytes: testBytes, title: 'Test Track');
      expect(player.loadedBytesA, equals(testBytes));
      expect(player.isDeckPlaying('A'), isFalse);

      player.dispose();
      expect(player.isPlayingA, isFalse);
      expect(player.isPlayingB, isFalse);
    });

    test('DjDeckAudioService executes cleanly in headless test environment', () async {
      final service = DjDeckAudioService(audioEngine: MemoryStudioAudioEngine());

      expect(service.isDeckPlaying('A'), isFalse);
      expect(service.isDeckPlaying('B'), isFalse);

      await service.loadDeckTrack('A', title: 'Studio Track A', bpm: 124.0);
      await service.playDeck('A');
      expect(service.isDeckPlaying('A'), isTrue);

      await service.pauseDeck('A');
      expect(service.isDeckPlaying('A'), isFalse);

      await service.setDeckVolume('A', 0.5);
      await service.setDeckPlaybackRate('A', 1.05);
      await service.seekDeck('A', const Duration(seconds: 2));

      service.dispose();
    });

    test('DjConsoleViewModel integrates with IDjDeckAudioPlayer for real audio dispatch', () async {
      final memoryPlayer = MemoryDjDeckAudioPlayer();
      final viewModel = DjConsoleViewModel(deckAudioPlayer: memoryPlayer);

      // Verify initialization loaded tracks
      expect(viewModel.deckAudioPlayer, equals(memoryPlayer));

      // Toggle play Deck A
      viewModel.togglePlay('A');
      expect(memoryPlayer.isPlayingA, isTrue);
      expect(viewModel.deckA.isPlaying, isTrue);

      viewModel.togglePlay('A');
      expect(memoryPlayer.isPlayingA, isFalse);
      expect(viewModel.deckA.isPlaying, isFalse);

      // Crossfader updates volume attenuation
      viewModel.setCrossfaderPosition(-1.0); // Full left (Deck A 100%, Deck B 0%)
      expect(memoryPlayer.volumeA, closeTo(1.0, 0.05));
      expect(memoryPlayer.volumeB, closeTo(0.0, 0.05));

      viewModel.setCrossfaderPosition(1.0); // Full right (Deck A 0%, Deck B 100%)
      expect(memoryPlayer.volumeA, closeTo(0.0, 0.05));
      expect(memoryPlayer.volumeB, closeTo(1.0, 0.05));

      // Cue trigger seeks deck and updates playback state
      viewModel.triggerCue('A');
      expect(memoryPlayer.positionA.inMilliseconds, equals(viewModel.deckA.cuePositionMs));

      // Pitch adjustment alters playback rate
      viewModel.adjustPitch('A', 0.05); // +5% pitch bend
      expect(memoryPlayer.playbackRateA, greaterThan(1.0));

      viewModel.resetPitch('A');
      expect(memoryPlayer.playbackRateA, closeTo(1.0, 0.001));

      // Action dispatch deckBPlayPause
      viewModel.executeAction(DjAction.deckBPlayPause);
      expect(memoryPlayer.isPlayingB, isTrue);

      viewModel.executeAction(DjAction.deckBPlayPause);
      expect(memoryPlayer.isPlayingB, isFalse);

      viewModel.dispose();
    });
  });
}
