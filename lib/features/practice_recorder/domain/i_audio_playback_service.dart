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
