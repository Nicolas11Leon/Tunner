import 'dart:io';

import '../../features/instrument/domain/instrument_profile_entity.dart';
import '../../features/mixer/domain/mixer_track_entity.dart';
import '../../features/modular_rack/domain/module_connection.dart';
import '../../features/project_format/data/local_project_storage_repository.dart';
import '../../features/project_format/domain/patchbay_routing_connection.dart';
import '../../features/project_format/domain/tunner_project_package.dart';
import '../../features/project_format/domain/tunner_tool_preset.dart';
import '../../features/sheet_music/domain/score_tree.dart';
import '../../features/song_library/domain/minus_one_orchestrator.dart';
import '../../features/song_library/domain/minus_one_session_entity.dart';
import '../../features/song_library/domain/song_decomposer_service.dart';
import '../../features/song_library/domain/song_package_entity.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing sandboxed `.tunner` project and `.tnt` tool
/// preset persistence, curated offline song library, stem decomposition,
/// instrument tessitura adaptation, and Minus-One ensemble session control.
///
/// Pure Dart: zero `package:flutter/` or `dart:ui` dependencies.
class ProjectLibraryMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final LocalProjectStorageRepository _storage;
  final MinusOneOrchestrator _minusOneOrchestrator;

  SongPackage? _activeSongPackage;
  MixerConsoleEntity _activeMixerConsole = MixerConsoleEntity.defaultSetup();
  MinusOneSessionEntity? _activeMinusOneSession;

  ProjectLibraryMcpModule({
    required this.facade,
    LocalProjectStorageRepository? storageRepository,
    MinusOneOrchestrator minusOneOrchestrator = const MinusOneOrchestrator(),
  })  : _storage = storageRepository ??
            LocalProjectStorageRepository(
              baseDirectoryPath: facade.workspaceDirectory.path,
            ),
        _minusOneOrchestrator = minusOneOrchestrator;

  @override
  String get moduleName => 'project_library';

  @override
  void register(McpRegistry registry) {
    _registerResources(registry);
    _registerTools(registry);
    _registerPrompts(registry);
  }

  // ---------------------------------------------------------------------------
  // Resources
  // ---------------------------------------------------------------------------

  void _registerResources(McpRegistry registry) {
    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://project/active',
        name: 'Active Tunner Project',
        description:
            'Serialized state of the currently loaded .tunner project package in session.',
        mimeType: 'application/json',
        reader: () async {
          final project = facade.activeProject;
          if (project == null) {
            return McpResourceContent.json(
              uri: 'tunner://project/active',
              data: const {
                'hasActiveProject': false,
                'project': null,
              },
            );
          }
          return McpResourceContent.json(
            uri: 'tunner://project/active',
            data: {
              'hasActiveProject': true,
              ...project.toJson(),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://projects/workspace',
        name: 'Workspace Projects and Presets',
        description:
            'Lists .tunner project packages and .tnt tool presets inside the authorized workspace directory.',
        mimeType: 'application/json',
        reader: () async {
          final workspaceRoot = facade.workspaceDirectory.absolute.path;
          final projectPaths = await _storage.listProjects(
            directoryPath: workspaceRoot,
          );

          final projects = <Map<String, dynamic>>[];
          for (final fullPath in projectPaths) {
            final file = File(fullPath);
            if (!await file.exists()) continue;
            final stat = await file.stat();
            projects.add({
              'fileName': _baseName(fullPath),
              'relativePath': _toRelativePath(workspaceRoot, fullPath),
              'sizeBytes': stat.size,
              'modifiedAt': stat.modified.toUtc().toIso8601String(),
            });
          }

          final presets = <Map<String, dynamic>>[];
          final rootDir = Directory(workspaceRoot);
          if (await rootDir.exists()) {
            await for (final entity
                in rootDir.list(recursive: true, followLinks: false)) {
              if (entity is File &&
                  entity.path.toLowerCase().endsWith('.tnt')) {
                final stat = await entity.stat();
                presets.add({
                  'fileName': _baseName(entity.path),
                  'relativePath': _toRelativePath(workspaceRoot, entity.path),
                  'sizeBytes': stat.size,
                  'modifiedAt': stat.modified.toUtc().toIso8601String(),
                });
              }
            }
          }
          presets.sort(
            (a, b) => (a['relativePath'] as String)
                .compareTo(b['relativePath'] as String),
          );

          return McpResourceContent.json(
            uri: 'tunner://projects/workspace',
            data: {
              'workspaceRoot': workspaceRoot,
              'projects': projects,
              'presets': presets,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://library/curated',
        name: 'Curated Offline Song Library',
        description:
            'Built-in curated song packages returned by SongDecomposerService.getCuratedLibrary().',
        mimeType: 'application/json',
        reader: () async {
          final songs = SongDecomposerService.getCuratedLibrary();
          return McpResourceContent.json(
            uri: 'tunner://library/curated',
            data: {
              'songs': songs
                  .map(
                    (s) => {
                      'id': s.id,
                      'title': s.title,
                      'composer': s.composer,
                      'genre': s.genre.name,
                      'difficulty': s.difficulty.name,
                      'defaultBpm': s.defaultBpm,
                      'totalMeasures': s.totalMeasures,
                      'timeSignature': s.initialTimeSignature.toString(),
                      'tracks': s.tracks
                          .map((t) => t.toMap())
                          .toList(growable: false),
                    },
                  )
                  .toList(growable: false),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://library/templates',
        name: 'Song Decomposition Templates',
        description:
            'Ready-to-decompose melody templates from SongDecomposerService.getDecompositionTemplates().',
        mimeType: 'application/json',
        reader: () async {
          final templates = SongDecomposerService.getDecompositionTemplates();
          return McpResourceContent.json(
            uri: 'tunner://library/templates',
            data: {
              'templates': templates
                  .map(
                    (t) => {
                      'title': t.title,
                      'composer': t.composer,
                      'genre': t.genre.name,
                      'difficulty': t.difficulty.name,
                      'bpm': t.bpm,
                      'timeSignature': t.timeSignature.toString(),
                      'melodyNotation': t.melodyNotation,
                    },
                  )
                  .toList(growable: false),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://minus-one/session',
        name: 'Active Minus-One Session',
        description:
            'State and pedagogical metrics of the active Minus-One practice ensemble session.',
        mimeType: 'application/json',
        reader: () async {
          final session = _activeMinusOneSession;
          if (session == null) {
            return McpResourceContent.json(
              uri: 'tunner://minus-one/session',
              data: const {
                'hasActiveSession': false,
                'session': null,
              },
            );
          }
          return McpResourceContent.json(
            uri: 'tunner://minus-one/session',
            data: {
              'hasActiveSession': true,
              ..._serializeMinusOneSession(session),
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tools
  // ---------------------------------------------------------------------------

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_project_save',
        description:
            'Saves a binary .tunner project package safely inside the workspace directory, embedding the active score and modular rack configuration.',
        inputSchema: {
          'type': 'object',
          'required': ['relativePath'],
          'properties': {
            'relativePath': {'type': 'string'},
            'projectName': {'type': 'string'},
            'author': {'type': 'string'},
            'masterBpm': {'type': 'number', 'minimum': 20.0, 'maximum': 300.0},
            'referenceA4Hz': {
              'type': 'number',
              'minimum': 350.0,
              'maximum': 500.0,
            },
            'musicalKey': {'type': 'string'},
            'notes': {'type': 'string'},
          },
        },
        handler: _handleProjectSave,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_project_load',
        description:
            'Loads a binary .tunner project package from the workspace directory, updates active project state, and optionally loads its first embedded score.',
        inputSchema: {
          'type': 'object',
          'required': ['relativePath'],
          'properties': {
            'relativePath': {'type': 'string'},
            'loadFirstScore': {'type': 'boolean'},
          },
        },
        handler: _handleProjectLoad,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_tool_preset_save',
        description:
            'Saves a modular tool preset (.tnt) safely inside the workspace directory.',
        inputSchema: {
          'type': 'object',
          'required': ['relativePath', 'moduleTypeCode', 'customTitle'],
          'properties': {
            'relativePath': {'type': 'string'},
            'moduleTypeCode': {'type': 'string'},
            'customTitle': {'type': 'string'},
            'defaultViewMode': {'type': 'string'},
            'isPoweredOn': {'type': 'boolean'},
            'toolParameters': {'type': 'object'},
          },
        },
        handler: _handleToolPresetSave,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_tool_preset_load',
        description:
            'Loads a modular tool preset (.tnt) safely from the workspace directory.',
        inputSchema: {
          'type': 'object',
          'required': ['relativePath'],
          'properties': {
            'relativePath': {'type': 'string'},
          },
        },
        handler: _handleToolPresetLoad,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_library_load_song',
        description:
            'Loads a curated song package by songId into the active MCP session and updates the active score.',
        inputSchema: {
          'type': 'object',
          'required': ['songId'],
          'properties': {
            'songId': {'type': 'string'},
          },
        },
        handler: _handleLibraryLoadSong,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_song_decompose',
        description:
            'Parses melodyNotation and decomposes a song into Lead, Harmony/Piano, Bass, and Rhythm stems using SongDecomposerService.',
        inputSchema: {
          'type': 'object',
          'required': ['title', 'bpm', 'timeSignature', 'melodyNotation'],
          'properties': {
            'title': {'type': 'string'},
            'composer': {'type': 'string'},
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'timeSignature': {'type': 'string'},
            'melodyNotation': {'type': 'string'},
            'includeLead': {'type': 'boolean'},
            'includePiano': {'type': 'boolean'},
            'includeBass': {'type': 'boolean'},
            'includeRhythm': {'type': 'boolean'},
            'isMinorMode': {'type': 'boolean'},
          },
        },
        handler: _handleSongDecompose,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_song_adapt_instrument',
        description:
            'Adapts the active song/score (or a curated songId) to a target instrument tessitura from InstrumentProfileEntity.standardInstruments.',
        inputSchema: {
          'type': 'object',
          'required': ['instrumentId'],
          'properties': {
            'songId': {'type': 'string'},
            'instrumentId': {'type': 'string'},
          },
        },
        handler: _handleSongAdaptInstrument,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_minus_one_configure',
        description:
            'Configures a Minus-One practice ensemble session for the active song, detecting and muting/attenuating the user instrument track.',
        inputSchema: {
          'type': 'object',
          'required': ['activeInstrumentId'],
          'properties': {
            'activeInstrumentId': {'type': 'string'},
            'muteUserTrack': {'type': 'boolean'},
            'guideVolume': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
          },
        },
        handler: _handleMinusOneConfigure,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_minus_one_restore',
        description:
            'Restores the full ensemble mixer by unmuting userTrackId and setting its volume back to standardVolume.',
        inputSchema: {
          'type': 'object',
          'required': ['userTrackId'],
          'properties': {
            'userTrackId': {'type': 'string'},
            'standardVolume': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
          },
        },
        handler: _handleMinusOneRestore,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Prompts
  // ---------------------------------------------------------------------------

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'create_practice_arrangement_package',
        description:
            'Creates a multi-stem practice arrangement from melody notation, adapts it to a target instrument, configures Minus-One, and saves a .tunner project.',
        arguments: const [
          McpPromptArgument(
            name: 'title',
            description: 'Title of the arrangement.',
            required: true,
          ),
          McpPromptArgument(
            name: 'instrumentId',
            description: 'Target instrument ID (e.g. "flute", "violin", "cello").',
            required: true,
          ),
          McpPromptArgument(
            name: 'melodyNotation',
            description: 'Melody string (e.g. "Do4:4 Re4:4 Mi4:4 Fa4:4").',
            required: false,
          ),
          McpPromptArgument(
            name: 'projectPath',
            description: 'Workspace-relative .tunner file path.',
            required: false,
          ),
        ],
        builder: (args) async {
          final title = args['title']!.trim();
          final instrumentId = args['instrumentId']!.trim();
          final melody = (args['melodyNotation']?.trim().isNotEmpty ?? false)
              ? args['melodyNotation']!.trim()
              : 'Do4:4 Re4:4 Mi4:4 Fa4:4 | Sol4:8 Do4:8';
          final projectPath = (args['projectPath']?.trim().isNotEmpty ?? false)
              ? args['projectPath']!.trim()
              : 'projects/${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}.tunner';

          return McpPromptResult(
            description:
                'End-to-end arrangement decomposition, instrument adaptation, Minus-One setup, and .tunner archival.',
            messages: [
              McpPromptMessage.user(
                'Build a complete practice arrangement for "$title" targeting instrument "$instrumentId":\n'
                '1. Call `tunner_song_decompose` with `title: "$title"`, `bpm: 100`, `timeSignature: "4/4"`, `melodyNotation: "$melody"`, and all 4 stems enabled.\n'
                '2. Call `tunner_song_adapt_instrument` with `instrumentId: "$instrumentId"`.\n'
                '3. Call `tunner_minus_one_configure` with `activeInstrumentId: "$instrumentId"`.\n'
                '4. Call `tunner_project_save` with `relativePath: "$projectPath"` and `projectName: "$title"`.\n'
                '5. Verify persistence by reading `tunner://projects/workspace` and `tunner://project/active`.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'audit_tunner_project_file',
        description:
            'Loads an existing .tunner project file, inspects its rack modules, patchbay routing, tuning calibration, and embedded scores.',
        arguments: const [
          McpPromptArgument(
            name: 'relativePath',
            description: 'Workspace-relative path to the .tunner project file.',
            required: true,
          ),
        ],
        builder: (args) async {
          final relativePath = args['relativePath']!.trim();
          return McpPromptResult(
            description: 'Technical audit workflow for a .tunner project archive.',
            messages: [
              McpPromptMessage.user(
                'Audit the Tunner project at "$relativePath":\n'
                '1. Call `tunner_project_load` with `relativePath: "$relativePath"`.\n'
                '2. Read `tunner://project/active` to inspect `formatVersion`, `masterBpm`, `referenceA4Hz`, `tools`, `patchConnections`, and `songPackages`.\n'
                '3. If an embedded score was loaded, call `tunner_score_validate` to check metric integrity.\n'
                '4. Summarize any configuration anomalies, missing connections, or metric warnings.',
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tool Handlers
  // ---------------------------------------------------------------------------

  Future<McpToolResult> _handleProjectSave(Map<String, dynamic> args) async {
    final relativePath = (args['relativePath'] as String?)?.trim() ?? '';
    if (relativePath.isEmpty) {
      return McpToolResult.error(
        'Parameter "relativePath" must be a non-empty string.',
      );
    }

    final existing = facade.activeProject;
    final nowMicros = DateTime.now().microsecondsSinceEpoch;

    final projectName = (args['projectName'] as String?)?.trim().isNotEmpty == true
        ? (args['projectName'] as String).trim()
        : (existing?.projectName ??
            facade.activeScore?.title ??
            'Tunner Session Project');
    final author = (args['author'] as String?)?.trim().isNotEmpty == true
        ? (args['author'] as String).trim()
        : (existing?.author ?? 'Tunner Artist');
    final masterBpm = ((args['masterBpm'] as num?)?.toDouble() ??
            existing?.masterBpm ??
            facade.activeScore?.baseBpm.toDouble() ??
            120.0)
        .clamp(20.0, 300.0);
    final referenceA4Hz = ((args['referenceA4Hz'] as num?)?.toDouble() ??
            existing?.referenceA4Hz ??
            440.0)
        .clamp(350.0, 500.0);
    final musicalKey = (args['musicalKey'] as String?)?.trim().isNotEmpty == true
        ? (args['musicalKey'] as String).trim()
        : (existing?.musicalKey ?? 'C Major');
    final notes = (args['notes'] as String?) ?? existing?.notes ?? '';

    final rackModules = facade.modularRackController.activeModules;
    final tools = rackModules.isNotEmpty
        ? rackModules
            .map((m) => TunnerToolPreset.fromModule(m))
            .toList(growable: false)
        : (existing?.tools ?? const <TunnerToolPreset>[]);

    final rackConns = facade.modularRackController.activeConnections;
    final patchConnections = rackConns.isNotEmpty
        ? rackConns
            .map(
              (c) => PatchbayRoutingConnection(
                connectionId: c.connectionId,
                sourceModuleId: c.sourcePort.ownerModuleId,
                sourcePortId: c.sourcePort.id,
                destinationModuleId: c.destinationPort?.ownerModuleId,
                destinationPortId: c.destinationPort?.id,
                signalType: c.signalType,
                isBroadcast: c.scope == ConnectionScope.broadcast,
              ),
            )
            .toList(growable: false)
        : (existing?.patchConnections ?? const <PatchbayRoutingConnection>[]);

    final songPackages = <SongPackage>[];
    final activeScore = facade.activeScore;
    if (activeScore != null) {
      if (_activeSongPackage != null &&
          _activeSongPackage!.score.title == activeScore.title) {
        songPackages.add(_activeSongPackage!.copyWith(score: activeScore));
      } else {
        songPackages.add(
          SongPackage(
            id: 'score_$nowMicros',
            title: activeScore.title,
            composer: author,
            genre: MusicGenre.classical,
            difficulty: SongDifficulty.intermediate,
            defaultBpm: activeScore.baseBpm,
            score: activeScore,
            tracks: const [
              AudioTrack(
                id: 'main_score',
                title: 'Main Score',
                instrumentIcon: 'piano',
                volume: 0.9,
              ),
            ],
          ),
        );
      }
    } else if (existing != null) {
      songPackages.addAll(existing.songPackages);
    }

    final project = TunnerProjectPackage(
      formatVersion: existing?.formatVersion ?? 1,
      projectId: existing?.projectId ?? 'proj_$nowMicros',
      projectName: projectName,
      author: author,
      masterBpm: masterBpm,
      referenceA4Hz: referenceA4Hz,
      musicalKey: musicalKey,
      notes: notes,
      tools: tools,
      patchConnections: patchConnections,
      songPackages: songPackages,
      createdAtMicros: existing?.createdAtMicros ?? nowMicros,
      updatedAtMicros: nowMicros,
    );

    try {
      await _storage.saveProject(relativePath, project);
    } on FileSystemException catch (e) {
      if (e.message.contains('Path Traversal') ||
          e.message.contains('Acceso denegado')) {
        throw McpException.securityViolation(e.message);
      }
      return McpToolResult.error('Failed to save project: ${e.message}');
    }

    facade.setActiveProject(project);
    final savedFile = _resolveRelativeWorkspaceFile(relativePath);
    final sizeBytes = await savedFile.exists() ? await savedFile.length() : 0;

    return McpToolResult.json({
      'savedPath': savedFile.path,
      'relativePath': relativePath,
      'sizeBytes': sizeBytes,
      'formatVersion': project.formatVersion,
      'projectId': project.projectId,
      'projectName': project.projectName,
      'embeddedScoresCount': project.songPackages.length,
    });
  }

  Future<McpToolResult> _handleProjectLoad(Map<String, dynamic> args) async {
    final relativePath = (args['relativePath'] as String?)?.trim() ?? '';
    if (relativePath.isEmpty) {
      return McpToolResult.error(
        'Parameter "relativePath" must be a non-empty string.',
      );
    }
    final loadFirstScore = args['loadFirstScore'] as bool? ?? true;

    TunnerProjectPackage project;
    try {
      project = await _storage.loadProject(relativePath);
    } on FileSystemException catch (e) {
      if (e.message.contains('Path Traversal') ||
          e.message.contains('Acceso denegado')) {
        throw McpException.securityViolation(e.message);
      }
      throw McpException.fileNotFound(e.message);
    } on FormatException catch (e) {
      return McpToolResult.error('Invalid .tunner project file: ${e.message}');
    }

    facade.setActiveProject(project);
    if (loadFirstScore && project.songPackages.isNotEmpty) {
      _activeSongPackage = project.songPackages.first;
      facade.setActiveScore(project.songPackages.first.score);
    }

    return McpToolResult.json({
      'projectId': project.projectId,
      'projectName': project.projectName,
      'author': project.author,
      'formatVersion': project.formatVersion,
      'masterBpm': project.masterBpm,
      'referenceA4Hz': project.referenceA4Hz,
      'musicalKey': project.musicalKey,
      'toolsCount': project.tools.length,
      'patchConnectionsCount': project.patchConnections.length,
      'songPackagesCount': project.songPackages.length,
      'loadedScoreTitle': loadFirstScore && project.songPackages.isNotEmpty
          ? project.songPackages.first.score.title
          : null,
    });
  }

  Future<McpToolResult> _handleToolPresetSave(
    Map<String, dynamic> args,
  ) async {
    final relativePath = (args['relativePath'] as String?)?.trim() ?? '';
    final moduleTypeCode = (args['moduleTypeCode'] as String?)?.trim() ?? '';
    final customTitle = (args['customTitle'] as String?)?.trim() ?? '';
    if (relativePath.isEmpty ||
        moduleTypeCode.isEmpty ||
        customTitle.isEmpty) {
      return McpToolResult.error(
        'Parameters "relativePath", "moduleTypeCode", and "customTitle" are required.',
      );
    }

    final defaultViewMode =
        (args['defaultViewMode'] as String?)?.trim().isNotEmpty == true
            ? (args['defaultViewMode'] as String).trim()
            : 'expanded';
    final isPoweredOn = args['isPoweredOn'] as bool? ?? true;
    final rawParams = args['toolParameters'];
    final toolParameters = rawParams is Map<String, dynamic>
        ? rawParams
        : const <String, dynamic>{};

    final preset = TunnerToolPreset(
      moduleTypeCode: moduleTypeCode,
      customTitle: customTitle,
      defaultViewMode: defaultViewMode,
      isPoweredOn: isPoweredOn,
      toolParameters: toolParameters,
      savedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );

    try {
      await _storage.saveToolPreset(relativePath, preset);
    } on FileSystemException catch (e) {
      if (e.message.contains('Path Traversal') ||
          e.message.contains('Acceso denegado')) {
        throw McpException.securityViolation(e.message);
      }
      return McpToolResult.error('Failed to save tool preset: ${e.message}');
    }

    final savedFile = _resolveRelativeWorkspaceFile(relativePath);
    final sizeBytes = await savedFile.exists() ? await savedFile.length() : 0;

    return McpToolResult.json({
      'savedPath': savedFile.path,
      'relativePath': relativePath,
      'sizeBytes': sizeBytes,
      'moduleTypeCode': preset.moduleTypeCode,
      'customTitle': preset.customTitle,
    });
  }

  Future<McpToolResult> _handleToolPresetLoad(
    Map<String, dynamic> args,
  ) async {
    final relativePath = (args['relativePath'] as String?)?.trim() ?? '';
    if (relativePath.isEmpty) {
      return McpToolResult.error(
        'Parameter "relativePath" must be a non-empty string.',
      );
    }

    TunnerToolPreset preset;
    try {
      preset = await _storage.loadToolPreset(relativePath);
    } on FileSystemException catch (e) {
      if (e.message.contains('Path Traversal') ||
          e.message.contains('Acceso denegado')) {
        throw McpException.securityViolation(e.message);
      }
      throw McpException.fileNotFound(e.message);
    } on FormatException catch (e) {
      return McpToolResult.error('Invalid .tnt tool preset file: ${e.message}');
    }

    return McpToolResult.json(preset.toJson());
  }

  Future<McpToolResult> _handleLibraryLoadSong(
    Map<String, dynamic> args,
  ) async {
    final songId = (args['songId'] as String?)?.trim() ?? '';
    if (songId.isEmpty) {
      return McpToolResult.error('Parameter "songId" must be a non-empty string.');
    }

    final songs = SongDecomposerService.getCuratedLibrary();
    SongPackage? found;
    for (final s in songs) {
      if (s.id == songId) {
        found = s;
        break;
      }
    }
    if (found == null) {
      return McpToolResult.error(
        'Curated song "$songId" not found. Available IDs: ${songs.map((s) => s.id).join(', ')}.',
      );
    }

    _activeSongPackage = found;
    _activeMixerConsole = MixerConsoleEntity(
      metronomeTrack: _activeMixerConsole.metronomeTrack,
      stems: found.tracks,
    );
    facade.setActiveScore(found.score);

    return McpToolResult.json({
      'id': found.id,
      'title': found.title,
      'composer': found.composer,
      'defaultBpm': found.defaultBpm,
      'totalMeasures': found.totalMeasures,
      'tracks': found.tracks.map((t) => t.toMap()).toList(growable: false),
    });
  }

  Future<McpToolResult> _handleSongDecompose(Map<String, dynamic> args) async {
    final title = (args['title'] as String?)?.trim() ?? '';
    final melodyNotation = (args['melodyNotation'] as String?)?.trim() ?? '';
    if (title.isEmpty || melodyNotation.isEmpty) {
      return McpToolResult.error(
        'Parameters "title" and "melodyNotation" must be non-empty strings.',
      );
    }

    final composer = (args['composer'] as String?)?.trim() ?? 'Tunner Artist';
    final bpm = ((args['bpm'] as num?)?.toInt() ?? 100).clamp(20, 300);
    final ts = _parseTimeSignature(args['timeSignature'] as String?);
    if (ts == null) {
      return McpToolResult.error('Invalid "timeSignature".');
    }

    final includeLead = args['includeLead'] as bool? ?? true;
    final includePiano = args['includePiano'] as bool? ?? true;
    final includeBass = args['includeBass'] as bool? ?? true;
    final includeRhythm = args['includeRhythm'] as bool? ?? true;
    final isMinorMode = args['isMinorMode'] as bool?;

    final measures = SongDecomposerService.parseMelodyText(melodyNotation, ts);
    final package = SongDecomposerService.decomposeCustomScore(
      title: title,
      composer: composer,
      bpm: bpm,
      timeSignature: ts,
      measures: measures,
      includeLead: includeLead,
      includePiano: includePiano,
      includeBass: includeBass,
      includeRhythm: includeRhythm,
      isMinorMode: isMinorMode,
    );

    _activeSongPackage = package;
    _activeMixerConsole = MixerConsoleEntity(
      metronomeTrack: _activeMixerConsole.metronomeTrack,
      stems: package.tracks,
    );
    facade.setActiveScore(package.score);

    return McpToolResult.json({
      'id': package.id,
      'title': package.title,
      'composer': package.composer,
      'bpm': package.defaultBpm,
      'totalMeasures': package.totalMeasures,
      'tracks': package.tracks.map((t) => t.toMap()).toList(growable: false),
      'stemIds': package.stemScores.keys.toList(growable: false),
    });
  }

  Future<McpToolResult> _handleSongAdaptInstrument(
    Map<String, dynamic> args,
  ) async {
    final instrumentId = (args['instrumentId'] as String?)?.trim() ?? '';
    if (instrumentId.isEmpty) {
      return McpToolResult.error(
        'Parameter "instrumentId" must be a non-empty string.',
      );
    }

    final instrument = _findInstrumentById(instrumentId);
    if (instrument == null) {
      return McpToolResult.error(
        'Unknown instrumentId "$instrumentId". Examples: flute, violin, cello, guitar, grand_piano, bb_clarinet.',
      );
    }

    final songId = (args['songId'] as String?)?.trim();
    SongPackage? sourcePackage;
    if (songId != null && songId.isNotEmpty) {
      for (final s in SongDecomposerService.getCuratedLibrary()) {
        if (s.id == songId) {
          sourcePackage = s;
          break;
        }
      }
      if (sourcePackage == null) {
        return McpToolResult.error('Curated song "$songId" not found.');
      }
    } else if (_activeSongPackage != null) {
      sourcePackage = facade.activeScore != null
          ? _activeSongPackage!.copyWith(score: facade.activeScore!)
          : _activeSongPackage!;
    } else if (facade.activeScore != null) {
      final activeScore = facade.activeScore!;
      sourcePackage = SongPackage(
        id: 'active_score',
        title: activeScore.title,
        composer: 'Tunner Artist',
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.intermediate,
        defaultBpm: activeScore.baseBpm,
        score: activeScore,
        tracks: const [
          AudioTrack(
            id: 'lead_stem',
            title: 'Lead',
            instrumentIcon: 'music_note',
            volume: 0.9,
          ),
        ],
      );
    } else {
      return McpToolResult.error(
        'No active score/song in session and no "songId" provided.',
      );
    }

    final adapted = SongDecomposerService.adaptSongPackageToInstrument(
      sourcePackage,
      instrument,
    );

    int shiftedNotesCount = 0;
    final minMeasures = sourcePackage.score.measures.length <
            adapted.score.measures.length
        ? sourcePackage.score.measures.length
        : adapted.score.measures.length;
    for (int m = 0; m < minMeasures; m++) {
      final origNotes = sourcePackage.score.measures[m].notes;
      final newNotes = adapted.score.measures[m].notes;
      final count =
          origNotes.length < newNotes.length ? origNotes.length : newNotes.length;
      for (int i = 0; i < count; i++) {
        if (!origNotes[i].isRest &&
            origNotes[i].noteName != newNotes[i].noteName) {
          shiftedNotesCount++;
        }
      }
    }

    _activeSongPackage = adapted;
    _activeMixerConsole = MixerConsoleEntity(
      metronomeTrack: _activeMixerConsole.metronomeTrack,
      stems: adapted.tracks,
    );
    facade.setActiveScore(adapted.score);

    return McpToolResult.json({
      'id': adapted.id,
      'title': adapted.title,
      'adaptedInstrument': {
        'id': instrument.id,
        'name': instrument.name,
        'clef': instrument.clef.name,
        'transpositionSemitones': instrument.transpositionSemitones,
      },
      'totalMeasures': adapted.totalMeasures,
      'shiftedNotesCount': shiftedNotesCount,
      'preservedStemIds': adapted.stemScores.keys.toList(growable: false),
    });
  }

  Future<McpToolResult> _handleMinusOneConfigure(
    Map<String, dynamic> args,
  ) async {
    final activeInstrumentId =
        (args['activeInstrumentId'] as String?)?.trim() ?? '';
    if (activeInstrumentId.isEmpty) {
      return McpToolResult.error(
        'Parameter "activeInstrumentId" must be a non-empty string.',
      );
    }

    final pkg = _activeSongPackage;
    if (pkg == null) {
      return McpToolResult.error(
        'No active song package. Load a curated song or decompose a song first.',
      );
    }

    final muteUserTrack = args['muteUserTrack'] as bool? ?? true;
    final guideVolume =
        ((args['guideVolume'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);

    final userTrackId =
        _minusOneOrchestrator.detectUserTrack(pkg, activeInstrumentId);
    final accompaniment =
        _minusOneOrchestrator.getAccompanimentStems(pkg, userTrackId);

    _activeMixerConsole = MixerConsoleEntity(
      metronomeTrack: _activeMixerConsole.metronomeTrack,
      stems: pkg.tracks,
    );
    _activeMixerConsole = _minusOneOrchestrator.configureMinusOneMixer(
      _activeMixerConsole,
      userTrackId,
      muteUserTrack: muteUserTrack,
      guideVolume: guideVolume,
    );

    final session = _minusOneOrchestrator.createSession(
      package: pkg,
      userTrackId: userTrackId,
      isMinusOneActive: true,
      isMutedUserTrack: muteUserTrack,
      guideTrackVolume: guideVolume,
    );
    _activeMinusOneSession = session;

    return McpToolResult.json({
      'userTrackId': userTrackId,
      'isSingleTrackWork': _minusOneOrchestrator.isSingleTrackWork(pkg),
      'accompanimentTracks':
          accompaniment.map((t) => t.toMap()).toList(growable: false),
      'isMinusOneActive': session.isMinusOneActive,
      'session': _serializeMinusOneSession(session),
    });
  }

  Future<McpToolResult> _handleMinusOneRestore(
    Map<String, dynamic> args,
  ) async {
    final userTrackId = (args['userTrackId'] as String?)?.trim() ?? '';
    if (userTrackId.isEmpty) {
      return McpToolResult.error(
        'Parameter "userTrackId" must be a non-empty string.',
      );
    }
    final standardVolume =
        ((args['standardVolume'] as num?)?.toDouble() ?? 0.85).clamp(0.0, 1.0);

    _activeMixerConsole = _minusOneOrchestrator.restoreFullEnsembleMixer(
      _activeMixerConsole,
      userTrackId,
      standardVolume: standardVolume,
    );
    if (_activeMinusOneSession != null &&
        _activeMinusOneSession!.userTrackId == userTrackId) {
      _activeMinusOneSession = _activeMinusOneSession!.copyWith(
        isMinusOneActive: false,
        isMutedUserTrack: false,
        guideTrackVolume: standardVolume,
      );
    }

    return McpToolResult.json({
      'userTrackId': userTrackId,
      'muted': false,
      'volume': standardVolume,
      'isMinusOneActive': _activeMinusOneSession?.isMinusOneActive ?? false,
    });
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  File _resolveRelativeWorkspaceFile(String relativePath) {
    final base = facade.workspaceDirectory.absolute.path;
    final sep = Platform.pathSeparator;
    final isAbs = relativePath.startsWith('/') ||
        relativePath.startsWith(r'\') ||
        (relativePath.length >= 2 && relativePath[1] == ':');
    return File(isAbs ? relativePath : '$base$sep$relativePath');
  }

  static InstrumentProfileEntity? _findInstrumentById(String rawId) {
    final normalized = rawId.trim().toLowerCase();
    for (final inst in InstrumentProfileEntity.standardInstruments) {
      if (inst.id.toLowerCase() == normalized ||
          inst.name.toLowerCase() == normalized) {
        return inst;
      }
    }
    return null;
  }

  static Map<String, dynamic> _serializeMinusOneSession(
    MinusOneSessionEntity session,
  ) {
    return {
      'songId': session.songId,
      'userTrackId': session.userTrackId,
      'isMinusOneActive': session.isMinusOneActive,
      'isMutedUserTrack': session.isMutedUserTrack,
      'guideTrackVolume': session.guideTrackVolume,
      'totalNotesEvaluated': session.totalNotesEvaluated,
      'hitNotesCount': session.hitNotesCount,
      'accuracyPercentage': session.accuracyPercentage,
      'averageCentsDeviation': session.averageCentsDeviation,
      'rushingCount': session.rushingCount,
      'draggingCount': session.draggingCount,
      'onTimeCount': session.onTimeCount,
      'overallScore': session.overallScore,
      'sessionGrade': session.sessionGrade,
    };
  }

  static TimeSignature? _parseTimeSignature(String? raw) {
    if (raw == null || raw.trim().isEmpty) return TimeSignature.commonTime44;
    final parts = raw.trim().split('/');
    if (parts.length != 2) return null;
    final numVal = int.tryParse(parts[0].trim());
    final denVal = int.tryParse(parts[1].trim());
    if (numVal == null || denVal == null) return null;
    if (numVal < 1 || numVal > 32) return null;
    if (denVal != 1 && denVal != 2 && denVal != 4 && denVal != 8 && denVal != 16) {
      return null;
    }
    return TimeSignature(numVal, denVal);
  }

  static String _baseName(String path) {
    final sep = Platform.pathSeparator;
    final idx = path.lastIndexOf(sep);
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  static String _toRelativePath(String root, String fullPath) {
    final sep = Platform.pathSeparator;
    final normalizedRoot = root.endsWith(sep) ? root : '$root$sep';
    if (fullPath.startsWith(normalizedRoot)) {
      return fullPath.substring(normalizedRoot.length);
    }
    return fullPath;
  }
}
