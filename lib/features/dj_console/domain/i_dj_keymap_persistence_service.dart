import 'dj_keymap_profile_entity.dart';

/// Contrato abstracto de dominio para la persistencia de perfiles de mapeo de teclado DJ.
abstract class IDjKeymapPersistenceService {
  Future<DjKeymapProfileEntity> loadActiveProfile();
  Future<void> saveProfile(DjKeymapProfileEntity profile);
  Future<void> saveActiveProfile(DjKeymapProfileEntity profile);
  Future<void> resetToDefault();
  Future<void> resetToDefaultProfile();
}

/// Implementación en memoria / no-op para inicializaciones sin dependencias de I/O.
class NoOpDjKeymapPersistenceService implements IDjKeymapPersistenceService {
  const NoOpDjKeymapPersistenceService();

  @override
  Future<DjKeymapProfileEntity> loadActiveProfile() async =>
      DjKeymapProfileEntity.defaultErgonomic();

  @override
  Future<void> saveProfile(DjKeymapProfileEntity profile) async {}

  @override
  Future<void> saveActiveProfile(DjKeymapProfileEntity profile) async {}

  @override
  Future<void> resetToDefault() async {}

  @override
  Future<void> resetToDefaultProfile() async {}
}
