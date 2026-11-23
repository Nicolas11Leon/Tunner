import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/logging/domain/i_studio_logger.dart';
import 'package:tunner/features/project_format/domain/tunner_project_package.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/mcp/facade/tunner_headless_facade.dart';
import 'package:tunner/mcp/protocol/mcp_dispatcher.dart';
import 'package:tunner/mcp/protocol/mcp_error_codes.dart';
import 'package:tunner/mcp/protocol/mcp_json_rpc_message.dart';
import 'package:tunner/mcp/protocol/mcp_primitives.dart';
import 'package:tunner/mcp/protocol/mcp_registry.dart';
import 'package:tunner/mcp/protocol/mcp_stdio_transport.dart';

class _SampleFeatureModule implements IMcpFeatureModule {
  @override
  String get moduleName => 'sample_acoustic_module';

  @override
  void register(McpRegistry registry) {
    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://test/tuning',
        name: 'Test Tuning Reference',
        description: 'Provides A4 calibration metadata.',
        mimeType: 'application/json',
        reader: () async => McpResourceContent.json(
          uri: 'tunner://test/tuning',
          data: const {'a4Hz': 440.0, 'temperament': 'equal'},
        ),
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_test_echo_note',
        description: 'Echoes a note and frequency or fails with an acoustic error.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'note': {'type': 'string'},
            'frequencyHz': {'type': 'number'},
          },
          'required': ['note'],
        },
        handler: (arguments) async {
          final note = arguments['note'];
          if (note is! String || note.isEmpty) {
            throw const McpException.invalidParams('Parameter "note" is required.');
          }
          final freq = arguments['frequencyHz'];
          if (freq is num && freq <= 0) {
            throw const McpException.acousticError(
              'Frequency must be strictly positive.',
            );
          }
          if (note == 'INVALID_TOOL_ERROR') {
            return McpToolResult.error('Note rejected by domain validator.');
          }
          return McpToolResult.json(
            {'note': note, 'frequencyHz': freq ?? 440.0},
            summary: 'Echoed note $note.',
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'tunner_test_harmony_coach',
        description: 'Generates a guided harmony prompt for a given key.',
        arguments: const [
          McpPromptArgument(
            name: 'key',
            description: 'Target musical key (e.g., C_MAJOR).',
            required: true,
          ),
        ],
        builder: (arguments) async => McpPromptResult(
          description: 'Harmony coaching workflow',
          messages: [
            McpPromptMessage.user(
              'Analyze voice leading in ${arguments['key']}.',
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('McpJsonRpcCodec', () {
    const codec = McpJsonRpcCodec();

    test('decodes valid JSON-RPC 2.0 request and encodes response', () {
      final request = codec.decodeLine(
        '{"jsonrpc":"2.0","id":1,"method":"ping","params":{}}',
      );
      expect(request.jsonrpc, '2.0');
      expect(request.id, 1);
      expect(request.method, 'ping');
      expect(request.isNotification, isFalse);

      final encoded = codec.encode(
        McpJsonRpcResponse.success(id: 1, result: const {'ok': true}),
      );
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['jsonrpc'], '2.0');
      expect(decoded['id'], 1);
      expect((decoded['result'] as Map<String, dynamic>)['ok'], isTrue);
    });

    test('throws -32700 parseError on malformed JSON', () {
      expect(
        () => codec.decodeLine('{broken json'),
        throwsA(
          isA<McpException>().having(
            (e) => e.code,
            'code',
            McpErrorCodes.parseError,
          ),
        ),
      );
    });

    test('throws -32600 invalidRequest when jsonrpc or method is invalid', () {
      expect(
        () => codec.decodeLine('{"jsonrpc":"1.0","id":1,"method":"ping"}'),
        throwsA(
          isA<McpException>().having(
            (e) => e.code,
            'code',
            McpErrorCodes.invalidRequest,
          ),
        ),
      );
    });
  });

  group('McpRegistry & McpDispatcher', () {
    late McpRegistry registry;
    late McpDispatcher dispatcher;

    setUp(() {
      registry = McpRegistry();
      registry.registerModule(_SampleFeatureModule());
      dispatcher = McpDispatcher(
        registry: registry,
        logger: const NoOpStudioLogger(),
      );
    });

    test('prevents duplicate resource, tool, prompt, and module registrations', () {
      expect(
        () => registry.registerModule(_SampleFeatureModule()),
        throwsArgumentError,
      );
      expect(
        () => registry.registerResource(
          McpResourceDefinition(
            uri: 'tunner://test/tuning',
            name: 'Duplicate',
            description: 'Duplicate',
            mimeType: 'application/json',
            reader: () async => McpResourceContent.text(
              uri: 'tunner://test/tuning',
              text: '{}',
            ),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('handles initialize handshake, notifications/initialized, and ping', () async {
      final initResponse = await dispatcher.dispatch(
        const McpJsonRpcRequest(
          id: 1,
          method: 'initialize',
          params: {
            'protocolVersion': '2024-11-05',
            'clientInfo': {'name': 'test-client', 'version': '0.1.0'},
          },
        ),
      );

      expect(initResponse, isNotNull);
      expect(initResponse!.isError, isFalse);
      expect(initResponse.result!['protocolVersion'], '2024-11-05');
      expect(
        (initResponse.result!['serverInfo'] as Map<String, dynamic>)['name'],
        'tunner-mcp-server',
      );
      expect(dispatcher.isInitialized, isTrue);

      final notifResponse = await dispatcher.dispatch(
        const McpJsonRpcRequest(method: 'notifications/initialized'),
      );
      expect(notifResponse, isNull);

      final pingResponse = await dispatcher.dispatch(
        const McpJsonRpcRequest(id: 'ping-1', method: 'ping'),
      );
      expect(pingResponse, isNotNull);
      expect(pingResponse!.isError, isFalse);
      expect(pingResponse.result, isEmpty);
    });

    test('handles resources/list and resources/read', () async {
      final listResp = await dispatcher.dispatch(
        const McpJsonRpcRequest(id: 2, method: 'resources/list'),
      );
      final resources = listResp!.result!['resources'] as List<dynamic>;
      expect(resources, hasLength(1));
      expect(
        (resources.first as Map<String, dynamic>)['uri'],
        'tunner://test/tuning',
      );

      final readResp = await dispatcher.dispatch(
        const McpJsonRpcRequest(
          id: 3,
          method: 'resources/read',
          params: {'uri': 'tunner://test/tuning'},
        ),
      );
      expect(readResp!.isError, isFalse);
      final contents = readResp.result!['contents'] as List<dynamic>;
      final item = contents.first as Map<String, dynamic>;
      expect(item['mimeType'], 'application/json');
      final payload = jsonDecode(item['text'] as String) as Map<String, dynamic>;
      expect(payload['a4Hz'], 440.0);
    });

    test('handles tools/list and tools/call including MCP isError results', () async {
      final listResp = await dispatcher.dispatch(
        const McpJsonRpcRequest(id: 4, method: 'tools/list'),
      );
      final tools = listResp!.result!['tools'] as List<dynamic>;
      expect(tools, hasLength(1));

      final callResp = await dispatcher.dispatch(
        const McpJsonRpcRequest(
          id: 5,
          method: 'tools/call',
          params: {
            'name': 'tunner_test_echo_note',
            'arguments': {'note': 'A4', 'frequencyHz': 440.0},
          },
        ),
      );
      expect(callResp!.isError, isFalse);
      expect(callResp.result!['isError'], isFalse);
      final content = callResp.result!['content'] as List<dynamic>;
      expect((content.first as Map<String, dynamic>)['text'], 'Echoed note A4.');
      expect(
        (callResp.result!['structuredData'] as Map<String, dynamic>)['note'],
        'A4',
      );

      final toolErrorResp = await dispatcher.dispatch(
        const McpJsonRpcRequest(
          id: 6,
          method: 'tools/call',
          params: {
            'name': 'tunner_test_echo_note',
            'arguments': {'note': 'INVALID_TOOL_ERROR'},
          },
        ),
      );
      expect(toolErrorResp!.isError, isFalse);
      expect(toolErrorResp.result!['isError'], isTrue);
    });

    test('handles prompts/list and prompts/get with required argument validation', () async {
      final listResp = await dispatcher.dispatch(
        const McpJsonRpcRequest(id: 7, method: 'prompts/list'),
      );
      final prompts = listResp!.result!['prompts'] as List<dynamic>;
      expect(prompts, hasLength(1));

      final getResp = await dispatcher.dispatch(
        const McpJsonRpcRequest(
          id: 8,
          method: 'prompts/get',
          params: {
            'name': 'tunner_test_harmony_coach',
            'arguments': {'key': 'D_MINOR'},
          },
        ),
      );
      expect(getResp!.isError, isFalse);
      final messages = getResp.result!['messages'] as List<dynamic>;
      expect(messages, hasLength(1));

      final missingArgResp = await dispatcher.dispatch(
        const McpJsonRpcRequest(
          id: 9,
          method: 'prompts/get',
          params: {
            'name': 'tunner_test_harmony_coach',
            'arguments': <String, dynamic>{},
          },
        ),
      );
      expect(missingArgResp!.isError, isTrue);
      expect(missingArgResp.error!.code, McpErrorCodes.invalidParams);
    });

    test('returns JSON-RPC error codes -32601, -32602, -32000, -32001', () async {
      final unknownMethod = await dispatcher.dispatch(
        const McpJsonRpcRequest(id: 10, method: 'unknown/method'),
      );
      expect(unknownMethod!.error!.code, McpErrorCodes.methodNotFound);

      final missingUri = await dispatcher.dispatch(
        const McpJsonRpcRequest(id: 11, method: 'resources/read', params: {}),
      );
      expect(missingUri!.error!.code, McpErrorCodes.invalidParams);

      final acousticErr = await dispatcher.dispatch(
        const McpJsonRpcRequest(
          id: 12,
          method: 'tools/call',
          params: {
            'name': 'tunner_test_echo_note',
            'arguments': {'note': 'A4', 'frequencyHz': -10},
          },
        ),
      );
      expect(acousticErr!.error!.code, McpErrorCodes.acousticError);

      final missingResource = await dispatcher.dispatch(
        const McpJsonRpcRequest(
          id: 13,
          method: 'resources/read',
          params: {'uri': 'tunner://missing/resource'},
        ),
      );
      expect(missingResource!.error!.code, McpErrorCodes.fileNotFound);
    });
  });

  group('McpStdioTransport', () {
    test('processes sequential requests, notifications, and parse errors over streams', () async {
      final registry = McpRegistry()..registerModule(_SampleFeatureModule());
      final dispatcher = McpDispatcher(
        registry: registry,
        logger: const NoOpStudioLogger(),
      );

      final inputController = StreamController<List<int>>();
      final outputBytes = StreamController<List<int>>();
      final outputLines = <String>[];
      final outputSub = outputBytes.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(outputLines.add);
      final outputSink = IOSink(outputBytes.sink);

      final transport = McpStdioTransport(
        dispatcher: dispatcher,
        input: inputController.stream,
        output: outputSink,
        logger: const NoOpStudioLogger(),
      );

      final runFuture = transport.start();

      inputController.add(
        utf8.encode(
          '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n'
          '{"jsonrpc":"2.0","method":"notifications/initialized"}\n'
          '{not-valid-json}\n'
          '{"jsonrpc":"2.0","id":2,"method":"ping"}\n',
        ),
      );
      await inputController.close();
      await runFuture;
      await outputSink.close();
      await outputBytes.close();
      await outputSub.cancel();

      expect(outputLines, hasLength(3));

      final first = jsonDecode(outputLines[0]) as Map<String, dynamic>;
      expect(first['id'], 1);
      expect((first['result'] as Map<String, dynamic>)['protocolVersion'], '2024-11-05');

      final second = jsonDecode(outputLines[1]) as Map<String, dynamic>;
      expect(second['id'], isNull);
      expect(
        (second['error'] as Map<String, dynamic>)['code'],
        McpErrorCodes.parseError,
      );

      final third = jsonDecode(outputLines[2]) as Map<String, dynamic>;
      expect(third['id'], 2);
      expect(third['result'], isEmpty);
    });
  });

  group('TunnerHeadlessFacade', () {
    test('initializes headless controllers, manages active session state, and emits IPC events', () {
      final tempDir = Directory.systemTemp.createTempSync('tunner_mcp_facade_');
      final events = <(String, Map<String, dynamic>)>[];

      final facade = TunnerHeadlessFacade.create(
        workspaceDirectory: tempDir,
        logger: const NoOpStudioLogger(),
        onIpcEvent: (event, payload) => events.add((event, payload)),
      );

      try {
        expect(facade.isDisposed, isFalse);
        expect(facade.djController, isNotNull);
        expect(facade.modularRackController, isNotNull);
        expect(facade.mediaVaultController, isNotNull);
        expect(facade.offlineScoreWavRenderer, isNotNull);
        expect(facade.offlinePitchContourAnalyzer, isNotNull);
        expect(facade.offlineMetronomeTrackGenerator, isNotNull);
        expect(facade.offlinePracticeTakeAnalyzer, isNotNull);
        expect(facade.mixerAudioRenderer, isNotNull);

        const score = HierarchicalScore(
          title: 'MCP Nocturne',
          measures: [],
        );
        facade.setActiveScore(score);
        expect(facade.activeScore?.title, 'MCP Nocturne');

        final project = TunnerProjectPackage(
          projectId: 'proj_001',
          projectName: 'Studio Session',
          tools: const [],
          createdAtMicros: 1000,
          updatedAtMicros: 1000,
        );
        facade.setActiveProject(project);
        expect(facade.activeProject?.projectId, 'proj_001');

        expect(events.map((e) => e.$1), [
          'ui.score.updated',
          'workspace.project.updated',
        ]);

        final status = facade.getServerStatusSnapshot(
          registeredResources: 1,
          registeredTools: 1,
          registeredPrompts: 0,
        );
        expect(status['status'], 'ready');
        expect(status['hasActiveScore'], isTrue);
        expect(status['hasActiveProject'], isTrue);
      } finally {
        facade.dispose();
        expect(facade.isDisposed, isTrue);
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
