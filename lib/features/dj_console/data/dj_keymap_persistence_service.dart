import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/dj_keymap_profile_entity.dart';

/// Service responsible for persisting and restoring custom DJ keymaps.
///
/// Operates offline-first with in-memory caching and persistent local disk storage.
class DjKeymapPersistenceService {
  final Future<String> Function()? _documentsPathProvider;
  final String _fileName;
  String? _cachedJson;

  DjKeymapPersistenceService({
    Future<String> Function()? documentsPathProvider,
    String fileName = 'tunner_dj_keymap.json',
    String? initialJson,
  })  : _documentsPathProvider = documentsPathProvider,
        _fileName = fileName,
        _cachedJson = initialJson;

  Future<File?> _getTargetFile() async {
    if (_documentsPathProvider != null) {
      try {
        final dir = await _documentsPathProvider();
        return File('$dir/$_fileName');
      } catch (_) {
        return null;
      }
    }
    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        return File('${dir.path}/$_fileName');
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Loads the active keymap profile. If none saved, returns the default ergonomic profile.
  Future<DjKeymapProfileEntity> loadActiveProfile() async {
    if (_cachedJson == null || _cachedJson!.trim().isEmpty) {
      final file = await _getTargetFile();
      if (file != null && await file.exists()) {
        try {
          _cachedJson = await file.readAsString();
        } catch (_) {}
      }
    }
    if (_cachedJson == null || _cachedJson!.trim().isEmpty) {
      return DjKeymapProfileEntity.defaultErgonomic();
    }
    try {
      final map = jsonDecode(_cachedJson!) as Map<String, dynamic>;
      return DjKeymapProfileEntity.fromJson(map);
    } catch (_) {
      return DjKeymapProfileEntity.defaultErgonomic();
    }
  }

  /// Persists a custom keymap profile.
  Future<void> saveProfile(DjKeymapProfileEntity profile) async {
    _cachedJson = jsonEncode(profile.toJson());
    final file = await _getTargetFile();
    if (file != null) {
      try {
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsString(_cachedJson!, flush: true);
      } catch (_) {}
    }
  }

  /// Resets to default ergonomic profile.
  Future<void> resetToDefault() async {
    _cachedJson = null;
    final file = await _getTargetFile();
    if (file != null && await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}
