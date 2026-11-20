import 'dj_console_blueprint_entity.dart';

/// Puerto abstracto de dominio para la persistencia de planos de consolas DJ.
abstract class IDjConsoleBlueprintStorageService {
  Future<void> saveBlueprint(DjConsoleBlueprintEntity blueprint);
  Future<List<DjConsoleBlueprintEntity>> loadAllBlueprints();
  Future<DjConsoleBlueprintEntity?> loadBlueprintById(String id);
  Future<void> deleteBlueprint(String id);
}

/// Implementación No-Op en memoria para pruebas y ejecución desacoplada.
class NoOpDjConsoleBlueprintStorageService implements IDjConsoleBlueprintStorageService {
  const NoOpDjConsoleBlueprintStorageService();

  @override
  Future<void> saveBlueprint(DjConsoleBlueprintEntity blueprint) async {}

  @override
  Future<List<DjConsoleBlueprintEntity>> loadAllBlueprints() async => const [];

  @override
  Future<DjConsoleBlueprintEntity?> loadBlueprintById(String id) async => null;

  @override
  Future<void> deleteBlueprint(String id) async {}
}
