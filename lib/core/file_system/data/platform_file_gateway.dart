import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/i_platform_file_gateway.dart';

/// Implementación concreta de infraestructura para selector nativo de archivos y rutas de documentos.
class PlatformFileGateway implements IPlatformFileGateway {
  const PlatformFileGateway();

  @override
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions}) async {
    final files = await FilePicker.pickFiles(
      type: allowedExtensions != null && allowedExtensions.isNotEmpty
          ? FileType.custom
          : FileType.any,
      allowedExtensions: allowedExtensions,
    );

    if (files.isEmpty) return null;
    final picked = files.first;
    final bytes = await picked.readAsBytes();
    return PlatformPickedFile(
      name: picked.name,
      path: picked.path,
      bytes: bytes,
    );
  }

  @override
  Future<String> getDocumentsDirectoryPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  @override
  Future<String> getTemporaryDirectoryPath() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }
}
