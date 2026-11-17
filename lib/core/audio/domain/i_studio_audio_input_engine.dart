import 'audio_device_entity.dart';
import 'audio_pcm_frame.dart';

/// Contrato central para el motor de captura de audio e ingesta física de Tunner Studio.
/// Gobierna la detección de interfaces de audio externas, el streaming continuo y la telemetría acústica.
abstract class IStudioAudioInputEngine {
  /// Lista las interfaces de captura de audio física y virtual detectadas en el host.
  Future<List<AudioDeviceEntity>> listInputDevices();

  /// Selecciona la interfaz de audio activa por su identificador.
  Future<void> setInputDevice(String deviceId);

  /// Dispositivo de captura actualmente seleccionado.
  AudioDeviceEntity? get currentDevice;

  /// Inicia la captura continua de audio con la frecuencia de muestreo y tamaño de buffer indicados.
  Future<void> startCapture({int sampleRate = 44100, int bufferSize = 1024});

  /// Detiene la captura física de audio.
  Future<void> stopCapture();

  /// Indica si el motor se encuentra capturando audio activamente.
  bool get isCapturing;

  /// Flujo continuo de cuadros de audio normalizados [AudioPcmFrame].
  Stream<AudioPcmFrame> get pcmFrameStream;

  /// Flujo de medición de nivel de energía RMS en decibelios Full Scale (dBFS).
  Stream<double> get rmsDbStream;

  /// Flujo de medición de pico máximo instantáneo en decibelios Full Scale (dBFS).
  Stream<double> get peakDbStream;

  /// Libera los recursos del motor y cierra los flujos reactivos.
  void dispose();
}
