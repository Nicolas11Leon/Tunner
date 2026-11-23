import 'facade/tunner_headless_facade.dart';
import 'modules/autotune_metronome_mcp_module.dart';
import 'modules/core_audio_mcp_module.dart';
import 'modules/dj_mixer_mcp_module.dart';
import 'modules/dsl_terminal_mcp_module.dart';
import 'modules/ear_training_mcp_module.dart';
import 'modules/harmony_chords_mcp_module.dart';
import 'modules/importers_omr_mcp_module.dart';
import 'modules/instruments_mcp_module.dart';
import 'modules/modular_rack_mcp_module.dart';
import 'modules/notation_editor_mcp_module.dart';
import 'modules/pedagogy_eval_mcp_module.dart';
import 'modules/persistence_shell_mcp_module.dart';
import 'modules/project_library_mcp_module.dart';
import 'modules/synth_drone_mcp_module.dart';
import 'modules/tuner_acoustic_mcp_module.dart';
import 'modules/vault_recorder_mcp_module.dart';
import 'modules/workspace_fs_mcp_module.dart';
import 'protocol/mcp_primitives.dart';
import 'protocol/mcp_registry.dart';

/// Central composition bootstrapper for the Tunner MCP Server.
///
/// Registers baseline server diagnostics (`tunner://server/status` and
/// `tunner_server_health`) alongside all 17 Pure Dart domain feature modules
/// into an [McpRegistry] with strict duplicate detection.
class TunnerMcpBootstrap {
  const TunnerMcpBootstrap._();

  /// Total number of domain feature modules bundled with Tunner MCP Server.
  static const int expectedModuleCount = 17;

  /// Instantiates all 17 Tunner MCP domain feature modules bound to [facade].
  static List<IMcpFeatureModule> buildDefaultModules(
    TunnerHeadlessFacade facade,
  ) {
    return <IMcpFeatureModule>[
      CoreAudioMcpModule(facade),
      TunerAcousticMcpModule(facade),
      AutotuneMetronomeMcpModule(facade),
      SynthDroneMcpModule(facade),
      ModularRackMcpModule(facade),
      DjMixerMcpModule(facade),
      NotationEditorMcpModule(facade: facade),
      ImportersOmrMcpModule(facade: facade),
      HarmonyChordsMcpModule(facade),
      InstrumentsMcpModule(facade),
      EarTrainingMcpModule(facade),
      PedagogyEvalMcpModule(facade),
      VaultRecorderMcpModule(facade),
      ProjectLibraryMcpModule(facade: facade),
      DslTerminalMcpModule(facade),
      WorkspaceFsMcpModule(facade),
      PersistenceShellMcpModule(facade),
    ];
  }

  /// Registers baseline server diagnostics (`tunner://server/status` and
  /// `tunner_server_health`) into [registry].
  static void registerCoreServerPrimitives({
    required McpRegistry registry,
    required TunnerHeadlessFacade facade,
    bool headlessOnly = true,
    int? ipcPort,
  }) {
    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://server/status',
        name: 'Tunner MCP Server Status',
        description:
            'Runtime status, workspace root, active session flags, and registered MCP primitive counts.',
        mimeType: 'application/json',
        reader: () async => McpResourceContent.json(
          uri: 'tunner://server/status',
          data: facade.getServerStatusSnapshot(
            registeredResources: registry.resourceCount,
            registeredTools: registry.toolCount,
            registeredPrompts: registry.promptCount,
            registeredModules: registry.registeredModules,
            headlessOnly: headlessOnly,
            ipcPort: ipcPort,
          ),
        ),
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_server_health',
        description:
            'Checks health, uptime, workspace path, and loaded primitive counts of the Tunner MCP server.',
        inputSchema: const {
          'type': 'object',
          'properties': <String, dynamic>{},
          'additionalProperties': false,
        },
        handler: (arguments) async {
          final snapshot = facade.getServerStatusSnapshot(
            registeredResources: registry.resourceCount,
            registeredTools: registry.toolCount,
            registeredPrompts: registry.promptCount,
            registeredModules: registry.registeredModules,
            headlessOnly: headlessOnly,
            ipcPort: ipcPort,
          );
          return McpToolResult.json(
            snapshot,
            summary:
                'Tunner MCP Server is ${snapshot['status']} (uptime ${snapshot['uptimeMs']} ms).',
          );
        },
      ),
    );
  }

  /// Registers baseline server primitives and all 17 feature modules into [registry].
  static McpRegistry registerAll({
    required McpRegistry registry,
    required TunnerHeadlessFacade facade,
    bool headlessOnly = true,
    int? ipcPort,
  }) {
    registerCoreServerPrimitives(
      registry: registry,
      facade: facade,
      headlessOnly: headlessOnly,
      ipcPort: ipcPort,
    );

    for (final module in buildDefaultModules(facade)) {
      registry.registerModule(module);
    }

    return registry;
  }

  /// Creates and populates a fresh [McpRegistry] with core server primitives
  /// and all 17 Tunner MCP feature modules.
  static McpRegistry createRegistry({
    required TunnerHeadlessFacade facade,
    bool headlessOnly = true,
    int? ipcPort,
  }) {
    final registry = McpRegistry();
    return registerAll(
      registry: registry,
      facade: facade,
      headlessOnly: headlessOnly,
      ipcPort: ipcPort,
    );
  }
}
