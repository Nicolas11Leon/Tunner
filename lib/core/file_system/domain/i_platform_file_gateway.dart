import 'dart:typed_data';

/// Resultado agnóstico de plataforma tras seleccionar un archivo del sistema.
class PlatformPickedFile {
  final String name;
  final String? path;
  final Uint8List? bytes;

  const PlatformPickedFile({
    required this.name,
    this.path,
    this.bytes,
  });
}

/// Entrada de directorio local para el explorador didáctico integrado.
class StudioDiskEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int sizeBytes;
  final String extensionName;

  const StudioDiskEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.sizeBytes = 0,
    this.extensionName = '',
  });
}

/// Acceso directo a carpeta del usuario (Música, Descargas, Documentos, etc.).
class StudioQuickDirectory {
  final String label;
  final String path;
  final String iconKey;

  const StudioQuickDirectory({
    required this.label,
    required this.path,
    required this.iconKey,
  });
}

/// Puerto abstracto de dominio para acceso a directorios y selector nativo de archivos,
/// desacoplando ViewModels de plugins concretos como `file_picker` o `path_provider`.
abstract class IPlatformFileGateway {
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions});
  Future<String> getDocumentsDirectoryPath();
  Future<String> getTemporaryDirectoryPath();
  Future<String> saveExportedBytes(String fileName, Uint8List bytes);
}

/// Capacidad opcional para listar carpetas locales y leer archivos seleccionados
/// dentro del explorador visual integrado sin depender del selector nativo externo.
abstract class IStudioDiskBrowserGateway {
  Future<List<StudioQuickDirectory>> getQuickDirectories();
  Future<List<StudioDiskEntry>> listDirectoryEntries(
    String directoryPath, {
    Set<String>? allowedExtensions,
  });
  Future<Uint8List?> readFileBytes(String filePath);
}

/// Implementación en memoria sin dependencias de plataforma para pruebas y fallbacks desacoplados.
class NoOpPlatformFileGateway implements IPlatformFileGateway {
  const NoOpPlatformFileGateway();

  @override
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions}) async => null;

  @override
  Future<String> getDocumentsDirectoryPath() async => '';

  @override
  Future<String> getTemporaryDirectoryPath() async => '';

  @override
  Future<String> saveExportedBytes(String fileName, Uint8List bytes) async => '';
}
