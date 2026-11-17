import 'audio_device_matrix_entity.dart';

/// Contrato formal del dominio para la persistencia no volátil
/// de la matriz de enrutamiento y calibración de audio de hardware de Tunner Studio.
///
/// Es puramente agnóstico de Flutter UI o dependencias de plataforma.
abstract class IStudioAudioHardwarePersistenceService {
  /// Carga asíncronamente el estado persistido de la matriz de audio.
  /// En caso de no existir o estar corrupto, debe retornar [AudioDeviceMatrixEntity.defaultConfiguration].
  Future<AudioDeviceMatrixEntity> loadMatrix();

  /// Persiste atómicamente el estado consolidado de la matriz en almacenamiento no volátil.
  Future<void> saveMatrix(AudioDeviceMatrixEntity matrix);

  /// Elimina los datos persistidos y restablece las configuraciones por defecto.
  Future<void> clear();
}
