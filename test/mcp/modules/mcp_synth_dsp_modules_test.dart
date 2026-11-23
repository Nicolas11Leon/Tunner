import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/mcp/facade/tunner_headless_facade.dart';
import 'package:tunner/mcp/modules/autotune_metronome_mcp_module.dart';
import 'package:tunner/mcp/modules/synth_drone_mcp_module.dart';
import 'package:tunner/mcp/modules/tuner_acoustic_mcp_module.dart';
import 'package:tunner/mcp/protocol/mcp_dispatcher.dart';
import 'package:tunner/mcp/protocol/mcp_error_codes.dart';
import 'package:tunner/mcp/protocol/mcp_json_rpc_message.dart';
import 'package:tunner/mcp/protocol/mcp_registry.dart';

void main() {
  late Directory tempWorkspace;
  late TunnerHeadlessFacade facade;
  late McpRegistry registry;
  late McpDispatcher dispatcher;
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
    tempWorkspace = await Directory.systemTemp.createTemp('tunner_mcp_dsp_');
    facade = TunnerHeadlessFacade.create(workspaceDirectory: tempWorkspace);
    registry = McpRegistry();
    registry.registerModule(SynthDroneMcpModule(facade));
    registry.registerModule(TunerAcousticMcpModule(facade));
    registry.registerModule(AutotuneMetronomeMcpModule(facade));
    dispatcher = McpDispatcher(registry: registry);
  });

  tearDown(() async {
    facade.dispose();
    if (await tempWorkspace.exists()) {
      await tempWorkspace.delete(recursive: true);
    }
  });

  test('registers exact counts of Resources, Tools, and Prompts without collisions', () async {
    expect(registry.registeredModules, hasLength(3));
    expect(registry.resourceCount, 11);
    expect(registry.toolCount, 19);
    expect(registry.promptCount, 6);

    final resList = await send('resources/list');
    expect((resList.result!['resources'] as List).length, 11);

    final toolList = await send('tools/list');
    expect((toolList.result!['tools'] as List).length, 19);

    final promptList = await send('prompts/list');
    expect((promptList.result!['prompts'] as List).length, 6);
  });

  test('reads all 11 registered Resources across the 3 modules', () async {
    final sf = await readResourceJson('tunner://synth/soundfonts/active');
    expect(sf['presetCount'], greaterThanOrEqualTo(8));

    final poly = await readResourceJson('tunner://synth/polyphonic/state');
    expect(poly['maxPolyphony'], greaterThan(0));

    final timbres = await readResourceJson('tunner://drone/timbres');
    expect(timbres['count'], 4);

    final droneDefault = await readResourceJson('tunner://drone/config/default');
    expect((droneDefault['frequenciesHz'] as Map)['fundamental'], greaterThan(100.0));

    final temps = await readResourceJson('tunner://tuner/temperaments');
    expect(temps['count'], 11);

    final rigors = await readResourceJson('tunner://tuner/rigor-presets');
    expect(rigors['count'], 6);

    final noteRef = await readResourceJson('tunner://tuner/note-reference');
    expect((noteRef['notes'] as List).length, 12);

    final harmIntervals =
        await readResourceJson('tunner://acoustic-lab/harmonic-intervals');
    expect((harmIntervals['harmonics'] as List).length, 8);

    final scales = await readResourceJson('tunner://vocal-autotune/scales');
    expect(scales['count'], 7);

    final presets = await readResourceJson('tunner://vocal-autotune/presets');
    expect(presets['count'], 4);

    final tempoMarks = await readResourceJson('tunner://metronome/tempo-marks');
    expect(tempoMarks['count'], 8);
  });

  test('resolves all 6 registered Prompts via prompts/get', () async {
    final promptRequests = <Map<String, dynamic>>[
      {
        'name': 'compose_and_render_practice_backing',
        'arguments': {'key': 'D', 'bpm': '96', 'temperamentId': 'vallotti'},
      },
      {
        'name': 'audition_soundfont_instrument_range',
        'arguments': {'sf2FilePath': 'banks/piano.sf2', 'patch': '0'},
      },
      {
        'name': 'audit_recording_intonation_and_timbre',
        'arguments': {'wavFilePath': 'takes/a4.wav'},
      },
      {
        'name': 'compare_historical_temperaments',
        'arguments': {'rootKey': '0', 'octave': '4'},
      },
      {
        'name': 'vocal_take_postproduction_pipeline',
        'arguments': {'inputWavPath': 'takes/vocal.wav', 'scaleType': 'major'},
      },
      {
        'name': 'build_rehearsal_click_track',
        'arguments': {'bpm': '120', 'meter': '3/4', 'bars': '4'},
      },
    ];

    for (final req in promptRequests) {
      final resp = await send('prompts/get', req);
      expect(resp.error, isNull, reason: 'Prompt ${req['name']} failed');
      final messages = resp.result!['messages'] as List<dynamic>;
      expect(messages, isNotEmpty);
    }
  });

  test('SynthDroneMcpModule renders melody WAV, SF2 note, polyphonic chord, stems, and drone', () async {
    // 1. Render melody WAV from timed note events (A4 = MIDI 69)
    final melodyData = await callToolOk('tunner_synth_score_wav', {
      'outputPath': 'audio/melody_a4.wav',
      'engine': 'additive',
      'notes': [
        {'startSeconds': 0.0, 'durationSeconds': 0.6, 'midiPitch': 69, 'velocity': 110},
      ],
      'totalDurationSeconds': 0.65,
    });
    expect(melodyData['eventCount'], 1);
    expect(melodyData['sizeBytes'], greaterThan(44));
    expect(File(melodyData['outputPath'] as String).existsSync(), isTrue);

    // 2. Render active score WAV using facade.activeScore
    facade.setActiveScore(HierarchicalScore.getCanonicalStudies().first);
    final activeScoreData = await callToolOk('tunner_synth_score_wav', {
      'outputPath': 'audio/active_score.wav',
      'bpm': 120,
      'engine': 'sf2',
      'sf2Patch': 0,
    });
    expect(activeScoreData['sourceMode'], 'active_score');
    expect(File(activeScoreData['outputPath'] as String).existsSync(), isTrue);

    // 3. Render SF2 note and reset bank
    final sf2Note = await callToolOk('tunner_sf2_render_note', {
      'midiPitch': 60,
      'patch': 0,
      'durationSeconds': 0.3,
      'outputPath': 'audio/sf2_c4.wav',
    });
    expect(sf2Note['sizeBytes'], greaterThan(44));

    final sf2Reset = await callToolOk('tunner_sf2_load_bank', {
      'resetToEssentials': true,
    });
    expect(sf2Reset['presetCount'], greaterThanOrEqualTo(8));

    // 4. Render polyphonic C major chord
    final chordData = await callToolOk('tunner_polyphonic_render_chord', {
      'midiNotes': [60, 64, 67],
      'waveform': 'triangle',
      'durationSeconds': 0.35,
      'outputPath': 'audio/chord_cmaj.wav',
    });
    expect(chordData['channels'], 2);
    expect(File(chordData['outputPath'] as String).existsSync(), isTrue);

    // 5. Generate harmonic drone with volume and Vallotti temperament
    final droneData = await callToolOk('tunner_drone_generate_wav', {
      'rootNoteIndex': 9, // La
      'octave': 3,
      'includeFifth': true,
      'includeOctave': false,
      'timbre': 'warmFlute',
      'volume': 0.65,
      'temperamentId': 'vallotti',
      'durationSeconds': 0.5,
      'outputPath': 'audio/drone_a3.wav',
    });
    expect(droneData['volume'], 0.65);
    expect(droneData['temperamentId'], 'vallotti');
    expect(File(droneData['outputPath'] as String).existsSync(), isTrue);

    // 6. Export stems and MIDI from active score
    final exportData = await callToolOk('tunner_export_stems_and_midi', {
      'bpm': 120,
      'trackTitle': 'Studio Test',
      'outputSubfolder': 'bundle_01',
      'includeMasterMixdown': true,
      'includeIndividualStems': false,
      'includeMidiFile': true,
    });
    expect((exportData['savedPaths'] as List).length, 2);
    expect(exportData['totalBytes'], greaterThan(100));
  });

  test('TunerAcousticMcpModule analyzes pitch contour, harmonics, temperaments, noise floor, and echo suppression', () async {
    // Generate clean 440 Hz musical note WAV inside workspace
    final toneData = await callToolOk('tunner_synth_tone_wav', {
      'type': 'musical_note',
      'frequencyHz': 440.0,
      'durationSeconds': 0.6,
      'outputPath': 'analysis/a4_440.wav',
    });
    expect(File(toneData['outputPath'] as String).existsSync(), isTrue);

    // 1. Detect pitch contour on generated WAV
    final pitchData = await callToolOk('tunner_detect_pitch_wav', {
      'wavFilePath': 'analysis/a4_440.wav',
      'a4Ref': 440.0,
      'temperamentId': 'equal',
    });
    expect(pitchData['voicedFrameCount'], greaterThan(0));
    expect((pitchData['medianPitchHz'] as num).toDouble(), closeTo(440.0, 4.0));

    // 2. Analyze harmonic series on generated WAV (auto-F0)
    final harmData = await callToolOk('tunner_analyze_harmonics_wav', {
      'wavFilePath': 'analysis/a4_440.wav',
      'maxHarmonics': 6,
    });
    expect((harmData['fundamentalHz'] as num).toDouble(), closeTo(440.0, 5.0));
    expect((harmData['harmonics'] as List).length, 6);
    expect((harmData['totalHarmonicDistortionPercent'] as num).toDouble(), greaterThan(5.0));

    // 3. Frequency to note & temperament table
    final noteData = await callToolOk('tunner_frequency_to_note', {
      'frequencyHz': 440.0,
      'temperamentId': 'just_intonation',
      'rootKey': 0,
    });
    expect(noteData['englishName'], 'A4');
    expect(noteData['midiNumber'], 69);

    final tableData = await callToolOk('tunner_temperament_table', {
      'temperamentId': 'werckmeister_iii',
      'rootKey': 0,
      'octave': 4,
    });
    expect((tableData['notes'] as List).length, 12);

    // 4. Analyze noise floor
    final noiseData = await callToolOk('tunner_analyze_noise_floor_wav', {
      'wavFilePath': 'analysis/a4_440.wav',
      'frameSize': 1024,
    });
    expect(noiseData['totalFramesAnalyzed'], greaterThan(0));
    expect((noiseData['meanRms'] as num).toDouble(), greaterThan(0.0));

    // 5. Simulate echo suppression
    final echoData = await callToolOk('tunner_simulate_echo_suppression', {
      'clickTimestampsMs': [1000],
      'pitchEvents': [
        {'timeMs': 1020, 'pitchHz': 1500.0},
        {'timeMs': 1200, 'pitchHz': 440.0},
      ],
      'blankingDurationMs': 70,
    });
    final echoResults = echoData['results'] as List<dynamic>;
    expect(echoResults, hasLength(2));
    expect((echoResults[0] as Map)['suppressed'], isTrue);
    expect((echoResults[1] as Map)['suppressed'], isFalse);
  });

  test('AutotuneMetronomeMcpModule runs quantization, autonomous autotune, wav-to-score, 3/4 click-track, and tap-tempo', () async {
    // 1. Scale quantization
    final quant = await callToolOk('tunner_vocal_quantize_pitch', {
      'detectedPitchHz': 446.0,
      'config': {
        'isEnabled': true,
        'scaleRoot': 0,
        'scaleType': 'major',
        'retuneSpeedMs': 0.0,
        'correctionAmount': 1.0,
      },
    });
    expect(quant['isVoiced'], isTrue);
    expect((quant['targetFrequencyHz'] as num).toDouble(), closeTo(440.0, 0.5));

    // 2. Generate slightly sharp vocal tone (~446 Hz) and apply autonomous autotune
    await callToolOk('tunner_synth_tone_wav', {
      'type': 'sine',
      'frequencyHz': 446.0,
      'durationSeconds': 0.6,
      'seamlessLoop': false,
      'outputPath': 'vocal/sharp_a4.wav',
    });

    final tuned = await callToolOk('tunner_vocal_autotune_wav', {
      'inputWavPath': 'vocal/sharp_a4.wav',
      'outputWavPath': 'vocal/tuned_a4.wav',
      'preset': 'hardTuneUrban',
      'scaleRoot': 0,
      'scaleType': 'major',
      'formantPreservation': false,
    });
    expect(File(tuned['outputWavPath'] as String).existsSync(), isTrue);
    expect(tuned['sizeBytes'], greaterThan(44));
    expect(tuned['voicedFramesBefore'], greaterThan(0));

    // 3. Transcribe WAV to score and snap to scale
    final transcribed = await callToolOk('tunner_vocal_wav_to_score', {
      'inputWavPath': 'vocal/tuned_a4.wav',
      'title': 'Test Vocal Take',
      'bpm': 120,
      'snapToScale': {'rootKey': 0, 'scaleType': 'major'},
    });
    expect(transcribed['measureCount'], greaterThanOrEqualTo(1));

    final snapped = await callToolOk('tunner_vocal_snap_score_to_scale', {
      'scorePackageJson': transcribed['package'] as Map<String, dynamic>,
      'rootKey': 0,
      'scaleType': 'majorPentatonic',
    });
    expect(snapped['updatedPackage'], isA<Map<String, dynamic>>());

    // 4. Generate 3/4, 4/4, and 6/8 metronome click-tracks
    final click34 = await callToolOk('tunner_metronome_generate_click_wav', {
      'bpm': 120,
      'numerator': 3,
      'denominator': 4,
      'bars': 2,
      'countInBars': 1,
      'outputPath': 'metronome/waltz_34.wav',
    });
    expect(click34['meter'], '3/4');
    expect(click34['totalBeats'], 9);
    expect(click34['isCompoundMeter'], isFalse);
    expect(File(click34['outputPath'] as String).existsSync(), isTrue);

    final click68 = await callToolOk('tunner_metronome_generate_click_wav', {
      'bpm': 120,
      'numerator': 6,
      'denominator': 8,
      'bars': 2,
      'outputPath': 'metronome/compound_68.wav',
    });
    expect(click68['meter'], '6/8');
    expect(click68['isCompoundMeter'], isTrue);
    expect(File(click68['outputPath'] as String).existsSync(), isTrue);

    // 5. Analyze tap-tempo timestamps (500 ms interval -> 120 BPM)
    final tapData = await callToolOk('tunner_metronome_analyze_tap_tempo', {
      'timestampsMs': [1000, 1500, 2000, 2500, 3000],
    });
    expect(tapData['bpm'], 120);
    expect(tapData['isCalibrated'], isTrue);
    expect((tapData['tempoMark'] as Map)['italianName'], 'Allegro');
  });

  test('enforces workspace Path Traversal protection with securityViolation across all 3 modules', () async {
    final synthEscape = await send('tools/call', {
      'name': 'tunner_drone_generate_wav',
      'arguments': {
        'rootNoteIndex': 0,
        'octave': 3,
        'outputPath': '../escape_drone.wav',
      },
    });
    expect(synthEscape.error?.code, McpErrorCodes.securityViolation);

    final tunerEscape = await send('tools/call', {
      'name': 'tunner_detect_pitch_wav',
      'arguments': {
        'wavFilePath': '../../etc/passwd',
      },
    });
    expect(tunerEscape.error?.code, McpErrorCodes.securityViolation);

    final metroEscape = await send('tools/call', {
      'name': 'tunner_metronome_generate_click_wav',
      'arguments': {
        'bpm': 120,
        'bars': 2,
        'outputPath': '../escape_click.wav',
      },
    });
    expect(metroEscape.error?.code, McpErrorCodes.securityViolation);
  });
}
