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

/// Puerto abstracto de dominio para acceso a directorios y selector nativo de archivos,
/// desacoplando ViewModels de plugins concretos como `file_picker` o `path_provider`.
abstract class IPlatformFileGateway {
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions});
  Future<String> getDocumentsDirectoryPath();
  Future<String> getTemporaryDirectoryPath();
}
