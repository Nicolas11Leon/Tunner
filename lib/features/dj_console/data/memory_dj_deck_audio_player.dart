import 'dart:typed_data';
import '../domain/i_dj_deck_audio_player.dart';

/// Implementación en memoria de [IDjDeckAudioPlayer] para pruebas unitarias y entornos sin hardware de audio.
class MemoryDjDeckAudioPlayer implements IDjDeckAudioPlayer {
  bool isPlayingA = false;
  bool isPlayingB = false;
  double volumeA = 1.0;
  double volumeB = 1.0;
  double playbackRateA = 1.0;
  double playbackRateB = 1.0;
  Duration positionA = Duration.zero;
  Duration positionB = Duration.zero;
  String? loadedPathA;
  String? loadedPathB;
  String? loadedTitleA;
  String? loadedTitleB;
  Uint8List? loadedBytesA;
  Uint8List? loadedBytesB;

  @override
  bool isDeckPlaying(String deckId) {
    return deckId.toUpperCase() == 'A' ? isPlayingA : isPlayingB;
  }

  @override
  Future<void> loadDeckTrack(
    String deckId, {
    String? filePath,
    Uint8List? wavBytes,
    String? title,
    double? bpm,
  }) async {
    if (deckId.toUpperCase() == 'A') {
      loadedPathA = filePath;
      loadedTitleA = title;
      loadedBytesA = wavBytes;
      isPlayingA = false;
    } else {
      loadedPathB = filePath;
      loadedTitleB = title;
      loadedBytesB = wavBytes;
      isPlayingB = false;
    }
  }

  @override
  Future<void> playDeck(String deckId) async {
    if (deckId.toUpperCase() == 'A') {
      isPlayingA = true;
    } else {
      isPlayingB = true;
    }
  }

  @override
  Future<void> pauseDeck(String deckId) async {
    if (deckId.toUpperCase() == 'A') {
      isPlayingA = false;
    } else {
      isPlayingB = false;
    }
  }

  @override
  Future<void> seekDeck(String deckId, Duration position) async {
    if (deckId.toUpperCase() == 'A') {
      positionA = position;
    } else {
      positionB = position;
    }
  }

  @override
  Future<void> setDeckVolume(String deckId, double volume) async {
    if (deckId.toUpperCase() == 'A') {
      volumeA = volume.clamp(0.0, 1.0);
    } else {
      volumeB = volume.clamp(0.0, 1.0);
    }
  }

  @override
  Future<void> setDeckPlaybackRate(String deckId, double rate) async {
    if (deckId.toUpperCase() == 'A') {
      playbackRateA = rate.clamp(0.2, 3.0);
    } else {
      playbackRateB = rate.clamp(0.2, 3.0);
    }
  }

  @override
  void dispose() {
    isPlayingA = false;
    isPlayingB = false;
  }
}
