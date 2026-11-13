import 'dart:convert';
import '../domain/dj_keymap_profile_entity.dart';

/// Service responsible for persisting and restoring custom DJ keymaps.
///
/// Operates offline-first with in-memory caching and JSON serialization.
class DjKeymapPersistenceService {
  String? _cachedJson;

  DjKeymapPersistenceService({String? initialJson}) : _cachedJson = initialJson;

  /// Loads the active keymap profile. If none saved, returns the default ergonomic profile.
  Future<DjKeymapProfileEntity> loadActiveProfile() async {
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
  }

  /// Resets to default ergonomic profile.
  Future<void> resetToDefault() async {
    _cachedJson = null;
  }
}
