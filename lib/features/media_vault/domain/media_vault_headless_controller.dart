import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'i_media_io_port.dart';
import 'in_memory_media_vault_repository.dart';
import 'media_asset_entity.dart';
import 'media_synergy_target.dart';
import 'timeline_project_entity.dart';

/// Pure Dart headless controller for the Multimedia Vault and Timeline arrangement.
///
/// Manages the asset catalog, multi-track timeline clip sequencing, mute/solo state,
/// I/O import/export delegation, and JSON disk persistence without Flutter or `ChangeNotifier`.
class MediaVaultHeadlessController {
  final IMediaVaultRepository _repository;
  final IMediaIoService _mediaIoService;
  TimelineProjectEntity _project;
  int _clipSequenceCounter = 0;

  MediaVaultHeadlessController({
    IMediaVaultRepository? repository,
    IMediaIoService? mediaIoService,
    TimelineProjectEntity? initialProject,
  })  : _repository = repository ?? InMemoryMediaVaultRepository(),
        _mediaIoService = mediaIoService ?? const NoOpMediaIoService(),
        _project = initialProject ?? TimelineProjectEntity.defaultWorkspace() {
    _syncClipCounterFromProject();
  }

  IMediaVaultRepository get repository => _repository;
  TimelineProjectEntity get project => _project;

  /// All assets currently indexed in the vault catalog.
  List<MediaAssetEntity> get assets => _repository.getAll();

  /// Registers or updates an asset in the catalog.
  void registerAsset(MediaAssetEntity asset) {
    _repository.upsert(asset);
  }

  /// Registers or updates multiple assets in the catalog.
  void registerAssets(List<MediaAssetEntity> assets) {
    _repository.upsertAll(assets);
  }

  /// Looks up an asset by its unique ID.
  MediaAssetEntity? findAsset(String assetId) => _repository.findById(assetId);

  /// Removes an asset from the catalog and strips any timeline clips referencing it.
  bool removeAsset(String assetId) {
    final existed = _repository.findById(assetId) != null;
    if (!existed) return false;
    _repository.remove(assetId);
    final cleanedTracks = _project.tracks
        .map(
          (track) => track.copyWith(
            clips: track.clips
                .where((c) => c.assetId != assetId)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
    _project = _project.copyWith(tracks: cleanedTracks);
    return true;
  }

  /// Filters catalog assets by free-text query and optional [MediaAssetKind].
  List<MediaAssetEntity> searchAssets({
    String query = '',
    MediaAssetKind? kindFilter,
  }) {
    return _repository
        .getAll()
        .where((asset) => asset.matchesFilter(query: query, kindFilter: kindFilter))
        .toList(growable: false);
  }

  /// Clears all assets from the catalog and resets the timeline workspace.
  void clearAll() {
    _repository.clear();
    _project = TimelineProjectEntity.defaultWorkspace();
    _clipSequenceCounter = 0;
  }

  // --- Timeline Arrangement & Mute/Solo ---

  /// Places an asset from the catalog onto [trackId] at [rawStartMs], returning
  /// the generated clip ID (or null if the asset or track does not exist).
  String? placeAssetOnTrack({
    required String assetId,
    required String trackId,
    required int rawStartMs,
    String? customClipId,
  }) {
    final asset = _repository.findById(assetId);
    if (asset == null) return null;
    final hasTrack = _project.tracks.any((t) => t.trackId == trackId);
    if (!hasTrack) return null;

    _clipSequenceCounter++;
    final clipId = customClipId ?? 'clip_$_clipSequenceCounter';
    _project = _project.placeAssetOnTrack(
      asset: asset,
      trackId: trackId,
      rawStartMs: rawStartMs,
      clipId: clipId,
    );
    return clipId;
  }

  /// Moves a clip within [trackId] to [rawStartMs].
  void moveClip({
    required String trackId,
    required String clipId,
    required int rawStartMs,
  }) {
    _project = _project.moveClip(
      trackId: trackId,
      clipId: clipId,
      rawStartMs: rawStartMs,
    );
  }

  /// Removes a clip from [trackId].
  void removeClip({
    required String trackId,
    required String clipId,
  }) {
    _project = _project.removeClip(trackId: trackId, clipId: clipId);
  }

  /// Toggles mute state for [trackId].
  void toggleTrackMute(String trackId) {
    _project = _project.toggleTrackMute(trackId);
  }

  /// Toggles solo state for [trackId].
  void toggleTrackSolo(String trackId) {
    _project = _project.toggleTrackSolo(trackId);
  }

  /// Explicitly sets mute and/or solo flags on [trackId].
  void setTrackState(String trackId, {bool? isMuted, bool? isSolo}) {
    final updatedTracks = _project.tracks
        .map(
          (track) => track.trackId == trackId
              ? track.copyWith(
                  isMuted: isMuted ?? track.isMuted,
                  isSolo: isSolo ?? track.isSolo,
                )
              : track,
        )
        .toList(growable: false);
    _project = _project.copyWith(tracks: updatedTracks);
  }

  /// Returns whether [trackId] is currently audible given global mute/solo state.
  bool isTrackAudible(String trackId) {
    final track = _project.tracks.where((t) => t.trackId == trackId).firstOrNull;
    if (track == null) return false;
    return _project.isTrackAudible(track);
  }

  /// Updates the master BPM of the timeline project.
  void setMasterBpm(double bpm) {
    final safeBpm = bpm.isFinite ? bpm.clamp(40.0, 240.0) : 124.0;
    _project = _project.copyWith(masterBpm: safeBpm);
  }

  /// Enables or disables beatgrid quantization snapping.
  void setSnapToBeatgrid(bool enabled) {
    _project = _project.copyWith(snapToBeatgrid: enabled);
  }

  // --- Media I/O Delegation ---

  Future<MediaImportResult> importBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final result = await _mediaIoService.importBytes(
      fileName: fileName,
      bytes: bytes,
    );
    if (result.success) {
      if (result.importedAssets.isNotEmpty) {
        _repository.upsertAll(result.importedAssets);
      }
      if (result.restoredTimeline != null) {
        _project = result.restoredTimeline!;
        _syncClipCounterFromProject();
      }
    }
    return result;
  }

  Future<MediaExportResult> exportTimeline(MediaExportFormat format) {
    final assetsMap = <String, MediaAssetEntity>{
      for (final asset in _repository.getAll()) asset.id: asset,
    };
    return _mediaIoService.exportTimeline(
      project: _project,
      assetsById: assetsMap,
      format: format,
    );
  }

  // --- JSON Serialization & Disk Persistence ---

  /// Serializes the full catalog and timeline arrangement into a JSON map.
  Map<String, dynamic> toJson({bool includeRawBytes = false}) {
    return <String, dynamic>{
      'version': 1,
      'clipSequenceCounter': _clipSequenceCounter,
      'assets': _repository
          .getAll()
          .map((a) => a.toMetadataJson(includeRawBytes: includeRawBytes))
          .toList(growable: false),
      'timeline': _project.toJson(),
    };
  }

  String toJsonString({bool includeRawBytes = false}) =>
      jsonEncode(toJson(includeRawBytes: includeRawBytes));

  /// Restores the catalog and timeline state from a JSON map.
  void loadFromJson(Map<String, dynamic> json) {
    _repository.clear();
    final rawAssets = json['assets'] as List<dynamic>? ?? const [];
    final restoredAssets = rawAssets
        .whereType<Map<String, dynamic>>()
        .map(MediaAssetEntity.fromMetadataJson)
        .toList(growable: false);
    if (restoredAssets.isNotEmpty) {
      _repository.upsertAll(restoredAssets);
    }

    final rawTimeline = json['timeline'];
    if (rawTimeline is Map<String, dynamic>) {
      _project = TimelineProjectEntity.fromJson(rawTimeline);
    } else {
      _project = TimelineProjectEntity.defaultWorkspace();
    }

    final savedCounter = (json['clipSequenceCounter'] as num?)?.toInt();
    _syncClipCounterFromProject();
    if (savedCounter != null && savedCounter > _clipSequenceCounter) {
      _clipSequenceCounter = savedCounter;
    }
  }

  /// Persists the catalog and timeline JSON snapshot to [filePath] on disk.
  void saveToFile(String filePath, {bool includeRawBytes = false}) {
    final file = File(filePath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    file.writeAsStringSync(
      toJsonString(includeRawBytes: includeRawBytes),
      flush: true,
    );
  }

  /// Loads catalog and timeline state from a JSON file on disk.
  /// Returns `true` if the file existed and was restored, `false` otherwise.
  bool loadFromFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return false;
    final raw = file.readAsStringSync();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return false;
    loadFromJson(decoded);
    return true;
  }

  void _syncClipCounterFromProject() {
    int maxSeq = 0;
    for (final track in _project.tracks) {
      for (final clip in track.clips) {
        final match = RegExp(r'(\d+)$').firstMatch(clip.clipId);
        if (match != null) {
          final parsed = int.tryParse(match.group(1) ?? '');
          if (parsed != null && parsed > maxSeq) {
            maxSeq = parsed;
          }
        }
      }
    }
    _clipSequenceCounter = maxSeq;
  }
}
