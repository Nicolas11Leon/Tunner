import 'dart:io';
import 'dart:typed_data';

import '../domain/i_platform_file_gateway.dart';

/// Implementacion Pure Dart de [IPlatformFileGateway] basada exclusivamente en `dart:io`.
///
/// Opera sobre un [rootDirectory] inyectado sin dependencias de `path_provider`,
/// `file_picker` ni `package:flutter/`, habilitando ejecucion determinista en CLI,
/// servidores MCP y pruebas headless.
class PosixFileGateway implements IPlatformFileGateway {
  final Directory rootDirectory;
  final Directory? _temporaryDirectory;

  const PosixFileGateway({
    required this.rootDirectory,
    Directory? temporaryDirectory,
  }) : _temporaryDirectory = temporaryDirectory;

  String _trimTrailingSeparator(String path) {
    if (path.length <= 1) return path;
    if (path.endsWith('/') || path.endsWith('\\')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  @override
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions}) async {
    return null;
  }

  @override
  Future<String> getDocumentsDirectoryPath() async {
    if (!await rootDirectory.exists()) {
      await rootDirectory.create(recursive: true);
    }
    return rootDirectory.path;
  }

  @override
  Future<String> getTemporaryDirectoryPath() async {
    final tempDir = _temporaryDirectory ??
        Directory(
          '${_trimTrailingSeparator(rootDirectory.path)}${Platform.pathSeparator}tmp',
        );
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir.path;
  }

  @override
  Future<String> saveExportedBytes(String fileName, Uint8List bytes) async {
    final dirPath = await getDocumentsDirectoryPath();
    final sanitized = fileName
        .replaceAll('..', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final safeName = sanitized.isEmpty ? 'export.bin' : sanitized;
    final file = File(
      '${_trimTrailingSeparator(dirPath)}${Platform.pathSeparator}$safeName',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
