import 'dart:typed_data';
import '../domain/studio_file_system_node.dart';
import '../domain/studio_file_system_repository.dart';
import '../domain/studio_file_type.dart';

/// Implementación en memoria de [StudioFileSystemRepository] para pruebas unitarias.
class MemoryStudioFileSystemRepository implements StudioFileSystemRepository {
  final Map<String, Uint8List> _files = {};
  final Set<String> _directories = {};
  StudioFolderEntity? customRoot;
  String? lastOpenedExplorerPath;

  MemoryStudioFileSystemRepository({StudioFolderEntity? initialRoot}) {
    customRoot = initialRoot;
    _seedDefaultDirectories();
  }

  void _seedDefaultDirectories() {
    _directories.addAll([
      '/Partituras & Notación',
      '/Tomas de Audio & WAV',
      '/Presets de Afinación',
      '/Modelos Consola DJ',
    ]);
    _files['/Partituras & Notación/Sonata No. 1 en C Mayor.musicxml'] =
        Uint8List.fromList([60, 62, 64]);
    _files['/Tomas de Audio & WAV/Toma_Acustica_440Hz.wav'] =
        Uint8List.fromList([1, 2, 3, 4]);
  }

  @override
  Future<StudioFolderEntity> loadRootWorkspace() async {
    if (customRoot != null) return customRoot!;

    final now = DateTime.now().microsecondsSinceEpoch;
    final folderMap = <String, List<StudioFileSystemNode>>{};

    for (final dir in _directories) {
      folderMap[dir] = [];
    }

    _files.forEach((path, bytes) {
      final lastSlash = path.lastIndexOf('/');
      final parentDir = lastSlash > 0 ? path.substring(0, lastSlash) : '/';
      final fileName = path.substring(lastSlash + 1);
      final fileType = StudioFileType.fromFileName(fileName);

      final fileEntity = StudioFileEntity(
        id: 'file_${path.hashCode.abs()}',
        name: fileName,
        relativePath: path,
        modifiedAtMicros: now,
        extension: fileType.extension,
        fileType: fileType,
        sizeBytes: bytes.length,
      );

      folderMap.putIfAbsent(parentDir, () => []).add(fileEntity);
    });

    final rootChildren = <StudioFileSystemNode>[];
    folderMap.forEach((dirPath, children) {
      if (dirPath == '/') return;
      final folderName = dirPath.startsWith('/') ? dirPath.substring(1) : dirPath;
      rootChildren.add(
        StudioFolderEntity(
          id: 'folder_${dirPath.hashCode.abs()}',
          name: folderName,
          relativePath: dirPath,
          modifiedAtMicros: now,
          isExpanded: true,
          children: children,
        ),
      );
    });

    return StudioFolderEntity(
      id: 'root',
      name: 'PROYECTO TUNNER',
      relativePath: '/',
      modifiedAtMicros: now,
      isExpanded: true,
      children: rootChildren,
    );
  }

  @override
  Future<void> saveFile({required String relativePath, required Uint8List bytes}) async {
    _files[relativePath] = bytes;
    final lastSlash = relativePath.lastIndexOf('/');
    if (lastSlash > 0) {
      _directories.add(relativePath.substring(0, lastSlash));
    }
  }

  @override
  Future<Uint8List> readFile(String relativePath) async {
    final bytes = _files[relativePath];
    if (bytes == null) {
      throw Exception('Archivo no encontrado en memoria: $relativePath');
    }
    return bytes;
  }

  @override
  Future<void> createFolder(String relativePath) async {
    _directories.add(relativePath);
  }

  @override
  Future<void> deletePath(String relativePath) async {
    _files.remove(relativePath);
    _directories.remove(relativePath);
    _files.removeWhere((k, _) => k.startsWith('$relativePath/'));
    _directories.removeWhere((d) => d.startsWith('$relativePath/'));
  }

  @override
  Future<void> movePath({required String oldRelativePath, required String newRelativePath}) async {
    if (_files.containsKey(oldRelativePath)) {
      final bytes = _files.remove(oldRelativePath)!;
      _files[newRelativePath] = bytes;
    } else if (_directories.contains(oldRelativePath)) {
      _directories.remove(oldRelativePath);
      _directories.add(newRelativePath);

      final filesToMove = <String, Uint8List>{};
      _files.forEach((k, v) {
        if (k.startsWith('$oldRelativePath/')) {
          filesToMove[k] = v;
        }
      });
      for (final entry in filesToMove.entries) {
        _files.remove(entry.key);
        final relocatedPath = entry.key.replaceFirst(oldRelativePath, newRelativePath);
        _files[relocatedPath] = entry.value;
      }
    }
  }

  @override
  Future<bool> openInSystemExplorer(String relativePath) async {
    lastOpenedExplorerPath = relativePath;
    return true;
  }
}
