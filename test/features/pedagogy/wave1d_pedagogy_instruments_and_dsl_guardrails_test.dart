import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/dsl/domain/tunner_ast_node.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_diagnostic.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_interpreter.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_parser.dart';
import 'package:tunner/core/terminal/domain/tunner_os_command_entity.dart';
import 'package:tunner/features/chord_analyzer/domain/chord_entity.dart';
import 'package:tunner/features/chord_analyzer/domain/chroma_vector_calculator.dart';
import 'package:tunner/features/chord_analyzer/domain/polyphonic_chord_recognizer.dart';
import 'package:tunner/features/chord_analyzer/domain/polyphonic_multitone_detector.dart';
import 'package:tunner/features/chord_analyzer/domain/polyphonic_pitch_entity.dart';
import 'package:tunner/features/ear_training/domain/blind_ear_headless_session_controller.dart';
import 'package:tunner/features/ear_training/domain/blind_ear_trainer_engine.dart';
import 'package:tunner/features/ear_training/domain/ear_training_exercise.dart';
import 'package:tunner/features/ear_training/domain/musical_interval.dart';
import 'package:tunner/features/guided_lessons/domain/curated_guided_lessons.dart';
import 'package:tunner/features/guided_lessons/domain/guided_lesson_entity.dart';
import 'package:tunner/features/guided_lessons/domain/guided_lesson_evaluator.dart';
import 'package:tunner/features/guided_lessons/domain/pedagogical_task_contract.dart';
import 'package:tunner/features/guided_lessons/domain/task_taxonomy_code.dart';
import 'package:tunner/features/instrument/domain/instrument_catalog_bridge.dart';
import 'package:tunner/features/instrument/domain/instrument_customization_profile.dart';
import 'package:tunner/features/instrument/domain/instrument_profile_entity.dart';
import 'package:tunner/features/instrument/domain/instrument_transposition_service.dart';
import 'package:tunner/features/instrument/domain/procedural_instrument_synthesizer.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_definition.dart';
import 'package:tunner/features/pedagogy/domain/ebbinghaus_spaced_repetition_engine.dart';
import 'package:tunner/features/pedagogy/domain/vocal_evaluation_result.dart';
import 'package:tunner/features/pedagogy_report/domain/pedagogical_session_aggregator.dart';
import 'package:tunner/features/practice_evaluator/domain/note_evaluation_entity.dart';
import 'package:tunner/features/practice_evaluator/domain/practice_report_entity.dart' as practice;
import 'package:tunner/features/sheet_music/domain/score_tree.dart';

List<double> _synthChordSamples(
  List<double> freqs, {
  int length = 4096,
  double sampleRate = 44100.0,
}) {
  return List<double>.generate(length, (i) {
    double acc = 0.0;
    for (final f in freqs) {
      acc += math.sin(2.0 * math.pi * f * i / sampleRate);
    }
    return acc / freqs.length;
  });
}

void main() {
  group('Ola 1D - BlindEarHeadlessSessionController', () {
    test('Prioritizes due Ebbinghaus items with lowest retention', () {
      final now = DateTime(2026, 11, 23, 12, 0);
      final ebbinghaus = EbbinghausSpacedRepetitionEngine();

      // Mark all canonical intervals as freshly reviewed except perfectFifth.
      for (final item in ebbinghaus.allItems) {
        if (item.id == 'interval_P5') {
          ebbinghaus.addItem(
            item.copyWith(
              lastReviewDate: now.subtract(const Duration(days: 10)),
              nextReviewDate: now.subtract(const Duration(days: 5)),
              stabilityDays: 1.0,
            ),
          );
        } else {
          ebbinghaus.addItem(
            item.copyWith(
              lastReviewDate: now,
              nextReviewDate: now.add(const Duration(days: 15)),
              stabilityDays: 20.0,
            ),
          );
        }
      }

      final controller = BlindEarHeadlessSessionController(
        engine: BlindEarTrainerEngine(random: math.Random(7)),
        ebbinghausEngine: ebbinghaus,
      );

      final q = controller.generateNextQuestion(prioritizeDue: true, now: now);
      expect(q.targetInterval, equals(MusicalInterval.perfectFifth));
    });

    test('Applies 3-sample sung stability filter and resets on drift or silence', () {
      final now = DateTime(2026, 11, 23, 12, 0);
      final ebbinghaus = EbbinghausSpacedRepetitionEngine();
      final controller = BlindEarHeadlessSessionController(
        engine: BlindEarTrainerEngine(
          config: EarTrainingConfig.beginner(),
          random: math.Random(3),
        ),
        ebbinghausEngine: ebbinghaus,
      );

      final q = controller.generateNextQuestion(prioritizeDue: false, now: now);
      final targetHz = q.targetFrequencyHz;

      // Sample 1: buffered
      expect(controller.ingestSungFrequencySample(targetHz, now: now), isNull);
      expect(controller.consecutiveStableSampleCount, equals(1));

      // Large drift (> 50 cents): resets buffer and stores new sample
      expect(controller.ingestSungFrequencySample(targetHz * 1.2, now: now), isNull);
      expect(controller.consecutiveStableSampleCount, equals(1));

      // Silence resets buffer
      expect(controller.ingestSungFrequencySample(0.0, now: now), isNull);
      expect(controller.consecutiveStableSampleCount, equals(0));

      // 3 consecutive stable samples trigger evaluation
      expect(controller.ingestSungFrequencySample(targetHz, now: now), isNull);
      expect(controller.ingestSungFrequencySample(targetHz * 1.001, now: now), isNull);
      final result = controller.ingestSungFrequencySample(targetHz * 0.999, now: now);

      expect(result, isNotNull);
      expect(result!.isCorrect, isTrue);
      expect(controller.lastEbbinghausEvaluation, isNotNull);
      expect(controller.toJson()['totalQuestionsAnswered'], equals(1));
    });
  });

  group('Ola 1D - PedagogicalSessionAggregator & PracticeReportEntity', () {
    test('Aggregates PedagogicalSessionData from PracticeReportEntity without TunerViewModel', () {
      final noteEval = NoteEvaluationEntity(
        expectedNote: HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4'),
        soundingExpectedNoteName: 'Do4',
        detectedNoteName: 'Do4',
        detectedFrequency: 261.63,
        centsDeviation: 3.5,
        timingCategory: NoteTimingCategory.onTime,
        timingDeltaMs: 8,
        sustainRatioPercentage: 95.0,
        isPitchAccurate: true,
        pitchScore: 96.0,
        rhythmScore: 92.0,
        sustainScore: 95.0,
        overallScore: 94.5,
      );

      final report = practice.PracticeReportEntity(
        songTitle: 'Escala de Do Mayor',
        instrumentName: 'Flauta Traversa',
        timestamp: DateTime(2026, 11, 23, 14, 0),
        totalNotes: 1,
        hitNotes: 1,
        pitchAccuracyPercentage: 96.0,
        averageCentsDeviation: 3.5,
        rhythmAccuracyPercentage: 92.0,
        averageTimingDeltaMs: 8.0,
        rhythmTendency: practice.RhythmTendency.stable,
        sustainAccuracyPercentage: 95.0,
        overallScore: 94.5,
        grade: practice.PerformanceGrade.a,
        evaluations: [noteEval],
        noteAccuracyMap: const {'Do4': 96.0},
        criticalNotes: const [],
        masteredNotes: const ['Do4'],
      );

      final vocalEval = VocalEvaluationResult(
        evaluationId: 'voc-01',
        timestamp: DateTime(2026, 11, 23, 14, 0),
        targetFrequencyHz: 440.0,
        measuredMeanFrequencyHz: 440.5,
        centsDeviation: 1.9,
        jitterPercent: 0.45,
        shimmerPercent: 1.8,
        vibratoRateHz: 5.5,
        vibratoDepthCents: 35.0,
        overallScore: 93.0,
        classificationLabel: 'Excelente',
      );

      final session = PedagogicalSessionAggregator.fromPracticeReport(
        report,
        duration: const Duration(minutes: 5),
        spectralCentroidHz: 850.0,
        thdPercentage: 8.2,
        rhythmMeanBpm: 96.0,
        vocalEvaluation: vocalEval,
      );

      expect(session.sessionTitle, equals('Escala de Do Mayor'));
      expect(session.totalEvaluatedNotes, equals(1));
      expect(session.inTuneNotesCount, equals(1));
      expect(session.tuningAccuracyPercentage, equals(96.0));
      expect(session.masteryLevel, equals('Virtuoso / Conservatorio'));
      expect(session.pedagogicalDiagnostic, contains('Excelente'));
      expect(session.timedPitchSamples.length, equals(1));

      // Verify PracticeReportEntity.toMap() preserves evaluations round-trip
      final map = report.toMap();
      expect(map['evaluations'], isA<List<dynamic>>());
      expect((map['evaluations'] as List<dynamic>).length, equals(1));

      final restored = practice.PracticeReportEntity.fromMap(map);
      expect(restored.evaluations.length, equals(1));
      expect(restored.evaluations.first.detectedNoteName, equals('Do4'));
      expect(restored.evaluations.first.centsDeviation, closeTo(3.5, 1e-6));
    });
  });

  group('Ola 1D - PolyphonicChordRecognizer Stateless & GuidedLessonEvaluator', () {
    test('Stateless mode avoids hysteresis carry-over between independent calls', () {
      // Build two moderate-confidence chroma vectors (between 0.58 and 0.82)
      final cMajorMod = ChromaVectorCalculator.normalizeChroma([
        0.75, 0.25, 0.20, 0.15, 0.70, 0.15, 0.10, 0.65, 0.15, 0.20, 0.15, 0.20,
      ]);
      final dMinorMod = ChromaVectorCalculator.normalizeChroma([
        0.15, 0.15, 0.75, 0.20, 0.15, 0.70, 0.15, 0.20, 0.15, 0.65, 0.20, 0.15,
      ]);

      final statelessRecognizer = PolyphonicChordRecognizer(stateless: true);
      final first = statelessRecognizer.identifyFromChroma(cMajorMod);
      final second = statelessRecognizer.identifyFromChroma(dMinorMod);

      expect(first.symbol, equals('C'));
      expect(second.symbol, equals('Dm'));
    });

    test('PolyphonicMultiToneDetector reuses DFT magnitudes and identifies triad', () {
      final samples = _synthChordSamples([261.63, 329.63, 392.00]);
      final detector = PolyphonicMultiToneDetector(
        chordRecognizer: PolyphonicChordRecognizer(stateless: true),
      );
      final result = detector.detectFromSamples(samples: samples);

      expect(result.isSilence, isFalse);
      expect(result.chord.symbol, equals('C'));
      expect(result.voices.length, greaterThanOrEqualTo(3));
      expect(result.toJson()['chord']['symbol'], equals('C'));
    });

    test('GuidedLessonEvaluator updates totalAccumulatedAccuracy on samples', () {
      final evaluator = GuidedLessonEvaluator();
      final lesson = CuratedGuidedLessons.all.first;
      evaluator.startLesson(lesson);

      final step = evaluator.activeProgress!.currentStep;
      // Perfect sample -> accuracy 1.0
      final p1 = evaluator.evaluateSample(
        frequencyHz: step.targetFrequencyHz,
        cents: 0.0,
        detectedNoteName: step.targetNoteName,
        deltaSeconds: 0.2,
      );
      expect(p1!.totalAccumulatedAccuracy, closeTo(1.0, 1e-6));

      // Wrong note -> accuracy drops to 0.5
      final p2 = evaluator.evaluateSample(
        frequencyHz: step.targetFrequencyHz * 1.5,
        cents: 45.0,
        detectedNoteName: 'Fa#5',
        deltaSeconds: 0.2,
      );
      expect(p2!.totalAccumulatedAccuracy, closeTo(0.5, 1e-6));
    });
  });

  group('Ola 1D - Instruments, Transposition & Procedural Synthesizer', () {
    test('InstrumentTranspositionService fixes Cb4, supports E#, B#, and scientific format', () {
      const service = InstrumentTranspositionService();

      expect(service.noteNameToMidi('Cb4'), equals(59));
      expect(service.noteNameToMidi('Dob4'), equals(59));
      expect(service.noteNameToMidi('E#4'), equals(65));
      expect(service.noteNameToMidi('Mi#4'), equals(65));
      expect(service.noteNameToMidi('B#3'), equals(60));
      expect(service.noteNameToMidi('Si#3'), equals(60));
      expect(service.noteNameToMidi('Fb4'), equals(64));

      // Concert pitch C flute: Cb4 sounds as B3 (Si3)
      expect(
        service.getSoundingNote('Cb4', InstrumentProfileEntity.flute),
        equals('Si3'),
      );
      expect(
        service.getSoundingNote(
          'Cb4',
          InstrumentProfileEntity.flute,
          useScientificNotation: true,
        ),
        equals('B3'),
      );
      // Bb Trumpet (-2 semitones): C4 written -> Bb3 (A#3) sounding
      expect(
        service.getSoundingNote(
          'C4',
          InstrumentProfileEntity.bbTrumpet,
          useScientificNotation: true,
        ),
        equals('A#3'),
      );
      expect(
        service.getWrittenNote(
          'A#3',
          InstrumentProfileEntity.bbTrumpet,
          useScientificNotation: true,
        ),
        equals('C4'),
      );
    });

    test('InstrumentCatalogBridge maps bidirectionally and serializes unified catalog', () {
      const bridge = InstrumentCatalogBridge();

      final pianoUniversal = InstrumentCatalogBridge.findUniversalByAnyId('grand_piano');
      expect(pianoUniversal, isNotNull);
      expect(pianoUniversal!.universalId, equals('chordophone.keyboard.piano_grand_acoustic'));

      final pianoProfile = InstrumentCatalogBridge.findProfileByAnyId(pianoUniversal.universalId);
      expect(pianoProfile, isNotNull);
      expect(pianoProfile!.id, equals('grand_piano'));

      final catalogJson = bridge.toJson();
      expect(catalogJson['count'], equals(UniversalInstrumentDefinition.masterCatalog.length));
      expect(catalogJson['legacyCount'], equals(InstrumentProfileEntity.standardInstruments.length));
      expect(catalogJson['instruments'], isA<List<dynamic>>());
    });

    test('ProceduralInstrumentSynthesizer supports custom sampleRate and resonanceFactor', () {
      final piano = UniversalInstrumentDefinition.grandPiano;

      final buf22k = ProceduralInstrumentSynthesizer.synthesizeNote(
        instrument: piano,
        frequencyHz: 440.0,
        durationSeconds: 0.2,
        sampleRate: 22050,
      );
      final buf48k = ProceduralInstrumentSynthesizer.synthesizeNote(
        instrument: piano,
        frequencyHz: 440.0,
        durationSeconds: 0.2,
        sampleRate: 48000,
      );
      expect(buf22k.length, equals(4410));
      expect(buf48k.length, equals(9600));

      final dry = ProceduralInstrumentSynthesizer.synthesizeCustomNote(
        customization: InstrumentCustomizationProfile.defaultFor(piano).copyWith(
          resonanceFactor: 0.0,
        ),
        frequencyHz: 440.0,
        durationSeconds: 0.1,
      );
      final resonant = ProceduralInstrumentSynthesizer.synthesizeCustomNote(
        customization: InstrumentCustomizationProfile.defaultFor(piano).copyWith(
          resonanceFactor: 1.0,
        ),
        frequencyHz: 440.0,
        durationSeconds: 0.1,
      );

      double maxDiff = 0.0;
      for (int i = 0; i < dry.length; i++) {
        final d = (dry[i] - resonant[i]).abs();
        if (d > maxDiff) maxDiff = d;
      }
      expect(maxDiff, greaterThan(0.01));
    });
  });

  group('Ola 1D - DSL Security Guardrails, Terminal structuredData & JSON Codecs', () {
    test('TunnerDslInterpreter enforces maxStatements budget', () async {
      const script = '''
loop 50 {
  loop 50 {
    note C4 1/16;
  }
}
''';
      final parseResult = TunnerDslParser().parse(script);
      expect(parseResult.isSuccess, isTrue);

      final interpreter = TunnerDslInterpreter(maxStatements: 100);
      final report = await interpreter.interpret(parseResult.program!, isDryRun: true);

      expect(report.isSuccess, isFalse);
      expect(report.totalStatementsExecuted, equals(100));
      expect(report.diagnostics, isNotEmpty);
      expect(report.diagnostics.first.message, contains('MAX_STATEMENTS_EXCEEDED'));
      expect(report.toJson()['isSuccess'], isFalse);
    });

    test('TunnerDslInterpreter enforces maxLoopDepth limit', () async {
      // Build AST with depth 4 when limit is 3
      TunnerStatementNode inner = const NoteStatementNode(
        pitch: 'C4',
        durationFraction: '1/4',
      );
      for (int depth = 0; depth < 4; depth++) {
        inner = LoopStatementNode(count: 2, body: [inner]);
      }
      final program = ProgramNode([inner]);

      final interpreter = TunnerDslInterpreter(maxLoopDepth: 3);
      final report = await interpreter.interpret(program, isDryRun: true);

      expect(report.isSuccess, isFalse);
      expect(report.diagnostics, isNotEmpty);
      expect(report.diagnostics.first.message, contains('MAX_LOOP_DEPTH_EXCEEDED'));
    });

    test('TunnerOsCommandResult structuredData and JSON codecs round-trip cleanly', () {
      final cmdResult = TunnerOsCommandResult.success(
        'OK',
        structuredData: const {'bpm': 120, 'active': true},
      );
      expect(cmdResult.structuredData, equals({'bpm': 120, 'active': true}));
      expect(cmdResult.toJson()['structuredData']['bpm'], equals(120));

      final diag = TunnerDslDiagnostic.warning('Demo', line: 3, column: 7);
      final diagRestored = TunnerDslDiagnostic.fromJson(diag.toJson());
      expect(diagRestored.message, equals('Demo'));
      expect(diagRestored.line, equals(3));
      expect(diagRestored.severity, equals(TunnerDslDiagnosticSeverity.warning));

      final chord = ChordEntity(
        rootNoteIndex: 0,
        quality: ChordQuality.major7,
        confidence: 0.91,
        chromaVector: List.filled(12, 0.1),
        notes: const ['Do', 'Mi', 'Sol', 'Si'],
      );
      expect(ChordEntity.fromJson(chord.toJson()), equals(chord));

      final voice = const DetectedPolyphonicVoice(
        noteName: 'La',
        noteNameInternational: 'A',
        octave: 4,
        pitchClassIndex: 9,
        frequencyHz: 440.0,
        midiNumber: 69,
        centsDeviation: 0.5,
        salience: 1.0,
        harmonicRole: 'Fundamental (Raiz)',
      );
      expect(DetectedPolyphonicVoice.fromJson(voice.toJson()).midiNumber, equals(69));

      final question = const EarTrainingQuestion(
        id: 'q_1',
        baseNoteName: 'A4',
        baseFrequencyHz: 440.0,
        targetFrequencyHz: 659.25,
        targetInterval: MusicalInterval.perfectFifth,
        isAscending: true,
        options: [MusicalInterval.perfectFifth, MusicalInterval.majorThird],
        correctOptionIndex: 0,
      );
      expect(EarTrainingQuestion.fromJson(question.toJson()).targetInterval, equals(MusicalInterval.perfectFifth));

      final lesson = CuratedGuidedLessons.all.first;
      expect(GuidedLessonEntity.fromJson(lesson.toJson()).id, equals(lesson.id));

      final task = StandardPedagogicalTask(
        code: TaskTaxonomyCode.parse('EAR.01.INTV.001'),
        title: 'Intervalo Base',
        description: 'Practica de quintas',
        steps: const [
          TaskStep(
            index: 0,
            instruction: 'Canta Sol4',
            noteOrTarget: 'Sol4',
            frequencyHz: 392.0,
            targetDurationSeconds: 2.0,
            hint: 'Mantener aire',
          ),
        ],
      );
      expect(StandardPedagogicalTask.fromJson(task.toJson()).code, equals(task.code));

      final vocal = VocalEvaluationResult(
        evaluationId: 'v-1',
        timestamp: DateTime(2026, 11, 23, 15, 0),
        targetFrequencyHz: 440.0,
        measuredMeanFrequencyHz: 440.0,
        centsDeviation: 0.0,
        jitterPercent: 0.3,
        shimmerPercent: 1.2,
        vibratoRateHz: 5.2,
        vibratoDepthCents: 30.0,
        overallScore: 98.0,
        classificationLabel: 'Virtuoso',
      );
      expect(VocalEvaluationResult.fromJson(vocal.toJson()), equals(vocal));
    });
  });
}
