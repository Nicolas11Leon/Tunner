import 'dart:typed_data';

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

  /// Inicia la reproducción en bucle continuo del buffer WAV sintetizado para el estudio de dron.
  Future<void> startDroneLoop(Uint8List wavBytes, {double volume = 0.7});

  /// Reproduce un buffer de audio WAV PCM de forma inmediata con baja latencia.
  Future<void> playPcmWav(Uint8List wavBytes, {double volume = 0.8});

  /// Detiene la reproducción del dron continuo.
  Future<void> stopDroneLoop();

  /// Indica si actualmente el dron pedal está reproduciéndose en bucle.
  bool get isDroneLoopPlaying;

  /// Libera recursos de audio nativos.
  void dispose();
}

/// Implementación nula / no-op para inicializaciones seguras sin dependencias de hardware.
class NoOpAudioSynthesizerService implements IAudioSynthesizerService {
  const NoOpAudioSynthesizerService();

  @override
  bool get isDiapasonPlaying => false;

  @override
  double get activeDiapasonFrequency => 0.0;

  @override
  bool get isDroneLoopPlaying => false;

  @override
  Future<void> playMetronomeClick({required bool isDownbeat, double volume = 1.0}) async {}

  @override
  Future<void> startDiapasonTone(double frequency, {double volume = 0.8}) async {}

  @override
  Future<void> stopDiapasonTone() async {}

  @override
  Future<void> playNoteTone({
    required double frequency,
    required Duration duration,
    double volume = 0.8,
  }) async {}

  @override
  Future<void> startDroneLoop(Uint8List wavBytes, {double volume = 0.7}) async {}

  @override
  Future<void> playPcmWav(Uint8List wavBytes, {double volume = 0.8}) async {}

  @override
  Future<void> stopDroneLoop() async {}

  @override
  void dispose() {}
}
