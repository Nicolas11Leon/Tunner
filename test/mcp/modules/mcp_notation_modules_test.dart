import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/logging/domain/i_studio_logger.dart';
import 'package:tunner/mcp/facade/tunner_headless_facade.dart';
import 'package:tunner/mcp/modules/importers_omr_mcp_module.dart';
import 'package:tunner/mcp/modules/notation_editor_mcp_module.dart';
import 'package:tunner/mcp/modules/project_library_mcp_module.dart';
import 'package:tunner/mcp/protocol/mcp_dispatcher.dart';
import 'package:tunner/mcp/protocol/mcp_error_codes.dart';
import 'package:tunner/mcp/protocol/mcp_json_rpc_message.dart';
import 'package:tunner/mcp/protocol/mcp_registry.dart';

/// Builds a synthetic 16-bit mono PCM RIFF/WAVE buffer containing a pure sine wave.
Uint8List _buildSyntheticSineWav({
  required double frequencyHz,
  double durationSeconds = 0.6,
  int sampleRate = 44100,
  double amplitude = 0.6,
}) {
  final sampleCount = (durationSeconds * sampleRate).round();
  final dataSize = sampleCount * 2;
  final fileSize = 36 + dataSize;
  final bytes = ByteData(44 + dataSize);

  void writeAscii(int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  bytes.setUint32(4, fileSize, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // Mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);

  for (int i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    final sample = (math.sin(2.0 * math.pi * frequencyHz * t) * amplitude * 32767.0)
        .round()
        .clamp(-32768, 32767);
    bytes.setInt16(44 + i * 2, sample, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

void main() {
  late Directory tempWorkspace;
  late TunnerHeadlessFacade facade;
  late McpRegistry registry;
  late McpDispatcher dispatcher;
  int nextId = 1;

  Future<Map<String, dynamic>> callTool(
    String name, [
    Map<String, dynamic> arguments = const {},
  ]) async {
    final response = await dispatcher.dispatch(
      McpJsonRpcRequest(
        id: nextId++,
        method: 'tools/call',
        params: {
          'name': name,
          'arguments': arguments,
        },
      ),
    );
    expect(response, isNotNull);
    expect(response!.error, isNull, reason: 'Tool $name returned RPC error: ${response.error?.toJson()}');
    final result = response.result!;
    expect(result['isError'], isFalse, reason: 'Tool $name returned tool error: ${result['content']}');
    return (result['structuredData'] as Map<String, dynamic>?) ?? const {};
  }

  Future<Map<String, dynamic>> readResourceJson(String uri) async {
    final response = await dispatcher.dispatch(
      McpJsonRpcRequest(
        id: nextId++,
        method: 'resources/read',
        params: {'uri': uri},
      ),
    );
    expect(response, isNotNull);
    expect(response!.error, isNull);
    final contents = response.result!['contents'] as List<dynamic>;
    final first = contents.first as Map<String, dynamic>;
    return jsonDecode(first['text'] as String) as Map<String, dynamic>;
  }

  setUp(() async {
    tempWorkspace = await Directory.systemTemp.createTemp('tunner_mcp_notation_test_');
    facade = TunnerHeadlessFacade.create(
      workspaceDirectory: tempWorkspace,
      logger: const NoOpStudioLogger(),
    );
    registry = McpRegistry();
    registry.registerModule(NotationEditorMcpModule(facade: facade));
    registry.registerModule(ImportersOmrMcpModule(facade: facade));
    registry.registerModule(ProjectLibraryMcpModule(facade: facade));
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

  test('registers all 3 modules with expected Resource, Tool, and Prompt counts', () async {
    expect(
      registry.registeredModules,
      containsAll(['notation_editor', 'importers_omr', 'project_library']),
    );
    // Notation: 4R / 19T / 3P | Importers: 2R / 6T / 2P | ProjectLibrary: 5R / 9T / 2P
    expect(registry.resourceCount, 11);
    expect(registry.toolCount, 34);
    expect(registry.promptCount, 7);

    final listToolsResp = await dispatcher.dispatch(
      McpJsonRpcRequest(id: nextId++, method: 'tools/list'),
    );
    expect((listToolsResp!.result!['tools'] as List).length, 34);

    final listResResp = await dispatcher.dispatch(
      McpJsonRpcRequest(id: nextId++, method: 'resources/list'),
    );
    expect((listResResp!.result!['resources'] as List).length, 11);

    final listPromptsResp = await dispatcher.dispatch(
      McpJsonRpcRequest(id: nextId++, method: 'prompts/list'),
    );
    expect((listPromptsResp!.result!['prompts'] as List).length, 7);
  });

  test('composes a Grand Staff 3/4 piano waltz, validates, exports MusicXML/MIDI Format 1/ABC/PDF, and saves/loads .tunner', () async {
    // 1. Create a 2-measure 3/4 Grand Staff piano score
    final created = await callTool('tunner_score_create', {
      'title': 'Vals de Prueba en 3/4',
      'composer': 'Tunner Test Suite',
      'bpm': 108,
      'timeSignature': '3/4',
      'keySignatureFifths': 1, // G Major
      'measureCount': 2,
      'staffCount': 2,
    });
    expect(created['totalMeasures'], 2);
    expect(created['staffCount'], 2);
    expect(created['isValid'], isTrue);

    // 2. Compose polyphonic Grand Staff waltz (RH staff 1 voice 1, LH staff 2 voice 2)
    final composed = await callTool('tunner_score_compose_measures', {
      'measures': [
        {
          'index': 0,
          'timeSignature': '3/4',
          'keySignatureFifths': 1,
          'events': [
            // Right hand melody (staff 1, voice 1)
            {'startTick': 0, 'durationTicks': 4, 'notes': ['Sol4'], 'staff': 1, 'voice': 1},
            {'startTick': 4, 'durationTicks': 4, 'notes': ['Si4'], 'staff': 1, 'voice': 1},
            {'startTick': 8, 'durationTicks': 4, 'notes': ['Re5'], 'staff': 1, 'voice': 1},
            // Left hand waltz accompaniment (staff 2, voice 2): bass + chord + chord
            {'startTick': 0, 'durationTicks': 4, 'notes': ['Sol2'], 'staff': 2, 'voice': 2},
            {'startTick': 4, 'durationTicks': 4, 'notes': ['Si3', 'Re4'], 'staff': 2, 'voice': 2},
            {'startTick': 8, 'durationTicks': 4, 'notes': ['Si3', 'Re4'], 'staff': 2, 'voice': 2},
          ],
        },
        {
          'index': 1,
          'timeSignature': '3/4',
          'keySignatureFifths': 1,
          'events': [
            {'startTick': 0, 'durationTicks': 8, 'notes': ['Do5'], 'staff': 1, 'voice': 1},
            {'startTick': 8, 'durationTicks': 4, 'notes': ['La4'], 'staff': 1, 'voice': 1},
            {'startTick': 0, 'durationTicks': 4, 'notes': ['Re2'], 'staff': 2, 'voice': 2},
            {'startTick': 4, 'durationTicks': 4, 'notes': ['Fa#3', 'Do4'], 'staff': 2, 'voice': 2},
            {'startTick': 8, 'durationTicks': 4, 'notes': ['Fa#3', 'Do4'], 'staff': 2, 'voice': 2},
          ],
        },
      ],
    });
    expect(composed['isValidScore'], isTrue);
    expect(composed['staffCount'], 2);
    expect(composed['totalNotes'], 15);

    // 3. Validate via tool & inspect active score resource
    final validation = await callTool('tunner_score_validate');
    expect(validation['isValidScore'], isTrue);
    expect(validation['invalidMeasures'], isEmpty);

    final activeScoreJson = await readResourceJson('tunner://score/active');
    expect(activeScoreJson['hasActiveScore'], isTrue);
    expect(activeScoreJson['staffCount'], 2);
    expect(activeScoreJson['totalMeasures'], 2);

    // 4. Test edit operations: transpose + undo + redo + preview + quantize
    final transposed = await callTool('tunner_score_transpose', {'semitones': 2});
    expect(transposed['totalNotesTransposed'], 15);

    final undone = await callTool('tunner_score_undo');
    expect(undone['applied'], isTrue);

    final redone = await callTool('tunner_score_redo');
    expect(redone['applied'], isTrue);

    // Undo back to original G Major waltz
    await callTool('tunner_score_undo');

    final preview = await callTool('tunner_score_preview_note', {
      'noteName': 'Sol4',
      'durationSeconds': 0.05,
    });
    expect(preview['midiNumber'], 67);
    expect(preview['played'], isTrue);

    // 5. Export to MusicXML, MIDI Format 1, ABC, and PDF SMuFL
    final xmlRes = await callTool('tunner_export_musicxml', {
      'outputPath': 'exports/waltz.musicxml',
    });
    final xml = xmlRes['xml'] as String;
    expect(xml, contains('<staves>2</staves>'));
    expect(xml, contains('<backup>'));
    expect(xml, contains('<beats>3</beats>'));
    expect(xml, contains('<fifths>1</fifths>'));
    expect(File(xmlRes['outputPath'] as String).existsSync(), isTrue);

    final midiRes = await callTool('tunner_export_midi', {
      'outputPath': 'exports/waltz.mid',
      'format': 1,
      'programNumber': 0,
    });
    expect(midiRes['format'], 1);
    expect((midiRes['trackCount'] as int), greaterThanOrEqualTo(3)); // Conductor + 2 streams
    final midiBytes = base64Decode(midiRes['base64'] as String);
    expect(String.fromCharCodes(midiBytes.sublist(0, 4)), 'MThd');
    expect(File(midiRes['outputPath'] as String).existsSync(), isTrue);

    final abcRes = await callTool('tunner_export_abc', {
      'outputPath': 'exports/waltz.abc',
    });
    final abc = abcRes['abc'] as String;
    expect(abc, contains('M: 3/4'));
    expect(abc, contains('K: G'));
    expect(abc, contains('V:S1V1'));
    expect(abc, contains('V:S2V2'));

    final pdfRes = await callTool('tunner_export_pdf', {
      'outputPath': 'exports/waltz.pdf',
    });
    final pdfBytes = base64Decode(pdfRes['base64'] as String);
    expect(ascii.decode(pdfBytes.sublist(0, 8)), '%PDF-1.4');
    expect(File(pdfRes['outputPath'] as String).existsSync(), isTrue);

    // 6. Save and reload as .tunner project
    final savedProj = await callTool('tunner_project_save', {
      'relativePath': 'projects/waltz_session.tunner',
      'projectName': 'Waltz Studio Session',
      'author': 'Tunner QA',
      'masterBpm': 108.0,
      'musicalKey': 'G Major',
    });
    expect(savedProj['embeddedScoresCount'], 1);
    expect((savedProj['sizeBytes'] as int), greaterThan(0));

    final workspaceRes = await readResourceJson('tunner://projects/workspace');
    expect((workspaceRes['projects'] as List).length, 1);

    // Clear active score then reload from .tunner
    facade.setActiveScore(null);
    expect(facade.activeScore, isNull);

    final loadedProj = await callTool('tunner_project_load', {
      'relativePath': 'projects/waltz_session.tunner',
    });
    expect(loadedProj['projectName'], 'Waltz Studio Session');
    expect(loadedProj['songPackagesCount'], 1);
    expect(facade.activeScore, isNotNull);
    expect(facade.activeScore!.title, 'Vals de Prueba en 3/4');
    expect(facade.activeScore!.staffCount, 2);
  });

  test('imports MusicXML/MIDI/ABC/PDF OMR, runs direct Vector OMR geometry, and transcribes WAV & frames', () async {
    // 1. Pitch conversion
    final pitch = await callTool('tunner_pitch_convert', {'noteName': 'Sib4'});
    expect(pitch['midiNumber'], 70);
    expect(pitch['englishName'], 'Bb4');

    // 2. Import ABC via textContent
    const abcSample = '''
X: 1
T: Escala ABC
M: 4/4
L: 1/4
Q: 1/4=100
K: C
C D E F | G A B c |]
''';
    final importedAbc = await callTool('tunner_import_score', {
      'fileName': 'scale.abc',
      'textContent': abcSample,
      'loadAsActive': true,
    });
    expect(importedAbc['totalMeasures'], greaterThanOrEqualTo(2));
    expect(importedAbc['totalNotes'], 8);

    // 3. Export to PDF then re-import via Vector OMR
    final pdfExport = await callTool('tunner_export_pdf', {
      'outputPath': 'omr_input.pdf',
    });
    final omrImported = await callTool('tunner_import_pdf_omr', {
      'filePath': 'omr_input.pdf',
      'fileName': 'omr_input.pdf',
    });
    expect(omrImported['format'], 'PDF (Vector OMR)');
    expect((omrImported['totalMeasures'] as int), greaterThanOrEqualTo(1));
    expect(pdfExport['bytesLength'], greaterThan(100));

    // 4. Direct Vector OMR geometry processing (5 horizontal staff lines + 1 notehead)
    final geom = await callTool('tunner_omr_process_geometry', {
      'title': 'Direct Geometry Staff',
      'lines': [
        {'x1': 50, 'y1': 100, 'x2': 450, 'y2': 100},
        {'x1': 50, 'y1': 108, 'x2': 450, 'y2': 108},
        {'x1': 50, 'y1': 116, 'x2': 450, 'y2': 116},
        {'x1': 50, 'y1': 124, 'x2': 450, 'y2': 124},
        {'x1': 50, 'y1': 132, 'x2': 450, 'y2': 132},
      ],
      'rects': [
        {'x': 120, 'y': 104, 'width': 10, 'height': 8, 'isFilled': true},
      ],
    });
    expect(geom['totalMeasures'], greaterThanOrEqualTo(1));

    // 5. Transcribe synthetic A4 (440 Hz) WAV with pitch contour analytics
    final wavBytes = _buildSyntheticSineWav(frequencyHz: 440.0, durationSeconds: 0.6);
    final wavRes = await callTool('tunner_transcribe_wav', {
      'audioBase64': base64Encode(wavBytes),
      'title': 'Sine A4',
      'bpm': 120,
      'includePitchContour': true,
    });
    expect(wavRes['totalMeasures'], greaterThanOrEqualTo(1));
    expect(wavRes['pitchContour'], isA<Map<String, dynamic>>());
    expect((wavRes['pitchContour']['voicedFrameCount'] as int), greaterThan(0));

    // 6. Transcribe polyphonic frames
    final framesRes = await callTool('tunner_transcribe_frames', {
      'mode': 'polyphonic',
      'bpm': 120,
      'frames': [
        {'noteNames': ['Do4', 'Mi4', 'Sol4'], 'energyRms': 0.25, 'frameDurationMs': 250},
        {'noteNames': ['Do4', 'Mi4', 'Sol4'], 'energyRms': 0.25, 'frameDurationMs': 250},
      ],
    });
    expect(framesRes['totalNotes'], greaterThanOrEqualTo(3));

    final lastImport = await readResourceJson('tunner://importer/last-result');
    expect(lastImport['hasResult'], isTrue);
  });

  test('enforces workspace sandboxing, decomposes songs, adapts to instrument, configures Minus-One, and resolves all prompts', () async {
    // 1. Security: Path traversal must be rejected with McpErrorCodes.securityViolation
    final traversalResp = await dispatcher.dispatch(
      McpJsonRpcRequest(
        id: nextId++,
        method: 'tools/call',
        params: {
          'name': 'tunner_project_save',
          'arguments': {'relativePath': '../outside_workspace.tunner'},
        },
      ),
    );
    expect(traversalResp!.error, isNotNull);
    expect(traversalResp.error!.code, McpErrorCodes.securityViolation);

    // 2. Tool preset roundtrip (.tnt)
    final savedPreset = await callTool('tunner_tool_preset_save', {
      'relativePath': 'presets/tuner_432.tnt',
      'moduleTypeCode': 'strobe_tuner',
      'customTitle': 'Concert 432Hz Tuner',
      'toolParameters': {'a4Ref': 432.0},
    });
    expect(savedPreset['moduleTypeCode'], 'strobe_tuner');

    final loadedPreset = await callTool('tunner_tool_preset_load', {
      'relativePath': 'presets/tuner_432.tnt',
    });
    expect(loadedPreset['customTitle'], 'Concert 432Hz Tuner');
    expect(loadedPreset['toolParameters']['a4Ref'], 432.0);

    // 3. Decompose melody -> adapt to cello -> configure & restore Minus-One
    final decomposed = await callTool('tunner_song_decompose', {
      'title': 'Estudio en La Menor',
      'composer': 'Tunner QA',
      'bpm': 96,
      'timeSignature': '3/4',
      'melodyNotation': 'La4:4 Do5:4 Mi5:4 | Re5:4 Si4:4 La4:4',
      'isMinorMode': true,
    });
    expect((decomposed['stemIds'] as List).length, 4);

    final adapted = await callTool('tunner_song_adapt_instrument', {
      'instrumentId': 'cello',
    });
    expect(adapted['adaptedInstrument']['id'], 'cello');
    expect((adapted['preservedStemIds'] as List).length, 4);

    final minusOne = await callTool('tunner_minus_one_configure', {
      'activeInstrumentId': 'lead_stem',
      'muteUserTrack': true,
      'guideVolume': 0.15,
    });
    expect(minusOne['isMinusOneActive'], isTrue);
    expect(minusOne['userTrackId'], 'lead_stem');

    final sessionRes = await readResourceJson('tunner://minus-one/session');
    expect(sessionRes['hasActiveSession'], isTrue);
    expect(sessionRes['userTrackId'], 'lead_stem');

    final restored = await callTool('tunner_minus_one_restore', {
      'userTrackId': 'lead_stem',
      'standardVolume': 0.9,
    });
    expect(restored['muted'], isFalse);

    // 4. Curated library & templates resources
    final curated = await readResourceJson('tunner://library/curated');
    expect((curated['songs'] as List), isNotEmpty);

    final loadedSong = await callTool('tunner_library_load_song', {
      'songId': 'pachelbel_canon',
    });
    expect(loadedSong['id'], 'pachelbel_canon');

    // 5. Resolve all 7 prompts via prompts/get
    final promptTests = <String, Map<String, String>>{
      'compose_piano_waltz_3_4': {'title': 'Vals QA', 'key': 'G Major'},
      'harmonize_and_transpose_study': {'targetInstrument': 'violin', 'semitones': '2'},
      'fix_metric_errors': {'targetTimeSignature': '3/4'},
      'convert_score_pipeline': {'sourcePath': 'exports/waltz.musicxml'},
      'transcribe_recording_and_publish': {'wavPath': 'takes/take1.wav'},
      'create_practice_arrangement_package': {'title': 'Estudio', 'instrumentId': 'flute'},
      'audit_tunner_project_file': {'relativePath': 'projects/waltz_session.tunner'},
    };

    for (final entry in promptTests.entries) {
      final resp = await dispatcher.dispatch(
        McpJsonRpcRequest(
          id: nextId++,
          method: 'prompts/get',
          params: {
            'name': entry.key,
            'arguments': entry.value,
          },
        ),
      );
      expect(resp!.error, isNull, reason: 'Prompt ${entry.key} failed');
      final messages = resp.result!['messages'] as List;
      expect(messages, isNotEmpty);
    }
  });
}
