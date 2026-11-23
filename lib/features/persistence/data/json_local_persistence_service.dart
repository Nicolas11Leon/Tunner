import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/logging/domain/i_studio_logger.dart';
import '../../../core/logging/infrastructure/studio_debug_logger.dart';
import 'atomic_json_file_persistence_service.dart';

/// Adaptador Flutter de infraestructura para persistencia local offline atomica en JSON.
///
/// Delega toda la logica de E/S atomica en [AtomicJsonFilePersistenceService] (Pure Dart)
/// e inyecta por defecto `getApplicationDocumentsDirectory()` y [StudioDebugLogger].
class JsonLocalPersistenceService extends AtomicJsonFilePersistenceService {
  JsonLocalPersistenceService({
    Future<String> Function()? documentsPathProvider,
    super.fileName = 'tunner_settings.json',
    IStudioLogger? logger,
  }) : super(
          directoryPathProvider: documentsPathProvider ?? _defaultDocumentsPath,
          logger: logger ?? StudioDebugLogger.instance,
        );

  static Future<String> _defaultDocumentsPath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } catch (_) {
      // Fallback seguro para entornos de prueba o terminales
      return Directory.systemTemp.path;
    }
  }
}
