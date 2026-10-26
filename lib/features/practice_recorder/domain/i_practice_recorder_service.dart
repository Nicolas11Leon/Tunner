/// Contrato de dominio abstracto para el servicio de grabación de audio de práctica.
/// Desacopla la lógica de negocio de los plugins específicos de hardware o SO.
abstract class IPracticeRecorderService {
  /// Inicia la grabación acústica y la almacena en [destinationPath].
  Future<void> startRecording({required String destinationPath});

  /// Detiene la grabación activa y retorna la ruta del archivo generado.
  /// Si la grabación no estaba activa o falló, retorna `null`.
  Future<String?> stopRecording();

  /// Pausa temporalmente la grabación en curso.
  Future<void> pauseRecording();

  /// Reanuda la grabación previamente pausada.
  Future<void> resumeRecording();

  /// Indica si hay una grabación activa en progreso.
  bool get isRecording;

  /// Stream reactivo de picos de amplitud normalizados (0.0 a 1.0) para visualización en tiempo real.
  Stream<double> get amplitudeStream;

  /// Libera recursos del hardware de audio.
  void dispose();
}
