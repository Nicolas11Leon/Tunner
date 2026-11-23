import 'dart:convert';
import 'dart:io';

import '../../../core/logging/domain/i_studio_logger.dart';
import '../domain/dj_console_blueprint_entity.dart';
import '../domain/dj_hardware_catalog.dart';
import '../domain/i_dj_console_blueprint_storage_service.dart';
import 'dj_console_file_codec.dart';

export '../domain/i_dj_console_blueprint_storage_service.dart';

/// Implementacion Pure Dart de persistencia de planos de consolas DJ.
///
/// Opera offline-first sobre `dart:io` con directorio raiz inyectable y cache en memoria,
/// sin dependencias de `package:flutter/` ni `path_provider`.
class HeadlessDjConsoleBlueprintStorageService
    implements IDjConsoleBlueprintStorageService {
  final DjConsoleFileCodec _codec;
  final Future<String?> Function()? _documentsPathProvider;
  final String _fileName;
  final IStudioLogger _logger;

  // Cache de planos de consolas
  final Map<String, String> _storageMap = {};
  final List<DjConsoleBlueprintEntity> _inMemoryBlueprints = [];

  HeadlessDjConsoleBlueprintStorageService({
    Map<String, String>? initialStorage,
    DjConsoleFileCodec codec = const DjConsoleFileCodec(),
    Directory? rootDirectory,
    Future<String?> Function()? documentsPathProvider,
    String fileName = 'tunner_dj_blueprints.json',
    IStudioLogger logger = const NoOpStudioLogger(),
  })  : _codec = codec,
        _documentsPathProvider = rootDirectory != null
            ? (() async => rootDirectory.path)
            : documentsPathProvider,
        _fileName = fileName,
        _logger = logger {
    if (initialStorage != null) {
      _storageMap.addAll(initialStorage);
    }
  }

  Future<File?> _getTargetFile() async {
    final provider = _documentsPathProvider;
    if (provider == null) return null;
    try {
      final dir = await provider();
      if (dir == null || dir.trim().isEmpty) return null;
      final normalized = dir.endsWith('/') || dir.endsWith('\\')
          ? dir.substring(0, dir.length - 1)
          : dir;
      return File('$normalized/$_fileName');
    } catch (e, st) {
      _logger.warning(
        'HeadlessDjConsoleBlueprintStorageService',
        'Error resolviendo ruta provista: $e',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> _persistToDisk() async {
    final file = await _getTargetFile();
    if (file != null) {
      try {
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsString(jsonEncode(_storageMap), flush: true);
      } catch (e, st) {
        _logger.warning(
          'HeadlessDjConsoleBlueprintStorageService',
          'Error persistiendo planos a disco: $e',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  /// Inicializa y carga todas las consolas guardadas en el catalogo de hardware.
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
        } catch (e, st) {
          _logger.warning(
            'HeadlessDjConsoleBlueprintStorageService',
            'Error leyendo planos desde disco: $e',
            error: e,
            stackTrace: st,
          );
        }
      }
    }

    _inMemoryBlueprints.clear();
    for (final jsonStr in _storageMap.values) {
      try {
        final blueprint = _codec.decodeFromJsonString(jsonStr);
        _inMemoryBlueprints.add(blueprint);
        DjHardwareCatalog.registerCustomSkin(blueprint.toHardwareSkin());
      } catch (e, st) {
        _logger.warning(
          'HeadlessDjConsoleBlueprintStorageService',
          'Ignorando plano corrupto: $e',
          error: e,
          stackTrace: st,
        );
      }
    }

    return List.unmodifiable(_inMemoryBlueprints);
  }

  @override
  Future<List<DjConsoleBlueprintEntity>> loadAllBlueprints() =>
      loadCustomBlueprints();

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

  List<DjConsoleBlueprintEntity> get currentBlueprints =>
      List.unmodifiable(_inMemoryBlueprints);
}
