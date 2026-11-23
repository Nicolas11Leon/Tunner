import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import '../domain/project_storage_repository.dart';
import '../domain/tunner_project_package.dart';
import '../domain/tunner_tool_preset.dart';
import 'tunner_binary_project_codec.dart';

/// Implementación del repositorio de almacenamiento local en el sistema de archivos del usuario.
/// Ejecuta la codificación y decodificación ZLib de archivos en segundo plano con [Isolate.run]
/// para no bloquear el hilo de UI, e incluye validación estricta anti Path Traversal
/// cuando se configura un [baseDirectoryPath].
class LocalProjectStorageRepository implements ProjectStorageRepository {
  final TunnerBinaryProjectCodec _codec;
  final String? baseDirectoryPath;

  LocalProjectStorageRepository({
    TunnerBinaryProjectCodec? codec,
    this.baseDirectoryPath,
  }) : _codec = codec ?? TunnerBinaryProjectCodec();

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
    final safePath = _resolveAndValidatePath(filePath);
    final maxBytes = _codec.maxAllowedDecompressedBytes;
    final bytes = await Isolate.run(
      () => TunnerBinaryProjectCodec(maxAllowedDecompressedBytes: maxBytes)
          .encodeProject(project),
    );
    final file = File(safePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<TunnerProjectPackage> loadProject(String filePath) async {
    final safePath = _resolveAndValidatePath(filePath);
    final file = File(safePath);
    if (!await file.exists()) {
      throw FileSystemException('El archivo de proyecto no existe', safePath);
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
    final safePath = _resolveAndValidatePath(filePath);
    final maxBytes = _codec.maxAllowedDecompressedBytes;
    final bytes = await Isolate.run(
      () => TunnerBinaryProjectCodec(maxAllowedDecompressedBytes: maxBytes)
          .encodeToolPreset(tool),
    );
    final file = File(safePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<TunnerToolPreset> loadToolPreset(String filePath) async {
    final safePath = _resolveAndValidatePath(filePath);
    final file = File(safePath);
    if (!await file.exists()) {
      throw FileSystemException('El archivo de herramienta no existe', safePath);
    }
    final bytes = await file.readAsBytes();
    final maxBytes = _codec.maxAllowedDecompressedBytes;
    return Isolate.run(
      () => TunnerBinaryProjectCodec(maxAllowedDecompressedBytes: maxBytes)
          .decodeToolPreset(bytes),
    );
  }

  @override
  Future<List<String>> listProjects({String? directoryPath}) async {
    final targetDirPath = directoryPath ?? baseDirectoryPath;
    if (targetDirPath == null || targetDirPath.trim().isEmpty) {
      return const [];
    }

    final safeDirPath = _resolveAndValidatePath(targetDirPath, allowExactBase: true);
    final dir = Directory(safeDirPath);
    if (!await dir.exists()) {
      return const [];
    }

    final projectPaths = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.tunner')) {
        projectPaths.add(entity.path);
      }
    }
    projectPaths.sort();
    return projectPaths;
  }

  /// Valida que [rawPath] no contenga caracteres nulos ni escape fuera de [baseDirectoryPath]
  /// mediante secuencias `..`, rutas absolutas externas o enlaces simbólicos.
  String _resolveAndValidatePath(String rawPath, {bool allowExactBase = false}) {
    if (rawPath.trim().isEmpty || rawPath.contains('\u0000')) {
      throw FileSystemException('Ruta de archivo inválida', rawPath);
    }

    final base = baseDirectoryPath;
    if (base == null || base.trim().isEmpty) {
      return rawPath;
    }

    final canonicalBase = _canonicalizePath(base);
    final isRelative = !_isAbsolutePath(rawPath);
    final candidatePath = isRelative
        ? '$canonicalBase${Platform.pathSeparator}$rawPath'
        : rawPath;
    final canonicalTarget = _canonicalizePath(candidatePath);

    final isExactBase = canonicalTarget == canonicalBase;
    final baseWithSep = canonicalBase.endsWith(Platform.pathSeparator)
        ? canonicalBase
        : '$canonicalBase${Platform.pathSeparator}';
    final isInsideBase = canonicalTarget.startsWith(baseWithSep);

    if (!(isInsideBase || (allowExactBase && isExactBase))) {
      throw FileSystemException(
        'Acceso denegado: ruta fuera del directorio base permitido (Path Traversal)',
        rawPath,
      );
    }

    return canonicalTarget;
  }

  static bool _isAbsolutePath(String path) {
    if (path.startsWith('/') || path.startsWith(r'\')) return true;
    // Windows drive letter (ej. C:\...)
    if (path.length >= 2 && path[1] == ':') return true;
    return false;
  }

  /// Canoniza una ruta resolviendo segmentos `.` / `..` y enlaces simbólicos del ancestro más cercano existente.
  static String _canonicalizePath(String inputPath) {
    final normalized = _normalizeLexicalPath(File(inputPath).absolute.path);
    final entityType = FileSystemEntity.typeSync(normalized, followLinks: false);
    if (entityType != FileSystemEntityType.notFound) {
      try {
        return File(normalized).resolveSymbolicLinksSync();
      } catch (_) {
        return normalized;
      }
    }

    // Si el archivo aún no existe, resolver enlaces simbólicos del directorio ancestro existente
    final pendingSegments = <String>[];
    String current = normalized;
    while (true) {
      final parent = Directory(current).parent.path;
      final baseName = current.substring(current.lastIndexOf(Platform.pathSeparator) + 1);
      if (baseName.isNotEmpty) {
        pendingSegments.add(baseName);
      }
      if (parent == current) {
        break;
      }
      current = parent;
      if (FileSystemEntity.typeSync(current, followLinks: false) !=
          FileSystemEntityType.notFound) {
        try {
          current = Directory(current).resolveSymbolicLinksSync();
        } catch (_) {
          // Mantener ruta léxica si no se puede resolver symlink
        }
        break;
      }
    }

    final rebuilt = pendingSegments.isEmpty
        ? current
        : '$current${current.endsWith(Platform.pathSeparator) ? '' : Platform.pathSeparator}${pendingSegments.reversed.join(Platform.pathSeparator)}';
    return _normalizeLexicalPath(rebuilt);
  }

  static String _normalizeLexicalPath(String rawPath) {
    final sep = Platform.pathSeparator;
    final unified = rawPath.replaceAll('/', sep).replaceAll(r'\', sep);
    final isPosixAbsolute = unified.startsWith(sep);
    final segments = unified.split(sep);
    final stack = <String>[];

    for (final seg in segments) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (stack.isNotEmpty && stack.last != '..') {
          stack.removeLast();
        } else if (!isPosixAbsolute) {
          stack.add('..');
        }
      } else {
        stack.add(seg);
      }
    }

    if (isPosixAbsolute) {
      return '$sep${stack.join(sep)}';
    }
    return stack.join(sep);
  }
}
