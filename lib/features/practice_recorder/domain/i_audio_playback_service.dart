/// Contrato de dominio abstracto para la reproducción y auto-escucha de audio grabado.
abstract class IAudioPlaybackService {
  /// Inicia la reproducción del archivo de audio ubicado en [filePath].
  Future<void> play(String filePath);

  /// Pausa la reproducción actual preservando la posición.
  Future<void> pause();

  /// Detiene la reproducción y reinicia la posición al inicio.
  Future<void> stop();

  /// Salta a una posición temporal específica dentro del audio.
  Future<void> seek(Duration position);

  /// Ajusta la velocidad de reproducción (ej. 0.75, 1.0, 1.25).
  Future<void> setPlaybackRate(double rate);

  /// Stream que emite la posición actual de reproducción en tiempo real.
  Stream<Duration> get onPositionChanged;

  /// Stream que emite la duración total del archivo cargado.
  Stream<Duration> get onDurationChanged;

  /// Stream que notifica cuando la reproducción ha llegado al final del archivo.
  Stream<void> get onPlayerComplete;

  /// Indica si actualmente se está reproduciendo audio.
  bool get isPlaying;

  /// Libera recursos del motor de reproducción.
  void dispose();
}

/// Implementación nula / no-op en dominio puro para pruebas y entornos aislados.
class NoOpAudioPlaybackService implements IAudioPlaybackService {
  const NoOpAudioPlaybackService();

  @override
  Future<void> play(String filePath) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Stream<Duration> get onPositionChanged => const Stream<Duration>.empty();

  @override
  Stream<Duration> get onDurationChanged => const Stream<Duration>.empty();

  @override
  Stream<void> get onPlayerComplete => const Stream<void>.empty();

  @override
  bool get isPlaying => false;

  @override
  void dispose() {}
}
