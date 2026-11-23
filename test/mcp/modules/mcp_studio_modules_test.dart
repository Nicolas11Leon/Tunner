import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/domain/dj_mix_wav_encoder.dart';
import 'package:tunner/mcp/facade/tunner_headless_facade.dart';
import 'package:tunner/mcp/modules/dj_mixer_mcp_module.dart';
import 'package:tunner/mcp/modules/modular_rack_mcp_module.dart';
import 'package:tunner/mcp/modules/vault_recorder_mcp_module.dart';
import 'package:tunner/mcp/protocol/mcp_dispatcher.dart';
import 'package:tunner/mcp/protocol/mcp_error_codes.dart';
import 'package:tunner/mcp/protocol/mcp_json_rpc_message.dart';
import 'package:tunner/mcp/protocol/mcp_registry.dart';

/// Synthesizes a deterministic 16-bit mono PCM WAV buffer with a pulsing
/// harmonic sine tone at [frequencyHz] and rhythmic amplitude envelope at [bpm].
Uint8List _synthesizeTestWav({
  required double frequencyHz,
  double bpm = 120.0,
  double durationSeconds = 1.5,
  int sampleRate = 44100,
  double amplitude = 0.65,
}) {
  final totalSamples = (durationSeconds * sampleRate).round();
  final samples = Float32List(totalSamples);
  final beatSeconds = 60.0 / bpm;

  for (int i = 0; i < totalSamples; i++) {
    final t = i / sampleRate;
    final beatPhase = (t % beatSeconds) / beatSeconds;
    final env = beatPhase < 0.25 ? 1.0 : 0.35;
    final fundamental = math.sin(2.0 * math.pi * frequencyHz * t);
    final harmonic2 = 0.25 * math.sin(2.0 * math.pi * (frequencyHz * 2.0) * t);
    samples[i] = ((fundamental + harmonic2) * 0.8 * amplitude * env)
        .clamp(-1.0, 1.0);
  }

  return DjMixWavEncoder.encode(
    samples: samples,
    sampleRate: sampleRate,
    numChannels: 1,
  );
}

Future<Map<String, dynamic>> _callTool(
  McpDispatcher dispatcher,
  String name,
  Map<String, dynamic> arguments, {
  int id = 1,
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
  expect(response, isNotNull);
  expect(response!.isError, isFalse, reason: 'Tool $name failed: ${response.error?.message}');
  final result = response.result!;
  expect(result['isError'], isFalse);
  return result['structuredData'] as Map<String, dynamic>;
}

Future<McpJsonRpcResponse> _callToolRaw(
  McpDispatcher dispatcher,
  String name,
  Map<String, dynamic> arguments, {
  int id = 99,
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
  expect(response, isNotNull);
  return response!;
}

Future<Map<String, dynamic>> _readResourceJson(
  McpDispatcher dispatcher,
  String uri, {
  int id = 10,
}) async {
  final response = await dispatcher.dispatch(
    McpJsonRpcRequest(
      id: id,
      method: 'resources/read',
      params: {'uri': uri},
    ),
  );
  expect(response, isNotNull);
  expect(response!.isError, isFalse, reason: 'Resource $uri failed: ${response.error?.message}');
  final contents = response.result!['contents'] as List<dynamic>;
  expect(contents, isNotEmpty);
  final first = contents.first as Map<String, dynamic>;
  return jsonDecode(first['text'] as String) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _getPrompt(
  McpDispatcher dispatcher,
  String name,
  Map<String, String> arguments, {
  int id = 20,
}) async {
  final response = await dispatcher.dispatch(
    McpJsonRpcRequest(
      id: id,
      method: 'prompts/get',
      params: {
        'name': name,
        'arguments': arguments,
      },
    ),
  );
  expect(response, isNotNull);
  expect(response!.isError, isFalse, reason: 'Prompt $name failed: ${response.error?.message}');
  return response.result!;
}

void main() {
  late Directory tempWorkspace;
  late TunnerHeadlessFacade facade;
  late McpRegistry registry;
  late McpDispatcher dispatcher;

  setUp(() {
    tempWorkspace = Directory.systemTemp.createTempSync('tunner_mcp_studio_');
    facade = TunnerHeadlessFacade.create(workspaceDirectory: tempWorkspace);
    registry = McpRegistry();
    registry.registerModule(DjMixerMcpModule(facade));
    registry.registerModule(ModularRackMcpModule(facade));
    registry.registerModule(VaultRecorderMcpModule(facade));
    dispatcher = McpDispatcher(registry: registry);
  });

  tearDown(() {
    facade.dispose();
    if (tempWorkspace.existsSync()) {
      tempWorkspace.deleteSync(recursive: true);
    }
  });

  group('Registration & Discovery', () {
    test('registers all 3 studio modules with exact Resource/Tool/Prompt counts', () async {
      expect(registry.registeredModules, containsAll(['dj_mixer', 'modular_rack', 'vault_recorder']));
      expect(registry.resourceCount, equals(11));
      expect(registry.toolCount, equals(34));
      expect(registry.promptCount, equals(7));

      final initResp = await dispatcher.dispatch(
        const McpJsonRpcRequest(id: 1, method: 'initialize', params: {}),
      );
      expect(initResp!.isError, isFalse);

      final resList = await dispatcher.dispatch(
        const McpJsonRpcRequest(id: 2, method: 'resources/list', params: {}),
      );
      expect((resList!.result!['resources'] as List).length, equals(11));

      final toolsList = await dispatcher.dispatch(
        const McpJsonRpcRequest(id: 3, method: 'tools/list', params: {}),
      );
      expect((toolsList!.result!['tools'] as List).length, equals(34));

      final promptsList = await dispatcher.dispatch(
        const McpJsonRpcRequest(id: 4, method: 'prompts/list', params: {}),
      );
      expect((promptsList!.result!['prompts'] as List).length, equals(7));
    });
  });

  group('Report 10: DJ Console & Multi-Track Mixer', () {
    test('analyzes 2 tracks, loads decks, syncs, renders Automix WAV, and mixes stereo stems', () async {
      final trackAPath = '${tempWorkspace.path}${Platform.pathSeparator}track_a.wav';
      final trackBPath = '${tempWorkspace.path}${Platform.pathSeparator}track_b.wav';
      File(trackAPath).writeAsBytesSync(_synthesizeTestWav(frequencyHz: 440.0, bpm: 124.0));
      File(trackBPath).writeAsBytesSync(_synthesizeTestWav(frequencyHz: 329.63, bpm: 126.0));

      // 1. Stateless analysis of both tracks
      final analysisA = await _callTool(dispatcher, 'tunner_dj_analyze_track', {
        'file_path': 'track_a.wav',
        'deck_id': 'A',
      });
      expect((analysisA['bpm'] as num).toDouble(), greaterThan(0));
      expect(analysisA['camelotKey'], isA<String>());
      expect(analysisA['durationMs'], greaterThan(1000));

      final analysisB = await _callTool(dispatcher, 'tunner_dj_analyze_track', {
        'file_path': 'track_b.wav',
        'deck_id': 'B',
      });
      expect((analysisB['bpm'] as num).toDouble(), greaterThan(0));

      // 2. Harmonic compatibility check
      final compat = await _callTool(dispatcher, 'tunner_dj_check_harmonic_compatibility', {
        'source_key': '8A',
        'target_key': '9A',
      });
      expect(compat['compatibility'], equals('HARMONIC STEP'));

      // 3. Load both decks & configure DSP / loops / sync
      await _callTool(dispatcher, 'tunner_dj_load_deck', {
        'deck_id': 'A',
        'file_path': 'track_a.wav',
        'title': 'Track A',
      });
      await _callTool(dispatcher, 'tunner_dj_load_deck', {
        'deck_id': 'B',
        'file_path': 'track_b.wav',
        'title': 'Track B',
      });

      final dspA = await _callTool(dispatcher, 'tunner_dj_configure_deck_dsp', {
        'deck_id': 'A',
        'volume': 0.9,
        'trim': 1.1,
        'eq_low': 1.0,
        'eq_mid': 0.95,
        'eq_high': 1.05,
        'filter': -0.2,
        'delay_active': true,
        'delay_division': 'quarterBeat',
      });
      expect(dspA['volume'], closeTo(0.9, 1e-6));
      expect((dspA['fx'] as Map)['isDelayActive'], isTrue);

      final loopState = await _callTool(dispatcher, 'tunner_dj_control_mixer_and_loops', {
        'crossfader_position': -0.25,
        'crossfader_curve': 'constantPower',
        'deck_id': 'A',
        'loop_action': 'engage',
        'loop_beats': 4.0,
      });
      expect((loopState['crossfader'] as Map)['position'], closeTo(-0.25, 1e-6));
      expect(((loopState['deckA'] as Map)['loop'] as Map)['isActive'], isTrue);

      final syncRes = await _callTool(dispatcher, 'tunner_dj_sync_decks', {
        'target_deck_id': 'B',
        'sync_bpm': true,
        'sync_key': true,
      });
      expect(syncRes['targetDeckId'], equals('B'));

      // 4. Render offline Automix WAV transition
      final automix = await _callTool(dispatcher, 'tunner_dj_render_transition_wav', {
        'output_path': 'renders/automix_transition.wav',
        'direction': 'deckAToDeckB',
        'duration_bars': 2,
        'enable_bass_swap': true,
      });
      final automixFile = File(automix['outputPath'] as String);
      expect(automixFile.existsSync(), isTrue);
      final automixBytes = automixFile.readAsBytesSync();
      expect(automixBytes.length, greaterThan(44));
      expect(String.fromCharCodes(automixBytes.sublist(0, 4)), equals('RIFF'));

      // 5. Extract stem WAV
      final stemOut = await _callTool(dispatcher, 'tunner_dj_extract_stem_wav', {
        'input_path': 'track_a.wav',
        'output_path': 'renders/track_a_acapella.wav',
        'preset': 'acapella',
      });
      expect(File(stemOut['outputPath'] as String).existsSync(), isTrue);

      // 6. Multi-track stereo mixer configuration + render
      final mixerCfg = await _callTool(dispatcher, 'tunner_mixer_configure_track', {
        'track_id': 'voice',
        'volume': 0.9,
        'pan': -0.4,
        'is_muted': false,
        'is_solo': false,
      });
      expect(mixerCfg['hasAnySolo'], isFalse);

      final mixdown = await _callTool(dispatcher, 'tunner_mixer_render_stems_wav', {
        'stems': [
          {
            'track_id': 'voice',
            'file_path': 'track_a.wav',
            'volume': 0.85,
            'pan': -0.5,
          },
          {
            'track_id': 'piano',
            'file_path': 'track_b.wav',
            'volume': 0.75,
            'pan': 0.5,
          },
        ],
        'output_path': 'renders/stereo_mixdown.wav',
      });
      final mixFile = File(mixdown['outputPath'] as String);
      expect(mixFile.existsSync(), isTrue);
      expect(String.fromCharCodes(mixFile.readAsBytesSync().sublist(0, 4)), equals('RIFF'));
      expect((mixdown['peakDbfs'] as num).toDouble(), greaterThan(-60.0));

      // 7. Resources & Prompts
      final djState = await _readResourceJson(dispatcher, 'tunner://dj/state');
      expect((djState['deckA'] as Map)['title'], equals('Track A'));

      final camelotWheel = await _readResourceJson(dispatcher, 'tunner://dj/camelot-wheel');
      expect((camelotWheel['keys'] as List).length, equals(24));

      final skins = await _readResourceJson(dispatcher, 'tunner://dj/hardware-skins');
      expect((skins['skins'] as List).length, greaterThanOrEqualTo(5));

      final mixerState = await _readResourceJson(dispatcher, 'tunner://mixer/state');
      expect((mixerState['stems'] as List).isNotEmpty, isTrue);

      final prompt = await _getPrompt(dispatcher, 'dj_harmonic_setlist_planner', {
        'track_paths': 'track_a.wav, track_b.wav',
      });
      expect((prompt['messages'] as List).isNotEmpty, isTrue);
    });

    test('blocks path traversal with securityViolation (-32002)', () async {
      final resp = await _callToolRaw(dispatcher, 'tunner_dj_analyze_track', {
        'file_path': '../outside_secret.wav',
      });
      expect(resp.isError, isTrue);
      expect(resp.error!.code, equals(McpErrorCodes.securityViolation));
    });
  });

  group('Report 11: Modular Rack & SignalBus', () {
    test('mounts modules, patches cables, rejects DAG cycles, mutates gain/mute, exports & restores JSON', () async {
      // 1. Add 2 bidirectional audio modules to test DAG cycle rejection
      final autotune = await _callTool(dispatcher, 'tunner_rack_add_module', {
        'module_type': 'vocal_autotune',
        'custom_id': 'mod_autotune_1',
      });
      expect(autotune['moduleId'], equals('mod_autotune_1'));

      final recorder = await _callTool(dispatcher, 'tunner_rack_add_module', {
        'module_type': 'practice_recorder',
        'custom_id': 'mod_recorder_1',
      });
      expect(recorder['moduleId'], equals('mod_recorder_1'));

      // 2. Validate forward patch
      final validation = await _callTool(dispatcher, 'tunner_rack_validate_patch', {
        'source_module_id': 'mod_autotune_1',
        'source_port_id': 'tuned_out',
        'dest_module_id': 'mod_recorder_1',
        'dest_port_id': 'audio_in',
      });
      expect(validation['isApproved'], isTrue);

      // 3. Patch forward cable A -> B
      final conn = await _callTool(dispatcher, 'tunner_rack_patch_ports', {
        'source_module_id': 'mod_autotune_1',
        'source_port_id': 'tuned_out',
        'dest_module_id': 'mod_recorder_1',
        'dest_port_id': 'audio_in',
        'gain': 1.25,
      });
      final connId = conn['connectionId'] as String;
      expect(conn['gain'], closeTo(1.25, 1e-6));

      // 4. Attempt reverse cable B -> A (must be rejected as a DAG cycle)
      final cycleResp = await _callToolRaw(dispatcher, 'tunner_rack_patch_ports', {
        'source_module_id': 'mod_recorder_1',
        'source_port_id': 'playback_out',
        'dest_module_id': 'mod_autotune_1',
        'dest_port_id': 'vocal_in',
      });
      expect(cycleResp.isError, isTrue);
      expect(cycleResp.error!.code, equals(McpErrorCodes.acousticError));
      expect(cycleResp.error!.message.toLowerCase(), contains('ciclo'));

      // 5. Mutate gain/mute on existing connection
      final updatedConn = await _callTool(dispatcher, 'tunner_rack_update_connection', {
        'connection_id': connId,
        'gain': 0.75,
        'is_muted': true,
      });
      expect(updatedConn['gain'], closeTo(0.75, 1e-6));
      expect(updatedConn['isMuted'], isTrue);

      // 6. Export topology JSON to workspace, load preset, then restore topology
      final exported = await _callTool(dispatcher, 'tunner_rack_export_topology', {
        'output_path': 'rack/topology_backup.json',
      });
      expect(exported['modulesCount'], equals(2));
      expect(exported['connectionsCount'], equals(1));
      expect(File(exported['outputPath'] as String).existsSync(), isTrue);

      final preset = await _callTool(dispatcher, 'tunner_rack_load_preset', {
        'preset_name': 'dj_studio',
      });
      expect((preset['modules'] as List).length, equals(3));

      final restored = await _callTool(dispatcher, 'tunner_rack_restore_topology', {
        'file_path': 'rack/topology_backup.json',
      });
      expect(restored['restored'], isTrue);
      expect(restored['modulesCount'], equals(2));
      expect(restored['connectionsCount'], equals(1));

      // 7. Resources & Prompts
      final topology = await _readResourceJson(dispatcher, 'tunner://rack/topology');
      expect((topology['modules'] as List).length, equals(2));

      final catalog = await _readResourceJson(dispatcher, 'tunner://rack/catalog');
      expect((catalog['moduleTypes'] as List).length, equals(12));

      final telemetry = await _readResourceJson(dispatcher, 'tunner://rack/telemetry');
      expect(telemetry['modulesCount'], equals(2));

      final prompt = await _getPrompt(dispatcher, 'rack_build_hyper_synergy', {
        'pedagogical_goal': 'vocal practice with autotune and recording',
      });
      expect((prompt['messages'] as List).isNotEmpty, isTrue);
    });
  });

  group('Report 12: Media Vault & Practice Recorder', () {
    test('imports WAV to vault, places clip, exports timeline, persists catalog, and analyzes/compares offline WAV takes', () async {
      final take1Path = '${tempWorkspace.path}${Platform.pathSeparator}take_a4_pure.wav';
      final take2Path = '${tempWorkspace.path}${Platform.pathSeparator}take_a4_sharp.wav';
      // 440.0 Hz (in tune A4) vs ~445.0 Hz (+19.5 cents sharp A4)
      File(take1Path).writeAsBytesSync(_synthesizeTestWav(frequencyHz: 440.0, durationSeconds: 1.0));
      File(take2Path).writeAsBytesSync(_synthesizeTestWav(frequencyHz: 445.0, durationSeconds: 1.0));

      // 1. Import WAV into Media Vault
      final imported = await _callTool(dispatcher, 'tunner_vault_import_file', {
        'file_path': 'take_a4_pure.wav',
      });
      expect(imported['success'], isTrue);
      final importedAssets = imported['importedAssets'] as List<dynamic>;
      expect(importedAssets, isNotEmpty);
      final assetId = (importedAssets.first as Map<String, dynamic>)['id'] as String;

      // 2. Search assets & place clip on timeline
      final search = await _callTool(dispatcher, 'tunner_vault_search_assets', {
        'query': 'take_a4_pure',
        'kind': 'audioTrack',
      });
      expect(search['count'], greaterThanOrEqualTo(1));

      final timelineRes = await _readResourceJson(dispatcher, 'tunner://vault/timeline');
      final firstTrackId =
          ((timelineRes['tracks'] as List).first as Map<String, dynamic>)['trackId'] as String;

      final placed = await _callTool(dispatcher, 'tunner_vault_place_clip', {
        'asset_id': assetId,
        'track_id': firstTrackId,
        'start_ms': 0,
        'quantize': false,
      });
      expect(placed['clipId'], isNotEmpty);

      // 3. Export timeline CUE sheet & persist catalog JSON
      final exportedCue = await _callTool(dispatcher, 'tunner_vault_export_timeline', {
        'format': 'cueSheet',
        'output_path': 'exports/session.cue',
      });
      expect(exportedCue['success'], isTrue);
      expect(File(exportedCue['outputPath'] as String).existsSync(), isTrue);

      final persisted = await _callTool(dispatcher, 'tunner_vault_persist_catalog', {
        'output_path': 'vault/catalog_snapshot.json',
      });
      expect(File(persisted['outputPath'] as String).existsSync(), isTrue);

      final reloaded = await _callTool(dispatcher, 'tunner_vault_load_catalog', {
        'file_path': 'vault/catalog_snapshot.json',
      });
      expect(reloaded['restored'], isTrue);

      // 4. Analyze 2 offline WAV practice takes (no microphone required)
      final takeA = await _callTool(dispatcher, 'tunner_recorder_analyze_wav_take', {
        'file_path': 'take_a4_sharp.wav',
        'take_name': 'Take 1 Baseline',
        'take_id': 'take_baseline',
        'add_to_session': true,
      });
      expect(takeA['takeId'], equals('take_baseline'));
      expect((takeA['pitchSamplesCount'] as num).toInt(), greaterThan(0));

      final takeB = await _callTool(dispatcher, 'tunner_recorder_analyze_wav_take', {
        'file_path': 'take_a4_pure.wav',
        'take_name': 'Take 2 Improved',
        'take_id': 'take_improved',
        'add_to_session': true,
      });
      expect(takeB['takeId'], equals('take_improved'));
      expect((takeB['averagePitchDeviationCents'] as num).toDouble(), lessThan(5.0));

      // 5. Compare takes via SpectralComparatorService
      final comparison = await _callTool(dispatcher, 'tunner_recorder_compare_takes', {
        'take_a_id': 'take_baseline',
        'take_b_id': 'take_improved',
        'include_points': false,
      });
      expect((comparison['pitchStabilityDelta'] as num).toDouble(), greaterThan(0.0));
      expect((comparison['inTunePercentageB'] as num).toDouble(), greaterThan(50.0));
      expect(comparison['pedagogicalSummary'], isA<String>());

      // 6. Manage session take gain/mute
      final managed = await _callTool(dispatcher, 'tunner_recorder_manage_session_take', {
        'take_id': 'take_improved',
        'gain': 1.2,
        'is_solo': true,
      });
      expect(managed['gain'], closeTo(1.2, 1e-6));
      expect(managed['isSolo'], isTrue);

      // 7. Resources & Prompts
      final vaultAssets = await _readResourceJson(dispatcher, 'tunner://vault/assets');
      expect((vaultAssets['count'] as num).toInt(), greaterThanOrEqualTo(1));

      final history = await _readResourceJson(dispatcher, 'tunner://recorder/history');
      expect(history['count'], equals(2));

      final session = await _readResourceJson(dispatcher, 'tunner://recorder/session');
      expect(session['takesCount'], equals(2));

      final prompt = await _getPrompt(dispatcher, 'practice_take_diagnostic_coach', {
        'take_a_path': 'take_a4_sharp.wav',
        'take_b_path': 'take_a4_pure.wav',
      });
      expect((prompt['messages'] as List).isNotEmpty, isTrue);
    });
  });
}
