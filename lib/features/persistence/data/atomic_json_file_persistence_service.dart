import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/logging/domain/i_studio_logger.dart';
import '../domain/app_user_settings_entity.dart';
import '../domain/i_local_persistence_service.dart';

/// Implementacion Pure Dart para persistencia local offline atomica en archivos JSON.
///
/// Cumple con escritura atomica en `.tmp` + `rename`, cola secuencial sin busy-waiting
/// y resolucion de directorio inyectable (sin dependencias de `package:flutter/` ni `path_provider`).
class AtomicJsonFilePersistenceService implements ILocalPersistenceService {
  final Future<Directory> Function() _directoryProvider;
  final String _fileName;
  final IStudioLogger _logger;
  Future<void>? _pendingSaveOperation;

  AtomicJsonFilePersistenceService({
    Directory? directory,
    Future<Directory> Function()? directoryProvider,
    Future<String> Function()? directoryPathProvider,
    String fileName = 'tunner_settings.json',
    IStudioLogger logger = const NoOpStudioLogger(),
  })  : _directoryProvider = _resolveDirectoryProvider(
          directory: directory,
          directoryProvider: directoryProvider,
          directoryPathProvider: directoryPathProvider,
        ),
        _fileName = fileName,
        _logger = logger;

  static Future<Directory> Function() _resolveDirectoryProvider({
    Directory? directory,
    Future<Directory> Function()? directoryProvider,
    Future<String> Function()? directoryPathProvider,
  }) {
    if (directory != null) {
      return () async => directory;
    }
    if (directoryProvider != null) {
      return directoryProvider;
    }
    if (directoryPathProvider != null) {
      return () async => Directory(await directoryPathProvider());
    }
    return () async => Directory.systemTemp;
  }

  Future<File> _getTargetFile() async {
    final directory = await _directoryProvider();
    final normalizedPath = directory.path.endsWith('/') || directory.path.endsWith('\\')
        ? directory.path.substring(0, directory.path.length - 1)
        : directory.path;
    return File('$normalizedPath/$_fileName');
  }

  @override
  Future<AppUserSettingsEntity> loadSettings() async {
    final pending = _pendingSaveOperation;
    if (pending != null) {
      try {
        await pending;
      } catch (e, st) {
        _logger.warning(
          'AtomicJsonFilePersistenceService',
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
      _logger.warning(
        'AtomicJsonFilePersistenceService',
        'Advertencia en loadSettings',
        error: e,
        stackTrace: st,
      );
      return AppUserSettingsEntity.defaultSettings;
    }
  }

  @override
  Future<void> saveSettings(AppUserSettingsEntity settings) async {
    final previous = _pendingSaveOperation;
    final completer = Completer<void>();
    _pendingSaveOperation = completer.future;

    if (previous != null) {
      try {
        await previous;
      } catch (e, st) {
        _logger.warning(
          'AtomicJsonFilePersistenceService',
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

      // 2. Renombrado atomico seguro
      try {
        await tempFile.rename(targetFile.path);
      } catch (e, st) {
        _logger.warning(
          'AtomicJsonFilePersistenceService',
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
      _logger.error(
        'AtomicJsonFilePersistenceService',
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
              _logger.warning(
                'AtomicJsonFilePersistenceService',
                'Advertencia al eliminar temporal huerfano $entityName',
                error: e,
                stackTrace: st,
              );
            }
          }
        }
      }
    } catch (e, st) {
      _logger.warning(
        'AtomicJsonFilePersistenceService',
        'Advertencia al limpiar configuraciones',
        error: e,
        stackTrace: st,
      );
    }
  }
}
