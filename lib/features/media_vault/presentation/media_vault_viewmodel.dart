import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/file_system/domain/i_platform_file_gateway.dart';
import '../../../core/file_system/domain/studio_file_system_repository.dart';
import '../../../core/logging/infrastructure/studio_debug_logger.dart';
import '../domain/in_memory_media_vault_repository.dart';
import '../domain/i_media_io_port.dart';
import '../domain/media_asset_entity.dart';
import '../domain/media_synergy_target.dart';
import '../domain/timeline_project_entity.dart';

/// Presentation ViewModel coordinating the Multimedia Vault catalog,
/// synchronized multi-track timeline, universal import/export, and
/// decoupled dispatch toward other Tunner tools.
class MediaVaultViewModel extends ChangeNotifier {
  final IMediaVaultRepository _repository;
  final IMediaIoService _ioService;
  final IPlatformFileGateway? _fileGateway;
  final StudioFileSystemRepository? _fileSystemRepository;
  final void Function(MediaAssetEntity asset, MediaSynergyTarget target)?
      onDispatchToTool;

  TimelineProjectEntity _timeline;
  String _searchQuery = '';
  MediaAssetKind? _kindFilter;
  double _pixelsPerSecond = 80.0;
  int _playheadMs = 0;
  bool _isPlaying = false;
  Timer? _playTimer;
  bool _isDisposed = false;
  String _statusMessage = 'Boveda Multimedia lista (100% Offline).';
  MediaExportResult? _lastExportResult;
  int _clipSequence = 0;

  MediaVaultViewModel({
    IMediaVaultRepository? repository,
    IMediaIoService? ioService,
    IPlatformFileGateway? fileGateway,
    StudioFileSystemRepository? fileSystemRepository,
    TimelineProjectEntity? initialTimeline,
    this.onDispatchToTool,
  })  : _repository = repository ?? InMemoryMediaVaultRepository(),
        _ioService = ioService ?? const NoOpMediaIoService(),
        _fileGateway = fileGateway,
        _fileSystemRepository = fileSystemRepository,
        _timeline = initialTimeline ?? TimelineProjectEntity.defaultWorkspace();

  /// Abre el selector de archivos nativo de forma desacoplada e importa los bytes a la boveda.
  Future<bool> pickAndImportFile({IPlatformFileGateway? gateway}) async {
    try {
      final gw = gateway ?? _fileGateway;
      if (gw == null) return false;
      final file = await gw.pickFile(
        allowedExtensions: const <String>[
          'wav',
          'mid',
          'midi',
          'musicxml',
          'xml',
          'mxl',
          'abc',
          'pdf',
          'json',
        ],
      );
      if (file == null || file.bytes == null) {
        return false;
      }
      final result = await importExternalBytes(
        fileName: file.name,
        bytes: file.bytes!,
      );
      return result.success;
    } catch (e) {
      StudioDebugLogger.instance.warning('MediaVaultViewModel', 'Error en seleccion de archivo: $e');
      return false;
    }
  }

  /// Exporta el timeline y lo persiste en disco sin dependencias directas de I/O en la UI.
  Future<String?> exportTimelineToDisk(
    MediaExportFormat format, {
    IPlatformFileGateway? gateway,
    StudioFileSystemRepository? repository,
  }) async {
    final result = await exportTimeline(format);
    if (!result.success) return null;
    try {
      final gw = gateway ?? _fileGateway;
      final repo = repository ?? _fileSystemRepository;
      if (gw == null || repo == null) return null;
      final dir = await gw.getDocumentsDirectoryPath();
      final path = '$dir/${result.fileName}';
      await repo.saveFile(relativePath: path, bytes: result.bytes);
      return path;
    } catch (e) {
      StudioDebugLogger.instance.warning('MediaVaultViewModel', 'Error guardando exportacion en disco: $e');
      return null;
    }
  }

  List<MediaAssetEntity> get allAssets => _repository.getAll();

  List<MediaAssetEntity> get filteredAssets => _repository
      .getAll()
      .where(
        (asset) => asset.matchesFilter(
          query: _searchQuery,
          kindFilter: _kindFilter,
        ),
      )
      .toList(growable: false);

  TimelineProjectEntity get timeline => _timeline;
  String get searchQuery => _searchQuery;
  MediaAssetKind? get kindFilter => _kindFilter;
  double get pixelsPerSecond => _pixelsPerSecond;
  int get playheadMs => _playheadMs;
  bool get isPlaying => _isPlaying;
  String get statusMessage => _statusMessage;
  MediaExportResult? get lastExportResult => _lastExportResult;

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setKindFilter(MediaAssetKind? kind) {
    _kindFilter = kind;
    notifyListeners();
  }

  void setZoom(double pixelsPerSecond) {
    _pixelsPerSecond = pixelsPerSecond.clamp(30.0, 240.0);
    notifyListeners();
  }

  void setMasterBpm(double bpm) {
    _timeline = _timeline.copyWith(masterBpm: bpm.clamp(40.0, 240.0));
    notifyListeners();
  }

  void toggleSnapToBeatgrid() {
    _timeline = _timeline.copyWith(snapToBeatgrid: !_timeline.snapToBeatgrid);
    notifyListeners();
  }

  void togglePlayback() {
    if (_isPlaying) {
      _stopTimer();
    } else {
      _isPlaying = true;
      // 30 FPS playhead step (~33 ms); zero busy-waiting.
      _playTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        final maxMs = _timeline.totalDurationMs > 0
            ? _timeline.totalDurationMs
            : 16000;
        _playheadMs = (_playheadMs + 33) % maxMs;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void stopPlayback() {
    _stopTimer();
    _playheadMs = 0;
    notifyListeners();
  }

  void _stopTimer() {
    _playTimer?.cancel();
    _playTimer = null;
    _isPlaying = false;
  }

  void registerAsset(MediaAssetEntity asset) {
    _repository.upsert(asset);
    _statusMessage = 'Activo "${asset.title}" guardado en la Boveda.';
    notifyListeners();
  }

  void removeAsset(String assetId) {
    _repository.remove(assetId);
    notifyListeners();
  }

  void dropAssetOnTrack({
    required MediaAssetEntity asset,
    required String trackId,
    int? dropMs,
  }) {
    _clipSequence++;
    final targetMs = dropMs ?? _playheadMs;
    _timeline = _timeline.placeAssetOnTrack(
      asset: asset,
      trackId: trackId,
      rawStartMs: targetMs,
      clipId: 'clip_${_clipSequence}_${asset.id}',
    );
    _statusMessage =
        'Clip "${asset.title}" anadido a la linea de tiempo.';
    notifyListeners();
  }

  void moveClip({
    required String trackId,
    required String clipId,
    required int newStartMs,
  }) {
    _timeline = _timeline.moveClip(
      trackId: trackId,
      clipId: clipId,
      rawStartMs: newStartMs,
    );
    notifyListeners();
  }

  void removeClip({
    required String trackId,
    required String clipId,
  }) {
    _timeline = _timeline.removeClip(trackId: trackId, clipId: clipId);
    notifyListeners();
  }

  void toggleTrackMute(String trackId) {
    _timeline = _timeline.toggleTrackMute(trackId);
    notifyListeners();
  }

  void toggleTrackSolo(String trackId) {
    _timeline = _timeline.toggleTrackSolo(trackId);
    notifyListeners();
  }

  Future<MediaImportResult> importExternalBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final result = await _ioService.importBytes(
      fileName: fileName,
      bytes: bytes,
    );
    if (result.success) {
      _repository.upsertAll(result.importedAssets);
    }
    _statusMessage = result.message;
    notifyListeners();
    return result;
  }

  Future<MediaExportResult> exportTimeline(MediaExportFormat format) async {
    final assetsMap = <String, MediaAssetEntity>{
      for (final asset in _repository.getAll()) asset.id: asset,
    };
    final result = await _ioService.exportTimeline(
      project: _timeline,
      assetsById: assetsMap,
      format: format,
    );
    _lastExportResult = result;
    _statusMessage = result.message;
    notifyListeners();
    return result;
  }

  void dispatchAssetToTool(
    MediaAssetEntity asset,
    MediaSynergyTarget target,
  ) {
    onDispatchToTool?.call(asset, target);
    _statusMessage =
        '"${asset.title}" sincronizado con ${target.displayName}.';
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _stopTimer();
    super.dispose();
  }
}
