import 'package:meta/meta.dart';
import 'studio_file_type.dart';

/// Nodo base inmutable para el sistema de archivos jerárquico del estudio.
@immutable
abstract class StudioFileSystemNode {
  final String id;
  final String name;
  final String relativePath;
  final int modifiedAtMicros;

  const StudioFileSystemNode({
    required this.id,
    required this.name,
    required this.relativePath,
    required this.modifiedAtMicros,
  });

  bool get isFolder;
  bool get isFile => !isFolder;
}

/// Nodo hoja inmutable que representa un archivo físico o de proyecto en Tunner.
@immutable
class StudioFileEntity extends StudioFileSystemNode {
  final String extension;
  final StudioFileType fileType;
  final int sizeBytes;
  final dynamic payload; // Contenido desacoplado en memoria si aplica

  const StudioFileEntity({
    required super.id,
    required super.name,
    required super.relativePath,
    required super.modifiedAtMicros,
    required this.extension,
    required this.fileType,
    this.sizeBytes = 0,
    this.payload,
  });

  @override
  bool get isFolder => false;

  /// Retorna el tamaño legible en KB o MB.
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  StudioFileEntity copyWith({
    String? id,
    String? name,
    String? relativePath,
    int? modifiedAtMicros,
    String? extension,
    StudioFileType? fileType,
    int? sizeBytes,
    dynamic payload,
  }) {
    return StudioFileEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      relativePath: relativePath ?? this.relativePath,
      modifiedAtMicros: modifiedAtMicros ?? this.modifiedAtMicros,
      extension: extension ?? this.extension,
      fileType: fileType ?? this.fileType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      payload: payload ?? this.payload,
    );
  }
}

/// Nodo rama inmutable que representa un directorio o carpeta en Tunner.
@immutable
class StudioFolderEntity extends StudioFileSystemNode {
  final List<StudioFileSystemNode> children;
  final bool isExpanded;

  const StudioFolderEntity({
    required super.id,
    required super.name,
    required super.relativePath,
    required super.modifiedAtMicros,
    this.children = const [],
    this.isExpanded = true,
  });

  @override
  bool get isFolder => true;

  /// Total recursivo de archivos contenidos en esta carpeta y sus subcarpetas.
  int get totalFilesCount {
    int count = 0;
    for (final child in children) {
      if (child.isFolder) {
        count += (child as StudioFolderEntity).totalFilesCount;
      } else {
        count++;
      }
    }
    return count;
  }

  StudioFolderEntity copyWith({
    String? id,
    String? name,
    String? relativePath,
    int? modifiedAtMicros,
    List<StudioFileSystemNode>? children,
    bool? isExpanded,
  }) {
    return StudioFolderEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      relativePath: relativePath ?? this.relativePath,
      modifiedAtMicros: modifiedAtMicros ?? this.modifiedAtMicros,
      children: children ?? this.children,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  /// Busca recursivamente un nodo por su ID.
  StudioFileSystemNode? findNode(String targetId) {
    if (id == targetId) return this;
    for (final child in children) {
      if (child.id == targetId) return child;
      if (child is StudioFolderEntity) {
        final found = child.findNode(targetId);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Inserta un nuevo nodo dentro de la carpeta con targetFolderId de forma inmutable.
  StudioFolderEntity insertChild(String targetFolderId, StudioFileSystemNode newNode) {
    if (id == targetFolderId) {
      final updatedList = List<StudioFileSystemNode>.from(children)..add(newNode);
      return copyWith(children: updatedList);
    }

    final updatedChildren = <StudioFileSystemNode>[];
    for (final child in children) {
      if (child is StudioFolderEntity) {
        updatedChildren.add(child.insertChild(targetFolderId, newNode));
      } else {
        updatedChildren.add(child);
      }
    }
    return copyWith(children: updatedChildren);
  }

  /// Elimina un nodo recursivamente por su ID.
  StudioFolderEntity removeChild(String targetId) {
    final updatedChildren = <StudioFileSystemNode>[];
    for (final child in children) {
      if (child.id == targetId) continue;
      if (child is StudioFolderEntity) {
        updatedChildren.add(child.removeChild(targetId));
      } else {
        updatedChildren.add(child);
      }
    }
    return copyWith(children: updatedChildren);
  }

  /// Renombra o actualiza un nodo recursivamente.
  StudioFolderEntity updateNode(StudioFileSystemNode updatedNode) {
    if (id == updatedNode.id && updatedNode is StudioFolderEntity) {
      return updatedNode;
    }

    final updatedChildren = <StudioFileSystemNode>[];
    for (final child in children) {
      if (child.id == updatedNode.id) {
        updatedChildren.add(updatedNode);
      } else if (child is StudioFolderEntity) {
        updatedChildren.add(child.updateNode(updatedNode));
      } else {
        updatedChildren.add(child);
      }
    }
    return copyWith(children: updatedChildren);
  }

  /// Conmuta el estado de expansión de una carpeta recursivamente.
  StudioFolderEntity toggleFolderExpansion(String folderId) {
    if (id == folderId) {
      return copyWith(isExpanded: !isExpanded);
    }

    final updatedChildren = <StudioFileSystemNode>[];
    for (final child in children) {
      if (child is StudioFolderEntity) {
        updatedChildren.add(child.toggleFolderExpansion(folderId));
      } else {
        updatedChildren.add(child);
      }
    }
    return copyWith(children: updatedChildren);
  }

  /// Mueve un nodo existente a una nueva carpeta de destino de forma inmutable.
  StudioFolderEntity moveChild(String targetNodeId, String targetFolderId) {
    final nodeToMove = findNode(targetNodeId);
    if (nodeToMove == null) return this;
    if (targetNodeId == targetFolderId) return this;
    if (nodeToMove is StudioFolderEntity && nodeToMove.findNode(targetFolderId) != null) {
      return this;
    }

    final withoutNode = removeChild(targetNodeId);
    final targetFolder = withoutNode.findNode(targetFolderId);
    final targetPath = targetFolder?.relativePath ?? '';
    final newRelativePath = '$targetPath/${nodeToMove.name}';

    final StudioFileSystemNode relocatedNode;
    if (nodeToMove is StudioFileEntity) {
      relocatedNode = nodeToMove.copyWith(relativePath: newRelativePath);
    } else if (nodeToMove is StudioFolderEntity) {
      relocatedNode = nodeToMove.copyWith(relativePath: newRelativePath);
    } else {
      relocatedNode = nodeToMove;
    }

    return withoutNode.insertChild(targetFolderId, relocatedNode);
  }

  /// Colapsa o expande todas las carpetas del árbol.
  StudioFolderEntity setExpansionAll(bool expanded) {
    final updatedChildren = <StudioFileSystemNode>[];
    for (final child in children) {
      if (child is StudioFolderEntity) {
        updatedChildren.add(child.setExpansionAll(expanded));
      } else {
        updatedChildren.add(child);
      }
    }
    return copyWith(isExpanded: expanded, children: updatedChildren);
  }
}
