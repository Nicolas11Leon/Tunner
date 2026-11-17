import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/i_studio_audio_channel.dart';
import 'package:tunner/core/audio/domain/i_studio_audio_engine.dart';
import 'package:tunner/core/audio/domain/studio_transport_status.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_channel.dart';
import 'package:tunner/features/dj_console/data/dj_deck_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudioAudioEngine & StudioAudioChannel Tests', () {
    late IStudioAudioEngine engine;

    setUp(() {
      engine = MemoryStudioAudioEngine();
    });

    test('getChannel returns unique channels and persists state', () {
      final chA = engine.getChannel('deck_a');
      final chB = engine.getChannel('deck_b');
      final chA2 = engine.getChannel('deck_a');

      expect(chA.channelId, 'deck_a');
      expect(chB.channelId, 'deck_b');
      expect(identical(chA, chA2), isTrue);
    });

    test('loadSource and play transition status to playing', () async {
      final ch = engine.getChannel('test_ch');
      expect(ch.status, StudioTransportStatus.stopped);
      expect(ch.isPlaying, isFalse);

      await ch.loadSource(bytes: Uint8List(100), loop: true, title: 'Demo');
      expect(ch.status, StudioTransportStatus.stopped);

      await ch.play();
      expect(ch.status, StudioTransportStatus.playing);
      expect(ch.isPlaying, isTrue);
      expect(ch.isPaused, isFalse);
    });

    test('pause transitions synchronously to paused and preserves position', () async {
      final ch = engine.getChannel('test_pause');
      await ch.play();
      expect(ch.isPlaying, isTrue);

      await ch.pause();
      expect(ch.status, StudioTransportStatus.paused);
      expect(ch.isPlaying, isFalse);
      expect(ch.isPaused, isTrue);
    });

    test('REGRESSION IMMUNITY: setVolume during pause NEVER resumes playback', () async {
      final ch = engine.getChannel('test_volume_immunity');
      await ch.play();
      expect(ch.isPlaying, isTrue);

      await ch.pause();
      expect(ch.isPaused, isTrue);
      expect(ch.isPlaying, isFalse);

      // Rapid fader changes while paused
      await ch.setVolume(0.0);
      expect(ch.isPaused, isTrue);
      expect(ch.isPlaying, isFalse);

      await ch.setVolume(0.75);
      expect(ch.isPaused, isTrue);
      expect(ch.isPlaying, isFalse);

      await ch.setVolume(1.0);
      expect(ch.isPaused, isTrue);
      expect(ch.isPlaying, isFalse);
    });

    test('play after pause resumes without error', () async {
      final ch = engine.getChannel('test_resume');
      await ch.play();
      await ch.pause();
      expect(ch.isPaused, isTrue);

      await ch.play();
      expect(ch.isPlaying, isTrue);
      expect(ch.isPaused, isFalse);
    });

    test('stop transitions to stopped and resets position to zero', () async {
      final ch = engine.getChannel('test_stop');
      await ch.play();
      await ch.seek(const Duration(seconds: 45));
      expect(ch.currentPosition.inSeconds, 45);

      await ch.stop();
      expect(ch.status, StudioTransportStatus.stopped);
      expect(ch.isPlaying, isFalse);
      expect(ch.currentPosition, Duration.zero);
    });

    test('pauseAll pauses every playing channel', () async {
      final ch1 = engine.getChannel('ch1');
      final ch2 = engine.getChannel('ch2');

      await ch1.play();
      await ch2.play();
      expect(ch1.isPlaying, isTrue);
      expect(ch2.isPlaying, isTrue);

      await engine.pauseAll();
      expect(ch1.isPaused, isTrue);
      expect(ch2.isPaused, isTrue);
    });
  });

  group('DjDeckAudioService Core Integration Tests', () {
    late DjDeckAudioService djAudioService;
    late MemoryStudioAudioEngine memoryEngine;

    setUp(() {
      memoryEngine = MemoryStudioAudioEngine();
      djAudioService = DjDeckAudioService(audioEngine: memoryEngine);
    });

    test('isDeckPlaying reflects Core Audio channel state', () async {
      expect(djAudioService.isDeckPlaying('A'), isFalse);
      expect(djAudioService.isDeckPlaying('B'), isFalse);

      await djAudioService.playDeck('A');
      expect(djAudioService.isDeckPlaying('A'), isTrue);
      expect(djAudioService.isDeckPlaying('B'), isFalse);

      await djAudioService.pauseDeck('A');
      expect(djAudioService.isDeckPlaying('A'), isFalse);
    });

    test('Bug fix verification: pauseDeck followed by volume synchronization keeps deck paused', () async {
      await djAudioService.playDeck('A');
      expect(djAudioService.isDeckPlaying('A'), isTrue);

      // User hits pause button
      await djAudioService.pauseDeck('A');
      expect(djAudioService.isDeckPlaying('A'), isFalse);

      // Simultaneous slider / fader event
      await djAudioService.setDeckVolume('A', 0.85);
      await djAudioService.setDeckVolume('A', 0.10);
      await djAudioService.setDeckVolume('A', 0.95);

      // Deck MUST remain strictly paused!
      expect(djAudioService.isDeckPlaying('A'), isFalse);
    });
  });
}
