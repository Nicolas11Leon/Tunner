import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import '../domain/project_storage_repository.dart';
import '../domain/tunner_project_package.dart';
import '../domain/tunner_tool_preset.dart';
import 'tunner_binary_project_codec.dart';

/// Implementación del repositorio de almacenamiento local en el sistema de archivos del usuario.
/// Ejecuta la codificación y decodificación ZLib de archivos en segundo plano con [Isolate.run]
/// para no bloquear el hilo de UI.
class LocalProjectStorageRepository implements ProjectStorageRepository {
  final TunnerBinaryProjectCodec _codec;

  LocalProjectStorageRepository({TunnerBinaryProjectCodec? codec})
      : _codec = codec ?? TunnerBinaryProjectCodec();

  @override
  Uint8List encodeProjectToBytes(TunnerProjectPackage project) {
    return _codec.encodeProject(project);
  }

  @override
  TunnerProjectPackage loadProjectFromBytes(Uint8List bytes) {
    return _codec.decodeProject(bytes);
  }

  @override
  Uint8List encodeToolPresetToBytes(TunnerToolPreset tool) {
    return _codec.encodeToolPreset(tool);
  }

  @override
  TunnerToolPreset loadToolPresetFromBytes(Uint8List bytes) {
    return _codec.decodeToolPreset(bytes);
  }

  @override
  Future<void> saveProject(String filePath, TunnerProjectPackage project) async {
    final maxBytes = _codec.maxAllowedDecompressedBytes;
    final bytes = await Isolate.run(
      () => TunnerBinaryProjectCodec(maxAllowedDecompressedBytes: maxBytes)
          .encodeProject(project),
    );
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<TunnerProjectPackage> loadProject(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('El archivo de proyecto no existe', filePath);
    }
    final bytes = await file.readAsBytes();
    final maxBytes = _codec.maxAllowedDecompressedBytes;
    return Isolate.run(
      () => TunnerBinaryProjectCodec(maxAllowedDecompressedBytes: maxBytes)
          .decodeProject(bytes),
    );
  }

  @override
  Future<void> saveToolPreset(String filePath, TunnerToolPreset tool) async {
    final maxBytes = _codec.maxAllowedDecompressedBytes;
    final bytes = await Isolate.run(
      () => TunnerBinaryProjectCodec(maxAllowedDecompressedBytes: maxBytes)
          .encodeToolPreset(tool),
    );
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<TunnerToolPreset> loadToolPreset(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('El archivo de herramienta no existe', filePath);
    }
    final bytes = await file.readAsBytes();
    final maxBytes = _codec.maxAllowedDecompressedBytes;
    return Isolate.run(
      () => TunnerBinaryProjectCodec(maxAllowedDecompressedBytes: maxBytes)
          .decodeToolPreset(bytes),
    );
  }
}
