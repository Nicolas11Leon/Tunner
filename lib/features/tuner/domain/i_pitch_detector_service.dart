import 'microphone_calibration_models.dart';

/// Contrato de dominio abstracto para el servicio de captura y detección acústica de tono.
/// Permite desacoplar totalmente la lógica de negocio de los plugins nativos (Record, PitchDetector)
/// y facilita la migración futura hacia FFI (C/Rust) o simuladores de prueba.
abstract class IPitchDetectorService {
  /// Callback invocado cuando se detecta una frecuencia fundamental válida (en Hz).
  Function(double pitchHz)? onPitchDetected;

  /// Callback invocado periódicamente con el nivel acústico RMS normalizado [0.0..1.0] para el medidor VU.
  Function(double rmsLevel)? onRmsLevelChanged;

  /// Inicia la captura de audio por micrófono y el análisis en Isolate.
  Future<void> startRecording();

  /// Detiene la captura y libera los recursos de hardware y puertos de memoria.
  Future<void> stopRecording();

  /// Actualiza los parámetros de calibración de ganancia, filtro DC y umbral de silencio en tiempo real.
  void updateCalibrationProfile(MicrophoneCalibrationProfile profile) {}

  /// Obtiene la lista de nombres/IDs de dispositivos de captura de audio disponibles.
  Future<List<String>> listInputDevices() async => const [];

  /// Selecciona el dispositivo de entrada activo.
  Future<void> setInputDevice(String deviceId) async {}
}

