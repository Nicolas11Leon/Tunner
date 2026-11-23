import 'dart:convert';
import 'dart:io';

import '../../../core/logging/domain/i_studio_logger.dart';
import '../domain/dj_keymap_profile_entity.dart';
import '../domain/i_dj_keymap_persistence_service.dart';

export '../domain/i_dj_keymap_persistence_service.dart';

/// Implementacion Pure Dart para persistencia y restauracion de keymaps DJ.
///
/// Opera offline-first con cache en memoria y almacenamiento local en disco `dart:io`,
/// sin dependencias de `package:flutter/` ni `path_provider`.
class HeadlessDjKeymapPersistenceService implements IDjKeymapPersistenceService {
  final Future<String?> Function()? _documentsPathProvider;
  final String _fileName;
  final IStudioLogger _logger;
  String? _cachedJson;

  HeadlessDjKeymapPersistenceService({
    Directory? rootDirectory,
    Future<String?> Function()? documentsPathProvider,
    String fileName = 'tunner_dj_keymap.json',
    String? initialJson,
    IStudioLogger logger = const NoOpStudioLogger(),
  })  : _documentsPathProvider = rootDirectory != null
            ? (() async => rootDirectory.path)
            : documentsPathProvider,
        _fileName = fileName,
        _cachedJson = initialJson,
        _logger = logger;

  Future<File?> _getTargetFile() async {
    final provider = _documentsPathProvider;
    if (provider == null) return null;
    try {
      final dir = await provider();
      if (dir == null || dir.trim().isEmpty) return null;
      final normalized = dir.endsWith('/') || dir.endsWith('\\')
          ? dir.substring(0, dir.length - 1)
          : dir;
      return File('$normalized/$_fileName');
    } catch (e, st) {
      _logger.warning(
        'HeadlessDjKeymapPersistenceService',
        'Error resolviendo ruta personalizada: $e',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Loads the active keymap profile. If none saved, returns the default ergonomic profile.
  @override
  Future<DjKeymapProfileEntity> loadActiveProfile() async {
    if (_cachedJson == null || _cachedJson!.trim().isEmpty) {
      final file = await _getTargetFile();
      if (file != null && await file.exists()) {
        try {
          _cachedJson = await file.readAsString();
        } catch (e, st) {
          _logger.warning(
            'HeadlessDjKeymapPersistenceService',
            'Error leyendo archivo keymap: $e',
            error: e,
            stackTrace: st,
          );
        }
      }
    }
    if (_cachedJson == null || _cachedJson!.trim().isEmpty) {
      return DjKeymapProfileEntity.defaultErgonomic();
    }
    try {
      final map = jsonDecode(_cachedJson!) as Map<String, dynamic>;
      return DjKeymapProfileEntity.fromJson(map);
    } catch (e, st) {
      _logger.warning(
        'HeadlessDjKeymapPersistenceService',
        'Error decodificando json keymap: $e',
        error: e,
        stackTrace: st,
      );
      return DjKeymapProfileEntity.defaultErgonomic();
    }
  }

  /// Persists a custom keymap profile.
  @override
  Future<void> saveActiveProfile(DjKeymapProfileEntity profile) =>
      saveProfile(profile);

  @override
  Future<void> saveProfile(DjKeymapProfileEntity profile) async {
    _cachedJson = jsonEncode(profile.toJson());
    final file = await _getTargetFile();
    if (file != null) {
      try {
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsString(_cachedJson!, flush: true);
      } catch (e, st) {
        _logger.warning(
          'HeadlessDjKeymapPersistenceService',
          'Error guardando keymap en disco: $e',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  /// Resets to default ergonomic profile.
  @override
  Future<void> resetToDefaultProfile() => resetToDefault();

  @override
  Future<void> resetToDefault() async {
    _cachedJson = null;
    final file = await _getTargetFile();
    if (file != null && await file.exists()) {
      try {
        await file.delete();
      } catch (e, st) {
        _logger.warning(
          'HeadlessDjKeymapPersistenceService',
          'Error eliminando keymap: $e',
          error: e,
          stackTrace: st,
        );
      }
    }
  }
}
