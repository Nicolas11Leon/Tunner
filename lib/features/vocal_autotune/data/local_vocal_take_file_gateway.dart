import 'dart:io';
import 'dart:typed_data';

import '../../../core/file_system/domain/i_platform_file_gateway.dart';
import '../../../core/logging/domain/i_studio_logger.dart';
import '../domain/i_vocal_take_file_gateway.dart';

/// Adaptador de infraestructura en disco (`dart:io`) para leer tomas WAV
/// originales y guardar archivos derivados `*_autotuned.wav` en post-produccion.
class LocalVocalTakeFileGateway implements IVocalTakeFileGateway {
  final IPlatformFileGateway? _platformFileGateway;
  final IStudioLogger _logger;

  const LocalVocalTakeFileGateway({
    IPlatformFileGateway? platformFileGateway,
    IStudioLogger logger = const NoOpStudioLogger(),
  })  : _platformFileGateway = platformFileGateway,
        _logger = logger;

  @override
  Future<Uint8List?> readTakeBytes(String filePath) async {
    final trimmed = filePath.trim();
    if (trimmed.isEmpty) return null;
    final file = File(trimmed);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<String?> saveAutoTunedWavBytes({
    required String originalFilePath,
    required String takeId,
    required Uint8List bytes,
  }) async {
    final targetPath = await buildAutoTunedPath(
      originalFilePath: originalFilePath,
      takeId: takeId,
    );
    final outFile = File(targetPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile.path;
  }

  /// Calcula la ruta destino `*_autotuned.wav` junto al archivo original cuando
  /// dispone de directorio padre valido, o en el directorio de documentos/temporal.
  Future<String> buildAutoTunedPath({
    required String originalFilePath,
    required String takeId,
  }) async {
    final trimmed = originalFilePath.trim();
    if (trimmed.isNotEmpty) {
      final originalFile = File(trimmed);
      final parentPath = originalFile.parent.path;
      final segments = originalFile.uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final rawFileName = segments.isNotEmpty ? segments.last : '$takeId.wav';
      final dotIndex = rawFileName.lastIndexOf('.');
      final stem = dotIndex > 0 ? rawFileName.substring(0, dotIndex) : rawFileName;
      final safeStem = stem.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final outName = safeStem.endsWith('_autotuned')
          ? '$safeStem.wav'
          : '${safeStem}_autotuned.wav';

      if (parentPath.isNotEmpty && parentPath != '.') {
        return '$parentPath${Platform.pathSeparator}$outName';
      }
      final fallbackDir = await _resolveFallbackDirectory();
      return '$fallbackDir${Platform.pathSeparator}$outName';
    }

    final fallbackDir = await _resolveFallbackDirectory();
    final safeId = takeId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '$fallbackDir${Platform.pathSeparator}${safeId}_autotuned.wav';
  }

  Future<String> _resolveFallbackDirectory() async {
    final gateway = _platformFileGateway;
    if (gateway != null) {
      try {
        final docsPath = await gateway.getDocumentsDirectoryPath();
        if (docsPath.isNotEmpty) return docsPath;
      } catch (e, st) {
        _logger.warning(
          'LocalVocalTakeFileGateway',
          'Fallo al resolver directorio de documentos, usando temporal del sistema: $e',
          error: e,
          stackTrace: st,
        );
      }
    }
    return Directory.systemTemp.path;
  }
}
