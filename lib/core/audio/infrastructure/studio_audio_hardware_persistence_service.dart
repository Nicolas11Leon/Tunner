import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../logging/infrastructure/studio_debug_logger.dart';
import '../domain/audio_device_matrix_entity.dart';
import '../domain/i_studio_audio_hardware_persistence_service.dart';

/// Implementacion de infraestructura para la persistencia no volatil offline
/// de la matriz de enrutamiento y calibracion de audio en formato JSON.
///
/// Implementa escritura atomica en archivo temporal (.tmp) y renombrado posterior,
/// previniendo corrupcion de datos ante cierres intempestivos del sistema.
class StudioAudioHardwarePersistenceService implements IStudioAudioHardwarePersistenceService {
  final Future<String> Function()? _documentsPathProvider;
  final String _fileName;

  Future<void>? _pendingSaveOperation;

  StudioAudioHardwarePersistenceService({
    Future<String> Function()? documentsPathProvider,
    String fileName = 'tunner_audio_hardware_matrix.json',
  })  : _documentsPathProvider = documentsPathProvider,
        _fileName = fileName;

  Future<File> _getTargetFile() async {
    String directoryPath;
    if (_documentsPathProvider != null) {
      directoryPath = await _documentsPathProvider();
    } else {
      try {
        final dir = await getApplicationDocumentsDirectory();
        directoryPath = dir.path;
      } catch (e) {
        directoryPath = Directory.systemTemp.path;
      }
    }
    return File('$directoryPath/$_fileName');
  }

  @override
  Future<AudioDeviceMatrixEntity> loadMatrix() async {
    final pending = _pendingSaveOperation;
    if (pending != null) {
      try {
        await pending;
      } catch (e, st) {
        StudioDebugLogger.instance.warning(
          'StudioAudioHardwarePersistenceService',
          'Pending matrix save failed prior to loadMatrix',
          error: e,
          stackTrace: st,
        );
      }
    }

    try {
      final file = await _getTargetFile();
      if (!await file.exists()) {
        return AudioDeviceMatrixEntity.defaultConfiguration();
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return AudioDeviceMatrixEntity.defaultConfiguration();
      }

      final jsonMap = jsonDecode(content) as Map<String, dynamic>;
      return AudioDeviceMatrixEntity.fromJson(jsonMap);
    } catch (e) {
      StudioDebugLogger.instance.warning('StudioAudioHardwarePersistenceService', 'Error al cargar la matriz de hardware de audio: $e');
      return AudioDeviceMatrixEntity.defaultConfiguration();
    }
  }

  @override
  Future<void> saveMatrix(AudioDeviceMatrixEntity matrix) async {
    final completer = Completer<void>();
    _pendingSaveOperation = completer.future;

    try {
      final file = await _getTargetFile();
      final tempFile = File('${file.path}.tmp');

      final jsonString = jsonEncode(matrix.toJson());
      await tempFile.writeAsString(jsonString, flush: true);

      if (await tempFile.exists()) {
        await tempFile.rename(file.path);
      }
      completer.complete();
    } catch (e) {
      StudioDebugLogger.instance.warning('StudioAudioHardwarePersistenceService', 'Error al guardar la matriz de hardware de audio: $e');
      completer.completeError(e);
    } finally {
      if (_pendingSaveOperation == completer.future) {
        _pendingSaveOperation = null;
      }
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _getTargetFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      StudioDebugLogger.instance.warning('StudioAudioHardwarePersistenceService', 'Error al limpiar la matriz de hardware de audio: $e');
    }
  }
}
