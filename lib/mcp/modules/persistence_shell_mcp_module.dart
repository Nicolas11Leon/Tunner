import 'dart:io';

import '../../app/studio_workspace_seed_provider.dart';
import '../../core/file_system/domain/i_workspace_seed_provider.dart';
import '../../core/theme/domain/theme_palette_data.dart';
import '../../features/navigation/domain/app_tool_item.dart';
import '../../features/persistence/domain/app_user_settings_entity.dart';
import '../../features/persistence/domain/i_local_persistence_service.dart';
import '../../features/workspaces/domain/workspace_type.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing atomic user settings persistence
/// (`AtomicJsonFilePersistenceService` / `AppUserSettingsEntity`), workspace
/// switching and configuration (`WorkspaceType`, `WorkspaceConfigurationEntity`),
/// global tool discovery (`AppToolCatalog`), custom theme palette management
/// (`ThemePaletteData`), workspace asset seeding (`StudioWorkspaceSeedProvider`),
/// and headless runtime capability introspection.
class PersistenceShellMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final IWorkspaceSeedProvider _seedProvider;

  PersistenceShellMcpModule(
    this.facade, {
    IWorkspaceSeedProvider seedProvider = const StudioWorkspaceSeedProvider(),
  }) : _seedProvider = seedProvider;

  @override
  String get moduleName => 'persistence_shell';

  ILocalPersistenceService get _persistence => facade.root.persistenceService;

  @override
  void register(McpRegistry registry) {
    _registerResources(registry);
    _registerTools(registry);
    _registerPrompts(registry);
  }

  // ===========================================================================
  // Resources (6)
  // ===========================================================================

  void _registerResources(McpRegistry registry) {
    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://settings/current',
        name: 'Current User Settings',
        description:
            'Persisted global user settings snapshot (AppUserSettingsEntity) loaded atomically from disk.',
        mimeType: 'application/json',
        reader: () async {
          final settings = await _persistence.loadSettings();
          return McpResourceContent.json(
            uri: 'tunner://settings/current',
            data: settings.toMap(),
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://workspace/active',
        name: 'Active Studio Workspace',
        description:
            'Active WorkspaceType (learning, composition, production), tool visibility configuration, and score summary.',
        mimeType: 'application/json',
        reader: () async {
          final settings = await _persistence.loadSettings();
          final workspace = settings.activeWorkspace;
          final config = settings.workspaceConfiguration ??
              WorkspaceConfigurationEntity.defaultFor(workspace);
          return McpResourceContent.json(
            uri: 'tunner://workspace/active',
            data: {
              'activeWorkspace': workspace.serializedKey,
              'displayName': workspace.displayName,
              'tagline': workspace.tagline,
              'configuration': config.toMap(),
              'workspaceScoresCount': settings.workspaceScores.length,
              'activeScoreId': settings.activeScoreId,
              'hasActiveSessionScore': facade.activeScore != null,
              'activeSessionScoreTitle': facade.activeScore?.title,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://catalog/tools',
        name: 'Global Tunner Tool Catalog',
        description:
            'Complete navigable catalog of Tunner tools (AppToolCatalog) organized across functional categories.',
        mimeType: 'application/json',
        reader: () async {
          final categories = AppToolCategory.values
              .map(
                (c) => {
                  'name': c.name,
                  'displayName': c.displayName,
                  'iconKey': c.iconKey,
                },
              )
              .toList(growable: false);
          final tools = AppToolCatalog.tools
              .map(_toolItemToJson)
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://catalog/tools',
            data: {
              'count': tools.length,
              'categories': categories,
              'tools': tools,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://help/tools',
        name: 'Pedagogical and Acoustic Reference Guide',
        description:
            'Pure Dart technical and pedagogical reference guide with acoustic formulas and standard workflow shortcuts.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://help/tools',
            data: {
              'count': _canonicalHelpItems.length,
              'items': _canonicalHelpItems,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://themes/palettes',
        name: 'Custom Theme Palettes and Active Skin',
        description:
            'Active theme identifiers and custom Pure Dart ARGB32 palettes persisted in AppUserSettingsEntity.',
        mimeType: 'application/json',
        reader: () async {
          final settings = await _persistence.loadSettings();
          return McpResourceContent.json(
            uri: 'tunner://themes/palettes',
            data: {
              'selectedThemeId': settings.selectedThemeId,
              'activeStudioThemeId': settings.activeStudioThemeId,
              'customPalettesCount': settings.customPalettes.length,
              'customPalettes': settings.customPalettes
                  .map(_paletteSummaryJson)
                  .toList(growable: false),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://runtime/capabilities',
        name: 'Headless Runtime Capabilities and Diagnostics',
        description:
            'Diagnostics for HeadlessCompositionRoot: native DSP FFI status, persistence path, IPC GUI attachment, and mounted services.',
        mimeType: 'application/json',
        reader: () async {
          final settings = await _persistence.loadSettings();
          final root = facade.root;
          return McpResourceContent.json(
            uri: 'tunner://runtime/capabilities',
            data: {
              'mode': 'headless',
              'status': facade.isDisposed ? 'disposed' : 'ready',
              'uptimeMs': facade.uptimeMs,
              'startedAtUtc': facade.startedAtUtc.toIso8601String(),
              'workspacePath': facade.workspaceDirectory.path,
              'persistenceService': root.persistenceService.runtimeType.toString(),
              'ffiNativeLoaded': root.nativeDspBridge.isNativeAvailable,
              'dspBridgeEngine': root.nativeDspBridge.engineName,
              'ipcGuiConnected': facade.onIpcEvent != null,
              'learnerProfile': settings.learnerProfile.toJson(),
              'loadedServices': const [
                'PosixFileGateway',
                'AtomicJsonFilePersistenceService',
                'NativeDspFfiBridge',
                'StudioMasterDspChain',
                'StudioAudioDeviceMatrixService',
                'StudioMasterClockService',
                'LocalDiskStudioFileSystemRepository',
                'PolyphonicVoicePool',
                'ScorePlaybackCoordinator',
                'StudioOsAudioKernel',
                'TunnerOsKernel',
                'UniversalScoreImporterService',
                'ScoreEditorController',
                'LocalProjectStorageRepository',
                'SongDecomposerService',
                'DjConsoleHeadlessController',
                'ModularRackHeadlessController',
                'MediaVaultHeadlessController',
              ],
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tools (7)
  // ===========================================================================

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_get_user_settings',
        description:
            'Reads the persisted AppUserSettingsEntity snapshot atomically, optionally filtered by logical sections (audio, workspace, pedagogy, themes, history).',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'sections': {
              'type': 'array',
              'items': {
                'type': 'string',
                'enum': ['audio', 'workspace', 'pedagogy', 'themes', 'history'],
              },
              'description':
                  'Optional list of sections to return. Omit to return the complete settings map.',
            },
          },
        },
        handler: _handleGetUserSettings,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_update_user_settings',
        description:
            'Atomically updates one or more user preferences (referencePitch, bpm, selectedInstrumentId, selectedTemperamentId, temperamentRootKey, isSmartWaitEnabled, displayMode, dspEngineName, targetRenderFps, centsPrecision, themes, activeScoreId) and notifies the live GUI via IPC if connected.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'referencePitch': {'type': 'number', 'minimum': 415.0, 'maximum': 466.0},
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'selectedInstrumentId': {'type': 'string'},
            'selectedTemperamentId': {'type': 'string'},
            'temperamentRootKey': {'type': 'integer', 'minimum': 0, 'maximum': 11},
            'isSmartWaitEnabled': {'type': 'boolean'},
            'displayMode': {
              'type': 'string',
              'enum': ['essential', 'conservatoryPro'],
            },
            'dspEngineName': {'type': 'string'},
            'targetRenderFps': {'type': 'integer', 'minimum': 30, 'maximum': 144},
            'centsPrecision': {'type': 'number', 'minimum': 0.1, 'maximum': 1.0},
            'selectedThemeId': {'type': 'string'},
            'activeStudioThemeId': {'type': 'string'},
            'activeScoreId': {'type': 'string'},
          },
        },
        handler: _handleUpdateUserSettings,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_reset_user_settings',
        description:
            'Resets persisted user settings back to AppUserSettingsEntity.defaultSettings by clearing the atomic JSON settings file (requires confirm=true).',
        inputSchema: const {
          'type': 'object',
          'required': ['confirm'],
          'properties': {
            'confirm': {
              'type': 'boolean',
              'description': 'Must be explicitly true to confirm resetting all user settings.',
            },
          },
        },
        handler: _handleResetUserSettings,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_switch_workspace',
        description:
            'Switches the active studio workspace (learning, composition, production), applies optional tool visibility overrides, persists atomically, and emits a workspace.switched IPC event.',
        inputSchema: const {
          'type': 'object',
          'required': ['workspace'],
          'properties': {
            'workspace': {
              'type': 'string',
              'enum': ['learning', 'composition', 'production'],
            },
            'configurationOverrides': {
              'type': 'object',
              'properties': {
                'showMetronome': {'type': 'boolean'},
                'showStrobeTuner': {'type': 'boolean'},
                'showSheetMusicCanvas': {'type': 'boolean'},
                'showAcousticSpectrogram': {'type': 'boolean'},
                'showChordAnalyzer': {'type': 'boolean'},
              },
            },
          },
        },
        handler: _handleSwitchWorkspace,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_search_tools',
        description:
            'Searches the global Tunner tool catalog (AppToolCatalog) using diacritic-insensitive free-text search and optional category filtering.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'default': '',
              'description': 'Free-text search query.',
            },
            'category': {
              'type': 'string',
              'description':
                  'Optional AppToolCategory name (tuner, metronome, learning, recording, library, acousticLab, settings).',
            },
          },
        },
        handler: _handleSearchTools,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_manage_custom_theme',
        description:
            'Lists, creates/updates (upsert), deletes, or selects custom Pure Dart ThemePaletteData entries persisted in AppUserSettingsEntity.',
        inputSchema: const {
          'type': 'object',
          'required': ['action'],
          'properties': {
            'action': {
              'type': 'string',
              'enum': ['list', 'upsert', 'delete', 'select'],
            },
            'themeId': {'type': 'string'},
            'studioThemeId': {'type': 'string'},
            'paletteData': {
              'type': 'object',
              'description':
                  'ThemePaletteData JSON object required when action="upsert".',
            },
          },
        },
        handler: _handleManageCustomTheme,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_seed_workspace_assets',
        description:
            'Generates canonical seed WAV audio files via StudioWorkspaceSeedProvider and writes them into a sandboxed directory inside the workspace.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'targetDirectory': {
              'type': 'string',
              'default': '.',
              'description':
                  'Relative or workspace-contained target directory for seed files.',
            },
            'overwrite': {
              'type': 'boolean',
              'default': false,
              'description': 'When true, overwrites existing seed files.',
            },
          },
        },
        handler: _handleSeedWorkspaceAssets,
      ),
    );
  }

  // ===========================================================================
  // Prompts (3)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_configure_studio_session',
        description:
            'Configures the studio environment (concert pitch A4, temperament, instrument, workspace, and tool panels) for a specific musical goal.',
        arguments: const [
          McpPromptArgument(
            name: 'goal',
            description:
                'Session goal (e.g. baroque rehearsal at 415 Hz, beginner vocal practice, acoustic lab).',
            required: false,
          ),
          McpPromptArgument(
            name: 'workspace',
            description: 'Target workspace (learning, composition, production).',
            required: false,
          ),
          McpPromptArgument(
            name: 'referencePitchA4',
            description: 'Target concert pitch A4 in Hz (e.g. 415.0, 440.0, 442.0).',
            required: false,
          ),
        ],
        builder: (args) async {
          final goal = args['goal'] ?? 'general conservatory practice';
          final workspace = args['workspace'] ?? 'learning';
          final a4 = args['referencePitchA4'] ?? '440.0';
          return McpPromptResult(
            description: 'Studio session configuration workflow.',
            messages: [
              McpPromptMessage.user(
                'Configure Tunner Studio for "$goal" (workspace: $workspace, A4: $a4 Hz). '
                'Step 1: Read tunner://settings/current and tunner://workspace/active. '
                'Step 2: Call tunner_update_user_settings with the required concert pitch, temperament, instrument, and cents precision. '
                'Step 3: Call tunner_switch_workspace to activate "$workspace" with appropriate panel visibility overrides.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_discover_workflow_tools',
        description:
            'Maps a complex musical task to the exact sequence of Tunner modules, tools, and acoustic formulas required.',
        arguments: const [
          McpPromptArgument(
            name: 'taskDescription',
            description: 'Description of the musical or audio engineering task.',
            required: false,
          ),
        ],
        builder: (args) async {
          final task = args['taskDescription'] ??
              'transcribe a vocal take, edit the score, and export stems';
          return McpPromptResult(
            description: 'Workflow tool discovery and chaining guide.',
            messages: [
              McpPromptMessage.user(
                'Plan an end-to-end Tunner workflow for: "$task". '
                'Step 1: Read tunner://catalog/tools and tunner://help/tools. '
                'Step 2: Call tunner_search_tools with relevant keywords from the task. '
                'Step 3: Produce a step-by-step execution plan listing the corresponding MCP tools and acoustic parameters.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_backup_and_migrate_settings',
        description:
            'Audits, backs up, updates, or safely resets user settings, presets, and custom theme palettes.',
        arguments: const [
          McpPromptArgument(
            name: 'operation',
            description: 'Desired operation (audit, backup, migrate, reset).',
            required: false,
          ),
        ],
        builder: (args) async {
          final operation = args['operation'] ?? 'audit';
          return McpPromptResult(
            description: 'User settings backup and migration workflow.',
            messages: [
              McpPromptMessage.user(
                'Perform a "$operation" workflow on the persisted Tunner user settings. '
                'Step 1: Call tunner_get_user_settings to inspect the current atomic JSON configuration. '
                'Step 2: Read tunner://themes/palettes to verify custom palettes. '
                'Step 3: Apply changes safely with tunner_update_user_settings, tunner_manage_custom_theme, or tunner_reset_user_settings (only with explicit confirmation).',
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

  Future<McpToolResult> _handleGetUserSettings(
    Map<String, dynamic> args,
  ) async {
    final settings = await _persistence.loadSettings();
    final fullMap = settings.toMap();

    final rawSections = args['sections'];
    if (rawSections == null) {
      return McpToolResult.json({
        'sections': ['all'],
        'settings': fullMap,
      });
    }

    if (rawSections is! List) {
      throw const McpException.invalidParams(
        'Parameter "sections" must be an array of section names.',
      );
    }

    final filtered = <String, dynamic>{};
    final requested = <String>[];
    for (final raw in rawSections) {
      if (raw is! String) {
        throw const McpException.invalidParams(
          'Each entry in "sections" must be a string.',
        );
      }
      final section = raw.trim().toLowerCase();
      requested.add(section);
      switch (section) {
        case 'audio':
          filtered['audio'] = {
            'referencePitch': settings.referencePitch,
            'bpm': settings.bpm,
            'selectedInstrumentId': settings.selectedInstrumentId,
            'selectedTemperamentId': settings.selectedTemperamentId,
            'temperamentRootKey': settings.temperamentRootKey,
            'dspEngineName': settings.dspEngineName,
            'centsPrecision': settings.centsPrecision,
            'micCalibrationProfile': settings.micCalibrationProfile.toJson(),
            'acousticRigorProfile': settings.acousticRigorProfile.toJson(),
          };
          break;
        case 'workspace':
          filtered['workspace'] = {
            'activeWorkspace': settings.activeWorkspace.serializedKey,
            'displayMode': settings.displayMode.name,
            'targetRenderFps': settings.targetRenderFps,
            'activeScoreId': settings.activeScoreId,
            'workspaceConfiguration': (settings.workspaceConfiguration ??
                    WorkspaceConfigurationEntity.defaultFor(
                      settings.activeWorkspace,
                    ))
                .toMap(),
            'workspaceScoresCount': settings.workspaceScores.length,
          };
          break;
        case 'pedagogy':
          filtered['pedagogy'] = {
            'isSmartWaitEnabled': settings.isSmartWaitEnabled,
            'learnerProfile': settings.learnerProfile.toJson(),
            'earTrainingItemsCount': settings.earTrainingItemsJson.length,
            'taskStatuses': settings.taskStatuses,
            'completedLessonIds': settings.completedLessonIds,
          };
          break;
        case 'themes':
          filtered['themes'] = {
            'selectedThemeId': settings.selectedThemeId,
            'activeStudioThemeId': settings.activeStudioThemeId,
            'customPalettes': settings.customPalettes
                .map(_paletteSummaryJson)
                .toList(growable: false),
          };
          break;
        case 'history':
          filtered['history'] = {
            'sessionHistoryCount': settings.sessionHistory.length,
            'recordingHistoryCount': settings.recordingHistory.length,
            'tuningPresetsCount': settings.tuningPresets.length,
            'hasMultiTrackSession': settings.multiTrackSession != null,
            'hasMixerConsole': settings.mixerConsole != null,
          };
          break;
        default:
          throw McpException.invalidParams(
            'Unknown settings section: "$raw". Allowed: audio, workspace, pedagogy, themes, history.',
          );
      }
    }

    return McpToolResult.json({
      'sections': requested,
      'settings': filtered,
    });
  }

  Future<McpToolResult> _handleUpdateUserSettings(
    Map<String, dynamic> args,
  ) async {
    final referencePitch = _optionalDouble(args, 'referencePitch');
    if (referencePitch != null &&
        (referencePitch < 415.0 || referencePitch > 466.0)) {
      throw const McpException.invalidParams(
        'Parameter "referencePitch" must be between 415.0 and 466.0 Hz.',
      );
    }

    final bpm = _optionalInt(args, 'bpm');
    if (bpm != null && (bpm < 20 || bpm > 300)) {
      throw const McpException.invalidParams(
        'Parameter "bpm" must be between 20 and 300.',
      );
    }

    final temperamentRootKey = _optionalInt(args, 'temperamentRootKey');
    if (temperamentRootKey != null &&
        (temperamentRootKey < 0 || temperamentRootKey > 11)) {
      throw const McpException.invalidParams(
        'Parameter "temperamentRootKey" must be between 0 and 11.',
      );
    }

    final targetRenderFps = _optionalInt(args, 'targetRenderFps');
    if (targetRenderFps != null &&
        (targetRenderFps < 30 || targetRenderFps > 144)) {
      throw const McpException.invalidParams(
        'Parameter "targetRenderFps" must be between 30 and 144.',
      );
    }

    final centsPrecision = _optionalDouble(args, 'centsPrecision');
    if (centsPrecision != null &&
        (centsPrecision < 0.1 || centsPrecision > 1.0)) {
      throw const McpException.invalidParams(
        'Parameter "centsPrecision" must be between 0.1 and 1.0.',
      );
    }

    AppDisplayMode? displayMode;
    final displayModeRaw = _optionalString(args, 'displayMode');
    if (displayModeRaw != null) {
      if (displayModeRaw == AppDisplayMode.essential.name) {
        displayMode = AppDisplayMode.essential;
      } else if (displayModeRaw == AppDisplayMode.conservatoryPro.name) {
        displayMode = AppDisplayMode.conservatoryPro;
      } else {
        throw McpException.invalidParams(
          'Invalid displayMode "$displayModeRaw". Allowed: essential, conservatoryPro.',
        );
      }
    }

    final current = await _persistence.loadSettings();
    final updated = current.copyWith(
      referencePitch: referencePitch,
      bpm: bpm,
      selectedInstrumentId: _optionalString(args, 'selectedInstrumentId'),
      selectedTemperamentId: _optionalString(args, 'selectedTemperamentId'),
      temperamentRootKey: temperamentRootKey,
      isSmartWaitEnabled: _optionalBool(args, 'isSmartWaitEnabled'),
      displayMode: displayMode,
      dspEngineName: _optionalString(args, 'dspEngineName'),
      targetRenderFps: targetRenderFps,
      centsPrecision: centsPrecision,
      selectedThemeId: _optionalString(args, 'selectedThemeId'),
      activeStudioThemeId: _optionalString(args, 'activeStudioThemeId'),
      activeScoreId: _optionalString(args, 'activeScoreId'),
    );

    await _persistence.saveSettings(updated);

    final ipcNotified = facade.onIpcEvent != null;
    facade.emitIpcEvent('settings.updated', {
      'referencePitch': updated.referencePitch,
      'bpm': updated.bpm,
      'selectedInstrumentId': updated.selectedInstrumentId,
      'selectedTemperamentId': updated.selectedTemperamentId,
      'activeWorkspace': updated.activeWorkspace.serializedKey,
      'displayMode': updated.displayMode.name,
    });

    return McpToolResult.json({
      'updated': true,
      'persistedAtomically': true,
      'ipcNotified': ipcNotified,
      'settings': updated.toMap(),
    });
  }

  Future<McpToolResult> _handleResetUserSettings(
    Map<String, dynamic> args,
  ) async {
    final confirm = _optionalBool(args, 'confirm');
    if (confirm != true) {
      throw const McpException.invalidParams(
        'Resetting user settings requires explicit confirmation: set "confirm": true.',
      );
    }

    await _persistence.clearSettings();

    final ipcNotified = facade.onIpcEvent != null;
    facade.emitIpcEvent('settings.reset', {
      'reset': true,
      'activeWorkspace':
          AppUserSettingsEntity.defaultSettings.activeWorkspace.serializedKey,
    });

    return McpToolResult.json({
      'reset': true,
      'ipcNotified': ipcNotified,
      'settings': AppUserSettingsEntity.defaultSettings.toMap(),
    });
  }

  Future<McpToolResult> _handleSwitchWorkspace(
    Map<String, dynamic> args,
  ) async {
    final workspaceRaw = _requireString(args, 'workspace');
    if (workspaceRaw != 'learning' &&
        workspaceRaw != 'composition' &&
        workspaceRaw != 'production') {
      throw McpException.invalidParams(
        'Invalid workspace "$workspaceRaw". Allowed: learning, composition, production.',
      );
    }

    final workspaceType = WorkspaceType.fromSerializedKey(workspaceRaw);
    var config = WorkspaceConfigurationEntity.defaultFor(workspaceType);

    final rawOverrides = args['configurationOverrides'];
    if (rawOverrides != null) {
      if (rawOverrides is! Map<String, dynamic>) {
        throw const McpException.invalidParams(
          'Parameter "configurationOverrides" must be a JSON object.',
        );
      }
      config = config.copyWith(
        showMetronome: _optionalBool(rawOverrides, 'showMetronome'),
        showStrobeTuner: _optionalBool(rawOverrides, 'showStrobeTuner'),
        showSheetMusicCanvas:
            _optionalBool(rawOverrides, 'showSheetMusicCanvas'),
        showAcousticSpectrogram:
            _optionalBool(rawOverrides, 'showAcousticSpectrogram'),
        showChordAnalyzer: _optionalBool(rawOverrides, 'showChordAnalyzer'),
      );
    }

    final current = await _persistence.loadSettings();
    final updated = current.copyWith(
      activeWorkspace: workspaceType,
      workspaceConfiguration: config,
    );
    await _persistence.saveSettings(updated);

    final ipcNotified = facade.onIpcEvent != null;
    facade.emitIpcEvent('workspace.switched', {
      'activeWorkspace': workspaceType.serializedKey,
      'displayName': workspaceType.displayName,
      'configuration': config.toMap(),
    });

    return McpToolResult.json({
      'activeWorkspace': workspaceType.serializedKey,
      'displayName': workspaceType.displayName,
      'tagline': workspaceType.tagline,
      'configuration': config.toMap(),
      'ipcNotified': ipcNotified,
    });
  }

  Future<McpToolResult> _handleSearchTools(Map<String, dynamic> args) async {
    final query = _optionalString(args, 'query') ?? '';
    final categoryRaw = _optionalString(args, 'category');

    var matches = AppToolCatalog.searchTools(query);
    if (categoryRaw != null && categoryRaw.isNotEmpty) {
      final norm = categoryRaw.toLowerCase();
      final matchedCategories = AppToolCategory.values
          .where((c) => c.name.toLowerCase() == norm)
          .toList();
      if (matchedCategories.isEmpty) {
        throw McpException.invalidParams(
          'Unknown AppToolCategory: "$categoryRaw".',
        );
      }
      final cat = matchedCategories.first;
      matches = matches.where((t) => t.category == cat).toList();
    }

    return McpToolResult.json({
      'query': query,
      'count': matches.length,
      'matches': matches.map(_toolItemToJson).toList(growable: false),
    });
  }

  Future<McpToolResult> _handleManageCustomTheme(
    Map<String, dynamic> args,
  ) async {
    final action = _requireString(args, 'action');
    final current = await _persistence.loadSettings();

    switch (action) {
      case 'list':
        return McpToolResult.json({
          'action': 'list',
          'selectedThemeId': current.selectedThemeId,
          'activeStudioThemeId': current.activeStudioThemeId,
          'customPalettesCount': current.customPalettes.length,
          'customPalettes': current.customPalettes
              .map(_paletteSummaryJson)
              .toList(growable: false),
        });

      case 'upsert':
        final rawPalette = args['paletteData'];
        if (rawPalette is! Map<String, dynamic>) {
          throw const McpException.invalidParams(
            'Parameter "paletteData" (JSON object) is required for action="upsert".',
          );
        }
        final palette = ThemePaletteData.fromJson(rawPalette);
        final updatedPalettes = List<ThemePaletteData>.from(
          current.customPalettes,
        );
        final idx = updatedPalettes.indexWhere((p) => p.id == palette.id);
        if (idx >= 0) {
          updatedPalettes[idx] = palette;
        } else {
          updatedPalettes.add(palette);
        }
        final updated = current.copyWith(customPalettes: updatedPalettes);
        await _persistence.saveSettings(updated);
        facade.emitIpcEvent('ui.theme.updated', {
          'action': 'upsert',
          'themeId': palette.id,
          'displayName': palette.displayName,
        });
        return McpToolResult.json({
          'action': 'upsert',
          'selectedThemeId': updated.selectedThemeId,
          'activeStudioThemeId': updated.activeStudioThemeId,
          'customPalettesCount': updated.customPalettes.length,
          'palette': _paletteSummaryJson(palette),
        });

      case 'delete':
        final themeId = _requireString(args, 'themeId');
        final updatedPalettes = current.customPalettes
            .where((p) => p.id != themeId)
            .toList();
        if (updatedPalettes.length == current.customPalettes.length) {
          throw McpException.fileNotFound(
            'Custom theme palette not found: "$themeId".',
          );
        }
        final updated = current.copyWith(
          customPalettes: updatedPalettes,
          selectedThemeId: current.selectedThemeId == themeId
              ? AppUserSettingsEntity.defaultSettings.selectedThemeId
              : current.selectedThemeId,
        );
        await _persistence.saveSettings(updated);
        facade.emitIpcEvent('ui.theme.updated', {
          'action': 'delete',
          'themeId': themeId,
        });
        return McpToolResult.json({
          'action': 'delete',
          'deletedThemeId': themeId,
          'selectedThemeId': updated.selectedThemeId,
          'activeStudioThemeId': updated.activeStudioThemeId,
          'customPalettesCount': updated.customPalettes.length,
          'palette': null,
        });

      case 'select':
        final themeId = _optionalString(args, 'themeId');
        final studioThemeId = _optionalString(args, 'studioThemeId');
        if (themeId == null && studioThemeId == null) {
          throw const McpException.invalidParams(
            'Provide "themeId" and/or "studioThemeId" for action="select".',
          );
        }
        final updated = current.copyWith(
          selectedThemeId: themeId,
          activeStudioThemeId: studioThemeId,
        );
        await _persistence.saveSettings(updated);
        facade.emitIpcEvent('ui.theme.updated', {
          'action': 'select',
          'selectedThemeId': updated.selectedThemeId,
          'activeStudioThemeId': updated.activeStudioThemeId,
        });
        final selectedCustom = updated.customPalettes
            .where((p) => p.id == updated.selectedThemeId)
            .toList();
        return McpToolResult.json({
          'action': 'select',
          'selectedThemeId': updated.selectedThemeId,
          'activeStudioThemeId': updated.activeStudioThemeId,
          'customPalettesCount': updated.customPalettes.length,
          'palette': selectedCustom.isNotEmpty
              ? _paletteSummaryJson(selectedCustom.first)
              : null,
        });

      default:
        throw McpException.invalidParams(
          'Invalid action "$action". Allowed: list, upsert, delete, select.',
        );
    }
  }

  Future<McpToolResult> _handleSeedWorkspaceAssets(
    Map<String, dynamic> args,
  ) async {
    final targetDirRaw = _optionalString(args, 'targetDirectory') ?? '.';
    final overwrite = _optionalBool(args, 'overwrite') ?? false;

    final targetDir = _resolveSandboxedDirectory(targetDirRaw);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final seedFiles = await _seedProvider.buildSeedBinaryFiles();
    final created = <Map<String, dynamic>>[];

    for (final entry in seedFiles.entries) {
      final relativePath = entry.key;
      final bytes = entry.value;
      final fullCandidate =
          '${targetDir.path}${Platform.pathSeparator}$relativePath';
      final outputFile = _resolveSandboxedFile(fullCandidate);

      final existed = await outputFile.exists();
      if (existed && !overwrite) {
        created.add({
          'relativePath': relativePath,
          'fullPath': outputFile.path,
          'bytes': await outputFile.length(),
          'skipped': true,
        });
        continue;
      }

      if (!await outputFile.parent.exists()) {
        await outputFile.parent.create(recursive: true);
      }
      await outputFile.writeAsBytes(bytes, flush: true);
      created.add({
        'relativePath': relativePath,
        'fullPath': outputFile.path,
        'bytes': bytes.length,
        'skipped': false,
      });
    }

    return McpToolResult.json({
      'targetDirectory': targetDir.path,
      'overwrite': overwrite,
      'filesCount': created.length,
      'filesCreated': created,
    });
  }

  // ===========================================================================
  // Serialization & Static Reference Data
  // ===========================================================================

  static Map<String, dynamic> _toolItemToJson(AppToolItem item) {
    return {
      'id': item.id,
      'title': item.title,
      'subtitle': item.subtitle,
      'category': item.category.name,
      'categoryDisplayName': item.category.displayName,
      'iconKey': item.iconKey,
      'keywords': List<String>.from(item.keywords),
      'targetTabIndex': item.targetTabIndex,
      'actionId': item.actionId,
    };
  }

  static Map<String, dynamic> _paletteSummaryJson(ThemePaletteData p) {
    return {
      ...p.toJson(),
      'isDark': p.isDark,
      'primaryAccentHex': _toHexArgb(p.primaryAccentArgb),
      'secondaryAccentHex': _toHexArgb(p.secondaryAccentArgb),
      'scaffoldBackgroundHex': _toHexArgb(p.scaffoldBackgroundArgb),
    };
  }

  static String _toHexArgb(int argb) =>
      '0x${argb.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static const List<Map<String, dynamic>> _canonicalHelpItems = [
    {
      'id': 'concert_pitch_calibration',
      'title': 'Concert Pitch Calibration (A4)',
      'category': 'tuner',
      'description':
          'Scales all 12-EDO and temperament target frequencies relative to concert pitch A4 (415 Hz Baroque to 466 Hz).',
      'pedagogicalTip':
          'Use 440 Hz for standard ensembles, 442 Hz for European symphonic orchestras, and 415 Hz for Baroque repertoire.',
      'acousticFormula': 'f(midi) = A4 * 2^((midi - 69) / 12)',
      'shortcutKeys': ['Alt+A'],
    },
    {
      'id': 'cents_deviation_metric',
      'title': 'Cents Deviation Measurement',
      'category': 'tuner',
      'description':
          'Logarithmic pitch error relative to the nearest target frequency, where 100 cents equals one equal-tempered semitone.',
      'pedagogicalTip':
          'Professional intonation tolerance is typically within +/- 5 cents; beginner scaffolding starts around +/- 15 cents.',
      'acousticFormula': 'cents = 1200 * log2(f_detected / f_target)',
      'shortcutKeys': ['T'],
    },
    {
      'id': 'mcleod_pitch_method',
      'title': 'McLeod Pitch Method (MPM / NSDF)',
      'category': 'acousticLab',
      'description':
          'Time-domain Normalized Square Difference Function pitch estimator achieving sub-cent accuracy with low latency.',
      'pedagogicalTip':
          'Keep clarity threshold above 0.80 in reverberant rooms to reject breath and transient noise.',
      'acousticFormula': 'NSDF(tau) = 2 * r(tau) / m(tau)',
      'shortcutKeys': ['Ctrl+Shift+A'],
    },
    {
      'id': 'workspace_modes',
      'title': 'Studio Workspaces (Learning, Composition, Production)',
      'category': 'settings',
      'description':
          'Reconfigures panel visibility for practice pedagogy, SMuFL sheet notation, or FFT acoustic laboratory diagnostics.',
      'pedagogicalTip':
          'Switch to Composition when editing scores and Production when inspecting harmonic spectra or historical temperaments.',
      'acousticFormula': null,
      'shortcutKeys': ['Ctrl+1', 'Ctrl+2', 'Ctrl+3'],
    },
  ];

  // ===========================================================================
  // Path Sandboxing & Argument Validation
  // ===========================================================================

  Directory _resolveSandboxedDirectory(String rawPath) {
    final resolved = _resolveSandboxedPath(rawPath);
    return Directory(resolved);
  }

  File _resolveSandboxedFile(String rawPath) {
    final resolved = _resolveSandboxedPath(rawPath);
    return File(resolved);
  }

  String _resolveSandboxedPath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty || trimmed.contains('\u0000')) {
      throw const McpException.securityViolation('Invalid or empty path.');
    }

    final rootPath =
        _normalizeAbsolutePath(facade.workspaceDirectory.absolute.path);
    final candidateRaw = _isAbsolutePath(trimmed)
        ? trimmed
        : '$rootPath${Platform.pathSeparator}$trimmed';
    final resolvedPath = _normalizeAbsolutePath(candidateRaw);

    final prefix = rootPath.endsWith(Platform.pathSeparator)
        ? rootPath
        : '$rootPath${Platform.pathSeparator}';
    if (resolvedPath != rootPath && !resolvedPath.startsWith(prefix)) {
      throw McpException.securityViolation(
        'Path traversal violation: "$rawPath" escapes workspace directory.',
      );
    }
    return resolvedPath;
  }

  static bool _isAbsolutePath(String p) {
    if (p.startsWith('/') || p.startsWith('\\')) return true;
    return p.length >= 2 && p[1] == ':';
  }

  static String _normalizeAbsolutePath(String path) {
    final uri = Uri.file(path, windows: Platform.isWindows).normalizePath();
    var normalized = uri.toFilePath(windows: Platform.isWindows);
    if (normalized.length > 1 && normalized.endsWith(Platform.pathSeparator)) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static String _requireString(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! String || value.trim().isEmpty) {
      throw McpException.invalidParams(
        'Missing or invalid required string parameter "$key".',
      );
    }
    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is! String) {
      throw McpException.invalidParams(
        'Parameter "$key" must be a string.',
      );
    }
    return value.trim();
  }

  static int? _optionalInt(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is! num || value % 1 != 0) {
      throw McpException.invalidParams(
        'Parameter "$key" must be an integer.',
      );
    }
    return value.toInt();
  }

  static double? _optionalDouble(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is! num || !value.isFinite) {
      throw McpException.invalidParams(
        'Parameter "$key" must be a finite number.',
      );
    }
    return value.toDouble();
  }

  static bool? _optionalBool(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value == null) return null;
    if (value is! bool) {
      throw McpException.invalidParams(
        'Parameter "$key" must be a boolean.',
      );
    }
    return value;
  }
}
