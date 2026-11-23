import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/logging/domain/i_studio_logger.dart';
import '../../../core/logging/infrastructure/studio_debug_logger.dart';
import 'headless_dj_keymap_persistence_service.dart';

export '../domain/i_dj_keymap_persistence_service.dart';
export 'headless_dj_keymap_persistence_service.dart';

/// Flutter infrastructure adapter for persisting and restoring custom DJ keymaps.
///
/// Delegates storage to [HeadlessDjKeymapPersistenceService] and injects
/// `getApplicationDocumentsDirectory()` (on non-web platforms) and [StudioDebugLogger].
class DjKeymapPersistenceService extends HeadlessDjKeymapPersistenceService {
  DjKeymapPersistenceService({
    Future<String> Function()? documentsPathProvider,
    super.fileName = 'tunner_dj_keymap.json',
    super.initialJson,
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
        'DjKeymapPersistenceService',
        'Error resolviendo ruta documentos: $e',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
