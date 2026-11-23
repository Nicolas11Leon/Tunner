import 'audio_device_matrix_entity.dart';

/// Puerto abstracto de dominio para consultar, enrutar y procesar la matriz de audio
/// sin acoplar ViewModels de presentación al servicio de infraestructura concreto.
abstract class IStudioAudioDeviceMatrixPort {
  AudioDeviceMatrixEntity get matrix;
  void restoreMatrix(AudioDeviceMatrixEntity savedMatrix);

  /// Procesa un bloque de muestras de audio estéreo normalizadas a través de la cadena DSP maestra.
  /// Modifica el estado del vúmetro y vuelca las muestras al servicio de captura si la grabación está activa.
  void processMasterStereoSamples(List<double> left, List<double> right);
}
