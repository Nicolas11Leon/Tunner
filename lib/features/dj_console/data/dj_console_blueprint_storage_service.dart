import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/logging/infrastructure/studio_debug_logger.dart';
import '../domain/dj_console_blueprint_entity.dart';
import '../domain/i_dj_console_blueprint_storage_service.dart';
import 'dj_console_file_codec.dart';
import '../domain/dj_hardware_catalog.dart';

export '../domain/i_dj_console_blueprint_storage_service.dart';

/// Servicio de persistencia y registro de consolas emuladas creadas por el usuario.
///
/// Opera offline-first con almacenamiento persistente en disco y cache en memoria.
class DjConsoleBlueprintStorageService implements IDjConsoleBlueprintStorageService {
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
      } catch (e) {
        StudioDebugLogger.instance.warning('DjConsoleBlueprintStorageService', 'Error resolviendo ruta provista: $e');
        return null;
      }
    }
    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        return File('${dir.path}/$_fileName');
      } catch (e) {
        StudioDebugLogger.instance.warning('DjConsoleBlueprintStorageService', 'Error resolviendo directorio de documentos: $e');
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
      } catch (e) {
        StudioDebugLogger.instance.warning('DjConsoleBlueprintStorageService', 'Error persistiendo planos a disco: $e');
      }
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
        } catch (e) {
          StudioDebugLogger.instance.warning('DjConsoleBlueprintStorageService', 'Error leyendo planos desde disco: $e');
        }
      }
    }

    _inMemoryBlueprints.clear();
    for (final jsonStr in _storageMap.values) {
      try {
        final blueprint = _codec.decodeFromJsonString(jsonStr);
        _inMemoryBlueprints.add(blueprint);
        DjHardwareCatalog.registerCustomSkin(blueprint.toHardwareSkin());
      } catch (e) {
        StudioDebugLogger.instance.warning('DjConsoleBlueprintStorageService', 'Ignorando plano corrupto: $e');
      }
    }

    return List.unmodifiable(_inMemoryBlueprints);
  }

  @override
  Future<List<DjConsoleBlueprintEntity>> loadAllBlueprints() => loadCustomBlueprints();

  @override
  Future<DjConsoleBlueprintEntity?> loadBlueprintById(String id) async {
    final all = await loadAllBlueprints();
    return all.where((b) => b.id == id).firstOrNull;
  }

  /// Guarda una nueva consola o actualiza una existente.
  @override
  Future<void> saveBlueprint(DjConsoleBlueprintEntity blueprint) async {
    _inMemoryBlueprints.removeWhere((b) => b.id == blueprint.id);
    _inMemoryBlueprints.add(blueprint);

    DjHardwareCatalog.registerCustomSkin(blueprint.toHardwareSkin());
    _storageMap[blueprint.id] = _codec.encodeToJsonString(blueprint);
    await _persistToDisk();
  }

  /// Elimina una consola personalizada.
  @override
  Future<void> deleteBlueprint(String id) async {
    _inMemoryBlueprints.removeWhere((b) => b.id == id);
    DjHardwareCatalog.unregisterCustomSkin(id);
    _storageMap.remove(id);
    await _persistToDisk();
  }

  List<DjConsoleBlueprintEntity> get currentBlueprints => List.unmodifiable(_inMemoryBlueprints);
}
