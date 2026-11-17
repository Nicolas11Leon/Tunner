import '../domain/audio_device_matrix_entity.dart';
import '../domain/i_studio_audio_hardware_persistence_service.dart';

/// Implementacion en memoria de [IStudioAudioHardwarePersistenceService]
/// disenada para pruebas unitarias rapidas sin tocar el sistema de archivos del sistema operativo.
class MemoryAudioHardwarePersistenceService implements IStudioAudioHardwarePersistenceService {
  AudioDeviceMatrixEntity? _storedMatrix;

  MemoryAudioHardwarePersistenceService([this._storedMatrix]);

  @override
  Future<AudioDeviceMatrixEntity> loadMatrix() async {
    return _storedMatrix ?? AudioDeviceMatrixEntity.defaultConfiguration();
  }

  @override
  Future<void> saveMatrix(AudioDeviceMatrixEntity matrix) async {
    _storedMatrix = matrix;
  }

  @override
  Future<void> clear() async {
    _storedMatrix = null;
  }
}
