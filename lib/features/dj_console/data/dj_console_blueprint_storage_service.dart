import '../domain/dj_console_blueprint_entity.dart';
import 'dj_console_file_codec.dart';
import 'dj_hardware_catalog.dart';

/// Servicio de persistencia y registro de consolas emuladas creadas por el usuario.
///
/// Opera offline-first con almacenamiento en memoria y serialización canónica.
class DjConsoleBlueprintStorageService {
  final DjConsoleFileCodec _codec;

  // Cache de planos de consolas
  final Map<String, String> _storageMap = {};
  final List<DjConsoleBlueprintEntity> _inMemoryBlueprints = [];

  DjConsoleBlueprintStorageService({
    Map<String, String>? initialStorage,
    DjConsoleFileCodec codec = const DjConsoleFileCodec(),
  }) : _codec = codec {
    if (initialStorage != null) {
      _storageMap.addAll(initialStorage);
    }
  }

  /// Inicializa y carga todas las consolas guardadas en el catálogo de hardware.
  Future<List<DjConsoleBlueprintEntity>> loadCustomBlueprints() async {
    _inMemoryBlueprints.clear();
    for (final jsonStr in _storageMap.values) {
      try {
        final blueprint = _codec.decodeFromJsonString(jsonStr);
        _inMemoryBlueprints.add(blueprint);
        DjHardwareCatalog.registerCustomSkin(blueprint.toHardwareSkin());
      } catch (_) {
        // Ignorar archivo corrupto sin bloquear el sistema
      }
    }

    return List.unmodifiable(_inMemoryBlueprints);
  }

  /// Guarda una nueva consola o actualiza una existente.
  Future<void> saveBlueprint(DjConsoleBlueprintEntity blueprint) async {
    _inMemoryBlueprints.removeWhere((b) => b.id == blueprint.id);
    _inMemoryBlueprints.add(blueprint);

    DjHardwareCatalog.registerCustomSkin(blueprint.toHardwareSkin());
    _storageMap[blueprint.id] = _codec.encodeToJsonString(blueprint);
  }

  /// Elimina una consola personalizada.
  Future<void> deleteBlueprint(String id) async {
    _inMemoryBlueprints.removeWhere((b) => b.id == id);
    DjHardwareCatalog.unregisterCustomSkin(id);
    _storageMap.remove(id);
  }

  List<DjConsoleBlueprintEntity> get currentBlueprints => List.unmodifiable(_inMemoryBlueprints);
}
