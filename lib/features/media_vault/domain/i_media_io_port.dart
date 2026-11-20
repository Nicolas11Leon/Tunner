import 'dart:typed_data';

import 'media_asset_entity.dart';
import 'media_synergy_target.dart';
import 'timeline_project_entity.dart';

/// Abstract port for importing and exporting multimedia assets and timeline
/// arrangements without coupling domain logic to file system or UI plugins.
abstract class IMediaIoService {
  Future<MediaImportResult> importBytes({
    required String fileName,
    required Uint8List bytes,
  });

  Future<MediaExportResult> exportTimeline({
    required TimelineProjectEntity project,
    required Map<String, MediaAssetEntity> assetsById,
    required MediaExportFormat format,
  });
}

/// Abstract repository managing the Multimedia Vault catalog.
abstract class IMediaVaultRepository {
  List<MediaAssetEntity> getAll();
  MediaAssetEntity? findById(String id);
  void upsert(MediaAssetEntity asset);
  void upsertAll(List<MediaAssetEntity> assets);
  void remove(String id);
  void clear();
}

/// Implementación nula / no-op para entornos sin orquestador configurado.
class NoOpMediaIoService implements IMediaIoService {
  const NoOpMediaIoService();

  @override
  Future<MediaImportResult> importBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    return const MediaImportResult(
      success: false,
      message: 'No media io service configured',
    );
  }

  @override
  Future<MediaExportResult> exportTimeline({
    required TimelineProjectEntity project,
    required Map<String, MediaAssetEntity> assetsById,
    required MediaExportFormat format,
  }) async {
    return MediaExportResult(
      bytes: Uint8List(0),
      fileName: '',
      success: false,
      message: 'No media io service configured',
    );
  }
}
