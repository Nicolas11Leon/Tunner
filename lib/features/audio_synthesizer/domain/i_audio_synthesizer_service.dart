/// Contrato de dominio abstracto para el sintetizador de audio procedimental.
/// Pure Dart: Cero dependencias de Flutter UI.
abstract class IAudioSynthesizerService {
  /// Emite un clic percusivo de metrónomo.
  ///
  /// * [isDownbeat]: True si es el primer pulso del compás (acento agudo).
  /// * [volume]: Ganancia normalizada entre 0.0 y 1.0.
  Future<void> playMetronomeClick({required bool isDownbeat, double volume = 1.0});

  /// Inicia el tono continuo de diapasón a la frecuencia especificada en [frequency] (Hz).
  Future<void> startDiapasonTone(double frequency, {double volume = 0.8});

  /// Detiene la reproducción del diapasón.
  Future<void> stopDiapasonTone();

  /// Indica si actualmente el diapasón está sonando.
  bool get isDiapasonPlaying;

  /// Frecuencia actualmente activa en el diapasón, o 0.0 si está inactivo.
  double get activeDiapasonFrequency;

  /// Sintetiza y reproduce una nota musical melódica con duración y envolvente ADSR suave.
  ///
  /// * [frequency]: Frecuencia exacta en Hz.
  /// * [duration]: Duración física de la nota.
  /// * [volume]: Ganancia normalizada entre 0.0 y 1.0.
  Future<void> playNoteTone({
    required double frequency,
    required Duration duration,
    double volume = 0.8,
  });

  /// Libera recursos de audio nativos.
  void dispose();
}
