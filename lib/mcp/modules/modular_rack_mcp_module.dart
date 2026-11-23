import 'dart:convert';
import 'dart:io';

import '../../features/modular_rack/domain/atomic_signal_event.dart';
import '../../features/modular_rack/domain/port_id.dart';
import '../../features/modular_rack/domain/rack_module_entity.dart';
import '../../features/modular_rack/domain/signal_type.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing the Modular Studio Rack and deterministic
/// `SignalBus` with DAG cycle prevention, synergy policy validation, per-cable
/// gain/mute mutation, presets, signal injection, and JSON topology persistence.
class ModularRackMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;

  const ModularRackMcpModule(this.facade);

  @override
  String get moduleName => 'modular_rack';

  @override
  void register(McpRegistry registry) {
    _registerResources(registry);
    _registerTools(registry);
    _registerPrompts(registry);
  }

  // ===========================================================================
  // Resources (3)
  // ===========================================================================

  void _registerResources(McpRegistry registry) {
    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://rack/topology',
        name: 'Modular Rack Topology',
        description:
            'Complete topology of mounted rack modules, power states, declared ports, and active SignalBus connections.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://rack/topology',
            data: facade.modularRackController.toJson(),
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://rack/catalog',
        name: 'Modular Rack Catalog',
        description:
            'Canonical catalog of all supported RackModuleType definitions with standard input/output ports and SignalType definitions.',
        mimeType: 'application/json',
        reader: () async {
          final moduleTypes = RackModuleType.values.map((type) {
            final sample = RackModuleEntity.standard(type, 0);
            return {
              'code': type.code,
              'name': type.name,
              'displayName': type.displayName,
              'icon': type.icon,
              'defaultInputs': sample.inputPorts
                  .map((p) => '${p.id}:${p.signalType.code}')
                  .toList(growable: false),
              'defaultOutputs': sample.outputPorts
                  .map((p) => '${p.id}:${p.signalType.code}')
                  .toList(growable: false),
            };
          }).toList(growable: false);

          return McpResourceContent.json(
            uri: 'tunner://rack/catalog',
            data: {
              'moduleTypes': moduleTypes,
              'signalTypes': SignalType.values
                  .map(
                    (s) => {
                      'code': s.code,
                      'name': s.name,
                      'displayName': s.displayName,
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
        uri: 'tunner://rack/telemetry',
        name: 'SignalBus Node Telemetry',
        description:
            'Per-node SignalBus execution telemetry including processed event counts, last received signal types, and session state.',
        mimeType: 'application/json',
        reader: () async {
          final ctrl = facade.modularRackController;
          final nodeTelemetry = <String, dynamic>{};
          int totalProcessedEvents = 0;

          for (final entry in ctrl.nodes.entries) {
            totalProcessedEvents += entry.value.processedEventsCount;
            nodeTelemetry[entry.key] = entry.value.toTelemetryJson();
          }

          return McpResourceContent.json(
            uri: 'tunner://rack/telemetry',
            data: {
              'isSessionRunning': ctrl.isSessionRunning,
              'isRecording': ctrl.isRecording,
              'modulesCount': ctrl.activeModules.length,
              'connectionsCount': ctrl.activeConnections.length,
              'totalProcessedEvents': totalProcessedEvents,
              'nodes': nodeTelemetry,
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tools (11)
  // ===========================================================================

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_rack_add_module',
        description:
            'Mounts a new module onto the modular rack and registers its interoperability node and ports in SignalBus.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'module_type': {
              'type': 'string',
              'enum': RackModuleType.values.map((e) => e.code).toList(),
            },
            'custom_id': {'type': 'string'},
            'title': {'type': 'string'},
            'is_powered_on': {'type': 'boolean'},
          },
          'required': const ['module_type'],
        },
        handler: _handleAddModule,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_rack_remove_module',
        description:
            'Removes a mounted module by ID and unregisters its node and associated connections from SignalBus.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'module_id': {'type': 'string'},
          },
          'required': ['module_id'],
        },
        handler: _handleRemoveModule,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_rack_set_module_power',
        description: 'Turns a mounted rack module on or off.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'module_id': {'type': 'string'},
            'is_powered_on': {'type': 'boolean'},
          },
          'required': ['module_id', 'is_powered_on'],
        },
        handler: _handleSetModulePower,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_rack_validate_patch',
        description:
            'Validates a proposed point-to-point cable between two ports against PortPermissionBroker and SynergyPolicyEngine without mutating the bus.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'source_module_id': {'type': 'string'},
            'source_port_id': {'type': 'string'},
            'dest_module_id': {'type': 'string'},
            'dest_port_id': {'type': 'string'},
          },
          'required': [
            'source_module_id',
            'source_port_id',
            'dest_module_id',
            'dest_port_id',
          ],
        },
        handler: _handleValidatePatch,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_rack_patch_ports',
        description:
            'Patches a point-to-point or broadcast cable in SignalBus with strict DAG anti-cycle validation, PortPermissionBroker, and SynergyPolicyEngine enforcement.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'source_module_id': {'type': 'string'},
            'source_port_id': {'type': 'string'},
            'dest_module_id': {'type': 'string'},
            'dest_port_id': {'type': 'string'},
            'broadcast': {'type': 'boolean'},
            'gain': {'type': 'number', 'minimum': 0.0, 'maximum': 2.0},
            'is_muted': {'type': 'boolean'},
          },
          'required': ['source_module_id', 'source_port_id'],
        },
        handler: _handlePatchPorts,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_rack_update_connection',
        description:
            'Mutates gain [0.0, 2.0], mute state, or enabled state of an existing SignalBus cable.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'connection_id': {'type': 'string'},
            'gain': {'type': 'number', 'minimum': 0.0, 'maximum': 2.0},
            'is_muted': {'type': 'boolean'},
            'is_enabled': {'type': 'boolean'},
          },
          'required': ['connection_id'],
        },
        handler: _handleUpdateConnection,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_rack_unpatch',
        description: 'Disconnects and removes a cable from SignalBus by connection_id.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'connection_id': {'type': 'string'},
          },
          'required': ['connection_id'],
        },
        handler: _handleUnpatch,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_rack_load_preset',
        description:
            'Loads a canonical modular rack preset (default, calentamiento, transcripcion_partitura, produccion_vocal, dj_studio), clearing previous modules and routes.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'preset_name': {
              'type': 'string',
              'enum': [
                'default',
                'calentamiento',
                'transcripcion_partitura',
                'produccion_vocal',
                'dj_studio',
              ],
            },
          },
          'required': ['preset_name'],
        },
        handler: _handleLoadPreset,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_rack_inject_signal',
        description:
            'Injects a typed AtomicSignalEvent into SignalBus from a registered output port (or global broadcast) for deterministic headless testing and orchestration.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'source_module_id': {'type': 'string'},
            'source_port_id': {'type': 'string'},
            'signal_type': {
              'type': 'string',
              'enum': [
                'temporal_clock',
                'pitch_events',
                'tuning_calibration',
                'transport_control',
                'audio_pcm',
              ],
            },
            'payload': {'type': 'object'},
            'broadcast': {'type': 'boolean'},
          },
          'required': [
            'source_module_id',
            'source_port_id',
            'signal_type',
            'payload',
          ],
        },
        handler: _handleInjectSignal,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_rack_export_topology',
        description:
            'Exports the complete modular rack topology (modules and SignalBus connections) as JSON, optionally writing it to a sandboxed file path inside the workspace.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'output_path': {
              'type': 'string',
              'description': 'Optional workspace file path to persist the topology JSON.',
            },
          },
        },
        handler: _handleExportTopology,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_rack_restore_topology',
        description:
            'Restores a complete modular rack topology from a workspace JSON file or an inline topology JSON object.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'file_path': {
              'type': 'string',
              'description': 'Workspace path to a previously exported topology JSON file.',
            },
            'topology': {
              'type': 'object',
              'description': 'Inline topology JSON object (used when file_path is omitted).',
            },
          },
        },
        handler: _handleRestoreTopology,
      ),
    );
  }

  // ===========================================================================
  // Prompts (2)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'rack_build_hyper_synergy',
        description:
            'Mounts and patches a validated Hyper-Synergy modular rack topology tailored to a musical or pedagogical goal.',
        arguments: const [
          McpPromptArgument(
            name: 'pedagogical_goal',
            description: 'Target practice or studio workflow goal.',
            required: true,
          ),
        ],
        builder: (args) async {
          final goal = args['pedagogical_goal']!;
          return McpPromptResult(
            description: 'Guided workflow for building a Hyper-Synergy rack topology.',
            messages: [
              McpPromptMessage.user(
                'Design and assemble a modular rack topology for: $goal. '
                'Step 1: Read tunner://rack/catalog to inspect available module types and ports. '
                'Step 2: Mount required modules using tunner_rack_add_module. '
                'Step 3: Validate each proposed connection with tunner_rack_validate_patch and verify isHyperSynergy and pedagogicalNote. '
                'Step 4: Wire approved connections with tunner_rack_patch_ports (respecting DAG acyclicity) and summarize the resulting topology from tunner://rack/topology.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'rack_audit_routing_safety',
        description:
            'Audits the current modular rack topology for acoustic safety, orphan or powered-off modules, and gain staging anomalies.',
        arguments: const [
          McpPromptArgument(
            name: 'focus_area',
            description: 'Optional audit focus (e.g., "gain staging", "orphan nodes").',
          ),
        ],
        builder: (args) async {
          final focus = args['focus_area'];
          final focusClause = focus != null && focus.trim().isNotEmpty
              ? ' Focus specifically on: $focus.'
              : '';
          return McpPromptResult(
            description: 'Guided workflow for auditing modular rack routing safety.',
            messages: [
              McpPromptMessage.user(
                'Audit the active modular rack for routing safety and signal hygiene.$focusClause '
                'Step 1: Read tunner://rack/topology and tunner://rack/telemetry. '
                'Step 2: Identify any powered-off modules, unconnected ports, muted cables, or excessive connection gains (>1.5). '
                'Step 3: Propose or apply corrective actions via tunner_rack_update_connection or tunner_rack_set_module_power.',
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

  Future<McpToolResult> _handleAddModule(Map<String, dynamic> args) async {
    final typeRaw = _requireNonEmptyString(args, 'module_type');
    final moduleType = _parseRackModuleType(typeRaw);
    final customId = _optionalString(args, 'custom_id');
    final title = _optionalString(args, 'title');
    final isPoweredOn = _optionalBool(args, 'is_powered_on') ?? true;

    final module = facade.modularRackController.addModule(
      moduleType,
      customId: customId,
      title: title,
      isPoweredOn: isPoweredOn,
    );
    return McpToolResult.json(module.toJson());
  }

  Future<McpToolResult> _handleRemoveModule(Map<String, dynamic> args) async {
    final moduleId = _requireNonEmptyString(args, 'module_id');
    final removed = facade.modularRackController.removeModule(moduleId);
    if (!removed) {
      throw McpException.invalidParams('Rack module not found: "$moduleId".');
    }
    return McpToolResult.json({
      'removedModuleId': moduleId,
      'remainingModulesCount': facade.modularRackController.activeModules.length,
      'activeConnectionsCount':
          facade.modularRackController.activeConnections.length,
    });
  }

  Future<McpToolResult> _handleSetModulePower(Map<String, dynamic> args) async {
    final moduleId = _requireNonEmptyString(args, 'module_id');
    final isPoweredOn = _requireBool(args, 'is_powered_on');

    final updated = facade.modularRackController.setModulePower(
      moduleId,
      isPoweredOn,
    );
    if (updated == null) {
      throw McpException.invalidParams('Rack module not found: "$moduleId".');
    }
    return McpToolResult.json({
      'moduleId': updated.moduleId,
      'isPoweredOn': updated.isPoweredOn,
    });
  }

  Future<McpToolResult> _handleValidatePatch(Map<String, dynamic> args) async {
    final srcMod = _requireNonEmptyString(args, 'source_module_id');
    final srcPortId = _requireNonEmptyString(args, 'source_port_id');
    final dstMod = _requireNonEmptyString(args, 'dest_module_id');
    final dstPortId = _requireNonEmptyString(args, 'dest_port_id');

    final bus = facade.modularRackController.signalBus;
    final source = bus.findPort(srcMod, srcPortId);
    if (source == null) {
      throw McpException.invalidParams(
        'Source port not found: $srcMod.$srcPortId',
      );
    }
    final dest = bus.findPort(dstMod, dstPortId);
    if (dest == null) {
      throw McpException.invalidParams(
        'Destination port not found: $dstMod.$dstPortId',
      );
    }

    final result = facade.modularRackController.validatePatch(source, dest);
    return McpToolResult.json({
      'isApproved': result.isApproved,
      'isHyperSynergy': result.isHyperSynergy,
      'pedagogicalNote': result.pedagogicalNote,
      'rejectionReason': result.rejectionReason,
    });
  }

  Future<McpToolResult> _handlePatchPorts(Map<String, dynamic> args) async {
    final srcMod = _requireNonEmptyString(args, 'source_module_id');
    final srcPortId = _requireNonEmptyString(args, 'source_port_id');
    final broadcast = _optionalBool(args, 'broadcast') ?? false;
    final dstMod = _optionalString(args, 'dest_module_id');
    final dstPortId = _optionalString(args, 'dest_port_id');
    final gain = _optionalDouble(args, 'gain') ?? 1.0;
    final isMuted = _optionalBool(args, 'is_muted') ?? false;

    if (!broadcast && (dstMod == null || dstPortId == null)) {
      throw const McpException.invalidParams(
        'Parameters "dest_module_id" and "dest_port_id" are required unless broadcast=true.',
      );
    }

    final ctrl = facade.modularRackController;
    final bus = ctrl.signalBus;
    final source = bus.findPort(srcMod, srcPortId);
    if (source == null) {
      throw McpException.invalidParams(
        'Source port not found: $srcMod.$srcPortId',
      );
    }

    PortId? dest;
    if (!broadcast) {
      dest = bus.findPort(dstMod!, dstPortId!);
      if (dest == null) {
        throw McpException.invalidParams(
          'Destination port not found: $dstMod.$dstPortId',
        );
      }
    }

    final validation =
        dest != null ? ctrl.validatePatch(source, dest) : null;

    try {
      final connection = ctrl.connectPorts(
        source,
        dest,
        gain: gain,
        isMuted: isMuted,
      );
      return McpToolResult.json({
        ...connection.toJson(),
        'isHyperSynergy': validation?.isHyperSynergy ?? false,
        'pedagogicalNote': validation?.pedagogicalNote,
      });
    } on ArgumentError catch (e) {
      throw McpException.acousticError(e.message.toString());
    }
  }

  Future<McpToolResult> _handleUpdateConnection(
    Map<String, dynamic> args,
  ) async {
    final connectionId = _requireNonEmptyString(args, 'connection_id');
    final gain = _optionalDouble(args, 'gain');
    final isMuted = _optionalBool(args, 'is_muted');
    final isEnabled = _optionalBool(args, 'is_enabled');

    final updated = facade.modularRackController.updateConnection(
      connectionId,
      gain: gain,
      isMuted: isMuted,
      isEnabled: isEnabled,
    );
    if (updated == null) {
      throw McpException.invalidParams(
        'SignalBus connection not found: "$connectionId".',
      );
    }
    return McpToolResult.json(updated.toJson());
  }

  Future<McpToolResult> _handleUnpatch(Map<String, dynamic> args) async {
    final connectionId = _requireNonEmptyString(args, 'connection_id');
    final existed = facade.modularRackController.activeConnections
        .any((c) => c.connectionId == connectionId);
    if (!existed) {
      throw McpException.invalidParams(
        'SignalBus connection not found: "$connectionId".',
      );
    }
    facade.modularRackController.disconnect(connectionId);
    return McpToolResult.json({
      'removedConnectionId': connectionId,
      'activeConnectionsCount':
          facade.modularRackController.activeConnections.length,
    });
  }

  Future<McpToolResult> _handleLoadPreset(Map<String, dynamic> args) async {
    final presetName = _requireNonEmptyString(args, 'preset_name');
    facade.modularRackController.loadPreset(presetName);
    return McpToolResult.json({
      'presetName': presetName,
      ...facade.modularRackController.toJson(),
    });
  }

  Future<McpToolResult> _handleInjectSignal(Map<String, dynamic> args) async {
    final srcMod = _requireNonEmptyString(args, 'source_module_id');
    final srcPortId = _requireNonEmptyString(args, 'source_port_id');
    final signalTypeRaw = _requireNonEmptyString(args, 'signal_type');
    final broadcast = _optionalBool(args, 'broadcast') ?? false;
    final payload = args['payload'];
    if (payload is! Map<String, dynamic>) {
      throw const McpException.invalidParams(
        'Parameter "payload" must be a JSON object.',
      );
    }

    final ctrl = facade.modularRackController;
    final sourcePort = ctrl.signalBus.findPort(srcMod, srcPortId);
    if (sourcePort == null) {
      throw McpException.invalidParams(
        'Source port not found: $srcMod.$srcPortId',
      );
    }

    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    final eventId = 'mcp_sig_$nowMicros';
    final AtomicSignalEvent event;

    switch (signalTypeRaw.toLowerCase()) {
      case 'temporal_clock':
        final bpm = (_optionalDouble(payload, 'bpm') ?? 120.0).clamp(20.0, 300.0);
        event = ClockTickEvent(
          eventId: eventId,
          sourcePort: sourcePort,
          timestampMicros: nowMicros,
          tickIndex: _optionalInt(payload, 'tick_index') ?? 0,
          beatsPerBar: _optionalInt(payload, 'beats_per_bar') ?? 4,
          bpm: bpm,
          isDownbeat: _optionalBool(payload, 'is_downbeat') ?? true,
          tickDurationMs: 60000.0 / bpm,
        );
      case 'pitch_events':
        event = PitchDetectionEvent(
          eventId: eventId,
          sourcePort: sourcePort,
          timestampMicros: nowMicros,
          frequencyHz: _optionalDouble(payload, 'frequency_hz') ?? 440.0,
          noteName: _optionalString(payload, 'note_name') ?? 'A4',
          centsOffset: _optionalDouble(payload, 'cents_offset') ?? 0.0,
          clarity: _optionalDouble(payload, 'clarity') ?? 0.95,
          amplitude: _optionalDouble(payload, 'amplitude') ?? 0.5,
        );
      case 'tuning_calibration':
        event = TuningCalibrationEvent(
          eventId: eventId,
          sourcePort: sourcePort,
          timestampMicros: nowMicros,
          referenceA4Hz: _optionalDouble(payload, 'reference_a4_hz') ?? 440.0,
          temperamentName:
              _optionalString(payload, 'temperament_name') ?? 'equal',
        );
      case 'transport_control':
        final cmdRaw =
            (_optionalString(payload, 'command') ?? 'play').toLowerCase();
        final command = TransportCommand.values.firstWhere(
          (c) => c.name.toLowerCase() == cmdRaw,
          orElse: () => TransportCommand.play,
        );
        event = TransportControlEvent(
          eventId: eventId,
          sourcePort: sourcePort,
          timestampMicros: nowMicros,
          command: command,
        );
      case 'audio_pcm':
        final rawSamples = payload['samples'];
        final samples = rawSamples is List
            ? rawSamples
                .whereType<num>()
                .map((n) => n.toDouble())
                .toList(growable: false)
            : const <double>[0.0, 0.25, -0.25, 0.0];
        event = AudioPcmEvent(
          eventId: eventId,
          sourcePort: sourcePort,
          timestampMicros: nowMicros,
          samples: samples,
          sampleRate: _optionalInt(payload, 'sample_rate') ?? 44100,
          rmsLevel: _optionalDouble(payload, 'rms_level') ?? 0.2,
        );
      default:
        throw McpException.invalidParams(
          'Unsupported signal_type "$signalTypeRaw".',
        );
    }

    if (broadcast) {
      ctrl.broadcastGlobalSignal(event);
    } else {
      ctrl.emitAtomicEvent(event);
    }

    // Allow microtask stream listeners on SignalBus to flush synchronously.
    await Future<void>.delayed(Duration.zero);

    final affectedNodes = ctrl.nodes.values
        .where((n) => n.lastReceivedEvent?.eventId == eventId)
        .map((n) => n.nodeId)
        .toList(growable: false);

    return McpToolResult.json({
      'dispatched': true,
      'eventId': eventId,
      'signalType': event.signalType.code,
      'broadcast': broadcast,
      'affectedNodes': affectedNodes,
    });
  }

  Future<McpToolResult> _handleExportTopology(Map<String, dynamic> args) async {
    final topology = facade.modularRackController.toJson();
    final rawOutputPath = _optionalString(args, 'output_path');

    if (rawOutputPath != null) {
      final outputPath = _resolveWorkspacePath(rawOutputPath);
      final file = File(outputPath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      final encoded = jsonEncode(topology);
      file.writeAsStringSync(encoded, flush: true);

      return McpToolResult.json({
        'outputPath': outputPath,
        'bytesWritten': utf8.encode(encoded).length,
        'modulesCount': facade.modularRackController.activeModules.length,
        'connectionsCount':
            facade.modularRackController.activeConnections.length,
        'topology': topology,
      });
    }

    return McpToolResult.json({
      'modulesCount': facade.modularRackController.activeModules.length,
      'connectionsCount': facade.modularRackController.activeConnections.length,
      'topology': topology,
    });
  }

  Future<McpToolResult> _handleRestoreTopology(
    Map<String, dynamic> args,
  ) async {
    final rawFilePath = _optionalString(args, 'file_path');
    final inlineTopology = args['topology'];

    Map<String, dynamic> topologyMap;
    if (rawFilePath != null) {
      final resolvedPath = _resolveWorkspacePath(rawFilePath);
      final file = File(resolvedPath);
      if (!file.existsSync()) {
        throw McpException.fileNotFound(
          'Topology JSON file not found: $rawFilePath',
        );
      }
      try {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is! Map<String, dynamic>) {
          throw const McpException.invalidParams(
            'Topology file does not contain a JSON object.',
          );
        }
        topologyMap = decoded;
      } on FormatException catch (e) {
        throw McpException.invalidParams('Invalid JSON topology: ${e.message}');
      }
    } else if (inlineTopology is Map<String, dynamic>) {
      topologyMap = inlineTopology;
    } else {
      throw const McpException.invalidParams(
        'Either "file_path" or "topology" JSON object must be provided.',
      );
    }

    facade.modularRackController.loadTopologyFromJson(topologyMap);
    return McpToolResult.json({
      'restored': true,
      'modulesCount': facade.modularRackController.activeModules.length,
      'connectionsCount': facade.modularRackController.activeConnections.length,
      'topology': facade.modularRackController.toJson(),
    });
  }

  // ===========================================================================
  // Helpers & Sandbox Security
  // ===========================================================================

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

  static RackModuleType _parseRackModuleType(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final value in RackModuleType.values) {
      if (value.code == normalized || value.name.toLowerCase() == normalized) {
        return value;
      }
    }
    throw McpException.invalidParams(
      'Unknown module_type "$raw". Valid codes: ${RackModuleType.values.map((e) => e.code).join(', ')}.',
    );
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

  static int? _optionalInt(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! num) {
      throw McpException.invalidParams('Parameter "$key" must be an integer.');
    }
    return v.toInt();
  }

  static bool _requireBool(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! bool) {
      throw McpException.invalidParams('Parameter "$key" must be a boolean.');
    }
    return v;
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
