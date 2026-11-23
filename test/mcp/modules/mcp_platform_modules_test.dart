import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/mcp/facade/tunner_headless_facade.dart';
import 'package:tunner/mcp/modules/instruments_mcp_module.dart';
import 'package:tunner/mcp/modules/persistence_shell_mcp_module.dart';
import 'package:tunner/mcp/protocol/mcp_dispatcher.dart';
import 'package:tunner/mcp/protocol/mcp_error_codes.dart';
import 'package:tunner/mcp/protocol/mcp_json_rpc_message.dart';
import 'package:tunner/mcp/protocol/mcp_registry.dart';

void main() {
  late Directory tempWorkspace;
  late TunnerHeadlessFacade facade;
  late McpRegistry registry;
  late McpDispatcher dispatcher;
  late List<Map<String, dynamic>> ipcEvents;
  int reqId = 1;

  Future<McpJsonRpcResponse> send(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final response = await dispatcher.dispatch(
      McpJsonRpcRequest(
        id: reqId++,
        method: method,
        params: params,
      ),
    );
    expect(response, isNotNull);
    return response!;
  }

  Future<Map<String, dynamic>> callToolOk(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final resp = await send('tools/call', {
      'name': name,
      'arguments': arguments,
    });
    expect(
      resp.error,
      isNull,
      reason: 'Tool $name failed unexpectedly: ${resp.error?.message}',
    );
    final result = resp.result!;
    expect(result['isError'], isFalse);
    return result['structuredData'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> readResourceJson(String uri) async {
    final resp = await send('resources/read', {'uri': uri});
    expect(resp.error, isNull, reason: 'Resource $uri failed: ${resp.error}');
    final contents = resp.result!['contents'] as List<dynamic>;
    expect(contents, hasLength(1));
    final first = contents.first as Map<String, dynamic>;
    return jsonDecode(first['text'] as String) as Map<String, dynamic>;
  }

  setUp(() async {
    tempWorkspace = await Directory.systemTemp.createTemp('tunner_mcp_plat_');
    ipcEvents = [];
    facade = TunnerHeadlessFacade.create(
      workspaceDirectory: tempWorkspace,
      onIpcEvent: (event, payload) {
        ipcEvents.add({'event': event, 'payload': payload});
      },
    );
    registry = McpRegistry();
    registry.registerModule(InstrumentsMcpModule(facade));
    registry.registerModule(PersistenceShellMcpModule(facade));
    dispatcher = McpDispatcher(registry: registry);
  });

  tearDown(() async {
    facade.dispose();
    if (await tempWorkspace.exists()) {
      await tempWorkspace.delete(recursive: true);
    }
  });

  test('registers exact counts of Resources, Tools, and Prompts without collisions', () async {
    expect(registry.registeredModules, hasLength(2));
    expect(registry.registeredModules, containsAll(['instruments', 'persistence_shell']));
    expect(registry.resourceCount, 10);
    expect(registry.toolCount, 16);
    expect(registry.promptCount, 6);

    final resList = await send('resources/list');
    expect((resList.result!['resources'] as List).length, 10);

    final toolList = await send('tools/list');
    expect((toolList.result!['tools'] as List).length, 16);

    final promptList = await send('prompts/list');
    expect((promptList.result!['prompts'] as List).length, 6);
  });

  test('reads all 10 registered Resources across Instruments and PersistenceShell', () async {
    final catalog = await readResourceJson('tunner://catalog/instruments');
    expect(catalog['count'], greaterThanOrEqualTo(40));
    expect(catalog['legacyCount'], greaterThanOrEqualTo(40));
    expect((catalog['instruments'] as List).length, catalog['count']);

    final taxonomy = await readResourceJson('tunner://catalog/taxonomy');
    expect(taxonomy['categoryCount'], 6);
    expect(taxonomy['subfamilyCount'], 14);

    final detuning = await readResourceJson('tunner://catalog/detuning-presets');
    expect(detuning['count'], 5);

    final phrases = await readResourceJson('tunner://catalog/phrases');
    expect(phrases['count'], 5);

    final settings = await readResourceJson('tunner://settings/current');
    expect(settings['referencePitch'], 440.0);
    expect(settings['activeWorkspace'], 'learning');

    final activeWs = await readResourceJson('tunner://workspace/active');
    expect(activeWs['activeWorkspace'], 'learning');
    expect(activeWs['configuration'], isA<Map<String, dynamic>>());

    final toolsCatalog = await readResourceJson('tunner://catalog/tools');
    expect(toolsCatalog['count'], greaterThanOrEqualTo(20));

    final helpCatalog = await readResourceJson('tunner://help/tools');
    expect(helpCatalog['count'], greaterThanOrEqualTo(4));

    final themes = await readResourceJson('tunner://themes/palettes');
    expect(themes['selectedThemeId'], 'obsidian_studio');

    final capabilities = await readResourceJson('tunner://runtime/capabilities');
    expect(capabilities['mode'], 'headless');
    expect(capabilities['ipcGuiConnected'], isTrue);
    expect(capabilities['workspacePath'], tempWorkspace.path);
  });

  group('InstrumentsMcpModule', () {
    test('searches instruments and retrieves detailed profile with scaled tuning', () async {
      final searchRes = await callToolOk('tunner_search_instruments', {
        'category': 'aerophone',
        'onlyTransposing': true,
      });
      expect(searchRes['total'], greaterThanOrEqualTo(5));

      final detail = await callToolOk('tunner_get_instrument_detail', {
        'instrumentId': 'violin',
        'referencePitchA4': 442.0,
      });
      expect(detail['universalId'], 'chordophone.bowed_strings.violin_acoustic');
      expect(detail['referencePitchA4'], 442.0);
      final scaled = detail['standardTuningFrequenciesScaled'] as List;
      expect(scaled, hasLength(4));
      // Violin A4 string (index 2) at A4=442 Hz must equal 442.0 Hz
      expect((scaled[2] as num).toDouble(), closeTo(442.0, 0.05));
    });

    test('derives pure standard tuning frequencies at A4=442 Hz', () async {
      final res = await callToolOk('tunner_get_standard_tuning', {
        'instrumentId': 'violin',
        'referencePitchA4': 442.0,
      });
      expect(res['referencePitchA4'], 442.0);
      final strings = res['strings'] as List<dynamic>;
      expect(strings, hasLength(4));
      final aString = strings[2] as Map<String, dynamic>;
      expect((aString['frequencyHz'] as num).toDouble(), closeTo(442.0, 0.05));
    });

    test('transposes enharmonic boundaries Cb4, B#3, and E#4 accurately', () async {
      // Cb4 == MIDI 59 (B3). On Concert C flute (0 semitones) -> B3.
      final cb4Concert = await callToolOk('tunner_transpose_note', {
        'note': 'Cb4',
        'instrumentId': 'flute',
        'direction': 'written_to_sounding',
        'outputFormat': 'scientific',
      });
      expect(cb4Concert['inputMidi'], 59);
      expect(cb4Concert['soundingMidi'], 59);
      expect(cb4Concert['resultNote'], 'B3');

      // B#3 == MIDI 60 (C4). On Bb Clarinet (-2 semitones) -> A#3 / Bb3 (MIDI 58).
      final bSharpClarinet = await callToolOk('tunner_transpose_note', {
        'note': 'B#3',
        'instrumentId': 'bb_clarinet',
        'direction': 'written_to_sounding',
        'outputFormat': 'scientific',
        'a4RefHz': 442.0,
      });
      expect(bSharpClarinet['inputMidi'], 60);
      expect(bSharpClarinet['soundingMidi'], 58);
      expect(bSharpClarinet['resultNote'], 'A#3');
      expect(
        (bSharpClarinet['soundingFrequencyHz'] as num).toDouble(),
        closeTo(234.14, 0.2),
      );

      // E#4 == MIDI 65 (F4). Sounding F4 -> Written G4 (Sol4) on Bb Clarinet.
      final eSharpToWritten = await callToolOk('tunner_transpose_note', {
        'note': 'E#4',
        'instrumentId': 'bb_clarinet',
        'direction': 'sounding_to_written',
        'outputFormat': 'solfege',
      });
      expect(eSharpToWritten['inputMidi'], 65);
      expect(eSharpToWritten['writtenMidi'], 67);
      expect(eSharpToWritten['resultNote'], 'Sol4');
    });

    test('validates instrument tessitura in MIDI notes and Hz', () async {
      final res = await callToolOk('tunner_validate_instrument_range', {
        'instrumentId': 'flute',
        'midiNotes': [60, 72, 40], // 40 (E2) is below flute C4 (60)
        'frequenciesHz': [440.0, 80.0], // 80 Hz is below flute 261.63 Hz
      });
      expect(res['allInRange'], isFalse);
      expect(res['outOfRangeCount'], 2);
    });

    test('calculates microtonal frequency with Maqam Bayati -50 cents preset', () async {
      final res = await callToolOk('tunner_calculate_microtonal_frequency', {
        'instrumentId': 'sitar',
        'midiNote': 64, // E4
        'referencePitchA4': 440.0,
        'detuningPresetId': 'quarter_tone_maqam',
      });
      expect((res['totalOffsetCents'] as num).toDouble(), closeTo(-50.0, 0.01));
      expect(
        (res['frequencyHz'] as num).toDouble(),
        lessThan((res['equal12EdoHz'] as num).toDouble()),
      );
    });

    test('synthesizes procedural single note and phrase WAV files and blocks path traversal', () async {
      final noteRes = await callToolOk('tunner_synthesize_instrument_note', {
        'instrumentId': 'grand_piano',
        'midiNote': 69,
        'durationSeconds': 0.25,
        'velocity': 0.9,
        'sampleRate': 22050,
        'outputWavPath': 'renders/piano_a4.wav',
        'customization': {
          'referencePitchA4': 442.0,
          'resonanceFactor': 0.85,
        },
      });
      final noteFile = File(noteRes['outputWavPath'] as String);
      expect(await noteFile.exists(), isTrue);
      final noteBytes = await noteFile.readAsBytes();
      expect(utf8.decode(noteBytes.sublist(0, 4)), 'RIFF');
      expect(noteRes['sampleRate'], 22050);
      expect(noteRes['resonanceFactor'], 0.85);
      expect((noteRes['frequencyHz'] as num).toDouble(), closeTo(442.0, 0.05));

      final phraseRes = await callToolOk('tunner_synthesize_instrument_phrase', {
        'instrumentId': 'sitar',
        'phraseId': 'maqam_bayati_stanza',
        'bpm': 160,
        'sampleRate': 22050,
        'outputWavPath': 'renders/maqam_demo.wav',
        'customization': {
          'detuningPresetId': 'quarter_tone_maqam',
        },
      });
      final phraseFile = File(phraseRes['outputWavPath'] as String);
      expect(await phraseFile.exists(), isTrue);
      expect(phraseRes['bytesWritten'], greaterThan(44));

      // Path traversal must fail with McpErrorCodes.securityViolation
      final escapeResp = await send('tools/call', {
        'name': 'tunner_synthesize_instrument_note',
        'arguments': {
          'instrumentId': 'flute',
          'midiNote': 69,
          'outputWavPath': '../escaped_audio.wav',
        },
      });
      expect(escapeResp.error, isNotNull);
      expect(escapeResp.error!.code, McpErrorCodes.securityViolation);
    });

    test('detects instrument from acoustic spectral signature', () async {
      final res = await callToolOk('tunner_detect_instrument_from_signature', {
        'fundamentalFrequencyHz': 440.0,
        'clarity': 0.96,
        'overtoneAmplitudes': [1.0, 0.08, 0.65, 0.05, 0.35, 0.03, 0.18, 0.02],
        'spectralCentroidHz': 920.0,
        'limit': 3,
        'minimumConfidence': 0.75,
      });
      final best = res['bestMatch'] as Map<String, dynamic>?;
      expect(best, isNotNull);
      final inst = best!['instrument'] as Map<String, dynamic>;
      expect(inst['id'], 'bb_clarinet');
      expect((best['confidence'] as num).toDouble(), greaterThan(0.90));
    });
  });

  group('PersistenceShellMcpModule', () {
    test('reads, atomically updates, and resets user settings with IPC notifications', () async {
      final updated = await callToolOk('tunner_update_user_settings', {
        'referencePitch': 442.0,
        'bpm': 112,
        'selectedInstrumentId': 'bb_clarinet',
        'selectedTemperamentId': 'vallotti',
        'displayMode': 'essential',
        'centsPrecision': 0.5,
      });
      expect(updated['updated'], isTrue);
      expect(updated['persistedAtomically'], isTrue);
      expect(updated['ipcNotified'], isTrue);

      // Verify persisted JSON file exists on disk
      final settingsFile = File('${tempWorkspace.path}/tunner_settings.json');
      expect(await settingsFile.exists(), isTrue);

      // Verify filtered read
      final filtered = await callToolOk('tunner_get_user_settings', {
        'sections': ['audio', 'workspace'],
      });
      final audioSection =
          (filtered['settings'] as Map<String, dynamic>)['audio'] as Map<String, dynamic>;
      expect(audioSection['referencePitch'], 442.0);
      expect(audioSection['bpm'], 112);
      expect(audioSection['selectedInstrumentId'], 'bb_clarinet');
      expect(audioSection['selectedTemperamentId'], 'vallotti');

      // Reset without confirm=true must fail
      final badReset = await send('tools/call', {
        'name': 'tunner_reset_user_settings',
        'arguments': {'confirm': false},
      });
      expect(badReset.error, isNotNull);
      expect(badReset.error!.code, McpErrorCodes.invalidParams);

      // Reset with confirm=true restores defaults
      final resetRes = await callToolOk('tunner_reset_user_settings', {
        'confirm': true,
      });
      expect(resetRes['reset'], isTrue);
      final reloaded = await readResourceJson('tunner://settings/current');
      expect(reloaded['referencePitch'], 440.0);
      expect(reloaded['bpm'], 68);
    });

    test('switches workspaces, manages custom themes, searches tools, and seeds assets safely', () async {
      final wsRes = await callToolOk('tunner_switch_workspace', {
        'workspace': 'production',
        'configurationOverrides': {
          'showMetronome': true,
          'showAcousticSpectrogram': true,
        },
      });
      expect(wsRes['activeWorkspace'], 'production');
      expect(wsRes['ipcNotified'], isTrue);
      expect((wsRes['configuration'] as Map)['showMetronome'], isTrue);
      expect(
        ipcEvents.any((e) => e['event'] == 'workspace.switched'),
        isTrue,
      );

      // Manage custom theme: upsert -> select -> list -> delete
      final upsert = await callToolOk('tunner_manage_custom_theme', {
        'action': 'upsert',
        'paletteData': {
          'id': 'baroque_gold',
          'displayName': 'Baroque Gold',
          'brightness': 'dark',
          'primaryAccent': '#FFD700',
          'secondaryAccent': '#00E676',
        },
      });
      expect(upsert['customPalettesCount'], 1);

      final selected = await callToolOk('tunner_manage_custom_theme', {
        'action': 'select',
        'themeId': 'baroque_gold',
      });
      expect(selected['selectedThemeId'], 'baroque_gold');

      final deleted = await callToolOk('tunner_manage_custom_theme', {
        'action': 'delete',
        'themeId': 'baroque_gold',
      });
      expect(deleted['customPalettesCount'], 0);
      expect(deleted['selectedThemeId'], 'obsidian_studio');

      // Search tools (diacritic-insensitive)
      final toolsFound = await callToolOk('tunner_search_tools', {
        'query': 'afinacion',
        'category': 'tuner',
      });
      expect(toolsFound['count'], greaterThanOrEqualTo(1));

      // Seed workspace assets
      final seedRes = await callToolOk('tunner_seed_workspace_assets', {
        'targetDirectory': 'seeded_demo',
        'overwrite': false,
      });
      expect(seedRes['filesCount'], 2);
      final filesCreated = seedRes['filesCreated'] as List<dynamic>;
      for (final f in filesCreated) {
        final fullPath = (f as Map<String, dynamic>)['fullPath'] as String;
        expect(await File(fullPath).exists(), isTrue);
      }

      // Path traversal on seed directory must fail
      final badSeed = await send('tools/call', {
        'name': 'tunner_seed_workspace_assets',
        'arguments': {'targetDirectory': '../../outside_workspace'},
      });
      expect(badSeed.error, isNotNull);
      expect(badSeed.error!.code, McpErrorCodes.securityViolation);
    });
  });

  test('resolves all 6 guided Prompts across both modules', () async {
    const promptNames = [
      'tunner_orchestration_range_audit',
      'tunner_microtonal_ethnomusicology_lab',
      'tunner_timbral_identification_diagnostic',
      'tunner_configure_studio_session',
      'tunner_discover_workflow_tools',
      'tunner_backup_and_migrate_settings',
    ];

    for (final name in promptNames) {
      final resp = await send('prompts/get', {
        'name': name,
        'arguments': <String, String>{},
      });
      expect(resp.error, isNull, reason: 'Prompt $name failed: ${resp.error}');
      final messages = resp.result!['messages'] as List<dynamic>;
      expect(messages, isNotEmpty);
    }
  });
}
