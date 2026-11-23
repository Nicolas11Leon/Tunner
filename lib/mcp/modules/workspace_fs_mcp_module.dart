import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../core/design_system/domain/studio_theme_skin_entity.dart';
import '../../core/design_system/domain/studio_workspace_tab_spec.dart';
import '../../core/docking/domain/studio_dock_layout_entity.dart';
import '../../core/docking/domain/studio_dock_zone.dart';
import '../../core/file_system/domain/studio_file_system_node.dart';
import '../../core/file_system/domain/studio_file_system_repository.dart';
import '../../core/file_system/domain/studio_file_type.dart';
import '../../core/packaging/domain/tunner_package_exceptions.dart';
import '../../core/packaging/domain/tunner_project_manifest_entity.dart';
import '../../core/packaging/domain/tunner_project_package_entity.dart';
import '../../core/packaging/infrastructure/tunner_package_codec_service.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing sandboxed Workspace File System operations,
/// `.tunner` cryptographic project package encoding/decoding, and live UI
/// IPC synchronization for themes, docking layouts, and studio navigation tabs.
class WorkspaceFsMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final TunnerPackageCodecService _packageCodec;

  final List<StudioThemeSkinEntity> _availableSkins;
  String _activeSkinId;
  StudioDockLayoutEntity _dockLayout;
  StudioWorkspaceTabId _activeTabId;

  WorkspaceFsMcpModule(
    this.facade, {
    TunnerPackageCodecService packageCodec = const TunnerPackageCodecService(),
  })  : _packageCodec = packageCodec,
        _availableSkins = List<StudioThemeSkinEntity>.from(
          StudioThemeSkinEntity.defaultCatalog,
        ),
        _activeSkinId = StudioThemeSkinEntity.studioOledMonochrome.id,
        _dockLayout = StudioDockLayoutEntity.presetClubClassic(),
        _activeTabId = StudioWorkspaceTabId.home;

  @override
  String get moduleName => 'workspace_fs';

  StudioFileSystemRepository get _fsRepo => facade.root.fileSystemRepository;

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
        uri: 'tunner://workspace/tree',
        name: 'Workspace File Tree',
        description:
            'Complete hierarchical directory and file tree inside the sandboxed Tunner workspace.',
        mimeType: 'application/json',
        reader: () async {
          final rootFolder = await _fsRepo.loadRootWorkspace();
          return McpResourceContent.json(
            uri: 'tunner://workspace/tree',
            data: {
              'rootPath': facade.workspaceDirectory.path,
              'totalFilesCount': rootFolder.totalFilesCount,
              'root': _nodeToJson(rootFolder),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://ui/themes',
        name: 'Studio Theme Skins Catalog',
        description:
            'Catalog of available .tntheme studio skins and currently active skin identifier.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://ui/themes',
            data: {
              'activeSkinId': _activeSkinId,
              'count': _availableSkins.length,
              'skins':
                  _availableSkins.map((s) => s.toJson()).toList(growable: false),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://ui/docking/layout',
        name: 'Studio Docking Layout',
        description:
            'Current multi-panel DAW docking zone assignment, split ratios, and available presets.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://ui/docking/layout',
            data: _dockLayoutToJson(_dockLayout),
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://ui/navigation/tabs',
        name: 'Studio Navigation Tabs',
        description:
            'Canonical Tunner Studio workspace tabs and active tab identifier.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://ui/navigation/tabs',
            data: {
              'activeTabId': _activeTabId.id,
              'tabs': StudioWorkspaceTabSpec.canonicalTabs
                  .map(
                    (t) => {
                      'id': t.id,
                      'index': t.index,
                      'label': t.desktopLabel,
                      'shortcut': t.desktopShortcut,
                      'windowShortcut': t.windowShortcut,
                      'breadcrumb': t.breadcrumb,
                    },
                  )
                  .toList(growable: false),
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tools (10)
  // ===========================================================================

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_fs_list_workspace',
        description:
            'Lists the workspace file tree, optionally filtered case-insensitively by searchQuery.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'searchQuery': {'type': 'string'},
          },
        },
        handler: (args) async {
          final query = _optionalString(args, 'searchQuery')?.toLowerCase();
          final rootFolder = await _fsRepo.loadRootWorkspace();
          if (query == null || query.isEmpty) {
            return McpToolResult.json({
              'rootPath': facade.workspaceDirectory.path,
              'totalFilesCount': rootFolder.totalFilesCount,
              'root': _nodeToJson(rootFolder),
            });
          }

          final matches = <Map<String, dynamic>>[];
          _collectMatchingNodes(rootFolder, query, matches);
          return McpToolResult.json({
            'rootPath': facade.workspaceDirectory.path,
            'searchQuery': query,
            'matchCount': matches.length,
            'matches': matches,
          });
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_fs_read_file',
        description:
            'Reads a file from the sandboxed workspace as UTF-8 text or Base64.',
        inputSchema: {
          'type': 'object',
          'required': ['relativePath'],
          'properties': {
            'relativePath': {'type': 'string'},
            'asBase64': {'type': 'boolean', 'default': false},
          },
        },
        handler: (args) async {
          final rawPath = _requireNonEmptyString(args, 'relativePath');
          final asBase64 = (args['asBase64'] as bool?) ?? false;
          final cleanPath = _validateSafeRelativePath(rawPath);

          final Uint8List bytes;
          try {
            bytes = await _fsRepo.readFile(cleanPath);
          } on FileSystemException catch (e) {
            throw McpException.fileNotFound(
              'Workspace file not found: $cleanPath (${e.message})',
            );
          } on ArgumentError catch (e) {
            throw McpException.securityViolation(e.message.toString());
          }

          final fileName = cleanPath.split('/').last;
          final fileType = StudioFileType.fromFileName(fileName);
          String encoding;
          String content;
          if (asBase64) {
            encoding = 'base64';
            content = base64Encode(bytes);
          } else {
            try {
              content = utf8.decode(bytes);
              encoding = 'utf-8';
            } on FormatException {
              encoding = 'base64';
              content = base64Encode(bytes);
            }
          }

          return McpToolResult.json({
            'relativePath': cleanPath,
            'fileType': fileType.name,
            'encoding': encoding,
            'sizeBytes': bytes.lengthInBytes,
            'content': content,
          });
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_fs_write_file',
        description:
            'Creates or overwrites a file inside the sandboxed workspace using UTF-8 text or Base64 content.',
        inputSchema: {
          'type': 'object',
          'required': ['relativePath', 'content'],
          'properties': {
            'relativePath': {'type': 'string'},
            'content': {'type': 'string'},
            'isBase64': {'type': 'boolean', 'default': false},
          },
        },
        handler: (args) async {
          final rawPath = _requireNonEmptyString(args, 'relativePath');
          final rawContent = _requireString(args, 'content');
          final isBase64 = (args['isBase64'] as bool?) ?? false;
          final cleanPath = _validateSafeRelativePath(rawPath);

          final Uint8List bytes;
          if (isBase64) {
            try {
              bytes = Uint8List.fromList(base64Decode(rawContent));
            } on FormatException catch (e) {
              throw McpException.invalidParams(
                'Invalid Base64 content: ${e.message}',
              );
            }
          } else {
            bytes = Uint8List.fromList(utf8.encode(rawContent));
          }

          try {
            await _fsRepo.saveFile(relativePath: cleanPath, bytes: bytes);
          } on ArgumentError catch (e) {
            throw McpException.securityViolation(e.message.toString());
          }

          facade.emitIpcEvent('workspace.fs.changed', {
            'action': 'write',
            'relativePath': cleanPath,
          });

          return McpToolResult.json({
            'relativePath': cleanPath,
            'sizeBytes': bytes.lengthInBytes,
            'updated': true,
          });
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_fs_manage_node',
        description:
            'Manages workspace folders and files: create_folder, rename, move, or delete.',
        inputSchema: {
          'type': 'object',
          'required': ['action', 'relativePath'],
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['create_folder', 'rename', 'move', 'delete'],
            },
            'relativePath': {'type': 'string'},
            'targetPath': {'type': 'string'},
            'newName': {'type': 'string'},
          },
        },
        handler: (args) async {
          final action = _requireNonEmptyString(args, 'action').toLowerCase();
          final rawPath = _requireNonEmptyString(args, 'relativePath');
          final cleanPath = _validateSafeRelativePath(rawPath);

          String? resultingPath;
          try {
            switch (action) {
              case 'create_folder':
                await _fsRepo.createFolder(cleanPath);
                resultingPath = cleanPath;
              case 'rename':
                final newName = _requireNonEmptyString(args, 'newName');
                if (newName.contains('/') ||
                    newName.contains('\\') ||
                    newName == '..' ||
                    newName == '.') {
                  throw McpException.securityViolation(
                    'Invalid newName "$newName": path separators and traversal segments are forbidden.',
                  );
                }
                final segments = cleanPath.split('/');
                segments[segments.length - 1] = newName;
                final newRel = _validateSafeRelativePath(segments.join('/'));
                await _fsRepo.movePath(
                  oldRelativePath: cleanPath,
                  newRelativePath: newRel,
                );
                resultingPath = newRel;
              case 'move':
                final rawTarget = _requireNonEmptyString(args, 'targetPath');
                final cleanTarget = _validateSafeRelativePath(rawTarget);
                await _fsRepo.movePath(
                  oldRelativePath: cleanPath,
                  newRelativePath: cleanTarget,
                );
                resultingPath = cleanTarget;
              case 'delete':
                await _fsRepo.deletePath(cleanPath);
                resultingPath = null;
              default:
                throw McpException.invalidParams(
                  'Invalid action "$action". Expected create_folder, rename, move, or delete.',
                );
            }
          } on ArgumentError catch (e) {
            throw McpException.securityViolation(e.message.toString());
          }

          facade.emitIpcEvent('workspace.fs.changed', {
            'action': action,
            'relativePath': cleanPath,
            'resultingPath': ?resultingPath,
          });

          return McpToolResult.json({
            'action': action,
            'status': 'ok',
            'relativePath': cleanPath,
            'resultingPath': ?resultingPath,
          });
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_package_decode',
        description:
            'Decodes a .tunner project container in a background Isolate with optional SHA-256 cryptographic integrity verification.',
        inputSchema: {
          'type': 'object',
          'required': ['relativePath'],
          'properties': {
            'relativePath': {'type': 'string'},
            'verifyHashes': {'type': 'boolean', 'default': true},
          },
        },
        handler: (args) async {
          final rawPath = _requireNonEmptyString(args, 'relativePath');
          final verifyHashes = (args['verifyHashes'] as bool?) ?? true;
          final cleanPath = _validateSafeRelativePath(rawPath);

          final Uint8List packageBytes;
          try {
            packageBytes = await _fsRepo.readFile(cleanPath);
          } on FileSystemException catch (e) {
            throw McpException.fileNotFound(
              'Project package not found: $cleanPath (${e.message})',
            );
          }

          final TunnerProjectPackageEntity decoded;
          try {
            decoded = await _decodePackageInIsolate(
              _packageCodec,
              packageBytes,
              verifyHashes,
            );
          } on TunnerPackageCorruptedException catch (e) {
            throw McpException.securityViolation(
              'Package integrity/security check failed: $e',
              data: {
                'filePath': e.filePath,
                'expectedHash': e.expectedHash,
                'actualHash': e.actualHash,
              },
            );
          } on TunnerPackageInvalidFormatException catch (e) {
            throw McpException.invalidParams(
              'Invalid .tunner package format: ${e.message}',
            );
          }

          return McpToolResult.json({
            'relativePath': cleanPath,
            'integrityVerified': verifyHashes,
            'manifest': decoded.manifest.toJson(),
            'hasRoutingMatrix': decoded.hasRoutingMatrix,
            'hasScore': decoded.hasScore,
            'hasSynthPreset': decoded.hasSynthPreset,
            'hasDjSession': decoded.hasDjSession,
            'hasAudioFiles': decoded.hasAudioFiles,
            'totalAudioBytes': decoded.totalAudioBytes,
            'audioFiles': decoded.audioFiles.entries
                .map(
                  (e) => {
                    'name': e.key,
                    'sizeBytes': e.value.lengthInBytes,
                  },
                )
                .toList(growable: false),
            if (decoded.hasRoutingMatrix)
              'routingMatrixJson': decoded.routingMatrixJson,
            if (decoded.hasScore) 'scoreJson': decoded.scoreJson,
            if (decoded.hasSynthPreset)
              'synthPresetJson': decoded.synthPresetJson,
            if (decoded.hasDjSession) 'djSessionJson': decoded.djSessionJson,
          });
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_package_encode',
        description:
            'Encodes a canonical .tunner project container with SHA-256 signatures in a background Isolate and writes it into the workspace.',
        inputSchema: {
          'type': 'object',
          'required': ['outputRelativePath', 'manifest'],
          'properties': {
            'outputRelativePath': {'type': 'string'},
            'manifest': {'type': 'object'},
            'routingMatrixJson': {'type': 'object'},
            'scoreJson': {'type': 'object'},
            'synthPresetJson': {'type': 'object'},
            'djSessionJson': {'type': 'object'},
            'audioFilePaths': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
        },
        handler: (args) async {
          final rawOutput = _requireNonEmptyString(args, 'outputRelativePath');
          final cleanOutput = _validateSafeRelativePath(rawOutput);
          final rawManifest = args['manifest'];
          if (rawManifest is! Map<String, dynamic>) {
            throw const McpException.invalidParams(
              'Parameter "manifest" must be a JSON object.',
            );
          }

          final manifest = TunnerProjectManifestEntity.fromJson(rawManifest);
          final routingMatrixJson =
              _optionalJsonMap(args, 'routingMatrixJson');
          final scoreJson = _optionalJsonMap(args, 'scoreJson');
          final synthPresetJson = _optionalJsonMap(args, 'synthPresetJson');
          final djSessionJson = _optionalJsonMap(args, 'djSessionJson');

          final audioFiles = <String, Uint8List>{};
          final rawAudioPaths = args['audioFilePaths'];
          if (rawAudioPaths != null) {
            if (rawAudioPaths is! List) {
              throw const McpException.invalidParams(
                'Parameter "audioFilePaths" must be an array of strings.',
              );
            }
            for (final item in rawAudioPaths) {
              if (item is! String || item.trim().isEmpty) {
                throw const McpException.invalidParams(
                  'Every entry in "audioFilePaths" must be a non-empty string.',
                );
              }
              final cleanAudio = _validateSafeRelativePath(item);
              try {
                audioFiles[cleanAudio.split('/').last] =
                    await _fsRepo.readFile(cleanAudio);
              } on FileSystemException catch (e) {
                throw McpException.fileNotFound(
                  'Audio file not found for packaging: $cleanAudio (${e.message})',
                );
              }
            }
          }

          final packageEntity = TunnerProjectPackageEntity(
            manifest: manifest,
            routingMatrixJson: routingMatrixJson,
            scoreJson: scoreJson,
            synthPresetJson: synthPresetJson,
            djSessionJson: djSessionJson,
            audioFiles: audioFiles,
          );

          final encodedBytes = await _encodePackageInIsolate(
            _packageCodec,
            packageEntity,
          );
          await _fsRepo.saveFile(
            relativePath: cleanOutput,
            bytes: encodedBytes,
          );
          final finalManifest = _packageCodec.readManifest(encodedBytes);

          facade.emitIpcEvent('workspace.fs.changed', {
            'action': 'write',
            'relativePath': cleanOutput,
          });

          return McpToolResult.json({
            'outputRelativePath': cleanOutput,
            'sizeBytes': encodedBytes.lengthInBytes,
            'fileHashes': finalManifest.fileHashes,
          });
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_ui_set_theme',
        description:
            'Selects an active studio theme skin by skinId and emits the ui.theme.changed IPC event.',
        inputSchema: {
          'type': 'object',
          'required': ['skinId'],
          'properties': {
            'skinId': {'type': 'string'},
          },
        },
        handler: (args) async {
          final skinId = _requireNonEmptyString(args, 'skinId');
          final match = _availableSkins
              .where((s) => s.id == skinId)
              .cast<StudioThemeSkinEntity?>()
              .firstWhere((s) => s != null, orElse: () => null);
          if (match == null) {
            throw McpException.invalidParams(
              'Unknown skinId "$skinId". Available: ${_availableSkins.map((s) => s.id).join(", ")}.',
            );
          }

          _activeSkinId = match.id;
          facade.emitIpcEvent('ui.theme.changed', {
            'skinId': match.id,
            'skinJson': match.toJson(),
          });

          return McpToolResult.json({
            'activeSkinId': _activeSkinId,
            'skinName': match.name,
            'ipcBroadcastSent': facade.onIpcEvent != null,
          });
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_ui_import_theme',
        description:
            'Imports a custom .tntheme JSON definition, activates it, and emits ui.theme.imported / ui.theme.changed IPC events.',
        inputSchema: {
          'type': 'object',
          'required': ['themeJson'],
          'properties': {
            'themeJson': {'type': 'string'},
          },
        },
        handler: (args) async {
          final rawJson = _requireNonEmptyString(args, 'themeJson');
          final Map<String, dynamic> decoded;
          try {
            final parsed = jsonDecode(rawJson);
            if (parsed is! Map<String, dynamic>) {
              throw const FormatException('Theme JSON root must be an object.');
            }
            decoded = parsed;
          } on FormatException catch (e) {
            throw McpException.invalidParams(
              'Invalid themeJson payload: ${e.message}',
            );
          }

          final skin = StudioThemeSkinEntity.fromJson(decoded);
          _availableSkins.removeWhere((s) => s.id == skin.id);
          _availableSkins.add(skin);
          _activeSkinId = skin.id;

          final skinJson = skin.toJson();
          facade.emitIpcEvent('ui.theme.imported', {'skinJson': skinJson});
          facade.emitIpcEvent('ui.theme.changed', {
            'skinId': skin.id,
            'skinJson': skinJson,
          });

          return McpToolResult.json({
            'importedSkinId': skin.id,
            'activeSkinId': _activeSkinId,
            'ipcBroadcastSent': facade.onIpcEvent != null,
          });
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_ui_set_dock_layout',
        description:
            'Applies a docking layout preset, moves a panel to a target zone, and/or updates split ratios, emitting ui.docking.layout_changed.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'preset': {
              'type': 'string',
              'enum': [
                'default',
                'club_classic',
                'hardware_focus',
                'stems_studio',
                'three_columns',
              ],
            },
            'movePanel': {
              'type': 'object',
              'required': ['panelId', 'targetZone'],
              'properties': {
                'panelId': {'type': 'string'},
                'targetZone': {
                  'type': 'string',
                  'enum': ['left', 'center', 'right', 'bottom', 'floating'],
                },
              },
            },
            'ratios': {
              'type': 'object',
              'properties': {
                'left': {'type': 'number', 'minimum': 0.15, 'maximum': 0.60},
                'right': {'type': 'number', 'minimum': 0.15, 'maximum': 0.60},
                'bottom': {'type': 'number', 'minimum': 0.15, 'maximum': 0.60},
              },
            },
          },
        },
        handler: (args) async {
          final preset = _optionalString(args, 'preset')?.toLowerCase();
          final movePanel = _optionalJsonMap(args, 'movePanel');
          final ratios = _optionalJsonMap(args, 'ratios');

          if (preset == null && movePanel == null && ratios == null) {
            throw const McpException.invalidParams(
              'Provide at least one of "preset", "movePanel", or "ratios".',
            );
          }

          var nextLayout = _dockLayout;
          if (preset != null) {
            switch (preset) {
              case 'default':
                nextLayout = StudioDockLayoutEntity.defaultLayout();
              case 'club_classic':
                nextLayout = StudioDockLayoutEntity.presetClubClassic();
              case 'hardware_focus':
                nextLayout = StudioDockLayoutEntity.presetHardwareFocus();
              case 'stems_studio':
                nextLayout = StudioDockLayoutEntity.presetStemsStudio();
              case 'three_columns':
                nextLayout = StudioDockLayoutEntity.presetThreeColumns();
              default:
                throw McpException.invalidParams(
                  'Unknown docking preset "$preset".',
                );
            }
          }

          if (movePanel != null) {
            final panelId = _requireNonEmptyString(movePanel, 'panelId');
            final zoneStr =
                _requireNonEmptyString(movePanel, 'targetZone').toLowerCase();
            final targetZone = _parseDockZone(zoneStr);
            nextLayout = nextLayout.movePanel(panelId, targetZone);
          }

          if (ratios != null) {
            final left = _optionalDouble(ratios, 'left');
            final right = _optionalDouble(ratios, 'right');
            final bottom = _optionalDouble(ratios, 'bottom');
            nextLayout = nextLayout.updateRatio(
              left: left,
              right: right,
              bottom: bottom,
            );
          }

          _dockLayout = nextLayout;
          final payload = _dockLayoutToJson(_dockLayout);
          facade.emitIpcEvent('ui.docking.layout_changed', payload);
          return McpToolResult.json(payload);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_ui_navigate_tab',
        description:
            'Switches the active Tunner Studio workspace tab and emits the ui.navigation.tab_changed IPC event.',
        inputSchema: {
          'type': 'object',
          'required': ['tabId'],
          'properties': {
            'tabId': {
              'type': 'string',
              'enum': ['home', 'tuner', 'learning', 'studio', 'library', 'dj'],
            },
          },
        },
        handler: (args) async {
          final tabId = _requireNonEmptyString(args, 'tabId');
          final spec = StudioWorkspaceTabSpec.findById(tabId);
          if (spec == null) {
            throw McpException.invalidParams(
              'Unknown tabId "$tabId". Expected one of: home, tuner, learning, studio, library, dj.',
            );
          }

          _activeTabId = spec.tabId;
          final payload = {
            'tabId': spec.id,
            'index': spec.index,
            'label': spec.desktopLabel,
          };
          facade.emitIpcEvent('ui.navigation.tab_changed', payload);

          return McpToolResult.json({
            'activeTabId': spec.id,
            'index': spec.index,
            'label': spec.desktopLabel,
            'ipcBroadcastSent': facade.onIpcEvent != null,
          });
        },
      ),
    );
  }

  // ===========================================================================
  // Prompts (2)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_project_archive_audit',
        description:
            'Guides the agent to scan the workspace tree for .tunner project archives, verify SHA-256 integrity, and summarize manifest contents.',
        arguments: const [
          McpPromptArgument(
            name: 'packagePath',
            description:
                'Optional relative path of a specific .tunner archive to audit.',
            required: false,
          ),
        ],
        builder: (args) async {
          final packagePath = args['packagePath']?.trim();
          final targetText =
              packagePath != null && packagePath.isNotEmpty
                  ? 'target archive "$packagePath"'
                  : 'all .tunner archives found in tunner://workspace/tree';
          return McpPromptResult(
            description: 'Cryptographic integrity audit for .tunner packages.',
            messages: [
              McpPromptMessage.user(
                'Inspect tunner://workspace/tree and run tunner_package_decode(verifyHashes: true) on $targetText. '
                'Report SHA-256 integrity status, manifest metadata (title, author, BPM, sampleRate), and which components (score, routing matrix, synth preset, DJ session, audio stems) are present.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_workspace_layout_personalizer',
        description:
            'Guides the agent to inspect themes, docking layout, and navigation tabs to configure the workspace for a requested musical workflow.',
        arguments: const [
          McpPromptArgument(
            name: 'taskType',
            description:
                'Musical task (e.g., vocal_rehearsal, dj_mix, dsl_composition, mastering).',
            required: false,
          ),
        ],
        builder: (args) async {
          final taskType = args['taskType']?.trim().isNotEmpty == true
              ? args['taskType']!.trim()
              : 'studio_production';
          return McpPromptResult(
            description: 'Workspace visual layout personalizer for $taskType.',
            messages: [
              McpPromptMessage.user(
                'Read tunner://ui/themes, tunner://ui/docking/layout, and tunner://ui/navigation/tabs. '
                'Configure the studio UI for "$taskType" by calling tunner_ui_set_theme, tunner_ui_set_dock_layout, and tunner_ui_navigate_tab.',
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Helpers & Security Validation
  // ===========================================================================

  /// Validates that [rawPath] stays strictly inside the workspace sandbox
  /// (rejecting path traversal, drive letters, null bytes, and symlink escapes).
  String _validateSafeRelativePath(String rawPath) {
    final normalized = rawPath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) {
      throw const McpException.invalidParams(
        'Parameter "relativePath" must not be empty.',
      );
    }
    if (normalized.contains('\x00') ||
        RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
      throw McpException.securityViolation(
        'Path violates workspace sandbox policy: $rawPath',
      );
    }

    var clean = normalized;
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }

    final segments = clean.split('/');
    final safeSegments = <String>[];
    for (final seg in segments) {
      if (seg == '..' || seg == '.') {
        throw McpException.securityViolation(
          'Path traversal sequence rejected: $rawPath',
        );
      }
      if (seg.isNotEmpty) {
        safeSegments.add(seg);
      }
    }
    if (safeSegments.isEmpty) {
      throw const McpException.securityViolation(
        'Operating directly on workspace root is not allowed.',
      );
    }

    final joinedRel = safeSegments.join('/');
    final rootDir = facade.workspaceDirectory;
    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }
    final canonicalRoot = rootDir.resolveSymbolicLinksSync();
    final candidatePath =
        '$canonicalRoot${Platform.pathSeparator}${joinedRel.replaceAll('/', Platform.pathSeparator)}';

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

    if (!canonicalTarget.startsWith('$canonicalRoot${Platform.pathSeparator}')) {
      throw McpException.securityViolation(
        'Resolved path escapes workspace sandbox: $rawPath',
      );
    }

    return joinedRel;
  }

  Map<String, dynamic> _nodeToJson(StudioFileSystemNode node) {
    if (node is StudioFolderEntity) {
      return {
        'id': node.id,
        'name': node.name,
        'relativePath': node.relativePath,
        'isFolder': true,
        'fileType': 'folder',
        'modifiedAtMicros': node.modifiedAtMicros,
        'children': node.children.map(_nodeToJson).toList(growable: false),
      };
    }
    final file = node as StudioFileEntity;
    return {
      'id': file.id,
      'name': file.name,
      'relativePath': file.relativePath,
      'isFolder': false,
      'extension': file.extension,
      'fileType': file.fileType.name,
      'sizeBytes': file.sizeBytes,
      'modifiedAtMicros': file.modifiedAtMicros,
    };
  }

  void _collectMatchingNodes(
    StudioFileSystemNode node,
    String query,
    List<Map<String, dynamic>> out,
  ) {
    if (node.name.toLowerCase().contains(query) ||
        node.relativePath.toLowerCase().contains(query)) {
      if (node is StudioFileEntity) {
        out.add(_nodeToJson(node));
      } else if (node is StudioFolderEntity && node.relativePath != '/') {
        out.add({
          'id': node.id,
          'name': node.name,
          'relativePath': node.relativePath,
          'isFolder': true,
          'fileType': 'folder',
        });
      }
    }
    if (node is StudioFolderEntity) {
      for (final child in node.children) {
        _collectMatchingNodes(child, query, out);
      }
    }
  }

  Map<String, dynamic> _dockLayoutToJson(StudioDockLayoutEntity layout) {
    final zones = <String, List<String>>{};
    for (final zone in StudioDockZone.values) {
      zones[zone.name] = List<String>.from(layout.zonePanelIds[zone] ?? const []);
    }
    return {
      'zonePanelIds': zones,
      'leftSplitRatio': layout.leftSplitRatio,
      'rightSplitRatio': layout.rightSplitRatio,
      'bottomSplitRatio': layout.bottomSplitRatio,
      'presets': const [
        'default',
        'club_classic',
        'hardware_focus',
        'stems_studio',
        'three_columns',
      ],
    };
  }

  StudioDockZone _parseDockZone(String raw) {
    for (final zone in StudioDockZone.values) {
      if (zone.name == raw) return zone;
    }
    throw McpException.invalidParams(
      'Invalid targetZone "$raw". Expected left, center, right, bottom, or floating.',
    );
  }

  static Future<TunnerProjectPackageEntity> _decodePackageInIsolate(
    TunnerPackageCodecService codec,
    Uint8List packageBytes,
    bool verifyHashes,
  ) {
    return Isolate.run(
      () => codec.decodePackage(packageBytes, verifyHashes: verifyHashes),
    );
  }

  static Future<Uint8List> _encodePackageInIsolate(
    TunnerPackageCodecService codec,
    TunnerProjectPackageEntity packageEntity,
  ) {
    return Isolate.run(() => codec.encodePackage(packageEntity));
  }

  static String _requireString(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! String) {
      throw McpException.invalidParams('Parameter "$key" must be a string.');
    }
    return v;
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

  static Map<String, dynamic>? _optionalJsonMap(
    Map<String, dynamic> args,
    String key,
  ) {
    final v = args[key];
    if (v == null) return null;
    if (v is! Map<String, dynamic>) {
      throw McpException.invalidParams(
        'Parameter "$key" must be a JSON object.',
      );
    }
    return v;
  }
}
