import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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
    } catch (e) {
      debugPrint("Advertencia en JsonLocalPersistenceService.loadSettings: $e");
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
      } catch (_) {}
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
      } catch (_) {
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }
        await targetFile.writeAsString(jsonString, flush: true);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      debugPrint("Error crítico al persistir configuraciones en JsonLocalPersistenceService: $e");
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
    } catch (e) {
      debugPrint("Advertencia al limpiar configuraciones en JsonLocalPersistenceService: $e");
    }
  }
}
