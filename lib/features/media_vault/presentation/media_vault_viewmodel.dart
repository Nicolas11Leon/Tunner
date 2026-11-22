import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/audio/domain/i_studio_audio_engine.dart';
import '../../../core/file_system/domain/i_platform_file_gateway.dart';
import '../../../core/file_system/domain/studio_file_system_repository.dart';
import '../../../core/logging/infrastructure/studio_debug_logger.dart';
import '../../audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import '../domain/in_memory_media_vault_repository.dart';
import '../domain/i_media_io_port.dart';
import '../domain/media_asset_entity.dart';
import '../domain/media_synergy_target.dart';
import '../domain/timeline_project_entity.dart';
import '../domain/wav_pcm_codec.dart';

/// Presentation ViewModel coordinating the Multimedia Vault catalog,
/// synchronized multi-track timeline, universal import/export, and
/// decoupled dispatch toward other Tunner tools.
class MediaVaultViewModel extends ChangeNotifier {
  static const String catalogStorageRelativePath = 'media_vault/catalog_v1.json';

  final IMediaVaultRepository _repository;
  final IMediaIoService _ioService;
  final IPlatformFileGateway? _fileGateway;
  final StudioFileSystemRepository? _fileSystemRepository;
  final IStudioAudioEngine? _audioEngine;
  final IAudioSynthesizerService? _audioSynthesizer;
  void Function(MediaAssetEntity asset, MediaSynergyTarget target)?
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
    IStudioAudioEngine? audioEngine,
    IAudioSynthesizerService? audioSynthesizer,
    TimelineProjectEntity? initialTimeline,
    this.onDispatchToTool,
  })  : _repository = repository ?? InMemoryMediaVaultRepository(),
        _ioService = ioService ?? const NoOpMediaIoService(),
        _fileGateway = fileGateway,
        _fileSystemRepository = fileSystemRepository,
        _audioEngine = audioEngine,
        _audioSynthesizer = audioSynthesizer,
        _timeline = initialTimeline ?? TimelineProjectEntity.defaultWorkspace() {
    if (_fileSystemRepository != null) {
      unawaited(_restoreCatalogFromDisk());
    }
  }

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
      unawaited(_audioEngine?.stopAll());
    } else {
      _isPlaying = true;
      unawaited(_syncLiveAudioPlayback(fromMs: _playheadMs));
      // 30 FPS playhead step (~33 ms); zero busy-waiting.
      _playTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        final maxMs = _timeline.totalDurationMs > 0
            ? _timeline.totalDurationMs
            : 16000;
        final nextMs = (_playheadMs + 33) % maxMs;
        final looped = nextMs < _playheadMs;
        _playheadMs = nextMs;
        if (looped && _isPlaying) {
          unawaited(_syncLiveAudioPlayback(fromMs: 0));
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void stopPlayback() {
    _stopTimer();
    _playheadMs = 0;
    unawaited(_audioEngine?.stopAll());
    notifyListeners();
  }

  void _stopTimer() {
    _playTimer?.cancel();
    _playTimer = null;
    _isPlaying = false;
  }

  Future<void> _restartLiveAudioAtPlayhead() async {
    await _audioEngine?.stopAll();
    if (_isPlaying && !_isDisposed) {
      await _syncLiveAudioPlayback(fromMs: _playheadMs);
    }
  }

  Future<void> _syncLiveAudioPlayback({int fromMs = 0}) async {
    if (_isDisposed || _audioSynthesizer == null) return;
    final hasAudibleTrack = _timeline.tracks.any(
      (t) => t.clips.isNotEmpty && _timeline.isTrackAudible(t),
    );
    if (!hasAudibleTrack) {
      await _audioEngine?.stopAll();
      return;
    }

    final assetsMap = <String, MediaAssetEntity>{
      for (final asset in _repository.getAll()) asset.id: asset,
    };
    final result = await _ioService.exportTimeline(
      project: _timeline,
      assetsById: assetsMap,
      format: MediaExportFormat.wavMixdown,
    );
    if (!result.success || result.bytes.isEmpty || _isDisposed || !_isPlaying) {
      return;
    }

    var wavToPlay = result.bytes;
    if (fromMs > 0) {
      const codec = WavPcmCodec();
      final decoded = codec.decode(result.bytes);
      if (decoded != null && decoded.monoSamples.isNotEmpty) {
        final startSample = math.min(
          decoded.monoSamples.length - 1,
          ((fromMs / 1000.0) * decoded.sampleRate).round().clamp(0, decoded.monoSamples.length - 1),
        );
        final sliced = Float64List.sublistView(decoded.monoSamples, startSample);
        wavToPlay = codec.encodeMono16Bit(sliced, sampleRate: decoded.sampleRate);
      }
    }
    if (!_isDisposed && _isPlaying) {
      await _audioSynthesizer.playPcmWav(wavToPlay, volume: 0.85);
    }
  }

  Future<void> persistCatalogToDisk() async {
    final repo = _fileSystemRepository;
    if (repo == null) return;
    try {
      final payload = <String, dynamic>{
        'version': 1,
        'assets': _repository
            .getAll()
            .map((a) => a.toMetadataJson(includeRawBytes: true))
            .toList(growable: false),
      };
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
      await repo.saveFile(relativePath: catalogStorageRelativePath, bytes: bytes);
    } catch (e) {
      StudioDebugLogger.instance.warning(
        'MediaVaultViewModel',
        'Error persistiendo catalogo en disco: $e',
      );
    }
  }

  Future<void> _restoreCatalogFromDisk() async {
    final repo = _fileSystemRepository;
    if (repo == null) return;
    try {
      final bytes = await repo.readFile(catalogStorageRelativePath);
      if (bytes.isEmpty || _isDisposed) return;
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return;
      final list = decoded['assets'];
      if (list is! List) return;
      const codec = WavPcmCodec();
      final restored = <MediaAssetEntity>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          var entity = MediaAssetEntity.fromMetadataJson(item);
          if (entity.pcmSamples == null &&
              entity.rawBytes != null &&
              entity.extensionName.toLowerCase() == 'wav') {
            final wav = codec.decode(entity.rawBytes!);
            if (wav != null) {
              entity = entity.copyWith(
                pcmSamples: wav.monoSamples,
                waveformPeaks: entity.waveformPeaks.isEmpty
                    ? codec.extractPeaks(wav.monoSamples)
                    : entity.waveformPeaks,
              );
            }
          }
          restored.add(entity);
        }
      }
      if (restored.isNotEmpty && !_isDisposed) {
        _repository.upsertAll(restored);
        notifyListeners();
      }
    } catch (_) {
      // Catalogo aun no creado en disco; se conservan activos semilla.
    }
  }

  void registerAsset(MediaAssetEntity asset) {
    _repository.upsert(asset);
    _statusMessage = 'Activo "${asset.title}" guardado en la Boveda.';
    unawaited(persistCatalogToDisk());
    notifyListeners();
  }

  void removeAsset(String assetId) {
    _repository.remove(assetId);
    unawaited(persistCatalogToDisk());
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
    if (_isPlaying) {
      unawaited(_restartLiveAudioAtPlayhead());
    }
    notifyListeners();
  }

  void toggleTrackSolo(String trackId) {
    _timeline = _timeline.toggleTrackSolo(trackId);
    if (_isPlaying) {
      unawaited(_restartLiveAudioAtPlayhead());
    }
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
      if (result.restoredTimeline != null) {
        _timeline = result.restoredTimeline!;
      }
      unawaited(persistCatalogToDisk());
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
    unawaited(_audioEngine?.stopAll());
    super.dispose();
  }
}
