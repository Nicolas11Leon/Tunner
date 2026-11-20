import 'package:flutter/foundation.dart';
import 'studio_file_system_node.dart';
import 'studio_file_system_repository.dart';
import 'studio_file_type.dart';

/// Callback para cuando un archivo es seleccionado o ejecutado para apertura.
typedef StudioOpenFileCallback = void Function(StudioFileEntity file);

/// Puerto abstracto de dominio para la orquestación reactiva del espacio de trabajo de archivos.
abstract class IStudioWorkspaceFileSystem implements Listenable {
  StudioFolderEntity get rootFolder;
  StudioFolderEntity get filteredRootFolder;
  String? get selectedNodeId;
  String get activeFolderId;
  String get searchQuery;
  StudioFileSystemRepository get fileSystemRepository;
  StudioOpenFileCallback? onOpenFile;

  Future<void> initializeWorkspace();
  Future<void> refreshFromDisk();
  void resetToDefaults();
  void selectNode(String nodeId);
  void toggleFolder(String folderId);
  void collapseAll();
  void expandAll();
  void setSearchQuery(String query);

  StudioFileEntity createFile({
    required String name,
    String? parentFolderId,
    StudioFileType? fileType,
    int? sizeBytes,
    dynamic payload,
    Uint8List? initialBytes,
  });

  StudioFolderEntity createFolder({
    required String name,
    String? parentFolderId,
  });

  void renameNode(String nodeId, String newName);
  void moveNode(String nodeId, String targetFolderId);
  void deleteNode(String nodeId);
}

/// Implementación en memoria sin dependencias de I/O para pruebas y UI desacoplada.
class NoOpStudioWorkspaceFileSystem extends ChangeNotifier implements IStudioWorkspaceFileSystem {
  NoOpStudioWorkspaceFileSystem({
    StudioFolderEntity? rootFolder,
  }) : _rootFolder = rootFolder ??
            const StudioFolderEntity(
              id: 'root',
              name: 'Root',
              relativePath: '/',
              modifiedAtMicros: 0,
              isExpanded: true,
            );

  final StudioFolderEntity _rootFolder;

  @override
  StudioFolderEntity get rootFolder => _rootFolder;

  @override
  StudioFolderEntity get filteredRootFolder => _rootFolder;

  @override
  String? get selectedNodeId => null;

  @override
  String get activeFolderId => 'root';

  @override
  String get searchQuery => '';

  @override
  StudioFileSystemRepository get fileSystemRepository => const NoOpStudioFileSystemRepository();

  @override
  StudioOpenFileCallback? onOpenFile;

  @override
  Future<void> initializeWorkspace() async {}

  @override
  Future<void> refreshFromDisk() async {}

  @override
  void resetToDefaults() {}

  @override
  void selectNode(String nodeId) {}

  @override
  void toggleFolder(String folderId) {}

  @override
  void collapseAll() {}

  @override
  void expandAll() {}

  @override
  void setSearchQuery(String query) {}

  @override
  StudioFileEntity createFile({
    required String name,
    String? parentFolderId,
    StudioFileType? fileType,
    int? sizeBytes,
    dynamic payload,
    Uint8List? initialBytes,
  }) {
    return StudioFileEntity(
      id: 'blank',
      name: name,
      relativePath: '/$name',
      modifiedAtMicros: 0,
      extension: '',
      fileType: fileType ?? StudioFileType.genericFile,
      sizeBytes: sizeBytes ?? 0,
    );
  }

  @override
  StudioFolderEntity createFolder({
    required String name,
    String? parentFolderId,
  }) {
    return StudioFolderEntity(
      id: 'blank_dir',
      name: name,
      relativePath: '/$name',
      modifiedAtMicros: 0,
      children: const [],
    );
  }

  @override
  void renameNode(String nodeId, String newName) {}

  @override
  void moveNode(String nodeId, String targetFolderId) {}

  @override
  void deleteNode(String nodeId) {}
}
