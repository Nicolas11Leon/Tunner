import 'app_user_settings_entity.dart';

/// Contrato abstracto del dominio para la persistencia no volátil offline de Tunner.
/// Totalmente agnóstico de Flutter UI o dependencias de plataforma.
abstract class ILocalPersistenceService {
  /// Carga asíncronamente las configuraciones y el historial persistido.
  /// Si no existe un archivo previo o se encuentra corrupto, retorna [AppUserSettingsEntity.defaultSettings].
  Future<AppUserSettingsEntity> loadSettings();

  /// Persiste atómicamente el estado consolidado de la aplicación en almacenamiento local no volátil.
  Future<void> saveSettings(AppUserSettingsEntity settings);

  /// Elimina los datos persistidos y restablece las configuraciones por defecto.
  Future<void> clearSettings();
}

/// Implementación en memoria para pruebas aisladas sin escritura en disco.
class InMemoryLocalPersistenceService implements ILocalPersistenceService {
  AppUserSettingsEntity _settings = AppUserSettingsEntity.defaultSettings;

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
