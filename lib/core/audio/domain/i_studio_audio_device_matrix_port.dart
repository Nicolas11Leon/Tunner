import 'audio_device_matrix_entity.dart';

/// Puerto abstracto de dominio para consultar y restaurar la matriz de ruteo de audio
/// sin acoplar ViewModels de presentación al servicio de infraestructura concreto.
abstract class IStudioAudioDeviceMatrixPort {
  AudioDeviceMatrixEntity get matrix;
  void restoreMatrix(AudioDeviceMatrixEntity savedMatrix);
}
