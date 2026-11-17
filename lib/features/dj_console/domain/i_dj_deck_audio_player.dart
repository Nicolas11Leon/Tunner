import 'dart:typed_data';

/// Contrato de dominio abstracto para el motor de reproducción de audio de la Consola DJ.
/// Permite desacoplar el ViewModel de la implementación concreta de audio (`audioplayers` o FFI).
abstract class IDjDeckAudioPlayer {
  /// Carga una pista en el deck especificado ('A' o 'B') mediante archivo local o buffer WAV.
  Future<void> loadDeckTrack(
    String deckId, {
    String? filePath,
    Uint8List? wavBytes,
    String? title,
    double? bpm,
  });

  /// Inicia o reanuda la reproducción audible en el deck.
  Future<void> playDeck(String deckId);

  /// Pausa la reproducción audible en el deck.
  Future<void> pauseDeck(String deckId);

  /// Desplaza la posición de reproducción (Cue o Scrubbing).
  Future<void> seekDeck(String deckId, Duration position);

  /// Modifica el volumen de salida efectivo del deck normalizado [0.0, 1.0].
  Future<void> setDeckVolume(String deckId, double volume);

  /// Modifica la velocidad y tasa de reproducción (Pitch Shifting en vivo) [0.5, 2.0].
  Future<void> setDeckPlaybackRate(String deckId, double rate);

  /// Consulta si el deck está emitiendo sonido audible activamente.
  bool isDeckPlaying(String deckId);

  /// Libera recursos de audio nativos.
  void dispose();
}
