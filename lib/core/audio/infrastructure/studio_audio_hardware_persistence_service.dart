import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../logging/domain/i_studio_logger.dart';
import '../domain/audio_device_matrix_entity.dart';
import '../domain/i_studio_audio_hardware_persistence_service.dart';

/// Implementacion de infraestructura para la persistencia no volatil offline
/// de la matriz de enrutamiento y calibracion de audio en formato JSON.
///
/// Implementa escritura atomica en archivo temporal (.tmp) y renombrado posterior,
/// previniendo corrupcion de datos ante cierres intempestivos del sistema.
class StudioAudioHardwarePersistenceService implements IStudioAudioHardwarePersistenceService {
  final Future<String> Function()? _documentsPathProvider;
  final Future<Directory> Function()? _rootDirectoryProvider;
  final IStudioLogger _logger;
  final String _fileName;

  Future<void>? _pendingSaveOperation;

  StudioAudioHardwarePersistenceService({
    Future<String> Function()? documentsPathProvider,
    Future<Directory> Function()? rootDirectoryProvider,
    IStudioLogger logger = const NoOpStudioLogger(),
    String fileName = 'tunner_audio_hardware_matrix.json',
  })  : _documentsPathProvider = documentsPathProvider,
        _rootDirectoryProvider = rootDirectoryProvider,
        _logger = logger,
        _fileName = fileName;

  Future<File> _getTargetFile() async {
    String directoryPath;
    if (_documentsPathProvider != null) {
      directoryPath = await _documentsPathProvider();
    } else if (_rootDirectoryProvider != null) {
      final dir = await _rootDirectoryProvider();
      directoryPath = dir.path;
    } else {
      directoryPath = _resolveDefaultDirectoryPath();
    }
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('$directoryPath${Platform.pathSeparator}$_fileName');
  }

  String _resolveDefaultDirectoryPath() {
    final envConfigDir = Platform.environment['TUNNER_CONFIG_DIR'] ??
        Platform.environment['TUNNER_WORKSPACE_ROOT'];
    if (envConfigDir != null && envConfigDir.isNotEmpty) {
      return envConfigDir;
    }
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      return '$home${Platform.pathSeparator}Documents';
    }
    return Directory.systemTemp.path;
  }

  @override
  Future<AudioDeviceMatrixEntity> loadMatrix() async {
    final pending = _pendingSaveOperation;
    if (pending != null) {
      try {
        await pending;
      } catch (e, st) {
        _logger.warning(
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
      _logger.warning('StudioAudioHardwarePersistenceService', 'Error al cargar la matriz de hardware de audio: $e');
      return AudioDeviceMatrixEntity.defaultConfiguration();
    }
  }

  @override
  Future<void> saveMatrix(AudioDeviceMatrixEntity matrix) async {
    final completer = Completer<void>();
    _pendingSaveOperation = completer.future;

    try {
      final file = await _getTargetFile();
      final tempFile = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');

      final jsonString = jsonEncode(matrix.toJson());
      await tempFile.writeAsString(jsonString, flush: true);

      try {
        await tempFile.rename(file.path);
      } catch (e, st) {
        _logger.warning(
          'StudioAudioHardwarePersistenceService',
          'Renombrado atomico fallback a escritura directa: $e',
          error: e,
          stackTrace: st,
        );
        await file.writeAsString(jsonString, flush: true);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
      completer.complete();
    } catch (e) {
      _logger.warning('StudioAudioHardwarePersistenceService', 'Error al guardar la matriz de hardware de audio: $e');
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
      _logger.warning('StudioAudioHardwarePersistenceService', 'Error al limpiar la matriz de hardware de audio: $e');
    }
  }
}
