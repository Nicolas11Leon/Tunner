import 'dart:typed_data';
import 'studio_file_system_node.dart';

/// Contrato abstracto para el repositorio de persistencia del sistema de archivos de Tunner.
abstract class StudioFileSystemRepository {
  /// Carga el árbol raíz de carpetas y archivos del espacio de trabajo.
  Future<StudioFolderEntity> loadRootWorkspace();

  /// Guarda o sincroniza el estado de un nodo de archivo con su contenido binario.
  Future<void> saveFile({
    required String relativePath,
    required Uint8List bytes,
  });

  /// Lee los bytes de un archivo dado su ruta relativa.
  Future<Uint8List> readFile(String relativePath);

  /// Elimina un archivo o directorio en la ruta indicada.
  Future<void> deletePath(String relativePath);

  /// Crea una nueva carpeta en la ruta indicada.
  Future<void> createFolder(String relativePath);

  /// Renombra o mueve una ruta a un nuevo destino.
  Future<void> movePath({
    required String oldRelativePath,
    required String newRelativePath,
  });
}
