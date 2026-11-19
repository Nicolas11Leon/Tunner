import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/dj_console_blueprint_entity.dart';
import 'dj_console_file_codec.dart';
import 'dj_hardware_catalog.dart';

/// Servicio de persistencia y registro de consolas emuladas creadas por el usuario.
///
/// Opera offline-first con almacenamiento persistente en disco y cache en memoria.
class DjConsoleBlueprintStorageService {
  final DjConsoleFileCodec _codec;
  final Future<String> Function()? _documentsPathProvider;
  final String _fileName;

  // Cache de planos de consolas
  final Map<String, String> _storageMap = {};
  final List<DjConsoleBlueprintEntity> _inMemoryBlueprints = [];

  DjConsoleBlueprintStorageService({
    Map<String, String>? initialStorage,
    DjConsoleFileCodec codec = const DjConsoleFileCodec(),
    Future<String> Function()? documentsPathProvider,
    String fileName = 'tunner_dj_blueprints.json',
  })  : _codec = codec,
        _documentsPathProvider = documentsPathProvider,
        _fileName = fileName {
    if (initialStorage != null) {
      _storageMap.addAll(initialStorage);
    }
  }

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

  Future<void> _persistToDisk() async {
    final file = await _getTargetFile();
    if (file != null) {
      try {
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsString(jsonEncode(_storageMap), flush: true);
      } catch (_) {}
    }
  }

  /// Inicializa y carga todas las consolas guardadas en el catálogo de hardware.
  Future<List<DjConsoleBlueprintEntity>> loadCustomBlueprints() async {
    if (_storageMap.isEmpty) {
      final file = await _getTargetFile();
      if (file != null && await file.exists()) {
        try {
          final content = await file.readAsString();
          final diskMap = jsonDecode(content) as Map<String, dynamic>;
          for (final entry in diskMap.entries) {
            _storageMap[entry.key] = entry.value.toString();
          }
        } catch (_) {}
      }
    }

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
    await _persistToDisk();
  }

  /// Elimina una consola personalizada.
  Future<void> deleteBlueprint(String id) async {
    _inMemoryBlueprints.removeWhere((b) => b.id == id);
    DjHardwareCatalog.unregisterCustomSkin(id);
    _storageMap.remove(id);
    await _persistToDisk();
  }

  List<DjConsoleBlueprintEntity> get currentBlueprints => List.unmodifiable(_inMemoryBlueprints);
}
