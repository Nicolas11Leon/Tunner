import 'dart:typed_data';
import 'tunner_project_package.dart';
import 'tunner_tool_preset.dart';

/// Contrato abstracto de persistencia y gestión de archivos de proyectos y herramientas.
abstract class ProjectStorageRepository {
  /// Guarda un paquete de proyecto en disco con compresión binaria (.tunner).
  Future<void> saveProject(String filePath, TunnerProjectPackage project);

  /// Carga y descomprime un paquete de proyecto desde un archivo (.tunner).
  Future<TunnerProjectPackage> loadProject(String filePath);

  /// Carga un paquete de proyecto directamente desde bytes binarios en memoria.
  TunnerProjectPackage loadProjectFromBytes(Uint8List bytes);

  /// Serializa y comprime un proyecto a bytes en memoria.
  Uint8List encodeProjectToBytes(TunnerProjectPackage project);

  /// Guarda una herramienta modular individual en disco (.tnt).
  Future<void> saveToolPreset(String filePath, TunnerToolPreset tool);

  /// Carga y descomprime una herramienta desde disco (.tnt).
  Future<TunnerToolPreset> loadToolPreset(String filePath);

  /// Serializa una herramienta individual a bytes binarios en memoria.
  Uint8List encodeToolPresetToBytes(TunnerToolPreset tool);

  /// Deserializa una herramienta individual desde bytes binarios.
  TunnerToolPreset loadToolPresetFromBytes(Uint8List bytes);

  /// Lista las rutas de archivos de proyecto (`.tunner`) disponibles en un directorio.
  Future<List<String>> listProjects({String? directoryPath});
}

/// Implementación en memoria / no-op para inicializaciones seguras sin I/O físico.
class NoOpProjectStorageRepository implements ProjectStorageRepository {
  const NoOpProjectStorageRepository();

  @override
  Future<void> saveProject(String filePath, TunnerProjectPackage project) async {}

  @override
  Future<TunnerProjectPackage> loadProject(String filePath) async {
    return const TunnerProjectPackage(
      projectId: 'blank',
      projectName: 'Proyecto en Blanco',
      tools: [],
      createdAtMicros: 0,
      updatedAtMicros: 0,
    );
  }

  @override
  TunnerProjectPackage loadProjectFromBytes(Uint8List bytes) {
    return const TunnerProjectPackage(
      projectId: 'blank',
      projectName: 'Proyecto en Blanco',
      tools: [],
      createdAtMicros: 0,
      updatedAtMicros: 0,
    );
  }

  @override
  Uint8List encodeProjectToBytes(TunnerProjectPackage project) => Uint8List(0);

  @override
  Future<void> saveToolPreset(String filePath, TunnerToolPreset tool) async {}

  @override
  Future<TunnerToolPreset> loadToolPreset(String filePath) async {
    return const TunnerToolPreset(
      moduleTypeCode: 'strobeTuner',
      customTitle: 'Blank Preset',
      savedAtMicros: 0,
    );
  }

  @override
  Uint8List encodeToolPresetToBytes(TunnerToolPreset tool) => Uint8List(0);

  @override
  TunnerToolPreset loadToolPresetFromBytes(Uint8List bytes) {
    return const TunnerToolPreset(
      moduleTypeCode: 'strobeTuner',
      customTitle: 'Blank Preset',
      savedAtMicros: 0,
    );
  }

  @override
  Future<List<String>> listProjects({String? directoryPath}) async => const [];
}
