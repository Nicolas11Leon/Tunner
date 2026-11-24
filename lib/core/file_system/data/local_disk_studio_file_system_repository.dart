import 'dart:io';
import 'dart:typed_data';
import '../../logging/domain/i_studio_logger.dart';
import '../domain/i_workspace_seed_provider.dart';
import '../domain/studio_file_system_node.dart';
import '../domain/studio_file_system_repository.dart';
import '../domain/studio_file_type.dart';

/// Implementación de producción para la persistencia real del sistema de archivos en disco (`dart:io`).
/// Permite almacenar, escanear, leer, escribir, mover y renombrar físicamente archivos
/// y carpetas en el almacenamiento local del usuario (`~/Documents/TunnerProjects`).
class LocalDiskStudioFileSystemRepository implements StudioFileSystemRepository {
  final String? _customRootPath;
  final Future<Directory> Function()? _rootDirectoryProvider;
  final Future<String> Function()? _rootPathProvider;
  final IWorkspaceSeedProvider? _seedProvider;
  final IStudioLogger _logger;
  String? _resolvedRootPath;

  LocalDiskStudioFileSystemRepository({
    String? customRootPath,
    Future<Directory> Function()? rootDirectoryProvider,
    Future<String> Function()? rootPathProvider,
    IWorkspaceSeedProvider? seedProvider,
    IStudioLogger logger = const NoOpStudioLogger(),
  })  : _customRootPath = customRootPath,
        _rootDirectoryProvider = rootDirectoryProvider,
        _rootPathProvider = rootPathProvider,
        _seedProvider = seedProvider,
        _logger = logger;

  /// Obtiene la ruta física absoluta de la carpeta raíz del espacio de trabajo.
  Future<String> getRootPath() async {
    if (_resolvedRootPath != null) return _resolvedRootPath!;
    if (_customRootPath != null && _customRootPath.isNotEmpty) {
      _resolvedRootPath = _customRootPath;
      return _resolvedRootPath!;
    }

    if (_rootPathProvider != null) {
      final providedPath = await _rootPathProvider();
      if (providedPath.isNotEmpty) {
        _resolvedRootPath = providedPath;
        return _resolvedRootPath!;
      }
    }

    if (_rootDirectoryProvider != null) {
      try {
        final providedDir = await _rootDirectoryProvider();
        _resolvedRootPath = providedDir.path;
        return _resolvedRootPath!;
      } catch (e, st) {
        _logger.warning(
          'LocalDiskStudioFileSystemRepository',
          'Fallback a directorio por defecto por error en rootDirectoryProvider: $e',
          error: e,
          stackTrace: st,
        );
      }
    }

    // Entorno de prueba unitaria
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final tempDir = Directory.systemTemp.createTempSync('tunner_workspace_');
      _resolvedRootPath = tempDir.path;
      return _resolvedRootPath!;
    }

    final envRoot = Platform.environment['TUNNER_WORKSPACE_ROOT'];
    if (envRoot != null && envRoot.isNotEmpty) {
      _resolvedRootPath = envRoot;
      return _resolvedRootPath!;
    }

    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      _resolvedRootPath = '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}TunnerProjects';
      return _resolvedRootPath!;
    }

    final fallbackDir = Directory.systemTemp.createTempSync('tunner_projects_fallback_');
    _resolvedRootPath = fallbackDir.path;
    return _resolvedRootPath!;
  }

  /// Limpia la ruta relativa eliminando barras iniciales duplicadas y previene path traversal.
  String _normalizeRelativePath(String relPath) {
    final normalized = relPath.replaceAll('\\', '/');
    if (RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
      throw ArgumentError('Ruta absoluta con letra de unidad no permitida: $relPath');
    }
    var clean = normalized;
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    final rawSegments = clean.split('/');
    final cleanSegments = <String>[];
    for (final seg in rawSegments) {
      if (seg == '..' || seg == '.' || seg.contains('\x00')) {
        throw ArgumentError('Secuencia de Path Traversal no permitida: $relPath');
      }
      if (seg.isNotEmpty) {
        cleanSegments.add(seg);
      }
    }
    return cleanSegments.join('/');
  }

  /// Resuelve y verifica que [relPath] permanezca estrictamente confinado dentro de [rootPath]
  /// incluso tras resolver enlaces simbólicos.
  String _resolveSafePath(String relPath, String rootPath, {bool allowRoot = false}) {
    final normRoot = rootPath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    final normInput = relPath.replaceAll('\\', '/');
    String relCandidate = normInput;
    if (normInput == normRoot) {
      relCandidate = '';
    } else if (normInput.startsWith('$normRoot/')) {
      relCandidate = normInput.substring(normRoot.length + 1);
    }

    final cleanRel = _normalizeRelativePath(relCandidate);
    if (!allowRoot && cleanRel.isEmpty) {
      throw ArgumentError('No se permite operar directamente sobre la raiz del espacio de trabajo');
    }

    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }
    final canonicalRoot = rootDir.resolveSymbolicLinksSync();
    final targetPath = cleanRel.isEmpty
        ? canonicalRoot
        : '$canonicalRoot${Platform.pathSeparator}${cleanRel.replaceAll('/', Platform.pathSeparator)}';

    // Verificar contención por enlaces simbólicos en el ancestro existente más cercano
    var probe = Directory(targetPath);
    final trailingSegments = <String>[];
    while (!probe.existsSync() && probe.parent.path != probe.path) {
      trailingSegments.add(probe.path.split(Platform.pathSeparator).last);
      probe = probe.parent;
    }
    final canonicalBase = probe.existsSync() ? probe.resolveSymbolicLinksSync() : probe.absolute.path;
    final canonicalTarget = trailingSegments.isEmpty
        ? canonicalBase
        : '$canonicalBase${Platform.pathSeparator}${trailingSegments.reversed.join(Platform.pathSeparator)}';

    final isInside = canonicalTarget == canonicalRoot ||
        canonicalTarget.startsWith('$canonicalRoot${Platform.pathSeparator}');
    if (!isInside) {
      throw ArgumentError('Acceso denegado fuera del sandbox del workspace: $relPath');
    }
    if (!allowRoot && canonicalTarget == canonicalRoot) {
      throw ArgumentError('No se permite operar directamente sobre la raiz del espacio de trabajo');
    }
    return canonicalTarget;
  }

  @override
  Future<StudioFolderEntity> loadRootWorkspace() async {
    final rootPath = await getRootPath();
    final rootDir = Directory(rootPath);

    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
      await _seedDefaultWorkspaceStructure(rootDir);
    } else {
      // Si el directorio existe pero está completamente vacío, sembramos la plantilla base
      final entries = await rootDir.list().toList();
      if (entries.isEmpty) {
        await _seedDefaultWorkspaceStructure(rootDir);
      }
    }

    return _scanDirectoryRecursively(rootDir, rootPath);
  }

  /// Sembrado inicial de directorios y archivos canónicos de estudio.
  Future<void> _seedDefaultWorkspaceStructure(Directory rootDir) async {
    final scoresDir = Directory('${rootDir.path}/Partituras & Notación');
    final audioDir = Directory('${rootDir.path}/Tomas de Audio & WAV');
    final tuningsDir = Directory('${rootDir.path}/Presets de Afinación');
    final djDir = Directory('${rootDir.path}/Modelos Consola DJ');

    await scoresDir.create(recursive: true);
    await audioDir.create(recursive: true);
    await tuningsDir.create(recursive: true);
    await djDir.create(recursive: true);

    // Archivos semilla
    final demoScore = File('${scoresDir.path}/Sonata No. 1 en C Mayor.musicxml');
    await demoScore.writeAsString(
      '<?xml version="1.0" encoding="UTF-8"?>\n<score-partwise version="3.1"><work><work-title>Sonata No. 1</work-title></work></score-partwise>',
      flush: true,
    );

    // Archivos semilla binarios provistos por adaptador externo (sin acoplar core a features)
    if (_seedProvider != null) {
      final binarySeeds = await _seedProvider.buildSeedBinaryFiles();
      for (final entry in binarySeeds.entries) {
        final safePath = _resolveSafePath(entry.key, rootDir.path);
        final outFile = File(safePath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(entry.value, flush: true);
      }
    }

    final demoPreset = File('${tuningsDir.path}/Temperamento_Pitagorico.tpreset');
    await demoPreset.writeAsString('{"presetName": "Pitagórico", "referenceA4": 440.0}', flush: true);

    final demoDj = File('${djDir.path}/Pioneer_DDJ_FLX4.djblueprint');
    await demoDj.writeAsString('{"model": "DDJ-FLX4", "decks": 2}', flush: true);
  }

  /// Escanea recursivamente un directorio y construye la jerarquía inmutable de dominio.
  Future<StudioFolderEntity> _scanDirectoryRecursively(Directory dir, String rootPath) async {
    final now = DateTime.now().microsecondsSinceEpoch;
    final dirPath = dir.path;
    final sep = Platform.pathSeparator;
    final normRoot = rootPath.endsWith(sep) ? rootPath.substring(0, rootPath.length - 1) : rootPath;
    final relativePath = dirPath == normRoot
        ? '/'
        : dirPath.replaceFirst('$normRoot$sep', '/').replaceAll('\\', '/');
    final folderName = dirPath == normRoot ? 'PROYECTO TUNNER' : dirPath.split(sep).last;
    final folderId = dirPath == normRoot ? 'root' : 'folder_${relativePath.hashCode.abs()}';

    final children = <StudioFileSystemNode>[];

    try {
      final entities = await dir.list(followLinks: false).toList();
      // Ordenar: primero carpetas alfabéticamente, luego archivos alfabéticamente
      entities.sort((a, b) {
        if (a is Directory && b is! Directory) return -1;
        if (a is! Directory && b is Directory) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      for (final entity in entities) {
        if (entity is Directory) {
          final subFolder = await _scanDirectoryRecursively(entity, rootPath);
          children.add(subFolder);
        } else if (entity is File) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final fileRelPath = entity.path
              .replaceFirst('$normRoot$sep', '/')
              .replaceAll('\\', '/');
          final fileType = StudioFileType.fromFileName(fileName);
          int size = 0;
          int modified = now;
          try {
            size = await entity.length();
            modified = (await entity.lastModified()).microsecondsSinceEpoch;
          } catch (e) {
            _logger.warning('LocalDiskStudioFileSystemRepository', 'Metadatos de archivo inaccesibles: $e');
          }

          children.add(
            StudioFileEntity(
              id: 'file_${fileRelPath.hashCode.abs()}',
              name: fileName,
              relativePath: fileRelPath,
              modifiedAtMicros: modified,
              extension: StudioFileType.extractExtension(fileName, fileType),
              fileType: fileType,
              sizeBytes: size,
            ),
          );
        }
      }
    } catch (e) {
      _logger.warning('LocalDiskStudioFileSystemRepository', 'Error escaneando ${dir.path}: $e');
    }

    return StudioFolderEntity(
      id: folderId,
      name: folderName,
      relativePath: relativePath,
      modifiedAtMicros: now,
      isExpanded: true,
      children: children,
    );
  }

  @override
  Future<void> saveFile({required String relativePath, required Uint8List bytes}) async {
    final rootPath = await getRootPath();
    final safePath = _resolveSafePath(relativePath, rootPath);
    final file = File(safePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List> readFile(String relativePath) async {
    final rootPath = await getRootPath();
    final safePath = _resolveSafePath(relativePath, rootPath);
    final file = File(safePath);
    if (!await file.exists()) {
      throw FileSystemException('El archivo físico no existe', file.path);
    }
    return file.readAsBytes();
  }

  @override
  Future<void> createFolder(String relativePath) async {
    final rootPath = await getRootPath();
    final safePath = _resolveSafePath(relativePath, rootPath);
    final dir = Directory(safePath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  @override
  Future<void> deletePath(String relativePath) async {
    final rootPath = await getRootPath();
    final safePath = _resolveSafePath(relativePath, rootPath, allowRoot: false);

    final file = File(safePath);
    if (await file.exists()) {
      await file.delete();
      return;
    }

    final dir = Directory(safePath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<void> movePath({required String oldRelativePath, required String newRelativePath}) async {
    final rootPath = await getRootPath();
    final oldPath = _resolveSafePath(oldRelativePath, rootPath, allowRoot: false);
    final newPath = _resolveSafePath(newRelativePath, rootPath, allowRoot: false);

    final oldFile = File(oldPath);
    if (await oldFile.exists()) {
      final newFile = File(newPath);
      await newFile.parent.create(recursive: true);
      await oldFile.rename(newPath);
      return;
    }

    final oldDir = Directory(oldPath);
    if (await oldDir.exists()) {
      final newDir = Directory(newPath);
      await newDir.parent.create(recursive: true);
      await oldDir.rename(newPath);
    }
  }

  @override
  Future<bool> openInSystemExplorer(String relativePath) async {
    try {
      final rootPath = await getRootPath();
      final safePath = _resolveSafePath(relativePath, rootPath, allowRoot: true);

      String targetDirPath;
      final file = File(safePath);
      if (await file.exists()) {
        targetDirPath = file.parent.path;
      } else {
        final dir = Directory(safePath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        targetDirPath = dir.path;
      }

      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }

      if (Platform.isLinux) {
        await Process.start('xdg-open', [targetDirPath], mode: ProcessStartMode.detached);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.start('open', [targetDirPath], mode: ProcessStartMode.detached);
        return true;
      }
      if (Platform.isWindows) {
        await Process.start('explorer', [targetDirPath], mode: ProcessStartMode.detached);
        return true;
      }
      return false;
    } catch (e, st) {
      _logger.warning(
        'LocalDiskStudioFileSystemRepository',
        'No se pudo abrir la ruta en el explorador del sistema ($relativePath): $e',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
