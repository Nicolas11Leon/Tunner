/// Contrato de dominio abstracto para el servicio de captura y detección acústica de tono.
/// Permite desacoplar totalmente la lógica de negocio de los plugins nativos (Record, PitchDetector)
/// y facilita la migración futura hacia FFI (C/Rust) o simuladores de prueba.
abstract class IPitchDetectorService {
  /// Callback invocado cuando se detecta una frecuencia fundamental válida (en Hz).
  Function(double pitchHz)? onPitchDetected;

  /// Inicia la captura de audio por micrófono y el análisis en Isolate.
  Future<void> startRecording();

  /// Detiene la captura y libera los recursos de hardware y puertos de memoria.
  Future<void> stopRecording();
}
