import 'dart:typed_data';
import '../../domain/i_studio_listenable.dart';
import 'studio_file_system_node.dart';
import 'studio_file_system_repository.dart';
import 'studio_file_type.dart';

/// Acciones musicales contextuales disponibles sobre un archivo del espacio de trabajo.
enum StudioFileMusicalAction {
  openDefault,
  transformToScoreAndStems,
  loadInDjDeckA,
  loadInDjDeckB,
  openInScoreEditor,
}

/// Callback para cuando un archivo es seleccionado o ejecutado para apertura.
typedef StudioOpenFileCallback = void Function(StudioFileEntity file);

/// Callback para ejecutar una acción musical explícita sobre un archivo.
typedef StudioFileMusicalActionCallback = void Function(
  StudioFileEntity file,
  StudioFileMusicalAction action,
);

/// Puerto abstracto de dominio para la orquestación reactiva del espacio de trabajo de archivos.
abstract class IStudioWorkspaceFileSystem implements IStudioListenable {
  StudioFolderEntity get rootFolder;
  StudioFolderEntity get filteredRootFolder;
  String? get selectedNodeId;
  String get activeFolderId;
  String get searchQuery;
  StudioFileSystemRepository get fileSystemRepository;
  StudioOpenFileCallback? onOpenFile;
  StudioFileMusicalActionCallback? onFileMusicalAction;

  Future<void> initializeWorkspace();
  Future<void> refreshFromDisk();
  void resetToDefaults();
  void selectNode(String nodeId);
  void triggerFileMusicalAction(StudioFileEntity file, StudioFileMusicalAction action);
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
  Future<bool> openInSystemExplorer(String relativePath);
}

/// Implementación en memoria sin dependencias de I/O para pruebas y UI desacoplada.
class NoOpStudioWorkspaceFileSystem with StudioPureNotifierMixin implements IStudioWorkspaceFileSystem {
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
  StudioFileMusicalActionCallback? onFileMusicalAction;

  @override
  Future<void> initializeWorkspace() async {}

  @override
  Future<void> refreshFromDisk() async {}

  @override
  void resetToDefaults() {}

  @override
  void selectNode(String nodeId) {}

  @override
  void triggerFileMusicalAction(
    StudioFileEntity file,
    StudioFileMusicalAction action,
  ) {
    selectNode(file.id);
    if (onFileMusicalAction != null) {
      onFileMusicalAction!(file, action);
    } else {
      onOpenFile?.call(file);
    }
  }

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

  @override
  Future<bool> openInSystemExplorer(String relativePath) async => false;
}
