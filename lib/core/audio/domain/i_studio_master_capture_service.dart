import 'dart:async';

/// Contrato formal del dominio para la captura en tiempo real
/// y volcado a archivo WAV sin pérdidas de la mezcla del bus maestro.
abstract class IStudioMasterCaptureService {
  /// Inicia la captura de audio en el archivo especificado en [destinationPath].
  Future<void> startCapture({
    required String destinationPath,
    int sampleRate = 44100,
    int channels = 2,
  });

  /// Detiene la captura, escribe la cabecera WAV final con el tamaño exacto y retorna la ruta del archivo generado.
  Future<String?> stopCapture();

  /// Agrega un bloque de muestras de audio estéreo normalizadas (-1.0 a 1.0) al búfer de captura activo.
  void appendStereoSamples(List<double> left, List<double> right);

  /// Indica si la captura de audio se encuentra actualmente en curso.
  bool get isCapturing;

  /// Tiempo acumulado transcurrido de la sesión de grabación activa.
  Duration get elapsedDuration;

  /// Flujo continuo de actualización temporal de la sesión de grabación.
  Stream<Duration> get durationStream;

  /// Libera los recursos y descriptores de archivo asociados.
  void dispose();
}
