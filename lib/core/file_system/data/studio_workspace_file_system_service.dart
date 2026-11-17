import 'package:flutter/foundation.dart';
import '../../../features/project_format/data/local_project_storage_repository.dart';
import '../../../features/project_format/data/tunner_binary_project_codec.dart';
import '../domain/studio_file_system_node.dart';
import '../domain/studio_file_system_repository.dart';
import '../domain/studio_file_type.dart';
import 'local_disk_studio_file_system_repository.dart';

/// Callback para cuando un archivo es seleccionado o ejecutado para apertura.
typedef StudioOpenFileCallback = void Function(StudioFileEntity file);

/// Servicio reactivo de orquestación del sistema de archivos del espacio de trabajo.
/// Proporciona operaciones CRUD atómicas, búsqueda/filtrado en tiempo real (<2ms),
/// gestión de expansión y persistencia física en disco sin bloqueo.
class StudioWorkspaceFileSystemService extends ChangeNotifier {
  static final StudioWorkspaceFileSystemService _instance = StudioWorkspaceFileSystemService._internal();
  factory StudioWorkspaceFileSystemService({
    LocalProjectStorageRepository? repository,
    StudioFileSystemRepository? fileSystemRepository,
  }) {
    if (repository != null) {
      _instance._repository = repository;
    }
    if (fileSystemRepository != null) {
      _instance._fileSystemRepository = fileSystemRepository;
    }
    return _instance;
  }

  StudioWorkspaceFileSystemService._internal() {
    _repository = LocalProjectStorageRepository(codec: TunnerBinaryProjectCodec());
    _fileSystemRepository = LocalDiskStudioFileSystemRepository();
    _initializeDefaultTree();
  }

  late LocalProjectStorageRepository _repository;
  late StudioFileSystemRepository _fileSystemRepository;
  late StudioFolderEntity _rootFolder;
  String? _selectedNodeId;
  String _activeFolderId = 'root';
  String _searchQuery = '';
  StudioOpenFileCallback? onOpenFile;

  LocalProjectStorageRepository get repository => _repository;
  StudioFileSystemRepository get fileSystemRepository => _fileSystemRepository;
  StudioFolderEntity get rootFolder => _rootFolder;
  String? get selectedNodeId => _selectedNodeId;
  String get activeFolderId => _activeFolderId;
  String get searchQuery => _searchQuery;

  /// Retorna el nodo actualmente seleccionado o null.
  StudioFileSystemNode? get selectedNode =>
      _selectedNodeId != null ? _rootFolder.findNode(_selectedNodeId!) : null;

  /// Carga de forma asíncrona la jerarquía real desde el disco.
  Future<void> initializeWorkspace() async {
    try {
      final diskRoot = await _fileSystemRepository.loadRootWorkspace();
      _rootFolder = diskRoot;
      notifyListeners();
    } catch (e) {
      debugPrint('StudioWorkspaceFileSystemService: Error al inicializar desde disco: $e');
    }
  }

  /// Recarga el árbol jerárquico re-escaneando el disco físico.
  Future<void> refreshFromDisk() async {
    try {
      final diskRoot = await _fileSystemRepository.loadRootWorkspace();
      _rootFolder = diskRoot;
      notifyListeners();
    } catch (e) {
      debugPrint('StudioWorkspaceFileSystemService: Error refrescando disco: $e');
    }
  }

  /// Inicializa la jerarquía canónica de directorios del estudio.
  void _initializeDefaultTree() {
    final now = DateTime.now().microsecondsSinceEpoch;

    _rootFolder = StudioFolderEntity(
      id: 'root',
      name: 'PROYECTO TUNNER',
      relativePath: '/',
      modifiedAtMicros: now,
      isExpanded: true,
      children: [
        StudioFolderEntity(
          id: 'folder_scores',
          name: 'Partituras & Notación',
          relativePath: '/Partituras & Notación',
          modifiedAtMicros: now,
          isExpanded: true,
          children: [
            StudioFileEntity(
              id: 'file_demo_sonata',
              name: 'Sonata No. 1 en C Mayor.musicxml',
              relativePath: '/Partituras & Notación/Sonata No. 1 en C Mayor.musicxml',
              modifiedAtMicros: now,
              extension: '.musicxml',
              fileType: StudioFileType.score,
              sizeBytes: 14200,
            ),
          ],
        ),
        StudioFolderEntity(
          id: 'folder_recordings',
          name: 'Tomas de Audio & WAV',
          relativePath: '/Tomas de Audio & WAV',
          modifiedAtMicros: now,
          isExpanded: true,
          children: [
            StudioFileEntity(
              id: 'file_demo_take_1',
              name: 'Toma_Acustica_440Hz.wav',
              relativePath: '/Tomas de Audio & WAV/Toma_Acustica_440Hz.wav',
              modifiedAtMicros: now,
              extension: '.wav',
              fileType: StudioFileType.audioWav,
              sizeBytes: 184500,
            ),
          ],
        ),
        StudioFolderEntity(
          id: 'folder_tunings',
          name: 'Presets de Afinación',
          relativePath: '/Presets de Afinación',
          modifiedAtMicros: now,
          isExpanded: false,
          children: [
            StudioFileEntity(
              id: 'file_preset_pitagorico',
              name: 'Temperamento_Pitagorico.tpreset',
              relativePath: '/Presets de Afinación/Temperamento_Pitagorico.tpreset',
              modifiedAtMicros: now,
              extension: '.tpreset',
              fileType: StudioFileType.tuningPreset,
              sizeBytes: 1024,
            ),
          ],
        ),
        StudioFolderEntity(
          id: 'folder_dj',
          name: 'Modelos Consola DJ',
          relativePath: '/Modelos Consola DJ',
          modifiedAtMicros: now,
          isExpanded: false,
          children: [
            StudioFileEntity(
              id: 'file_blueprint_flx4',
              name: 'Pioneer_DDJ_FLX4.djblueprint',
              relativePath: '/Modelos Consola DJ/Pioneer_DDJ_FLX4.djblueprint',
              modifiedAtMicros: now,
              extension: '.djblueprint',
              fileType: StudioFileType.djBlueprint,
              sizeBytes: 4096,
            ),
          ],
        ),
      ],
    );
  }

  /// Reinicia el árbol a su estado inicial canónico (para pruebas o nueva sesión).
  void resetToDefaults() {
    _initializeDefaultTree();
    _selectedNodeId = null;
    _activeFolderId = 'root';
    _searchQuery = '';
    notifyListeners();
  }

  /// Selecciona un nodo por su ID y si es carpeta la define como carpeta activa.
  void selectNode(String nodeId) {
    _selectedNodeId = nodeId;
    final node = _rootFolder.findNode(nodeId);
    if (node is StudioFolderEntity) {
      _activeFolderId = node.id;
    } else if (node is StudioFileEntity) {
      onOpenFile?.call(node);
    }
    notifyListeners();
  }

  /// Conmuta la expansión de una carpeta.
  void toggleFolder(String folderId) {
    _rootFolder = _rootFolder.toggleFolderExpansion(folderId);
    _activeFolderId = folderId;
    notifyListeners();
  }

  /// Colapsa todas las carpetas a nivel raíz.
  void collapseAll() {
    _rootFolder = _rootFolder.setExpansionAll(false);
    notifyListeners();
  }

  /// Expande todas las carpetas del árbol.
  void expandAll() {
    _rootFolder = _rootFolder.setExpansionAll(true);
    notifyListeners();
  }

  /// Establece el filtro de búsqueda en tiempo real.
  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  /// Crea un nuevo archivo en la carpeta especificada o en la carpeta activa.
  StudioFileEntity createFile({
    required String name,
    String? parentFolderId,
    StudioFileType? fileType,
    int? sizeBytes,
    dynamic payload,
    Uint8List? initialBytes,
  }) {
    final targetFolderId = parentFolderId ?? _activeFolderId;
    final type = fileType ?? StudioFileType.fromFileName(name);
    final fullName = name.contains('.') ? name : '$name${type.extension}';
    final now = DateTime.now().microsecondsSinceEpoch;
    final fileId = 'file_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode.abs()}';

    final parentNode = _rootFolder.findNode(targetFolderId);
    final parentPath = parentNode?.relativePath ?? '';
    final relativePath = '$parentPath/$fullName';

    final bytes = initialBytes ?? Uint8List.fromList([0]);

    final newFile = StudioFileEntity(
      id: fileId,
      name: fullName,
      relativePath: relativePath,
      modifiedAtMicros: now,
      extension: type.extension,
      fileType: type,
      sizeBytes: sizeBytes ?? bytes.length,
      payload: payload,
    );

    _rootFolder = _rootFolder.insertChild(targetFolderId, newFile);
    _selectedNodeId = newFile.id;
    notifyListeners();

    // Persistencia física en disco
    _fileSystemRepository.saveFile(
      relativePath: relativePath,
      bytes: bytes,
    ).catchError((e) {
      debugPrint('StudioWorkspaceFileSystemService: Error guardando archivo en disco: $e');
    });

    return newFile;
  }

  /// Crea una nueva carpeta en la carpeta especificada o en la carpeta activa.
  StudioFolderEntity createFolder({
    required String name,
    String? parentFolderId,
  }) {
    final targetFolderId = parentFolderId ?? _activeFolderId;
    final now = DateTime.now().microsecondsSinceEpoch;
    final folderId = 'folder_${DateTime.now().millisecondsSinceEpoch}_${name.hashCode.abs()}';

    final parentNode = _rootFolder.findNode(targetFolderId);
    final parentPath = parentNode?.relativePath ?? '';
    final relativePath = '$parentPath/$name';

    final newFolder = StudioFolderEntity(
      id: folderId,
      name: name,
      relativePath: relativePath,
      modifiedAtMicros: now,
      isExpanded: true,
      children: const [],
    );

    _rootFolder = _rootFolder.insertChild(targetFolderId, newFolder);
    _activeFolderId = newFolder.id;
    _selectedNodeId = newFolder.id;
    notifyListeners();

    // Persistencia física en disco
    _fileSystemRepository.createFolder(relativePath).catchError((e) {
      debugPrint('StudioWorkspaceFileSystemService: Error creando carpeta en disco: $e');
    });

    return newFolder;
  }

  /// Renombra un archivo o carpeta existente.
  void renameNode(String nodeId, String newName) {
    final node = _rootFolder.findNode(nodeId);
    if (node == null) return;

    final oldRelPath = node.relativePath;
    final lastSlash = oldRelPath.lastIndexOf('/');
    final parentRelPath = lastSlash > 0 ? oldRelPath.substring(0, lastSlash) : '';

    final now = DateTime.now().microsecondsSinceEpoch;
    String finalName = newName;
    String newRelPath = '';

    if (node is StudioFileEntity) {
      final type = StudioFileType.fromFileName(newName);
      finalName = newName.contains('.') ? newName : '$newName${type.extension}';
      newRelPath = '$parentRelPath/$finalName';
      final updated = node.copyWith(
        name: finalName,
        relativePath: newRelPath,
        extension: type.extension,
        fileType: type,
        modifiedAtMicros: now,
      );
      _rootFolder = _rootFolder.updateNode(updated);
    } else if (node is StudioFolderEntity) {
      newRelPath = '$parentRelPath/$newName';
      final updated = node.copyWith(
        name: newName,
        relativePath: newRelPath,
        modifiedAtMicros: now,
      );
      _rootFolder = _rootFolder.updateNode(updated);
    }
    notifyListeners();

    if (newRelPath.isNotEmpty && newRelPath != oldRelPath) {
      _fileSystemRepository.movePath(
        oldRelativePath: oldRelPath,
        newRelativePath: newRelPath,
      ).catchError((e) {
        debugPrint('StudioWorkspaceFileSystemService: Error renombrando en disco: $e');
      });
    }
  }

  /// Mueve un archivo o carpeta a una carpeta de destino.
  void moveNode(String nodeId, String targetFolderId) {
    final node = _rootFolder.findNode(nodeId);
    final targetFolder = _rootFolder.findNode(targetFolderId);
    if (node == null || targetFolder == null || targetFolder is! StudioFolderEntity) return;

    final oldRelPath = node.relativePath;
    final newRelPath = '${targetFolder.relativePath}/${node.name}';

    _rootFolder = _rootFolder.moveChild(nodeId, targetFolderId);
    _selectedNodeId = nodeId;
    notifyListeners();

    _fileSystemRepository.movePath(
      oldRelativePath: oldRelPath,
      newRelativePath: newRelPath,
    ).catchError((e) {
      debugPrint('StudioWorkspaceFileSystemService: Error moviendo en disco: $e');
    });
  }

  /// Elimina un nodo (archivo o carpeta con todos sus hijos).
  void deleteNode(String nodeId) {
    if (nodeId == 'root') return; // Raíz no se elimina
    final node = _rootFolder.findNode(nodeId);
    if (node == null) return;
    final relPath = node.relativePath;

    _rootFolder = _rootFolder.removeChild(nodeId);
    if (_selectedNodeId == nodeId) {
      _selectedNodeId = null;
    }
    if (_activeFolderId == nodeId) {
      _activeFolderId = 'root';
    }
    notifyListeners();

    _fileSystemRepository.deletePath(relPath).catchError((e) {
      debugPrint('StudioWorkspaceFileSystemService: Error eliminando en disco: $e');
    });
  }

  /// Retorna el árbol filtrado en base al término de búsqueda actual.
  StudioFolderEntity get filteredRootFolder {
    if (_searchQuery.isEmpty) return _rootFolder;
    return _filterFolderRecursively(_rootFolder, _searchQuery.toLowerCase()) ??
        _rootFolder.copyWith(children: const []);
  }

  StudioFolderEntity? _filterFolderRecursively(StudioFolderEntity folder, String query) {
    final matchingChildren = <StudioFileSystemNode>[];

    for (final child in folder.children) {
      if (child is StudioFileEntity) {
        if (child.name.toLowerCase().contains(query)) {
          matchingChildren.add(child);
        }
      } else if (child is StudioFolderEntity) {
        final filteredSubFolder = _filterFolderRecursively(child, query);
        if (filteredSubFolder != null && filteredSubFolder.children.isNotEmpty) {
          matchingChildren.add(filteredSubFolder.copyWith(isExpanded: true));
        } else if (child.name.toLowerCase().contains(query)) {
          matchingChildren.add(child.copyWith(isExpanded: true));
        }
      }
    }

    if (matchingChildren.isNotEmpty || folder.name.toLowerCase().contains(query)) {
      return folder.copyWith(children: matchingChildren, isExpanded: true);
    }
    return null;
  }
}
