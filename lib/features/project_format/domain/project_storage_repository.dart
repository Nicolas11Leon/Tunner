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
}
