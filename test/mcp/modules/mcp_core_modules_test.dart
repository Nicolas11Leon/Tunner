import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/logging/domain/i_studio_logger.dart';
import 'package:tunner/mcp/facade/tunner_headless_facade.dart';
import 'package:tunner/mcp/modules/core_audio_mcp_module.dart';
import 'package:tunner/mcp/modules/dsl_terminal_mcp_module.dart';
import 'package:tunner/mcp/modules/workspace_fs_mcp_module.dart';
import 'package:tunner/mcp/protocol/mcp_dispatcher.dart';
import 'package:tunner/mcp/protocol/mcp_error_codes.dart';
import 'package:tunner/mcp/protocol/mcp_json_rpc_message.dart';
import 'package:tunner/mcp/protocol/mcp_registry.dart';

Uint8List _buildMinimalMonoWav({int sampleRate = 8000, int frames = 64}) {
  final dataSize = frames * 2;
  final bytes = Uint8List(44 + dataSize);
  final bd = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  bd.setUint32(4, 36 + dataSize, Endian.little);
  bytes.setRange(8, 12, 'WAVE'.codeUnits);
  bytes.setRange(12, 16, 'fmt '.codeUnits);
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little);
  bd.setUint16(22, 1, Endian.little);
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, sampleRate * 2, Endian.little);
  bd.setUint16(32, 2, Endian.little);
  bd.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, 'data'.codeUnits);
  bd.setUint32(40, dataSize, Endian.little);
  bd.setInt16(44, 16000, Endian.little);
  return bytes;
}

void main() {
  late Directory tempWorkspace;
  late TunnerHeadlessFacade facade;
  late McpRegistry registry;
  late McpDispatcher dispatcher;
  late List<Map<String, dynamic>> emittedIpcEvents;

  Future<McpJsonRpcResponse> callRpc(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final response = await dispatcher.dispatch(
      McpJsonRpcRequest(
        id: 'req_$method',
        method: method,
        params: params,
      ),
    );
    expect(response, isNotNull);
    return response!;
  }

  setUp(() async {
    tempWorkspace = await Directory.systemTemp.createTemp('tunner_mcp_core_');
    emittedIpcEvents = <Map<String, dynamic>>[];
    facade = TunnerHeadlessFacade.create(
      workspaceDirectory: tempWorkspace,
      logger: const NoOpStudioLogger(),
      onIpcEvent: (event, payload) {
        emittedIpcEvents.add({'event': event, 'payload': payload});
      },
    );
    registry = McpRegistry()
      ..registerModule(CoreAudioMcpModule(facade))
      ..registerModule(DslTerminalMcpModule(facade))
      ..registerModule(WorkspaceFsMcpModule(facade));
    dispatcher = McpDispatcher(
      registry: registry,
      logger: const NoOpStudioLogger(),
    );
  });

  tearDown(() async {
    facade.dispose();
    if (await tempWorkspace.exists()) {
      await tempWorkspace.delete(recursive: true);
    }
  });

  group('MCP Registry & Discovery across Core Modules', () {
    test('lists all 13 Resources, 32 Tools, and 7 Prompts', () async {
      final resList = await callRpc('resources/list');
      final resources = resList.result!['resources'] as List<dynamic>;
      expect(resources.length, 13);
      expect(registry.resourceCount, 13);

      final toolList = await callRpc('tools/list');
      final tools = toolList.result!['tools'] as List<dynamic>;
      expect(tools.length, 32);
      expect(registry.toolCount, 32);

      final promptList = await callRpc('prompts/list');
      final prompts = promptList.result!['prompts'] as List<dynamic>;
      expect(prompts.length, 7);
      expect(registry.promptCount, 7);
    });

    test('reads all 13 registered resources as valid JSON', () async {
      final resList = await callRpc('resources/list');
      final resources = resList.result!['resources'] as List<dynamic>;
      for (final descriptor in resources) {
        final uri = (descriptor as Map<String, dynamic>)['uri'] as String;
        final readRes = await callRpc('resources/read', {'uri': uri});
        expect(readRes.error, isNull, reason: 'Resource $uri failed');
        final contents = readRes.result!['contents'] as List<dynamic>;
        expect(contents.length, 1);
        final first = contents.first as Map<String, dynamic>;
        expect(first['uri'], uri);
        final decoded = jsonDecode(first['text'] as String);
        expect(decoded, isA<Map<String, dynamic>>());
      }
    });

    test('resolves prompts/get for each core module', () async {
      final p1 = await callRpc('prompts/get', {
        'name': 'tunner_mastering_chain_setup',
        'arguments': {'targetGenre': 'vocal_academic'},
      });
      expect(p1.error, isNull);
      expect(p1.result!['messages'], isNotEmpty);

      final p2 = await callRpc('prompts/get', {
        'name': 'tunner_dsl_compose_and_verify',
        'arguments': {'musicalIdea': 'D Dorian pad'},
      });
      expect(p2.error, isNull);
      expect(p2.result!['messages'], isNotEmpty);

      final p3 = await callRpc('prompts/get', {
        'name': 'tunner_workspace_layout_personalizer',
        'arguments': {'taskType': 'mastering'},
      });
      expect(p3.error, isNull);
      expect(p3.result!['messages'], isNotEmpty);
    });
  });

  group('CoreAudioMcpModule Tools', () {
    test('mutates master matrix, EQ, compressor, clock, reverb, binaural, and emits IPC', () async {
      final gainRes = await callRpc('tools/call', {
        'name': 'tunner_audio_set_master_gain',
        'arguments': {'gainLinear': 0.8},
      });
      expect(gainRes.error, isNull);
      expect(
        (gainRes.result!['structuredData'] as Map)['masterGain'],
        closeTo(0.8, 1e-6),
      );

      final eqRes = await callRpc('tools/call', {
        'name': 'tunner_audio_configure_eq',
        'arguments': {'lowDb': 2.5, 'midDb': -1.0, 'highDb': 1.5},
      });
      expect(eqRes.error, isNull);
      expect((eqRes.result!['structuredData'] as Map)['eqLowDb'], 2.5);

      final compRes = await callRpc('tools/call', {
        'name': 'tunner_audio_configure_compressor',
        'arguments': {'thresholdDb': -14.0, 'ratio': 4.0},
      });
      expect(compRes.error, isNull);
      expect((compRes.result!['structuredData'] as Map)['compRatio'], 4.0);

      final bufRes = await callRpc('tools/call', {
        'name': 'tunner_audio_set_buffer_size',
        'arguments': {'bufferSize': 256},
      });
      expect(bufRes.error, isNull);
      expect((bufRes.result!['structuredData'] as Map)['bufferSize'], 256);

      final clockRes = await callRpc('tools/call', {
        'name': 'tunner_clock_control',
        'arguments': {'bpm': 128.0, 'numerator': 3, 'denominator': 4},
      });
      expect(clockRes.error, isNull);
      expect((clockRes.result!['structuredData'] as Map)['bpm'], 128.0);
      expect((clockRes.result!['structuredData'] as Map)['meter'], '3/4');

      final revRes = await callRpc('tools/call', {
        'name': 'tunner_dsp_configure_reverb',
        'arguments': {'roomSize': 0.75, 'wetMix': 0.45},
      });
      expect(revRes.error, isNull);
      expect((revRes.result!['structuredData'] as Map)['roomSize'], 0.75);

      final binRes = await callRpc('tools/call', {
        'name': 'tunner_dsp_configure_binaural',
        'arguments': {'azimuthDegrees': 45.0, 'distanceMeters': 2.0},
      });
      expect(binRes.error, isNull);
      expect((binRes.result!['structuredData'] as Map)['azimuthDegrees'], 45.0);

      final benchRes = await callRpc('tools/call', {
        'name': 'tunner_dsp_benchmark',
        'arguments': {'iterations': 5, 'blockSize': 256},
      });
      expect(benchRes.error, isNull);
      expect(
        (benchRes.result!['structuredData'] as Map)['throughputMegaSamplesPerSec'],
        greaterThan(0.0),
      );

      expect(
        emittedIpcEvents.any((e) => e['event'] == 'audio.matrix.updated'),
        isTrue,
      );
      expect(
        emittedIpcEvents.any((e) => e['event'] == 'audio.clock.state'),
        isTrue,
      );
    });

    test('manages patchbay channels, plugs, and parameters', () async {
      final createRes = await callRpc('tools/call', {
        'name': 'tunner_patchbay_manage_channel',
        'arguments': {'action': 'create', 'name': 'Synth Bus'},
      });
      expect(createRes.error, isNull);
      final channel =
          (createRes.result!['structuredData'] as Map)['channel'] as Map;
      final channelId = channel['id'] as String;

      final connectRes = await callRpc('tools/call', {
        'name': 'tunner_patchbay_connect_plug',
        'arguments': {
          'action': 'connect',
          'plugId': 'synth_out_1',
          'channelId': channelId,
          'plugType': 'audioOut',
        },
      });
      expect(connectRes.error, isNull);
      expect(
        (connectRes.result!['structuredData'] as Map)['connectedChannelId'],
        channelId,
      );

      final pubRes = await callRpc('tools/call', {
        'name': 'tunner_patchbay_publish_params',
        'arguments': {
          'channelId': channelId,
          'title': 'Lead Pad',
          'bpm': 124.0,
          'key': '9A',
        },
      });
      expect(pubRes.error, isNull);
      expect(
        (pubRes.result!['structuredData'] as Map)['activeTrackTitle'],
        'Lead Pad',
      );
    });

    test('renders IR convolution in Isolate and rejects invalid params / traversal', () async {
      final wavFile = File('${tempWorkspace.path}/input.wav');
      await wavFile.writeAsBytes(_buildMinimalMonoWav(), flush: true);

      final convRes = await callRpc('tools/call', {
        'name': 'tunner_dsp_render_ir_convolution',
        'arguments': {
          'inputWavPath': 'input.wav',
          'syntheticRt60': 0.08,
          'outputWavPath': 'out/convolved.wav',
        },
      });
      expect(convRes.error, isNull);
      expect(
        await File('${tempWorkspace.path}/out/convolved.wav').exists(),
        isTrue,
      );

      final badBuf = await callRpc('tools/call', {
        'name': 'tunner_audio_set_buffer_size',
        'arguments': {'bufferSize': 999},
      });
      expect(badBuf.error?.code, McpErrorCodes.invalidParams);

      final traversal = await callRpc('tools/call', {
        'name': 'tunner_dsp_render_ir_convolution',
        'arguments': {
          'inputWavPath': '../escape.wav',
          'syntheticRt60': 0.1,
          'outputWavPath': 'out.wav',
        },
      });
      expect(traversal.error?.code, McpErrorCodes.securityViolation);
    });
  });

  group('DslTerminalMcpModule Tools', () {
    test('validates, dry-runs, executes real DSL, and runs TunnerOsKernel commands', () async {
      const validScript = '''
tempo 120;
channel lead;
note C4 1/8;
chord [C4, E4, G4] 1/4;
''';

      final valRes = await callRpc('tools/call', {
        'name': 'tunner_dsl_validate',
        'arguments': {'sourceCode': validScript},
      });
      expect(valRes.error, isNull);
      expect((valRes.result!['structuredData'] as Map)['isValid'], isTrue);
      expect((valRes.result!['structuredData'] as Map)['statementCount'], 4);

      final dryRes = await callRpc('tools/call', {
        'name': 'tunner_dsl_execute',
        'arguments': {'sourceCode': validScript, 'dryRun': true},
      });
      expect(dryRes.error, isNull);
      expect((dryRes.result!['structuredData'] as Map)['isSuccess'], isTrue);
      expect(
        (dryRes.result!['structuredData'] as Map)['totalScheduledDurationMs'],
        greaterThan(0),
      );

      final execRes = await callRpc('tools/call', {
        'name': 'tunner_dsl_execute',
        'arguments': {'sourceCode': validScript, 'dryRun': false},
      });
      expect(execRes.error, isNull);
      expect(
        (execRes.result!['structuredData'] as Map)['generatedEventsCount'],
        greaterThanOrEqualTo(4),
      );

      final stopRes = await callRpc('tools/call', {
        'name': 'tunner_dsl_stop_scheduled',
        'arguments': const <String, dynamic>{},
      });
      expect(stopRes.error, isNull);
      expect((stopRes.result!['structuredData'] as Map)['status'], 'stopped');

      final mathRes = await callRpc('tools/call', {
        'name': 'tunner_dsl_pitch_math',
        'arguments': {'pitch': 'A4', 'fraction': '1/4', 'bpm': 120.0},
      });
      expect(mathRes.error, isNull);
      final mathData = mathRes.result!['structuredData'] as Map;
      expect(mathData['midiNote'], 69);
      expect(mathData['frequencyHz'], closeTo(440.0, 1e-6));
      expect(mathData['durationMs'], closeTo(500.0, 1e-6));

      final osRes = await callRpc('tools/call', {
        'name': 'tunner_os_execute',
        'arguments': {'commandLine': 'help'},
      });
      expect(osRes.error, isNull);
      expect((osRes.result!['structuredData'] as Map)['isSuccess'], isTrue);

      final clearRes = await callRpc('tools/call', {
        'name': 'tunner_kernel_clear_history',
        'arguments': const <String, dynamic>{},
      });
      expect(clearRes.error, isNull);
      expect(facade.root.audioKernel.eventHistory, isEmpty);
    });

    test('enforces DSL security guardrails (-32002) and invalidParams (-32602)', () async {
      const abusiveLoop = '''
loop 50 {
  note C4 1/16;
}
''';
      final limitRes = await callRpc('tools/call', {
        'name': 'tunner_dsl_execute',
        'arguments': {
          'sourceCode': abusiveLoop,
          'dryRun': true,
          'maxStatements': 10,
        },
      });
      expect(limitRes.error?.code, McpErrorCodes.securityViolation);

      final badExec = await callRpc('tools/call', {
        'name': 'tunner_os_execute',
        'arguments': {'commandLine': '   '},
      });
      expect(badExec.error?.code, McpErrorCodes.invalidParams);
    });
  });

  group('WorkspaceFsMcpModule Tools', () {
    test('performs workspace CRUD, .tunner encode/decode, and UI IPC sync', () async {
      final writeRes = await callRpc('tools/call', {
        'name': 'tunner_fs_write_file',
        'arguments': {
          'relativePath': 'scripts/demo.tndsl',
          'content': 'tempo 110;\nnote C4 1/4;\n',
        },
      });
      expect(writeRes.error, isNull);

      final readRes = await callRpc('tools/call', {
        'name': 'tunner_fs_read_file',
        'arguments': {'relativePath': 'scripts/demo.tndsl'},
      });
      expect(readRes.error, isNull);
      expect(
        (readRes.result!['structuredData'] as Map)['content'],
        contains('tempo 110;'),
      );

      final listRes = await callRpc('tools/call', {
        'name': 'tunner_fs_list_workspace',
        'arguments': {'searchQuery': 'demo.tndsl'},
      });
      expect(listRes.error, isNull);
      expect(
        (listRes.result!['structuredData'] as Map)['matchCount'],
        greaterThanOrEqualTo(1),
      );

      final renameRes = await callRpc('tools/call', {
        'name': 'tunner_fs_manage_node',
        'arguments': {
          'action': 'rename',
          'relativePath': 'scripts/demo.tndsl',
          'newName': 'demo_renamed.tndsl',
        },
      });
      expect(renameRes.error, isNull);
      expect(
        (renameRes.result!['structuredData'] as Map)['resultingPath'],
        'scripts/demo_renamed.tndsl',
      );

      final encodeRes = await callRpc('tools/call', {
        'name': 'tunner_package_encode',
        'arguments': {
          'outputRelativePath': 'projects/session.tunner',
          'manifest': {
            'id': 'proj_mcp_1',
            'title': 'MCP Test Session',
            'bpm': 122.0,
          },
          'scoreJson': {'title': 'Sketch 1', 'measures': []},
        },
      });
      expect(encodeRes.error, isNull);
      expect(
        ((encodeRes.result!['structuredData'] as Map)['fileHashes'] as Map),
        isNotEmpty,
      );

      final decodeRes = await callRpc('tools/call', {
        'name': 'tunner_package_decode',
        'arguments': {
          'relativePath': 'projects/session.tunner',
          'verifyHashes': true,
        },
      });
      expect(decodeRes.error, isNull);
      final decoded = decodeRes.result!['structuredData'] as Map;
      expect(decoded['integrityVerified'], isTrue);
      expect(decoded['hasScore'], isTrue);

      final themeRes = await callRpc('tools/call', {
        'name': 'tunner_ui_set_theme',
        'arguments': {'skinId': 'skin_neve_88rs'},
      });
      expect(themeRes.error, isNull);
      expect(
        (themeRes.result!['structuredData'] as Map)['ipcBroadcastSent'],
        isTrue,
      );

      final dockRes = await callRpc('tools/call', {
        'name': 'tunner_ui_set_dock_layout',
        'arguments': {'preset': 'three_columns'},
      });
      expect(dockRes.error, isNull);

      final tabRes = await callRpc('tools/call', {
        'name': 'tunner_ui_navigate_tab',
        'arguments': {'tabId': 'studio'},
      });
      expect(tabRes.error, isNull);

      expect(
        emittedIpcEvents.any((e) => e['event'] == 'ui.theme.changed'),
        isTrue,
      );
      expect(
        emittedIpcEvents.any((e) => e['event'] == 'ui.docking.layout_changed'),
        isTrue,
      );
      expect(
        emittedIpcEvents.any((e) => e['event'] == 'ui.navigation.tab_changed'),
        isTrue,
      );
    });

    test('blocks path traversal (-32002) and rejects invalid UI tab (-32602)', () async {
      final traversalRead = await callRpc('tools/call', {
        'name': 'tunner_fs_read_file',
        'arguments': {'relativePath': '../../etc/passwd'},
      });
      expect(traversalRead.error?.code, McpErrorCodes.securityViolation);

      final traversalWrite = await callRpc('tools/call', {
        'name': 'tunner_fs_write_file',
        'arguments': {'relativePath': '../escape.txt', 'content': 'blocked'},
      });
      expect(traversalWrite.error?.code, McpErrorCodes.securityViolation);

      final badTab = await callRpc('tools/call', {
        'name': 'tunner_ui_navigate_tab',
        'arguments': {'tabId': 'nonexistent_tab'},
      });
      expect(badTab.error?.code, McpErrorCodes.invalidParams);
    });
  });
}
