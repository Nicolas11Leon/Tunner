import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/logging/domain/i_studio_logger.dart';
import 'package:tunner/features/project_format/domain/tunner_project_package.dart';
import 'package:tunner/mcp/facade/tunner_headless_facade.dart';
import 'package:tunner/mcp/ipc/tunner_ipc_bridge.dart';
import 'package:tunner/mcp/protocol/mcp_dispatcher.dart';
import 'package:tunner/mcp/protocol/mcp_json_rpc_message.dart';
import 'package:tunner/mcp/tunner_mcp_bootstrap.dart';

class _RecordingLogger implements IStudioLogger {
  final List<String> warnings = <String>[];
  final List<String> errors = <String>[];

  @override
  void warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    warnings.add('[$tag] $message');
  }

  @override
  void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    errors.add('[$tag] $message');
  }
}

Future<Map<String, dynamic>> _callToolJson(
  McpDispatcher dispatcher, {
  required int id,
  required String name,
  Map<String, dynamic> arguments = const <String, dynamic>{},
}) async {
  final response = await dispatcher.dispatch(
    McpJsonRpcRequest(
      id: id,
      method: 'tools/call',
      params: {
        'name': name,
        'arguments': arguments,
      },
    ),
  );
  expect(response, isNotNull, reason: 'Tool $name must return a response');
  expect(
    response!.isError,
    isFalse,
    reason: 'Tool $name returned JSON-RPC error: ${response.error?.toJson()}',
  );
  final result = response.result!;
  expect(
    result['isError'],
    isFalse,
    reason: 'Tool $name returned tool-level error: ${result['content']}',
  );
  return (result['structuredData'] as Map<String, dynamic>?) ??
      const <String, dynamic>{};
}

void main() {
  late Directory tempWorkspace;
  late _RecordingLogger logger;
  late TunnerHeadlessFacade facade;

  setUp(() {
    tempWorkspace = Directory.systemTemp.createTempSync('tunner_mcp_e2e_');
    logger = _RecordingLogger();
    facade = TunnerHeadlessFacade.create(
      workspaceDirectory: tempWorkspace,
      logger: logger,
    );
  });

  tearDown(() {
    facade.dispose();
    if (tempWorkspace.existsSync()) {
      tempWorkspace.deleteSync(recursive: true);
    }
  });

  group('Tunner MCP Server E2E', () {
    test(
      'registers all 17 modules via TunnerMcpBootstrap with zero collisions',
      () async {
        final registry = TunnerMcpBootstrap.createRegistry(
          facade: facade,
          headlessOnly: true,
        );
        final dispatcher = McpDispatcher(
          registry: registry,
          logger: logger,
        );

        expect(
          registry.registeredModules.length,
          equals(TunnerMcpBootstrap.expectedModuleCount),
        );
        expect(registry.hasResource('tunner://server/status'), isTrue);
        expect(registry.hasTool('tunner_server_health'), isTrue);

        // Verify JSON-RPC listing primitives match registry counts exactly.
        final initResp = await dispatcher.dispatch(
          const McpJsonRpcRequest(
            id: 1,
            method: 'initialize',
            params: {
              'protocolVersion': '2024-11-05',
              'clientInfo': {'name': 'e2e-suite', 'version': '1.0.0'},
            },
          ),
        );
        expect(initResp, isNotNull);
        expect(initResp!.isError, isFalse);
        expect(initResp.result!['protocolVersion'], equals('2024-11-05'));

        final resourcesResp = await dispatcher.dispatch(
          const McpJsonRpcRequest(id: 2, method: 'resources/list'),
        );
        final toolsResp = await dispatcher.dispatch(
          const McpJsonRpcRequest(id: 3, method: 'tools/list'),
        );
        final promptsResp = await dispatcher.dispatch(
          const McpJsonRpcRequest(id: 4, method: 'prompts/list'),
        );

        final resources =
            (resourcesResp!.result!['resources'] as List<dynamic>);
        final tools = (toolsResp!.result!['tools'] as List<dynamic>);
        final prompts = (promptsResp!.result!['prompts'] as List<dynamic>);

        expect(resources.length, equals(71));
        expect(tools.length, equals(162));
        expect(prompts.length, equals(41));
        expect(resources.length, equals(registry.resourceCount));
        expect(tools.length, equals(registry.toolCount));
        expect(prompts.length, equals(registry.promptCount));

        // Verify tunner_server_health reports consistent totals.
        final healthData = await _callToolJson(
          dispatcher,
          id: 5,
          name: 'tunner_server_health',
        );
        final counts = healthData['registeredCounts'] as Map<String, dynamic>;
        expect(counts['modules'], equals(17));
        expect(counts['resources'], equals(registry.resourceCount));
        expect(counts['tools'], equals(registry.toolCount));
        expect(counts['prompts'], equals(registry.promptCount));
      },
    );

    test(
      'executes full musical pipeline: 3/4 Grand Staff -> MusicXML, MIDI F1, PDF, WAV -> Pitch Detection',
      () async {
        final registry = TunnerMcpBootstrap.createRegistry(
          facade: facade,
          headlessOnly: true,
        );
        final dispatcher = McpDispatcher(
          registry: registry,
          logger: logger,
        );

        // 1) Create 3/4 Grand Staff piano score (2 staves, 2 measures)
        final createData = await _callToolJson(
          dispatcher,
          id: 10,
          name: 'tunner_score_create',
          arguments: const {
            'title': 'Vals E2E Grand Staff',
            'composer': 'Tunner MCP Suite',
            'bpm': 120,
            'timeSignature': '3/4',
            'keySignatureFifths': 0,
            'measureCount': 2,
            'staffCount': 2,
          },
        );
        expect(createData['title'], equals('Vals E2E Grand Staff'));
        expect(facade.activeScore, isNotNull);
        expect(facade.activeScore!.measures.length, equals(2));

        // Insert right-hand melody (staff 1, voice 1) in measure 0 (12 ticks = 3/4)
        await _callToolJson(
          dispatcher,
          id: 11,
          name: 'tunner_score_insert_note',
          arguments: const {
            'measureIndex': 0,
            'startTick': 0,
            'durationTicks': 4,
            'noteName': 'A4',
            'staff': 1,
            'voice': 1,
          },
        );
        await _callToolJson(
          dispatcher,
          id: 12,
          name: 'tunner_score_insert_note',
          arguments: const {
            'measureIndex': 0,
            'startTick': 4,
            'durationTicks': 4,
            'noteName': 'A4',
            'staff': 1,
            'voice': 1,
          },
        );
        await _callToolJson(
          dispatcher,
          id: 13,
          name: 'tunner_score_insert_note',
          arguments: const {
            'measureIndex': 0,
            'startTick': 8,
            'durationTicks': 4,
            'noteName': 'A4',
            'staff': 1,
            'voice': 1,
          },
        );

        // Insert left-hand accompaniment (staff 2, voice 2) in measure 0
        await _callToolJson(
          dispatcher,
          id: 14,
          name: 'tunner_score_insert_note',
          arguments: const {
            'measureIndex': 0,
            'startTick': 0,
            'durationTicks': 12,
            'noteName': 'A3',
            'staff': 2,
            'voice': 2,
          },
        );

        // Measure 1: sustained A4 on staff 1 + A3 on staff 2
        await _callToolJson(
          dispatcher,
          id: 15,
          name: 'tunner_score_insert_note',
          arguments: const {
            'measureIndex': 1,
            'startTick': 0,
            'durationTicks': 12,
            'noteName': 'A4',
            'staff': 1,
            'voice': 1,
          },
        );
        await _callToolJson(
          dispatcher,
          id: 16,
          name: 'tunner_score_insert_note',
          arguments: const {
            'measureIndex': 1,
            'startTick': 0,
            'durationTicks': 12,
            'noteName': 'A3',
            'staff': 2,
            'voice': 2,
          },
        );

        // 2) Export MusicXML
        final xmlData = await _callToolJson(
          dispatcher,
          id: 20,
          name: 'tunner_export_musicxml',
          arguments: const {'outputPath': 'exports/waltz_e2e.musicxml'},
        );
        final xmlFile = File('${tempWorkspace.path}/exports/waltz_e2e.musicxml');
        expect(xmlFile.existsSync(), isTrue);
        final xmlContent = xmlFile.readAsStringSync();
        expect(xmlContent, contains('<score-partwise'));
        expect(xmlContent, contains('<staves>2</staves>'));
        expect(xmlData['bytesWritten'] ?? xmlContent.length, greaterThan(100));

        // 3) Export MIDI Format 1
        final midiData = await _callToolJson(
          dispatcher,
          id: 21,
          name: 'tunner_export_midi',
          arguments: const {
            'outputPath': 'exports/waltz_e2e.mid',
            'format': 1,
          },
        );
        final midiFile = File('${tempWorkspace.path}/exports/waltz_e2e.mid');
        expect(midiFile.existsSync(), isTrue);
        final midiBytes = midiFile.readAsBytesSync();
        expect(midiBytes.length, greaterThan(24));
        // MThd header + format 1 (bytes 8..9 == 0x00, 0x01)
        expect(String.fromCharCodes(midiBytes.sublist(0, 4)), equals('MThd'));
        expect(midiBytes[8], equals(0));
        expect(midiBytes[9], equals(1));
        expect(midiData['format'], equals(1));

        // 4) Export PDF
        final pdfData = await _callToolJson(
          dispatcher,
          id: 22,
          name: 'tunner_export_pdf',
          arguments: const {'outputPath': 'exports/waltz_e2e.pdf'},
        );
        final pdfFile = File('${tempWorkspace.path}/exports/waltz_e2e.pdf');
        expect(pdfFile.existsSync(), isTrue);
        final pdfBytes = pdfFile.readAsBytesSync();
        expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
        expect(pdfData['byteLength'] ?? pdfBytes.length, greaterThan(200));

        // 5) Synthesize WAV from active score
        final wavData = await _callToolJson(
          dispatcher,
          id: 23,
          name: 'tunner_synth_score_wav',
          arguments: const {
            'outputPath': 'exports/waltz_e2e.wav',
            'sampleRate': 44100,
          },
        );
        final wavFile = File('${tempWorkspace.path}/exports/waltz_e2e.wav');
        expect(wavFile.existsSync(), isTrue);
        expect(wavFile.lengthSync(), greaterThan(44100));
        expect(wavData['sampleRate'], equals(44100));

        // 6) Analyze synthesized WAV with tunner_detect_pitch_wav
        final pitchData = await _callToolJson(
          dispatcher,
          id: 24,
          name: 'tunner_detect_pitch_wav',
          arguments: const {
            'wavFilePath': 'exports/waltz_e2e.wav',
            'a4Ref': 440.0,
          },
        );
        final voicedFrames = pitchData['voicedFrameCount'] as num;
        expect(voicedFrames, greaterThan(0));
        final medianHz = pitchData['medianPitchHz'] as num?;
        expect(medianHz, isNotNull);
        expect(medianHz!, greaterThan(100.0));
        expect(pitchData['dominantNote'], isNotNull);
      },
    );

    test(
      'TunnerIpcBridge delivers live events from TunnerHeadlessFacade on loopback and degrades silently when closed',
      () async {
        final serverBridge = TunnerIpcBridge(logger: logger);
        final clientBridge = TunnerIpcBridge(logger: logger);

        addTearDown(() async {
          await clientBridge.close();
          await serverBridge.close();
        });

        final port = await serverBridge.startServer(port: 0);
        expect(port, greaterThan(0));
        expect(serverBridge.isServerRunning, isTrue);

        final received = <TunnerIpcEvent>[];
        final twoEventsCompleter = Completer<void>();
        final sub = serverBridge.events.listen((event) {
          received.add(event);
          if (received.length >= 2 && !twoEventsCompleter.isCompleted) {
            twoEventsCompleter.complete();
          }
        });
        addTearDown(() => sub.cancel());

        final connected = await clientBridge.connect(port: port);
        expect(connected, isTrue);
        expect(clientBridge.isConnected, isTrue);

        facade.onIpcEvent = clientBridge.emitEvent;

        // Trigger score + project updates through TunnerHeadlessFacade.
        final registry = TunnerMcpBootstrap.createRegistry(
          facade: facade,
          headlessOnly: false,
          ipcPort: port,
        );
        final dispatcher = McpDispatcher(
          registry: registry,
          logger: logger,
        );
        await _callToolJson(
          dispatcher,
          id: 30,
          name: 'tunner_score_create',
          arguments: const {
            'title': 'IPC Sync Score',
            'timeSignature': '4/4',
            'measureCount': 1,
          },
        );
        facade.setActiveProject(
          const TunnerProjectPackage(
            projectId: 'proj_ipc_1',
            projectName: 'IPC Sync Project',
            masterBpm: 118.0,
            tools: [],
            createdAtMicros: 1700000000000000,
            updatedAtMicros: 1700000000000000,
          ),
        );
        await clientBridge.flush();

        await twoEventsCompleter.future.timeout(const Duration(seconds: 3));

        expect(
          received.map((e) => e.event),
          containsAll(<String>['ui.score.updated', 'workspace.project.updated']),
        );
        final scoreEvent =
            received.firstWhere((e) => e.event == 'ui.score.updated');
        expect(scoreEvent.payload['title'], equals('IPC Sync Score'));

        final projectEvent =
            received.firstWhere((e) => e.event == 'workspace.project.updated');
        expect(projectEvent.payload['projectId'], equals('proj_ipc_1'));

        // Verify silent degradation when no server is listening on a closed port.
        await serverBridge.close();
        final silentLogger = _RecordingLogger();
        final offlineClient = TunnerIpcBridge(logger: silentLogger);
        addTearDown(() => offlineClient.close());

        final offlineConnected = await offlineClient.connect(port: port);
        expect(offlineConnected, isFalse);
        expect(offlineClient.isConnected, isFalse);
        expect(silentLogger.warnings, isNotEmpty);

        // Emitting while disconnected must be a silent no-op.
        expect(
          () => offlineClient.emitEvent('ui.noop', const {'ok': true}),
          returnsNormally,
        );
      },
    );
  });
}
