import '../domain/app_user_settings_entity.dart';
import '../domain/i_local_persistence_service.dart';

/// Implementación en memoria de [ILocalPersistenceService] diseñada específicamente
/// para tests unitarios deterministas y entornos sin acceso al sistema de archivos POSIX.
class MemoryPersistenceService implements ILocalPersistenceService {
  AppUserSettingsEntity _settings;

  MemoryPersistenceService([AppUserSettingsEntity? initialSettings])
      : _settings = initialSettings ?? AppUserSettingsEntity.defaultSettings;

  @override
  Future<AppUserSettingsEntity> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppUserSettingsEntity settings) async {
    _settings = settings;
  }

  @override
  Future<void> clearSettings() async {
    _settings = AppUserSettingsEntity.defaultSettings;
  }
}
