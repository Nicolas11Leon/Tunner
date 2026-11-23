import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/media_vault/domain/wav_pcm_codec.dart';
import 'package:tunner/mcp/facade/tunner_headless_facade.dart';
import 'package:tunner/mcp/modules/ear_training_mcp_module.dart';
import 'package:tunner/mcp/modules/harmony_chords_mcp_module.dart';
import 'package:tunner/mcp/modules/pedagogy_eval_mcp_module.dart';
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

  /// Generates a synthetic 16-bit mono WAV containing a pure C Major triad (C4, E4, G4).
  Future<File> writeSyntheticCMajorWav(String relativeName) async {
    const sampleRate = 44100;
    const durationSamples = 8192;
    const freqs = [261.63, 329.63, 392.00]; // C4, E4, G4
    final samples = Float64List(durationSamples);
    for (int i = 0; i < durationSamples; i++) {
      final t = i / sampleRate;
      double s = 0.0;
      for (final f in freqs) {
        s += math.sin(2.0 * math.pi * f * t) * 0.28;
      }
      samples[i] = s.clamp(-1.0, 1.0);
    }
    const codec = WavPcmCodec();
    final bytes = codec.encodeMono16Bit(samples, sampleRate: sampleRate);
    final file = File('${tempWorkspace.path}${Platform.pathSeparator}$relativeName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  setUp(() async {
    tempWorkspace = await Directory.systemTemp.createTemp('tunner_mcp_pedagogy_');
    facade = TunnerHeadlessFacade.create(workspaceDirectory: tempWorkspace);
    registry = McpRegistry();
    registry.registerModule(HarmonyChordsMcpModule(facade));
    registry.registerModule(EarTrainingMcpModule(facade));
    registry.registerModule(PedagogyEvalMcpModule(facade));
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
    expect(registry.resourceCount, 14); // 4 + 5 + 5
    expect(registry.toolCount, 26); // 7 + 10 + 9
    expect(registry.promptCount, 8); // 2 + 3 + 3

    final resList = await send('resources/list');
    expect((resList.result!['resources'] as List).length, 14);

    final toolList = await send('tools/list');
    expect((toolList.result!['tools'] as List).length, 26);

    final promptList = await send('prompts/list');
    expect((promptList.result!['prompts'] as List).length, 8);
  });

  group('HarmonyChordsMcpModule', () {
    test('recognizes C Major chord on synthetic WAV in stateless mode and decomposes voicing', () async {
      await writeSyntheticCMajorWav('c_major.wav');

      final chordData = await callToolOk('tunner_analyze_chord_from_pcm', {
        'wavPath': 'c_major.wav',
        'stateless': true,
      });

      expect(chordData['isRecognized'], isTrue);
      expect(chordData['symbol'], 'C');
      expect(chordData['quality'], 'major');
      expect(chordData['rootNoteIndex'], 0);
      expect((chordData['confidence'] as num).toDouble(), greaterThan(0.75));
      expect(chordData['stateless'], isTrue);

      final voicingData = await callToolOk('tunner_detect_polyphonic_voicing', {
        'wavPath': 'c_major.wav',
        'maxVoices': 3,
        'minMidi': 55,
        'maxMidi': 84,
        'stateless': true,
      });
      expect(voicingData['isSilence'], isFalse);
      expect((voicingData['polyphonyCount'] as int), greaterThanOrEqualTo(3));
      expect((voicingData['chord'] as Map<String, dynamic>)['symbol'], 'C');
      expect(voicingData['isInverted'], isFalse);
      expect(voicingData['slashSymbol'], 'C');
    });

    test('recognizes chord from discrete frequencies and analyzes Just Intonation', () async {
      final fromFreqs = await callToolOk('tunner_analyze_chord_from_frequencies', {
        'frequencyAmplitudes': {
          '220.0': 1.0, // A3
          '261.63': 0.9, // C4
          '329.63': 0.85, // E4
        },
      });
      expect(fromFreqs['isRecognized'], isTrue);
      expect(fromFreqs['symbol'], 'Am');

      final targetJi = await callToolOk('tunner_calculate_ji_target_frequency', {
        'rootFrequencyHz': 261.63,
        'role': 'majorThird',
      });
      final exactThirdHz = (targetJi['targetFrequencyHz'] as num).toDouble();
      expect(exactThirdHz, closeTo(261.63 * 5 / 4, 0.05));
      expect(targetJi['ratio'], '5/4');

      final jiAnalysis = await callToolOk('tunner_analyze_just_intonation', {
        'userFrequencyHz': exactThirdHz,
        'rootFrequencyHz': 261.63,
        'forcedRole': 'majorThird',
        'rootNoteName': 'C4',
      });
      expect(jiAnalysis['status'], 'pureConsonance');
      expect(jiAnalysis['isLocked'], isTrue);
      expect((jiAnalysis['centsOffsetFromJi'] as num).abs(), lessThan(0.5));

      final sessionRes =
          await readResourceJson('tunner://harmony/tutor/session/current');
      expect(sessionRes['rootNoteName'], 'C4');
      expect(sessionRes['activeAnalysis'], isNotNull);
    });

    test('synthesizes JI reference chord WAV and blocks path traversal', () async {
      final synthData = await callToolOk('tunner_synthesize_ji_reference_chord', {
        'rootFrequencyHz': 261.63,
        'chordType': 'majorTriad',
        'durationMs': 300,
        'outputPath': 'audio/c_major_ji.wav',
      });
      expect(synthData['wavFilePath'], isNotNull);
      expect((synthData['byteLength'] as int), greaterThan(44));
      expect(await File(synthData['wavFilePath'] as String).exists(), isTrue);

      final traversalResp = await send('tools/call', {
        'name': 'tunner_analyze_chord_from_pcm',
        'arguments': {'wavPath': '../../etc/passwd'},
      });
      expect(traversalResp.error, isNotNull);
      expect(traversalResp.error!.code, McpErrorCodes.securityViolation);

      final outTraversalResp = await send('tools/call', {
        'name': 'tunner_synthesize_ji_reference_chord',
        'arguments': {
          'rootFrequencyHz': 261.63,
          'outputPath': '../escape.wav',
        },
      });
      expect(outTraversalResp.error, isNotNull);
      expect(outTraversalResp.error!.code, McpErrorCodes.securityViolation);
    });
  });

  group('EarTrainingMcpModule', () {
    test('runs Ebbinghaus-connected ear training session and sung stability filter', () async {
      final cfg = await callToolOk('tunner_ear_training_configure', {
        'preset': 'beginner',
        'resetSession': true,
      });
      expect(cfg['configured'], isTrue);

      final question = await callToolOk('tunner_ear_training_next_question', {
        'prioritizeEbbinghausDue': true,
        'blindMode': false,
      });
      final targetInterval = question['targetInterval'] as String;
      expect(question['options'], isA<List>());

      final submit = await callToolOk('tunner_ear_training_submit_choice', {
        'selectedInterval': targetInterval,
        'responseTimeMs': 950,
        'centsDeviation': 2.0,
      });
      expect(submit['isCorrect'], isTrue);
      expect(submit['gradeLetter'], 'S');
      expect(submit['ebbinghausUpdate'], isNotNull);
      final ebbinghausUpdate = submit['ebbinghausUpdate'] as Map<String, dynamic>;
      expect(ebbinghausUpdate['qualityGrade'], 5);

      // Verify shared Ebbinghaus state in PedagogyEvalMcpModule resource
      final bank = await readResourceJson('tunner://pedagogy/ebbinghaus/bank');
      final items = (bank['items'] as List).cast<Map<String, dynamic>>();
      final updatedId =
          (ebbinghausUpdate['updatedItem'] as Map<String, dynamic>)['id'];
      final matching = items.firstWhere((e) => e['id'] == updatedId);
      expect(matching['repetitions'], 1);

      // Test sung pitch stability filter (3 consecutive stable samples)
      final q2 = await callToolOk('tunner_ear_training_next_question', {
        'prioritizeEbbinghausDue': false,
      });
      final targetHz = (q2['targetFrequencyHz'] as num).toDouble();

      final s1 = await callToolOk('tunner_ear_training_submit_sung_pitch', {
        'sungFrequencyHz': targetHz,
        'useStabilityFilter': true,
      });
      expect(s1['confirmed'], isFalse);
      expect(s1['consecutiveStableSampleCount'], 1);

      final s2 = await callToolOk('tunner_ear_training_submit_sung_pitch', {
        'sungFrequencyHz': targetHz * 1.001,
        'useStabilityFilter': true,
      });
      expect(s2['confirmed'], isFalse);

      final s3 = await callToolOk('tunner_ear_training_submit_sung_pitch', {
        'sungFrequencyHz': targetHz * 0.999,
        'useStabilityFilter': true,
      });
      expect(s3['confirmed'], isTrue);
      expect(s3['isCorrect'], isTrue);
    });

    test('generates exercise, adapts guided lesson, evaluates samples, and queries TTC tasks', () async {
      final ex = await callToolOk('tunner_generate_exercise', {
        'rootNote': 'Do4',
        'type': 'majorScale',
        'rhythm': 'quarter',
        'bpm': 96,
        'loadIntoActiveScore': true,
      });
      expect(ex['noteCount'], 15);
      expect(ex['measureCount'], 4);
      expect(facade.activeScore, isNotNull);
      expect(facade.activeScore!.baseBpm, 96);

      final adapted = await callToolOk('tunner_adapt_lesson_to_instrument', {
        'lessonId': 'lesson_01_master_notes',
        'instrumentId': 'bb_trumpet',
      });
      final adaptedSteps =
          ((adapted['lesson'] as Map<String, dynamic>)['steps'] as List)
              .cast<Map<String, dynamic>>();
      expect(adaptedSteps, isNotEmpty);
      expect(adaptedSteps.first['writtenNoteName'], isNotNull);

      final startProgress = await callToolOk('tunner_guided_lesson_start', {
        'lessonId': 'lesson_01_master_notes',
        'customToleranceCents': 15.0,
      });
      expect(startProgress['currentStepIndex'], 0);

      final evalProgress =
          await callToolOk('tunner_guided_lesson_evaluate_sample', {
        'frequencyHz': 392.0,
        'cents': 1.5,
        'detectedNoteName': 'Sol4',
        'deltaSeconds': 2.6,
      });
      expect(evalProgress['currentStepIndex'], 1);
      expect(evalProgress['isStepComplete'], isTrue);

      final progressRes =
          await readResourceJson('tunner://lessons/session/progress');
      expect(progressRes['hasActiveLesson'], isTrue);
      expect(progressRes['currentStepIndex'], 1);

      final search = await callToolOk('tunner_tasks_search', {
        'domain': 'EAR',
        'multiToolOnly': false,
      });
      expect((search['total'] as int), greaterThanOrEqualTo(3));

      final task = await callToolOk('tunner_tasks_get_by_code', {
        'code': 'EAR.01.INTV.001',
      });
      expect(task['code'], 'EAR.01.INTV.001');
      expect((task['steps'] as List), isNotEmpty);
    });
  });

  group('PedagogyEvalMcpModule', () {
    test('evaluates practice session, aggregates report JSON, and exports verified PDFs', () async {
      // Switch active learner profile
      final profile = await callToolOk('tunner_pedagogy_set_active_profile', {
        'preset': 'conservatory',
      });
      expect(profile['centsTolerance'], 5.0);

      final activeProfileRes =
          await readResourceJson('tunner://pedagogy/profiles/active');
      expect(activeProfileRes['type'], 'conservatoryMastery');

      // Adaptive scaffolding evaluation
      final diag = await callToolOk('tunner_scaffolding_evaluate_note', {
        'centsDeviation': 14.0,
        'profile': 'adult',
        'consecutiveErrors': 4,
      });
      expect(diag['isInTune'], isFalse);
      expect(diag['biomechanicalCue'], isNotNull);
      expect(diag['suggestedBpmAdjustment'], -5);

      // Practice session evaluation
      final practiceReport = await callToolOk('tunner_practice_evaluate_session', {
        'songTitle': 'Estudio de Do Mayor',
        'instrumentName': 'Flauta Traversa',
        'toleranceCents': 15.0,
        'notes': [
          {
            'expectedNoteName': 'Do4',
            'detectedNoteName': 'Do4',
            'detectedFrequency': 261.63,
            'detectedCents': 2.0,
            'timingDeltaMs': -10,
            'sustainRatio': 0.95,
          },
          {
            'expectedNoteName': 'Mi4',
            'detectedNoteName': 'Mi4',
            'detectedFrequency': 329.63,
            'detectedCents': -3.5,
            'timingDeltaMs': 15,
            'sustainRatio': 0.92,
          },
          {
            'expectedNoteName': 'Sol4',
            'detectedNoteName': 'Sol4',
            'detectedFrequency': 392.0,
            'detectedCents': 1.0,
            'timingDeltaMs': 5,
            'sustainRatio': 1.0,
          },
        ],
      });
      expect(practiceReport['totalNotes'], 3);
      expect(practiceReport['hitNotes'], 3);
      expect((practiceReport['overallScore'] as num).toDouble(), greaterThan(85.0));

      final latestReportRes =
          await readResourceJson('tunner://practice/reports/latest');
      expect(latestReportRes['hasReport'], isTrue);

      // Vocal stability evaluation
      final vocalEval = await callToolOk('tunner_evaluate_vocal_stability', {
        'frequenciesHz': List<double>.filled(30, 440.0),
        'amplitudes': List<double>.filled(30, 0.75),
        'targetFrequencyHz': 440.0,
        'evaluationId': 'EXAM-001',
      });
      expect(vocalEval['evaluationId'], 'EXAM-001');
      expect((vocalEval['overallScore'] as num).toDouble(), greaterThanOrEqualTo(90.0));
      expect((vocalEval['payloadHashSha256'] as String).length, 64);

      // Aggregate pedagogical session report JSON
      final aggregated =
          await callToolOk('tunner_pedagogy_aggregate_session_report', {
        'sessionTitle': 'Informe Conservatorio Do Mayor',
        'durationSeconds': 180,
        'spectralCentroidHz': 820.0,
        'thdPercentage': 9.5,
        'rhythmMeanBpm': 96.0,
      });
      expect(aggregated['sessionTitle'], 'Informe Conservatorio Do Mayor');
      expect(aggregated['totalEvaluatedNotes'], 3);
      expect(aggregated['inTuneNotesCount'], 3);
      expect((aggregated['recommendations'] as List), isNotEmpty);

      // Export Vocal Certificate PDF
      final certPdf = await callToolOk('tunner_export_vocal_certificate_pdf', {
        'studentName': 'Elena Martinez',
        'outputPath': 'reports/vocal_cert.pdf',
      });
      final certFile = File(certPdf['outputPath'] as String);
      expect(await certFile.exists(), isTrue);
      final certBytes = await certFile.readAsBytes();
      expect(String.fromCharCodes(certBytes.sublist(0, 8)), '%PDF-1.4');

      // Export Pedagogical Report PDF
      final reportPdf =
          await callToolOk('tunner_export_pedagogical_report_pdf', {
        'session': aggregated,
        'config': {
          'studentName': 'Elena Martinez',
          'instrument': 'Flauta Traversa',
          'includeCertificate': true,
        },
        'outputPath': 'reports/pedagogical_report.pdf',
      });
      expect(reportPdf['pages'], 2);
      final reportFile = File(reportPdf['outputPath'] as String);
      expect(await reportFile.exists(), isTrue);
      final reportBytes = await reportFile.readAsBytes();
      expect(String.fromCharCodes(reportBytes.sublist(0, 8)), '%PDF-1.4');

      // Path traversal rejection on PDF outputPath
      final pdfTraversal = await send('tools/call', {
        'name': 'tunner_export_vocal_certificate_pdf',
        'arguments': {
          'studentName': 'Hacker',
          'outputPath': '../../outside.pdf',
        },
      });
      expect(pdfTraversal.error, isNotNull);
      expect(pdfTraversal.error!.code, McpErrorCodes.securityViolation);
    });

    test('supports Ebbinghaus custom item addition and direct answer submission', () async {
      final added = await callToolOk('tunner_ebbinghaus_add_item', {
        'id': 'microtone_syntonic_comma',
        'name': 'Coma Sintonica',
        'category': 'microtone',
        'semitones': 0.215,
        'centsDeviation': 21.51,
      });
      expect(added['added'], isTrue);

      final answered = await callToolOk('tunner_ebbinghaus_submit_answer', {
        'itemId': 'microtone_syntonic_comma',
        'isCorrect': true,
        'centsError': 1.2,
        'responseTimeSeconds': 1.4,
      });
      expect(answered['qualityGrade'], 5);
    });
  });

  test('all registered Resources and Prompts resolve cleanly via dispatcher', () async {
    final resList = await send('resources/list');
    final resources = (resList.result!['resources'] as List)
        .cast<Map<String, dynamic>>();
    for (final r in resources) {
      final uri = r['uri'] as String;
      final data = await readResourceJson(uri);
      expect(data, isNotEmpty, reason: 'Resource $uri returned empty JSON');
    }

    final promptList = await send('prompts/list');
    final prompts = (promptList.result!['prompts'] as List)
        .cast<Map<String, dynamic>>();
    for (final p in prompts) {
      final name = p['name'] as String;
      final resp = await send('prompts/get', {'name': name, 'arguments': {}});
      expect(resp.error, isNull, reason: 'Prompt $name failed: ${resp.error}');
      final messages = resp.result!['messages'] as List<dynamic>;
      expect(messages, isNotEmpty);
    }
  });
}
