import '../../core/dsl/domain/studio_os_audio_event.dart';
import '../../core/dsl/domain/studio_os_audio_kernel.dart';
import '../../core/dsl/domain/tunner_dsl_diagnostic.dart';
import '../../core/dsl/domain/tunner_dsl_interpreter.dart';
import '../../core/dsl/domain/tunner_dsl_lexer.dart';
import '../../core/dsl/domain/tunner_dsl_parser.dart';
import '../../core/dsl/domain/tunner_dsl_template_catalog.dart';
import '../../core/terminal/application/tunner_os_kernel.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing Tunner DSL lexing, parsing, sandboxed AST
/// interpretation, the Studio OS Audio Kernel event bus, and the Tunner OS
/// command dispatcher (`TunnerOsKernel`).
class DslTerminalMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;

  const DslTerminalMcpModule(this.facade);

  @override
  String get moduleName => 'dsl_terminal';

  StudioOsAudioKernel get _audioKernel => facade.root.audioKernel;

  TunnerOsKernel get _terminalKernel => facade.root.terminalKernel;

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
        uri: 'tunner://dsl/templates',
        name: 'Tunner DSL Template Catalog',
        description:
            'Canonical offline catalog of Tunner DSL scripts ready for validation or execution.',
        mimeType: 'application/json',
        reader: () async {
          final templates = TunnerDslTemplateCatalog.allTemplates
              .map(
                (t) => {
                  'id': t.id,
                  'name': t.title,
                  'category': t.category,
                  'defaultBpm': t.defaultBpm,
                  'description': t.description,
                  'assetPath': t.assetPath,
                  'sourceCode': t.sourceCode,
                },
              )
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://dsl/templates',
            data: {
              'count': templates.length,
              'templates': templates,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://dsl/grammar',
        name: 'Tunner DSL Grammar Specification',
        description:
            'Structured summary of Tunner DSL statements, targets, units, pitch notations, and execution guardrails.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://dsl/grammar',
            data: {
              'statements': const [
                'tempo <bpm>;',
                'channel <name>;',
                'connect @<source> -> @<destination>;',
                'set @<target>.<param> = <value> [unit];',
                'note <pitch> <fraction>;',
                'chord [<pitch>, ...] <fraction>;',
                'rest <fraction>;',
                'play; | pause; | stop;',
                'loop <count> { <statements> }',
              ],
              'targets': const [
                '@master',
                '@eq',
                '@comp',
                '@synth',
                '@reverb',
                '@spatial',
              ],
              'units': const ['dB', 'ms', 's', 'Hz', 'BPM'],
              'pitchFormats': const [
                'C4',
                'F#5',
                'Eb3',
                'Do4',
                'Sol#4',
                'Sib3',
              ],
              'durationFractions': const [
                '1/1',
                '1/2',
                '1/4',
                '1/8',
                '1/16',
                '1/32',
              ],
              'guardrails': const {
                'defaultMaxStatements':
                    TunnerDslInterpreter.defaultMaxStatements,
                'defaultMaxLoopDepth': TunnerDslInterpreter.defaultMaxLoopDepth,
              },
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://kernel/events',
        name: 'Studio OS Audio Kernel Event History',
        description:
            'Bounded chronological history of acoustic events dispatched through StudioOsAudioKernel.',
        mimeType: 'application/json',
        reader: () async {
          final history = _audioKernel.eventHistory;
          return McpResourceContent.json(
            uri: 'tunner://kernel/events',
            data: {
              'count': history.length,
              'maxHistoryLength': _audioKernel.maxHistoryLength,
              'activeScheduledTimers':
                  facade.root.kernelBridge.activeScheduledTimerCount,
              'events': history.map(_eventToJson).toList(growable: false),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://terminal/domains',
        name: 'Tunner OS Terminal Domains',
        description:
            'Registered command domains in TunnerOsKernel and connectivity status of attached domain ports.',
        mimeType: 'application/json',
        reader: () async {
          final domains = _terminalKernel.registeredDomains.toList()..sort();
          return McpResourceContent.json(
            uri: 'tunner://terminal/domains',
            data: {
              'count': domains.length,
              'domains': domains,
              'attachedPorts': {
                'fileSystem': _terminalKernel.fileSystemRepository != null,
                'matrix': _terminalKernel.matrixService != null,
                'clock': _terminalKernel.clockService != null,
                'synth': _terminalKernel.synthVoicePool != null,
                'score': _terminalKernel.scorePlaybackCoordinator != null,
                'project': _terminalKernel.projectPort != null,
                'earTraining': _terminalKernel.earTrainingEngine != null,
                'vocalEvaluator': _terminalKernel.vocalEvaluator != null,
                'reverb': _terminalKernel.reverbEngine != null,
                'spatial': _terminalKernel.spatialEngine != null,
                'nativeDspBridge': _terminalKernel.nativeDspBridge != null,
              },
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tools (6)
  // ===========================================================================

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dsl_validate',
        description:
            'Lexes and parses Tunner DSL source code without executing side effects, returning AST statement count and diagnostics.',
        inputSchema: {
          'type': 'object',
          'required': ['sourceCode'],
          'properties': {
            'sourceCode': {'type': 'string'},
          },
        },
        handler: (args) async {
          final sourceCode = _requireString(args, 'sourceCode');
          final lexer = TunnerDslLexer();
          final tokens = lexer.tokenize(sourceCode);
          final parser = TunnerDslParser();
          final parseResult = parser.parseTokens(tokens);
          final allDiagnostics = <TunnerDslDiagnostic>[
            ...lexer.diagnostics,
            ...parseResult.diagnostics,
          ];
          final hasErrors = allDiagnostics.any(
            (d) => d.severity == TunnerDslDiagnosticSeverity.error,
          );

          return McpToolResult.json({
            'isValid': !hasErrors && parseResult.program != null,
            'tokenCount': tokens.length,
            'statementCount': parseResult.program?.statements.length ?? 0,
            'diagnostics':
                allDiagnostics.map((d) => d.toJson()).toList(growable: false),
          });
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dsl_execute',
        description:
            'Parses and executes a Tunner DSL script against StudioOsAudioKernel with configurable dry-run mode and anti-DoS guardrails (maxStatements, maxLoopDepth).',
        inputSchema: {
          'type': 'object',
          'required': ['sourceCode'],
          'properties': {
            'sourceCode': {'type': 'string'},
            'dryRun': {'type': 'boolean', 'default': false},
            'initialBpm': {
              'type': 'number',
              'minimum': 20.0,
              'maximum': 300.0,
              'default': 120.0,
            },
            'maxStatements': {
              'type': 'integer',
              'minimum': 1,
              'maximum': 50000,
              'default': TunnerDslInterpreter.defaultMaxStatements,
            },
            'maxLoopDepth': {
              'type': 'integer',
              'minimum': 1,
              'maximum': 16,
              'default': TunnerDslInterpreter.defaultMaxLoopDepth,
            },
          },
        },
        handler: (args) async {
          final sourceCode = _requireString(args, 'sourceCode');
          if (sourceCode.trim().isEmpty) {
            throw const McpException.invalidParams(
              'Parameter "sourceCode" must not be empty.',
            );
          }

          final dryRun = (args['dryRun'] as bool?) ?? false;
          final initialBpm = _optionalDouble(args, 'initialBpm') ?? 120.0;
          final maxStatements = _optionalInt(args, 'maxStatements') ??
              TunnerDslInterpreter.defaultMaxStatements;
          final maxLoopDepth = _optionalInt(args, 'maxLoopDepth') ??
              TunnerDslInterpreter.defaultMaxLoopDepth;

          if (initialBpm < 20.0 || initialBpm > 300.0) {
            throw const McpException.invalidParams(
              'Parameter "initialBpm" must be within [20.0, 300.0].',
            );
          }
          if (maxStatements < 1 || maxStatements > 50000) {
            throw const McpException.invalidParams(
              'Parameter "maxStatements" must be within [1, 50000].',
            );
          }
          if (maxLoopDepth < 1 || maxLoopDepth > 16) {
            throw const McpException.invalidParams(
              'Parameter "maxLoopDepth" must be within [1, 16].',
            );
          }

          final parser = TunnerDslParser();
          final parseResult = parser.parse(sourceCode);
          if (!parseResult.isSuccess || parseResult.program == null) {
            throw McpException.dslExecutionError(
              'Tunner DSL syntax error: ${parseResult.diagnostics.map((d) => d.message).join("; ")}',
              data: {
                'diagnostics': parseResult.diagnostics
                    .map((d) => d.toJson())
                    .toList(growable: false),
              },
            );
          }

          final interpreter = TunnerDslInterpreter(
            defaultKernel: _audioKernel,
            maxStatements: maxStatements,
            maxLoopDepth: maxLoopDepth,
          );
          final report = await interpreter.interpret(
            parseResult.program!,
            kernel: _audioKernel,
            isDryRun: dryRun,
            initialBpm: initialBpm,
            maxStatements: maxStatements,
            maxLoopDepth: maxLoopDepth,
          );

          if (!report.isSuccess) {
            final isSecurityLimit = report.diagnostics.any(
              (d) =>
                  d.message.contains('MAX_STATEMENTS_EXCEEDED') ||
                  d.message.contains('MAX_LOOP_DEPTH_EXCEEDED'),
            );
            if (isSecurityLimit) {
              throw McpException.securityViolation(
                report.warnings.isNotEmpty
                    ? report.warnings.first
                    : 'DSL security guardrail exceeded.',
                data: report.toJson(),
              );
            }
            throw McpException.dslExecutionError(
              report.warnings.isNotEmpty
                  ? report.warnings.first
                  : 'DSL execution failed.',
              data: report.toJson(),
            );
          }

          final payload = <String, dynamic>{
            ...report.toJson(),
            'dryRun': dryRun,
            'activeScheduledTimers':
                facade.root.kernelBridge.activeScheduledTimerCount,
          };

          if (!dryRun) {
            facade.emitIpcEvent('dsl.script.executed', {
              'totalStatementsExecuted': report.totalStatementsExecuted,
              'totalScheduledDurationMs': report.totalScheduledDurationMs,
              'generatedEventsCount': report.generatedEvents.length,
            });
          }

          return McpToolResult.json(payload);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dsl_stop_scheduled',
        description:
            'Cancels all active scheduled DSL note/chord timers and dispatches a global stop transport event.',
        inputSchema: const {
          'type': 'object',
          'properties': {},
        },
        handler: (args) async {
          final before = facade.root.kernelBridge.activeScheduledTimerCount;
          await _audioKernel.dispatchTransport('stop');
          final remaining = facade.root.kernelBridge.activeScheduledTimerCount;

          final data = {
            'cancelledTimers': before,
            'remainingTimers': remaining,
            'status': 'stopped',
          };
          facade.emitIpcEvent('dsl.playback.stopped', data);
          return McpToolResult.json(data);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_dsl_pitch_math',
        description:
            'Computes MIDI note number, equal-temperament frequency in Hz, and optional rhythmic duration in milliseconds.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'pitch': {'type': 'string'},
            'midiNote': {'type': 'integer', 'minimum': 0, 'maximum': 127},
            'referencePitchHz': {
              'type': 'number',
              'minimum': 200.0,
              'maximum': 1000.0,
              'default': 440.0,
            },
            'fraction': {'type': 'string'},
            'bpm': {
              'type': 'number',
              'minimum': 20.0,
              'maximum': 300.0,
              'default': 120.0,
            },
          },
        },
        handler: (args) async {
          final pitch = _optionalString(args, 'pitch');
          final midiArg = _optionalInt(args, 'midiNote');
          final refHz = _optionalDouble(args, 'referencePitchHz') ?? 440.0;
          final fraction = _optionalString(args, 'fraction');
          final bpm = _optionalDouble(args, 'bpm') ?? 120.0;

          if (pitch == null && midiArg == null && fraction == null) {
            throw const McpException.invalidParams(
              'Provide at least one of "pitch", "midiNote", or "fraction".',
            );
          }
          if (refHz < 200.0 || refHz > 1000.0) {
            throw const McpException.invalidParams(
              'Parameter "referencePitchHz" must be within [200.0, 1000.0].',
            );
          }
          if (bpm < 20.0 || bpm > 300.0) {
            throw const McpException.invalidParams(
              'Parameter "bpm" must be within [20.0, 300.0].',
            );
          }
          if (midiArg != null && (midiArg < 0 || midiArg > 127)) {
            throw const McpException.invalidParams(
              'Parameter "midiNote" must be within [0, 127].',
            );
          }

          int? resolvedMidi = midiArg;
          if (resolvedMidi == null && pitch != null) {
            resolvedMidi = TunnerDslInterpreter.pitchToMidi(pitch);
          }
          final frequencyHz = resolvedMidi != null
              ? TunnerDslInterpreter.midiToFrequency(
                  resolvedMidi,
                  referencePitchHz: refHz,
                )
              : null;
          final durationMs = fraction != null
              ? TunnerDslInterpreter.calculateDurationMs(fraction, bpm)
              : null;

          return McpToolResult.json({
            'pitch': ?pitch,
            'midiNote': ?resolvedMidi,
            'frequencyHz': ?frequencyHz,
            'referencePitchHz': refHz,
            'fraction': ?fraction,
            'durationMs': ?durationMs,
            if (fraction != null) 'bpm': bpm,
          });
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_os_execute',
        description:
            'Executes a command line through the TunnerOsKernel O(1) domain dispatcher.',
        inputSchema: {
          'type': 'object',
          'required': ['commandLine'],
          'properties': {
            'commandLine': {'type': 'string'},
          },
        },
        handler: (args) async {
          final commandLine = _requireString(args, 'commandLine').trim();
          if (commandLine.isEmpty) {
            throw const McpException.invalidParams(
              'Parameter "commandLine" must be a non-empty string.',
            );
          }

          final result = await _terminalKernel.execute(commandLine);
          final data = {
            'commandLine': commandLine,
            'isSuccess': result.isSuccess,
            'output': result.message,
            'rawOutput': ?result.rawOutput,
            'data': ?result.structuredData,
            'executedAt': result.executedAt.toIso8601String(),
          };

          facade.emitIpcEvent('terminal.command.executed', {
            'commandLine': commandLine,
            'isSuccess': result.isSuccess,
          });

          return McpToolResult.json(data, summary: result.message);
        },
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_kernel_clear_history',
        description:
            'Clears the in-memory StudioOsAudioKernel acoustic event history.',
        inputSchema: const {
          'type': 'object',
          'properties': {},
        },
        handler: (args) async {
          _audioKernel.clearHistory();
          return McpToolResult.json({'cleared': true});
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
        name: 'tunner_dsl_compose_and_verify',
        description:
            'Guides the agent to read the Tunner DSL grammar and templates, author a script, validate syntax, dry-run verify duration, and execute safely.',
        arguments: const [
          McpPromptArgument(
            name: 'musicalIdea',
            description:
                'Musical objective (e.g., modal ambient pad in D Dorian, 128 BPM bassline).',
            required: false,
          ),
        ],
        builder: (args) async {
          final idea = args['musicalIdea']?.trim().isNotEmpty == true
              ? args['musicalIdea']!.trim()
              : 'short harmonic progression';
          return McpPromptResult(
            description: 'Safe Tunner DSL composition and verification workflow.',
            messages: [
              McpPromptMessage.user(
                'Read tunner://dsl/grammar and tunner://dsl/templates first. '
                'Compose a clean Tunner DSL script for "$idea", validate it with tunner_dsl_validate, '
                'verify total duration and zero warnings with tunner_dsl_execute(dryRun: true), '
                'and only then execute it live with tunner_dsl_execute(dryRun: false).',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_os_cli_workflow',
        description:
            'Guides the agent to inspect available Tunner OS terminal domains and chain verified CLI commands.',
        arguments: const [
          McpPromptArgument(
            name: 'objective',
            description:
                'Operational objective (e.g., audit DSP and set clock to 124 BPM).',
            required: false,
          ),
        ],
        builder: (args) async {
          final objective = args['objective']?.trim().isNotEmpty == true
              ? args['objective']!.trim()
              : 'inspect studio status and configure master DSP';
          return McpPromptResult(
            description: 'Tunner OS terminal automation workflow.',
            messages: [
              McpPromptMessage.user(
                'Read tunner://terminal/domains to verify registered command domains and connected ports. '
                'Then execute the required commands via tunner_os_execute to accomplish "$objective", verifying each command result.',
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  Map<String, dynamic> _eventToJson(StudioOsAudioEvent event) {
    final payload = <String, dynamic>{};
    if (event is StudioOsTempoEvent) {
      payload['bpm'] = event.bpm;
    } else if (event is StudioOsChannelDeclaredEvent) {
      payload['channelName'] = event.channelName;
    } else if (event is StudioOsConnectionEvent) {
      payload['source'] = event.source;
      payload['destination'] = event.destination;
    } else if (event is StudioOsParameterEvent) {
      payload['target'] = event.target;
      payload['parameter'] = event.parameter;
      payload['value'] = event.value;
      if (event.unit != null) payload['unit'] = event.unit;
    } else if (event is StudioOsNoteEvent) {
      payload['pitch'] = event.pitch;
      payload['frequencyHz'] = event.frequencyHz;
      payload['midiNote'] = event.midiNote;
      payload['durationFraction'] = event.durationFraction;
      payload['velocity'] = event.velocity;
      payload['scheduledOffsetMs'] = event.scheduledOffsetMs;
      payload['durationMs'] = event.durationMs;
    } else if (event is StudioOsChordEvent) {
      payload['pitches'] = event.pitches;
      payload['frequenciesHz'] = event.frequenciesHz;
      payload['midiNotes'] = event.midiNotes;
      payload['durationFraction'] = event.durationFraction;
      payload['velocity'] = event.velocity;
      payload['scheduledOffsetMs'] = event.scheduledOffsetMs;
      payload['durationMs'] = event.durationMs;
    } else if (event is StudioOsRestEvent) {
      payload['durationFraction'] = event.durationFraction;
      payload['scheduledOffsetMs'] = event.scheduledOffsetMs;
      payload['durationMs'] = event.durationMs;
    } else if (event is StudioOsTransportEvent) {
      payload['action'] = event.action;
    }

    return {
      'type': event.eventType,
      'timestampMicroseconds': event.timestampMicroseconds,
      'payload': payload,
    };
  }

  static String _requireString(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! String) {
      throw McpException.invalidParams('Parameter "$key" must be a string.');
    }
    return v;
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
    if (v is! int) {
      throw McpException.invalidParams('Parameter "$key" must be an integer.');
    }
    return v;
  }
}
