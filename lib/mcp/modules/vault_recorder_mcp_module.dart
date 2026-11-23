import 'dart:io';

import '../../features/media_vault/data/universal_media_io_service.dart';
import '../../features/media_vault/domain/i_media_io_port.dart';
import '../../features/media_vault/domain/media_asset_entity.dart';
import '../../features/media_vault/domain/media_synergy_target.dart';
import '../../features/practice_recorder/domain/multitrack_session_entity.dart';
import '../../features/practice_recorder/domain/practice_recording_entity.dart';
import '../../features/practice_recorder/domain/spectral_comparator_service.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing the Multimedia Vault (`MediaVaultHeadlessController`),
/// multi-track timeline arrangement and disk catalog persistence, and offline
/// Practice Recorder WAV take analysis (`OfflinePracticeTakeAnalyzer`) with
/// spectral comparison (`SpectralComparatorService`).
class VaultRecorderMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final IMediaIoService _mediaIoService;
  final SpectralComparatorService _spectralComparator;

  final List<PracticeRecordingEntity> _recordingsHistory = [];
  MultiTrackSessionEntity _session;
  int _takeSequenceCounter = 0;

  VaultRecorderMcpModule(
    this.facade, {
    IMediaIoService mediaIoService = const UniversalMediaIoService(),
    SpectralComparatorService spectralComparator =
        const SpectralComparatorService(),
    MultiTrackSessionEntity? initialSession,
  })  : _mediaIoService = mediaIoService,
        _spectralComparator = spectralComparator,
        _session = initialSession ??
            MultiTrackSessionEntity(
              id: 'headless_session_1',
              title: 'Headless Practice Session',
              createdAt: DateTime.now().toUtc(),
              bpm: 100,
            );

  @override
  String get moduleName => 'vault_recorder';

  MultiTrackSessionEntity get session => _session;
  List<PracticeRecordingEntity> get recordingsHistory =>
      List.unmodifiable(_recordingsHistory);

  @override
  void register(McpRegistry registry) {
    _registerResources(registry);
    _registerTools(registry);
    _registerPrompts(registry);
  }

  // ===========================================================================
  // Resources (4)
  // ===========================================================================

  void _registerResources(McpRegistry registry) {
    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://vault/assets',
        name: 'Media Vault Assets Catalog',
        description:
            'Indexed media assets in the Multimedia Vault (metadata only, without rawBytesBase64).',
        mimeType: 'application/json',
        reader: () async {
          final assets = facade.mediaVaultController.assets;
          return McpResourceContent.json(
            uri: 'tunner://vault/assets',
            data: {
              'count': assets.length,
              'assets': assets
                  .map((a) => a.toMetadataJson(includeRawBytes: false))
                  .toList(growable: false),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://vault/timeline',
        name: 'Media Vault Multi-Track Timeline',
        description:
            'Current multi-track timeline arrangement including tracks, clips, mute/solo state, beatgrid, and total duration.',
        mimeType: 'application/json',
        reader: () async {
          final project = facade.mediaVaultController.project;
          return McpResourceContent.json(
            uri: 'tunner://vault/timeline',
            data: {
              ...project.toJson(),
              'totalDurationMs': project.totalDurationMs,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://recorder/history',
        name: 'Practice Recorder History',
        description:
            'History of analyzed and registered practice recordings with duration and BPM metadata.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://recorder/history',
            data: {
              'count': _recordingsHistory.length,
              'recordings': _recordingsHistory
                  .map((r) => r.toMap())
                  .toList(growable: false),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://recorder/session',
        name: 'Multi-Track Practice Session',
        description:
            'Active multi-track practice session with analyzed takes, pitch deviation averages, spectral centroids, and A/B selection.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://recorder/session',
            data: _sessionSummaryToJson(_session),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tools (13)
  // ===========================================================================

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vault_import_file',
        description:
            'Imports a local WAV, MIDI, MusicXML, ABC, or .tunner.json file from the workspace into the Media Vault catalog.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'file_path': {'type': 'string'},
          },
          'required': ['file_path'],
        },
        handler: _handleVaultImportFile,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vault_search_assets',
        description:
            'Searches Media Vault assets by optional text query and MediaAssetKind filter.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'query': const {'type': 'string'},
            'kind': {
              'type': 'string',
              'enum': MediaAssetKind.values.map((e) => e.name).toList(),
            },
          },
        },
        handler: _handleVaultSearchAssets,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vault_remove_asset',
        description:
            'Removes an asset from the Media Vault catalog and strips clips referencing it from the timeline.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'asset_id': {'type': 'string'},
          },
          'required': ['asset_id'],
        },
        handler: _handleVaultRemoveAsset,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vault_place_clip',
        description:
            'Places a catalog asset onto a timeline track at start_ms with optional beatgrid quantization.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'asset_id': {'type': 'string'},
            'track_id': {'type': 'string'},
            'start_ms': {'type': 'integer', 'minimum': 0},
            'quantize': {'type': 'boolean'},
            'custom_clip_id': {'type': 'string'},
          },
          'required': ['asset_id', 'track_id', 'start_ms'],
        },
        handler: _handleVaultPlaceClip,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vault_move_clip',
        description:
            'Moves an existing clip on a timeline track to a new start position in milliseconds.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'track_id': {'type': 'string'},
            'clip_id': {'type': 'string'},
            'new_start_ms': {'type': 'integer', 'minimum': 0},
          },
          'required': ['track_id', 'clip_id', 'new_start_ms'],
        },
        handler: _handleVaultMoveClip,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vault_remove_clip',
        description: 'Removes a clip from a timeline track.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'track_id': {'type': 'string'},
            'clip_id': {'type': 'string'},
          },
          'required': ['track_id', 'clip_id'],
        },
        handler: _handleVaultRemoveClip,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vault_set_track_state',
        description:
            'Updates mute and solo state for a timeline track and returns its audibility.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'track_id': {'type': 'string'},
            'is_muted': {'type': 'boolean'},
            'is_solo': {'type': 'boolean'},
            'toggle_mute': {'type': 'boolean'},
            'toggle_solo': {'type': 'boolean'},
          },
          'required': ['track_id'],
        },
        handler: _handleVaultSetTrackState,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vault_export_timeline',
        description:
            'Exports the current timeline arrangement in wavMixdown, cueSheet, tunnerBundleJson, midi, musicXml, or abcNotation format to a sandboxed file path.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'format': {
              'type': 'string',
              'enum': MediaExportFormat.values.map((e) => e.name).toList(),
            },
            'output_path': const {'type': 'string'},
          },
          'required': const ['format', 'output_path'],
        },
        handler: _handleVaultExportTimeline,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vault_persist_catalog',
        description:
            'Persists the Media Vault catalog and timeline arrangement snapshot to a JSON file inside the workspace.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'output_path': {'type': 'string'},
            'include_raw_bytes': {'type': 'boolean'},
          },
          'required': ['output_path'],
        },
        handler: _handleVaultPersistCatalog,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vault_load_catalog',
        description:
            'Restores the Media Vault catalog and timeline arrangement from a previously persisted JSON file inside the workspace.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'file_path': {'type': 'string'},
          },
          'required': ['file_path'],
        },
        handler: _handleVaultLoadCatalog,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_recorder_analyze_wav_take',
        description:
            'Analyzes a local WAV file offline (without microphone) using NSDF pitch contour tracking and FFT spectral centroid estimation, producing a PracticeTakeEntity.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'file_path': {'type': 'string'},
            'take_name': {'type': 'string'},
            'take_id': {'type': 'string'},
            'add_to_session': {'type': 'boolean'},
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
          },
          'required': ['file_path', 'take_name'],
        },
        handler: _handleRecorderAnalyzeWavTake,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_recorder_compare_takes',
        description:
            'Compares two analyzed practice takes in the active session using SpectralComparatorService to compute pitch stability delta, in-tune percentages, spectral centroid delta, and pedagogical diagnosis.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'take_a_id': {'type': 'string'},
            'take_b_id': {'type': 'string'},
            'time_step_ms': {'type': 'integer', 'minimum': 10, 'maximum': 500},
            'include_points': {'type': 'boolean'},
          },
          'required': ['take_a_id', 'take_b_id'],
        },
        handler: _handleRecorderCompareTakes,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_recorder_manage_session_take',
        description:
            'Updates gain, mute, solo, or A/B comparison selection for a take inside the active multi-track practice session.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'take_id': {'type': 'string'},
            'gain': {'type': 'number', 'minimum': 0.0, 'maximum': 2.0},
            'is_muted': {'type': 'boolean'},
            'is_solo': {'type': 'boolean'},
            'select_as_take_a': {'type': 'boolean'},
            'select_as_take_b': {'type': 'boolean'},
          },
          'required': ['take_id'],
        },
        handler: _handleRecorderManageSessionTake,
      ),
    );
  }

  // ===========================================================================
  // Prompts (2)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'vault_arrange_and_export_mix',
        description:
            'Inspects Media Vault assets, arranges harmonically compatible clips on the timeline without collisions, and exports WAV mixdown and CUE sheet.',
        arguments: const [
          McpPromptArgument(
            name: 'arrangement_goal',
            description: 'Target arrangement structure or mood.',
            required: true,
          ),
          McpPromptArgument(
            name: 'output_prefix',
            description: 'Optional workspace filename prefix for exports (default vault_mix).',
          ),
        ],
        builder: (args) async {
          final goal = args['arrangement_goal']!;
          final prefix = (args['output_prefix']?.trim().isNotEmpty ?? false)
              ? args['output_prefix']!.trim()
              : 'vault_mix';
          return McpPromptResult(
            description: 'Guided workflow for Media Vault timeline arrangement and export.',
            messages: [
              McpPromptMessage.user(
                'Arrange and export a multi-track timeline for: $goal. '
                'Step 1: Read tunner://vault/assets and tunner://vault/timeline. '
                'Step 2: Select harmonically compatible assets by camelotKey and BPM, then place clips using tunner_vault_place_clip. '
                'Step 3: Configure track mute/solo states with tunner_vault_set_track_state if needed. '
                'Step 4: Export both wavMixdown to "${prefix}_mixdown.wav" and cueSheet to "$prefix.cue" using tunner_vault_export_timeline.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'practice_take_diagnostic_coach',
        description:
            'Analyzes two student WAV takes offline, runs spectral and intonation comparison, and produces a technical practice correction plan.',
        arguments: const [
          McpPromptArgument(
            name: 'take_a_path',
            description: 'Workspace WAV path for baseline Take A.',
            required: true,
          ),
          McpPromptArgument(
            name: 'take_b_path',
            description: 'Workspace WAV path for follow-up Take B.',
            required: true,
          ),
          McpPromptArgument(
            name: 'instrument',
            description: 'Optional instrument or vocal register context.',
          ),
        ],
        builder: (args) async {
          final takeAPath = args['take_a_path']!;
          final takeBPath = args['take_b_path']!;
          final instrument = args['instrument'];
          final instClause = instrument != null && instrument.trim().isNotEmpty
              ? ' for $instrument'
              : '';
          return McpPromptResult(
            description: 'Guided workflow for offline practice take acoustic coaching.',
            messages: [
              McpPromptMessage.user(
                'Evaluate two practice takes$instClause: "$takeAPath" (Take A) and "$takeBPath" (Take B). '
                'Step 1: Analyze both WAV files using tunner_recorder_analyze_wav_take with add_to_session=true. '
                'Step 2: Call tunner_recorder_compare_takes on the resulting take IDs. '
                'Step 3: Draft an objective technical improvement plan grounded in pitchStabilityDelta, inTunePercentageA/B, and centroidDeltaHz.',
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tool Handlers
  // ===========================================================================

  Future<McpToolResult> _handleVaultImportFile(
    Map<String, dynamic> args,
  ) async {
    final rawPath = _requireNonEmptyString(args, 'file_path');
    final resolvedPath = _resolveWorkspacePath(rawPath);
    final file = File(resolvedPath);
    if (!file.existsSync()) {
      throw McpException.fileNotFound('Media file not found: $rawPath');
    }

    final fileName = _extractFileName(resolvedPath);
    final bytes = file.readAsBytesSync();
    final result = await _mediaIoService.importBytes(
      fileName: fileName,
      bytes: bytes,
    );

    if (!result.success) {
      return McpToolResult.error(result.message);
    }

    if (result.importedAssets.isNotEmpty) {
      facade.mediaVaultController.registerAssets(result.importedAssets);
    }
    if (result.restoredTimeline != null) {
      facade.mediaVaultController.loadFromJson({
        'assets': facade.mediaVaultController.assets
            .map((a) => a.toMetadataJson(includeRawBytes: true))
            .toList(growable: false),
        'timeline': result.restoredTimeline!.toJson(),
      });
    }

    return McpToolResult.json({
      'success': true,
      'message': result.message,
      'restoredTimeline': result.restoredTimeline != null,
      'importedAssets': result.importedAssets
          .map((a) => a.toMetadataJson(includeRawBytes: false))
          .toList(growable: false),
    });
  }

  Future<McpToolResult> _handleVaultSearchAssets(
    Map<String, dynamic> args,
  ) async {
    final query = _optionalString(args, 'query') ?? '';
    final kindRaw = _optionalString(args, 'kind');
    final kindFilter = kindRaw != null ? _parseAssetKind(kindRaw) : null;

    final matches = facade.mediaVaultController.searchAssets(
      query: query,
      kindFilter: kindFilter,
    );

    return McpToolResult.json({
      'count': matches.length,
      'matches': matches
          .map((a) => a.toMetadataJson(includeRawBytes: false))
          .toList(growable: false),
    });
  }

  Future<McpToolResult> _handleVaultRemoveAsset(
    Map<String, dynamic> args,
  ) async {
    final assetId = _requireNonEmptyString(args, 'asset_id');
    final removed = facade.mediaVaultController.removeAsset(assetId);
    if (!removed) {
      throw McpException.invalidParams('Vault asset not found: "$assetId".');
    }
    return McpToolResult.json({
      'removedAssetId': assetId,
      'remainingCount': facade.mediaVaultController.assets.length,
    });
  }

  Future<McpToolResult> _handleVaultPlaceClip(Map<String, dynamic> args) async {
    final assetId = _requireNonEmptyString(args, 'asset_id');
    final trackId = _requireNonEmptyString(args, 'track_id');
    final startMs = _requireInt(args, 'start_ms');
    final quantize = _optionalBool(args, 'quantize');
    final customClipId = _optionalString(args, 'custom_clip_id');

    final ctrl = facade.mediaVaultController;
    final previousSnap = ctrl.project.snapToBeatgrid;
    if (quantize != null) {
      ctrl.setSnapToBeatgrid(quantize);
    }

    final clipId = ctrl.placeAssetOnTrack(
      assetId: assetId,
      trackId: trackId,
      rawStartMs: startMs,
      customClipId: customClipId,
    );

    if (quantize != null) {
      ctrl.setSnapToBeatgrid(previousSnap);
    }

    if (clipId == null) {
      throw McpException.invalidParams(
        'Cannot place clip: asset "$assetId" or track "$trackId" not found.',
      );
    }

    final track = ctrl.project.tracks.firstWhere((t) => t.trackId == trackId);
    final clip = track.clips.firstWhere((c) => c.clipId == clipId);

    return McpToolResult.json({
      'clipId': clip.clipId,
      'trackId': trackId,
      'assetId': clip.assetId,
      'resolvedStartMs': clip.startMs,
      'durationMs': clip.durationMs,
      'totalDurationMs': ctrl.project.totalDurationMs,
    });
  }

  Future<McpToolResult> _handleVaultMoveClip(Map<String, dynamic> args) async {
    final trackId = _requireNonEmptyString(args, 'track_id');
    final clipId = _requireNonEmptyString(args, 'clip_id');
    final newStartMs = _requireInt(args, 'new_start_ms');

    final ctrl = facade.mediaVaultController;
    final trackExists = ctrl.project.tracks.any((t) => t.trackId == trackId);
    if (!trackExists) {
      throw McpException.invalidParams('Timeline track not found: "$trackId".');
    }

    ctrl.moveClip(
      trackId: trackId,
      clipId: clipId,
      rawStartMs: newStartMs,
    );

    final track = ctrl.project.tracks.firstWhere((t) => t.trackId == trackId);
    final clip = track.clips.where((c) => c.clipId == clipId).firstOrNull;
    if (clip == null) {
      throw McpException.invalidParams(
        'Clip "$clipId" not found on track "$trackId".',
      );
    }

    return McpToolResult.json({
      'clipId': clip.clipId,
      'trackId': trackId,
      'resolvedStartMs': clip.startMs,
      'totalDurationMs': ctrl.project.totalDurationMs,
    });
  }

  Future<McpToolResult> _handleVaultRemoveClip(
    Map<String, dynamic> args,
  ) async {
    final trackId = _requireNonEmptyString(args, 'track_id');
    final clipId = _requireNonEmptyString(args, 'clip_id');

    final ctrl = facade.mediaVaultController;
    ctrl.removeClip(trackId: trackId, clipId: clipId);

    return McpToolResult.json({
      'removedClipId': clipId,
      'trackId': trackId,
      'totalDurationMs': ctrl.project.totalDurationMs,
    });
  }

  Future<McpToolResult> _handleVaultSetTrackState(
    Map<String, dynamic> args,
  ) async {
    final trackId = _requireNonEmptyString(args, 'track_id');
    final isMuted = _optionalBool(args, 'is_muted');
    final isSolo = _optionalBool(args, 'is_solo');
    final toggleMute = _optionalBool(args, 'toggle_mute') ?? false;
    final toggleSolo = _optionalBool(args, 'toggle_solo') ?? false;

    final ctrl = facade.mediaVaultController;
    if (!ctrl.project.tracks.any((t) => t.trackId == trackId)) {
      throw McpException.invalidParams('Timeline track not found: "$trackId".');
    }

    if (toggleMute) ctrl.toggleTrackMute(trackId);
    if (toggleSolo) ctrl.toggleTrackSolo(trackId);
    if (isMuted != null || isSolo != null) {
      ctrl.setTrackState(trackId, isMuted: isMuted, isSolo: isSolo);
    }

    final track = ctrl.project.tracks.firstWhere((t) => t.trackId == trackId);
    return McpToolResult.json({
      'trackId': track.trackId,
      'isMuted': track.isMuted,
      'isSolo': track.isSolo,
      'isAudible': ctrl.isTrackAudible(trackId),
    });
  }

  Future<McpToolResult> _handleVaultExportTimeline(
    Map<String, dynamic> args,
  ) async {
    final formatRaw = _requireNonEmptyString(args, 'format');
    final format = _parseExportFormat(formatRaw);
    final rawOutputPath = _requireNonEmptyString(args, 'output_path');
    final outputPath = _resolveWorkspacePath(rawOutputPath);

    final ctrl = facade.mediaVaultController;
    final assetsMap = <String, MediaAssetEntity>{
      for (final asset in ctrl.assets) asset.id: asset,
    };

    final result = await _mediaIoService.exportTimeline(
      project: ctrl.project,
      assetsById: assetsMap,
      format: format,
    );

    if (!result.success) {
      return McpToolResult.error(result.message);
    }

    final outFile = File(outputPath);
    if (!outFile.parent.existsSync()) {
      outFile.parent.createSync(recursive: true);
    }
    outFile.writeAsBytesSync(result.bytes, flush: true);

    return McpToolResult.json({
      'success': true,
      'format': format.name,
      'outputPath': outputPath,
      'fileName': result.fileName,
      'bytesWritten': result.bytes.length,
      'message': result.message,
    });
  }

  Future<McpToolResult> _handleVaultPersistCatalog(
    Map<String, dynamic> args,
  ) async {
    final rawOutputPath = _requireNonEmptyString(args, 'output_path');
    final outputPath = _resolveWorkspacePath(rawOutputPath);
    final includeRawBytes = _optionalBool(args, 'include_raw_bytes') ?? false;

    final file = File(outputPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    file.writeAsStringSync(
      facade.mediaVaultController.toJsonString(
        includeRawBytes: includeRawBytes,
      ),
      flush: true,
    );

    return McpToolResult.json({
      'outputPath': outputPath,
      'bytesWritten': file.lengthSync(),
      'assetsCount': facade.mediaVaultController.assets.length,
      'tracksCount': facade.mediaVaultController.project.tracks.length,
    });
  }

  Future<McpToolResult> _handleVaultLoadCatalog(
    Map<String, dynamic> args,
  ) async {
    final rawFilePath = _requireNonEmptyString(args, 'file_path');
    final resolvedPath = _resolveWorkspacePath(rawFilePath);

    final file = File(resolvedPath);
    if (!file.existsSync()) {
      throw McpException.fileNotFound('Catalog file not found: $rawFilePath');
    }

    try {
      final restored = facade.mediaVaultController.loadFromJsonString(
        file.readAsStringSync(),
      );
      if (!restored) {
        throw McpException.invalidParams(
          'Failed to parse Media Vault catalog JSON: $rawFilePath',
        );
      }
      return McpToolResult.json({
        'restored': true,
        'filePath': resolvedPath,
        'assetsCount': facade.mediaVaultController.assets.length,
        'tracksCount': facade.mediaVaultController.project.tracks.length,
        'totalDurationMs': facade.mediaVaultController.project.totalDurationMs,
      });
    } on FormatException catch (e) {
      throw McpException.invalidParams('Invalid catalog JSON: ${e.message}');
    }
  }

  Future<McpToolResult> _handleRecorderAnalyzeWavTake(
    Map<String, dynamic> args,
  ) async {
    final rawPath = _requireNonEmptyString(args, 'file_path');
    final takeName = _requireNonEmptyString(args, 'take_name');
    final customTakeId = _optionalString(args, 'take_id');
    final addToSession = _optionalBool(args, 'add_to_session') ?? true;
    final bpm = _optionalInt(args, 'bpm') ?? _session.bpm;

    final resolvedPath = _resolveWorkspacePath(rawPath);
    if (!File(resolvedPath).existsSync()) {
      throw McpException.fileNotFound('WAV take file not found: $rawPath');
    }

    _takeSequenceCounter++;
    final takeId = customTakeId ?? 'take_$_takeSequenceCounter';

    try {
      final report = facade.offlinePracticeTakeAnalyzer.analyzeWavBytesDetailed(
        File(resolvedPath).readAsBytesSync(),
        takeId: takeId,
        takeName: takeName,
        filePath: resolvedPath,
      );

      if (addToSession) {
        final updatedTakes = [
          ..._session.takes.where((t) => t.id != report.take.id),
          report.take,
        ];
        _session = _session.copyWith(
          bpm: bpm,
          takes: updatedTakes,
          selectedTakeAId: _session.selectedTakeAId ?? report.take.id,
          selectedTakeBId: updatedTakes.length >= 2
              ? report.take.id
              : _session.selectedTakeBId,
        );
        _recordingsHistory.add(
          PracticeRecordingEntity(
            id: report.take.id,
            filePath: resolvedPath,
            recordedAt: report.take.timestamp,
            duration: report.take.duration,
            songTitle: report.take.name,
            bpm: bpm,
            waveformPeaks: report.take.waveformPeaks,
          ),
        );
      }

      return McpToolResult.json({
        ...report.toJson(),
        'addedToSession': addToSession,
      });
    } on FormatException catch (e) {
      throw McpException.acousticError('Invalid WAV take format: ${e.message}');
    }
  }

  Future<McpToolResult> _handleRecorderCompareTakes(
    Map<String, dynamic> args,
  ) async {
    final takeAId = _requireNonEmptyString(args, 'take_a_id');
    final takeBId = _requireNonEmptyString(args, 'take_b_id');
    final timeStepMs = (_optionalInt(args, 'time_step_ms') ?? 50).clamp(10, 500);
    final includePoints = _optionalBool(args, 'include_points') ?? false;

    final takeA = _session.takes.where((t) => t.id == takeAId).firstOrNull;
    if (takeA == null) {
      throw McpException.invalidParams(
        'Take A not found in active session: "$takeAId".',
      );
    }
    final takeB = _session.takes.where((t) => t.id == takeBId).firstOrNull;
    if (takeB == null) {
      throw McpException.invalidParams(
        'Take B not found in active session: "$takeBId".',
      );
    }

    final result = _spectralComparator.compareTakes(
      takeA,
      takeB,
      timeStepMs: timeStepMs,
    );

    return McpToolResult.json(result.toMap(includePoints: includePoints));
  }

  Future<McpToolResult> _handleRecorderManageSessionTake(
    Map<String, dynamic> args,
  ) async {
    final takeId = _requireNonEmptyString(args, 'take_id');
    final gain = _optionalDouble(args, 'gain');
    final isMuted = _optionalBool(args, 'is_muted');
    final isSolo = _optionalBool(args, 'is_solo');
    final selectA = _optionalBool(args, 'select_as_take_a') ?? false;
    final selectB = _optionalBool(args, 'select_as_take_b') ?? false;

    final index = _session.takes.indexWhere((t) => t.id == takeId);
    if (index == -1) {
      throw McpException.invalidParams(
        'Take not found in active session: "$takeId".',
      );
    }

    final existing = _session.takes[index];
    final updatedTake = existing.copyWith(
      gain: gain?.clamp(0.0, 2.0),
      isMuted: isMuted,
      isSolo: isSolo,
    );

    final updatedTakes = List<PracticeTakeEntity>.from(_session.takes);
    updatedTakes[index] = updatedTake;

    _session = _session.copyWith(
      takes: updatedTakes,
      selectedTakeAId: selectA ? takeId : _session.selectedTakeAId,
      selectedTakeBId: selectB ? takeId : _session.selectedTakeBId,
    );

    return McpToolResult.json({
      'takeId': updatedTake.id,
      'name': updatedTake.name,
      'gain': updatedTake.gain,
      'isMuted': updatedTake.isMuted,
      'isSolo': updatedTake.isSolo,
      'selectedTakeAId': _session.selectedTakeAId,
      'selectedTakeBId': _session.selectedTakeBId,
    });
  }

  // ===========================================================================
  // Helpers & Sandbox Security
  // ===========================================================================

  Map<String, dynamic> _sessionSummaryToJson(MultiTrackSessionEntity session) {
    return {
      'id': session.id,
      'title': session.title,
      'createdAt': session.createdAt.toIso8601String(),
      'bpm': session.bpm,
      'selectedTakeAId': session.selectedTakeAId,
      'selectedTakeBId': session.selectedTakeBId,
      'takesCount': session.takes.length,
      'takes': session.takes
          .map(
            (t) => {
              'id': t.id,
              'name': t.name,
              'filePath': t.filePath,
              'durationMs': t.duration.inMilliseconds,
              'averagePitchDeviationCents': t.averagePitchDeviationCents,
              'averageSpectralCentroidHz': t.averageSpectralCentroidHz,
              'pitchSamplesCount': t.pitchTrack.length,
              'spectralSamplesCount': t.spectralTrack.length,
              'gain': t.gain,
              'isMuted': t.isMuted,
              'isSolo': t.isSolo,
            },
          )
          .toList(growable: false),
    };
  }

  String _resolveWorkspacePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      throw const McpException.invalidParams('Path must not be empty.');
    }
    if (trimmed.contains('\x00')) {
      throw McpException.securityViolation(
        'Null byte rejected in path: $rawPath',
      );
    }

    final normalized = trimmed.replaceAll('\\', '/');
    for (final segment in normalized.split('/')) {
      if (segment == '..') {
        throw McpException.securityViolation(
          'Path traversal sequence rejected: $rawPath',
        );
      }
    }

    final rootDir = facade.workspaceDirectory;
    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }
    final canonicalRoot = rootDir.resolveSymbolicLinksSync();

    final bool isAbsolute =
        normalized.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(normalized);
    final String candidatePath = isAbsolute
        ? trimmed
        : '$canonicalRoot${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}';

    var probe = Directory(candidatePath);
    final trailing = <String>[];
    while (!probe.existsSync() && probe.parent.path != probe.path) {
      trailing.add(probe.path.split(Platform.pathSeparator).last);
      probe = probe.parent;
    }
    final canonicalBase = probe.existsSync()
        ? probe.resolveSymbolicLinksSync()
        : probe.absolute.path;
    final canonicalTarget = trailing.isEmpty
        ? canonicalBase
        : '$canonicalBase${Platform.pathSeparator}${trailing.reversed.join(Platform.pathSeparator)}';

    final rootPrefix = canonicalRoot.endsWith(Platform.pathSeparator)
        ? canonicalRoot
        : '$canonicalRoot${Platform.pathSeparator}';
    if (!canonicalTarget.startsWith(rootPrefix)) {
      throw McpException.securityViolation(
        'Resolved path escapes workspace sandbox: $rawPath',
      );
    }
    return canonicalTarget;
  }

  static MediaAssetKind _parseAssetKind(String raw) {
    for (final k in MediaAssetKind.values) {
      if (k.name.toLowerCase() == raw.trim().toLowerCase()) {
        return k;
      }
    }
    throw McpException.invalidParams(
      'Invalid MediaAssetKind "$raw". Valid values: ${MediaAssetKind.values.map((e) => e.name).join(', ')}.',
    );
  }

  static MediaExportFormat _parseExportFormat(String raw) {
    for (final f in MediaExportFormat.values) {
      if (f.name.toLowerCase() == raw.trim().toLowerCase()) {
        return f;
      }
    }
    throw McpException.invalidParams(
      'Invalid MediaExportFormat "$raw". Valid values: ${MediaExportFormat.values.map((e) => e.name).join(', ')}.',
    );
  }

  static String _extractFileName(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx >= 0 ? normalized.substring(idx + 1) : normalized;
  }

  static String _requireNonEmptyString(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! String || v.trim().isEmpty) {
      throw McpException.invalidParams(
        'Parameter "$key" must be a non-empty string.',
      );
    }
    return v.trim();
  }

  static String? _optionalString(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! String) {
      throw McpException.invalidParams('Parameter "$key" must be a string.');
    }
    final trimmed = v.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _optionalDouble(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! num) {
      throw McpException.invalidParams('Parameter "$key" must be a number.');
    }
    return v.toDouble();
  }

  static int _requireInt(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! num) {
      throw McpException.invalidParams('Parameter "$key" must be an integer.');
    }
    return v.toInt();
  }

  static int? _optionalInt(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! num) {
      throw McpException.invalidParams('Parameter "$key" must be an integer.');
    }
    return v.toInt();
  }

  static bool? _optionalBool(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! bool) {
      throw McpException.invalidParams('Parameter "$key" must be a boolean.');
    }
    return v;
  }
}
