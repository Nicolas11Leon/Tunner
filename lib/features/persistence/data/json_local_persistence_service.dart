import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/logging/infrastructure/studio_debug_logger.dart';
import '../domain/app_user_settings_entity.dart';
import '../domain/i_local_persistence_service.dart';

/// Implementación de infraestructura para persistencia local offline atómica en archivos JSON.
/// Cumple estrictamente con el principio de robustez: escritura atómica en `.tmp` + `rename`,
/// sin busy-waiting y con inyección desacoplada de la ruta de almacenamiento para tests unitarios.
class JsonLocalPersistenceService implements ILocalPersistenceService {
  final Future<String> Function()? _documentsPathProvider;
  final String _fileName;

  JsonLocalPersistenceService({
    Future<String> Function()? documentsPathProvider,
    String fileName = 'tunner_settings.json',
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
        // Fallback seguro para entornos de prueba o terminales
        directoryPath = Directory.systemTemp.path;
      }
    }
    return File('$directoryPath/$_fileName');
  }

  @override
  Future<AppUserSettingsEntity> loadSettings() async {
    final pending = _pendingSaveOperation;
    if (pending != null) {
      try {
        await pending;
      } catch (e, st) {
        StudioDebugLogger.instance.warning(
          'JsonLocalPersistenceService',
          'Pending save failed prior to loadSettings',
          error: e,
          stackTrace: st,
        );
      }
    }

    try {
      final file = await _getTargetFile();
      if (!await file.exists()) {
        return AppUserSettingsEntity.defaultSettings;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return AppUserSettingsEntity.defaultSettings;
      }

      final jsonMap = jsonDecode(content) as Map<String, dynamic>;
      return AppUserSettingsEntity.fromMap(jsonMap);
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'JsonLocalPersistenceService',
        'Advertencia en loadSettings',
        error: e,
        stackTrace: st,
      );
      return AppUserSettingsEntity.defaultSettings;
    }
  }

  Future<void>? _pendingSaveOperation;

  @override
  Future<void> saveSettings(AppUserSettingsEntity settings) async {
    final previous = _pendingSaveOperation;
    final completer = Completer<void>();
    _pendingSaveOperation = completer.future;

    if (previous != null) {
      try {
        await previous;
      } catch (e, st) {
        StudioDebugLogger.instance.warning(
          'JsonLocalPersistenceService',
          'Previous save failed prior to saveSettings',
          error: e,
          stackTrace: st,
        );
      }
    }

    try {
      final targetFile = await _getTargetFile();
      final parentDir = targetFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      final jsonString = jsonEncode(settings.toMap());
      final tempFile = File('${targetFile.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');

      // 1. Escritura en archivo temporal con flush asegurado
      await tempFile.writeAsString(jsonString, flush: true);

      // 2. Renombrado atómico seguro
      try {
        await tempFile.rename(targetFile.path);
      } catch (e, st) {
        StudioDebugLogger.instance.warning(
          'JsonLocalPersistenceService',
          'Renombrado atomico fallback a escritura directa: $e',
          error: e,
          stackTrace: st,
        );
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }
        await targetFile.writeAsString(jsonString, flush: true);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e, st) {
      StudioDebugLogger.instance.error(
        'JsonLocalPersistenceService',
        'Error critico al persistir configuraciones',
        error: e,
        stackTrace: st,
      );
    } finally {
      completer.complete();
    }
  }

  @override
  Future<void> clearSettings() async {
    try {
      final targetFile = await _getTargetFile();
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      final tempFile = File('${targetFile.path}.tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      final parentDir = targetFile.parent;
      if (await parentDir.exists()) {
        final targetBaseName =
            targetFile.path.replaceAll('\\', '/').split('/').last;
        final orphanPrefix = '$targetBaseName.';
        await for (final entity in parentDir.list(followLinks: false)) {
          if (entity is! File) continue;
          final entityName =
              entity.path.replaceAll('\\', '/').split('/').last;
          if (entityName.startsWith(orphanPrefix) &&
              entityName.endsWith('.tmp')) {
            try {
              await entity.delete();
            } catch (e, st) {
              StudioDebugLogger.instance.warning(
                'JsonLocalPersistenceService',
                'Advertencia al eliminar temporal huerfano $entityName',
                error: e,
                stackTrace: st,
              );
            }
          }
        }
      }
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'JsonLocalPersistenceService',
        'Advertencia al limpiar configuraciones',
        error: e,
        stackTrace: st,
      );
    }
  }
}
