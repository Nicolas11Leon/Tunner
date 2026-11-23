import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/logging/domain/i_studio_logger.dart';
import '../../../core/logging/infrastructure/studio_debug_logger.dart';
import 'dj_console_file_codec.dart';
import 'headless_dj_console_blueprint_storage_service.dart';

export '../domain/i_dj_console_blueprint_storage_service.dart';
export 'headless_dj_console_blueprint_storage_service.dart';

/// Adaptador Flutter para persistencia de consolas emuladas creadas por el usuario.
///
/// Delega en [HeadlessDjConsoleBlueprintStorageService] e inyecta por defecto
/// `getApplicationDocumentsDirectory()` (en plataformas no Web) y [StudioDebugLogger].
class DjConsoleBlueprintStorageService
    extends HeadlessDjConsoleBlueprintStorageService {
  DjConsoleBlueprintStorageService({
    super.initialStorage,
    super.codec = const DjConsoleFileCodec(),
    Future<String> Function()? documentsPathProvider,
    super.fileName = 'tunner_dj_blueprints.json',
    IStudioLogger? logger,
  }) : super(
          documentsPathProvider:
              documentsPathProvider ?? () => _defaultFlutterDocumentsPath(logger ?? StudioDebugLogger.instance),
          logger: logger ?? StudioDebugLogger.instance,
        );

  static Future<String?> _defaultFlutterDocumentsPath(
    IStudioLogger logger,
  ) async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } catch (e, st) {
      logger.warning(
        'DjConsoleBlueprintStorageService',
        'Error resolviendo directorio de documentos: $e',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
