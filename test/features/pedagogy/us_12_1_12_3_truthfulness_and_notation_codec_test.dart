import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/logging/domain/i_studio_logger.dart';
import 'package:tunner/features/audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import 'package:tunner/features/audio_synthesizer/domain/i_stem_export_persistence_service.dart';
import 'package:tunner/features/audio_synthesizer/domain/stem_audio_synthesizer.dart';
import 'package:tunner/features/audio_synthesizer/domain/stem_export_entity.dart';
import 'package:tunner/features/ear_training/domain/blind_ear_trainer_engine.dart';
import 'package:tunner/features/exercise_generator/domain/algorithmic_exercise_generator.dart';
import 'package:tunner/features/guided_lessons/domain/pedagogical_task_contract.dart';
import 'package:tunner/features/guided_lessons/domain/task_catalog_index.dart';
import 'package:tunner/features/guided_lessons/domain/task_taxonomy_code.dart';
import 'package:tunner/features/metronome/domain/tap_tempo_result.dart';
import 'package:tunner/features/metronome/domain/tempo_entity.dart';
import 'package:tunner/features/pedagogy/domain/vocal_stability_evaluator.dart';
import 'package:tunner/features/pedagogy_profiles/domain/adaptive_scaffolding_engine.dart';
import 'package:tunner/features/pedagogy_profiles/domain/learner_profile_entity.dart';
import 'package:tunner/features/pedagogy_report/domain/pedagogical_report_models.dart';
import 'package:tunner/features/pedagogy_report/domain/pedagogical_report_pdf_generator.dart';
import 'package:tunner/features/practice_evaluator/domain/practice_report_entity.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';
import 'package:tunner/features/score_editor/presentation/score_editor_controller.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
import 'package:tunner/features/transcription/domain/live_transcription_engine.dart';
import 'package:tunner/features/universal_importer/domain/canonical_midi_exporter.dart';
import 'package:tunner/features/universal_importer/domain/canonical_pitch_notation_codec.dart';
import 'package:tunner/features/universal_importer/domain/i_score_parser_service.dart';

class _NoopSynth implements IAudioSynthesizerService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopParser implements IScoreParserService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopStemPersistence implements IStemExportPersistenceService {
  @override
  Future<List<String>> saveExportBundle(
    ExportBundleResult bundle, {
    String? customSubfolder,
  }) async {
    return const <String>[];
  }
}

class _NoopLogger implements IStudioLogger {
  @override
  void error(String tag, String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void warning(String tag, String message, {Object? error, StackTrace? stackTrace}) {}
}

void main() {
  group('US-12.1: Pedagogical Acoustic Truthfulness', () {
    test('VocalStabilityEvaluator returns 0.0 score and 0.0 Hz on silence (< 5 valid frames)', () {
      const evaluator = VocalStabilityEvaluator();
      final result = evaluator.evaluate(
        frequenciesHz: const [0.0, 0.0, 10.0, 440.0, 0.0, 0.0],
        amplitudes: const [0.0, 0.0, 0.0, 0.5, 0.0, 0.0],
        targetFrequencyHz: 440.0,
      );

      expect(result.measuredMeanFrequencyHz, equals(0.0));
      expect(result.overallScore, equals(0.0));
      expect(result.centsDeviation, equals(0.0));
    });

    test('AdaptiveScaffoldingEngine honors isSharp and prints actual effectiveTolerance', () {
      const engine = AdaptiveScaffoldingEngine();
      final strictCustom = LearnerProfileEntity.conservatory().copyWith(
        centsTolerance: 7.5,
      );

      final inTune = engine.evaluateNote(
        centsDeviation: 2.0,
        profile: strictCustom,
      );
      expect(inTune.isInTune, isTrue);
      expect(inTune.primaryFeedback, contains('Tol: +-7.5c'));
      expect(inTune.primaryFeedback, isNot(contains('Tol: +-5c')));

      final sharpOverride = engine.evaluateNote(
        centsDeviation: -12.0,
        profile: strictCustom,
        isSharp: true,
      );
      expect(sharpOverride.isInTune, isFalse);
      expect(sharpOverride.primaryFeedback, contains('sharp'));
    });

    test('PedagogicalReportPdfGenerator uses TUNNER branding and wraps long diagnostic lines', () {
      const generator = PedagogicalReportPdfGenerator();
      final longDiagnostic =
          'Precision medida en sesion prolongada de conservatorio con analisis detallado de entonacion microtonal, estabilidad de flujo aereo costodiafragmatico y regularidad timbrica en el registro agudo.';
      final longRecommendation =
          'Practicar escalas cromáticas y arpegios lentos con dron armónico en afinación justa, monitoreando la estabilidad en cents durante cada transición de registro.';

      final session = PedagogicalSessionData(
        sessionTitle: 'Estudio de Verdad Acustica',
        sessionDate: DateTime(2026, 11, 23),
        duration: const Duration(minutes: 12),
        totalEvaluatedNotes: 40,
        inTuneNotesCount: 36,
        tuningAccuracyPercentage: 90.0,
        averageCentsDeviation: 3.2,
        centsStabilityDelta: 1.5,
        spectralCentroidHz: 1120.0,
        thdPercentage: 8.5,
        harmonicRatios: const [1.0, 0.5, 0.3],
        rhythmMeanBpm: 92.0,
        rhythmJitterMs: 7.4,
        timedPitchSamples: const [
          TimedCentsSample(timeSec: 0.0, cents: 2.0),
          TimedCentsSample(timeSec: 1.0, cents: 3.5),
        ],
        masteryLevel: 'Virtuoso / Conservatorio',
        pedagogicalDiagnostic: longDiagnostic,
        recommendations: [longRecommendation],
      );

      final bytes = generator.generateReportPdf(
        session: session,
        config: const PedagogicalReportConfig(
          studentName: 'Ana Maria',
          instrument: 'Violin',
          institution: 'Tunner Academy',
          teacherName: 'Maestro Solis',
          includeCertificate: true,
        ),
      );

      final pdfText = latin1.decode(bytes);
      expect(pdfText, contains('TUNNER CONSERVATORY ACADEMY OF MUSIC'));
      expect(pdfText, isNot(contains('TUNER CONSERVATORY')));
      // La linea original de >170 chars debe haberse dividido en multiples comandos Tj
      expect(pdfText, isNot(contains(longDiagnostic)));
    });

    test('AlgorithmicExerciseGenerator uses flat enharmonics for Fa and flat tonics', () {
      const generator = AlgorithmicExerciseGenerator();
      final fMajor = generator.generate(
        rootNote: 'Fa4',
        type: ExerciseType.majorScale,
      );
      final fNotes = fMajor.score.measures
          .expand((m) => m.notes)
          .where((n) => !n.isRest)
          .map((n) => n.noteName)
          .toList();

      expect(fNotes, contains('Sib4'));
      expect(fNotes, isNot(contains('La#4')));

      final bbMajor = generator.generate(
        rootNote: 'Sib3',
        type: ExerciseType.majorScale,
      );
      final bbNotes = bbMajor.score.measures
          .expand((m) => m.notes)
          .where((n) => !n.isRest)
          .map((n) => n.noteName)
          .toList();

      expect(bbNotes.first, equals('Sib3'));
      expect(bbNotes, contains('Mib4'));
      expect(bbNotes, isNot(contains('Re#4')));
    });

    test('ScoreEditorController builds dynamic recommendations from session metrics', () {
      final controller = ScoreEditorController(
        audioSynthesizer: _NoopSynth(),
        scoreImporterService: _NoopParser(),
        stemSynthesizer: const StemAudioSynthesizer(),
        exportPersistenceService: _NoopStemPersistence(),
        logger: _NoopLogger(),
        onNotify: () {},
      );

      const pkg = SongPackage(
        id: 'pkg_dyn',
        title: 'Estudio Dinamico',
        composer: 'Tunner',
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.intermediate,
        defaultBpm: 90,
        tracks: [],
        score: HierarchicalScore(
          title: 'Estudio Dinamico',
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.commonTime44,
              notes: [],
            ),
          ],
        ),
      );

      final sharpUnstableReport = PracticeReportEntity(
        songTitle: 'Estudio Dinamico',
        timestamp: DateTime(2026, 11, 23),
        totalNotes: 20,
        hitNotes: 10,
        pitchAccuracyPercentage: 50.0,
        averageCentsDeviation: 18.5,
        rhythmAccuracyPercentage: 62.0,
        overallScore: 55.0,
        grade: PerformanceGrade.d,
        evaluations: const [],
        noteAccuracyMap: const {},
        criticalNotes: const [],
        masteredNotes: const [],
      );

      final flatStableReport = PracticeReportEntity(
        songTitle: 'Estudio Dinamico',
        timestamp: DateTime(2026, 11, 23),
        totalNotes: 20,
        hitNotes: 19,
        pitchAccuracyPercentage: 95.0,
        averageCentsDeviation: -14.0,
        rhythmAccuracyPercentage: 96.0,
        overallScore: 95.0,
        grade: PerformanceGrade.s,
        evaluations: const [],
        noteAccuracyMap: const {},
        criticalNotes: const [],
        masteredNotes: const [],
      );

      final dataWeak = controller.buildPedagogicalSessionData(
        activePackage: pkg,
        sessionHistory: [sharpUnstableReport],
        multiTrackSession: MultiTrackSessionEntity(
          id: 'pkg_dyn',
          title: 'Estudio Dinamico',
          createdAt: DateTime(2026, 11, 23),
          bpm: 90,
        ),
        cents: 18.5,
        bpm: 90,
        lastTapTempoResult: TapTempoResult(
          bpm: 90,
          exactBpm: 90.0,
          jitterMs: 28.0,
          jitterPercentage: 4.2,
          stabilityDescription: 'Inestable',
          tempoMark: TempoMark.fromBpm(90),
          tapCount: 8,
        ),
      );

      final dataStrong = controller.buildPedagogicalSessionData(
        activePackage: pkg,
        sessionHistory: [flatStableReport],
        multiTrackSession: MultiTrackSessionEntity(
          id: 'pkg_dyn',
          title: 'Estudio Dinamico',
          createdAt: DateTime(2026, 11, 23),
          bpm: 90,
        ),
        cents: -14.0,
        bpm: 90,
        lastTapTempoResult: TapTempoResult(
          bpm: 90,
          exactBpm: 90.0,
          jitterMs: 6.0,
          jitterPercentage: 0.9,
          stabilityDescription: 'Solido',
          tempoMark: TempoMark.fromBpm(90),
          tapCount: 8,
        ),
      );

      expect(dataWeak.recommendations, isNot(equals(dataStrong.recommendations)));
      expect(dataWeak.recommendations.any((r) => r.contains('Tendencia aguda')), isTrue);
      expect(dataWeak.recommendations.any((r) => r.contains('Pulso ritmico inestable')), isTrue);
      expect(dataStrong.recommendations.any((r) => r.contains('Tendencia grave')), isTrue);
      expect(dataStrong.recommendations.any((r) => r.contains('Pulso solido')), isTrue);
    });

    test('TaskCatalogIndex normalizes Spanish diacritics and deduplicates re-registration', () {
      final index = TaskCatalogIndex();
      final initialCount = index.count;
      final code = TaskTaxonomyCode.parse('EAR.01.INTV.999');
      final task1 = StandardPedagogicalTask(
        code: code,
        title: 'Afinación de Canción Melódica',
        description: 'Práctica de oído rítmico con precisión',
        steps: const [],
      );
      index.register(task1);
      index.register(task1);

      expect(index.count, equals(initialCount + 1));
      final matches1 = index.searchByQuery('afinacion');
      expect(matches1.any((t) => t.code == code), isTrue);
      final matches2 = index.searchByQuery('ritmico');
      expect(matches2.any((t) => t.code == code), isTrue);
    });

    test('BlindEarTrainerEngine respects configured frequency range across A0..C8', () {
      final engine = BlindEarTrainerEngine(
        config: const EarTrainingConfig(
          minBaseFrequencyHz: 500.0,
          maxBaseFrequencyHz: 900.0,
          useJustIntonation: true,
        ),
      );

      for (int i = 0; i < 10; i++) {
        final q = engine.generateNextQuestion();
        expect(q.baseFrequencyHz, inInclusiveRange(500.0, 900.0));
      }
    });
  });

  group('US-12.3: CanonicalPitchNotationCodec & Dotted Rhythmic Quantization', () {
    test('CanonicalPitchNotationCodec distinguishes B4/b4 from Bb4/Sib4 accurately', () {
      final bUpper = CanonicalPitchNotationCodec.parse('B4');
      final bLower = CanonicalPitchNotationCodec.parse('b4');
      final bFlat = CanonicalPitchNotationCodec.parse('Bb4');
      final bFlatLower = CanonicalPitchNotationCodec.parse('bb4');
      final siNatural = CanonicalPitchNotationCodec.parse('Si4');
      final siFlat = CanonicalPitchNotationCodec.parse('Sib4');

      expect(bUpper, isNotNull);
      expect(bUpper!.step, equals('B'));
      expect(bUpper.solfegeBase, equals('Si'));
      expect(bUpper.alter, equals(0));
      expect(bUpper.midiNumber, equals(71));

      expect(bLower, equals(bUpper));
      expect(siNatural, equals(bUpper));

      expect(bFlat, isNotNull);
      expect(bFlat!.step, equals('B'));
      expect(bFlat.solfegeBase, equals('Si'));
      expect(bFlat.alter, equals(-1));
      expect(bFlat.midiNumber, equals(70));

      expect(bFlatLower, equals(bFlat));
      expect(siFlat, equals(bFlat));

      // Edge-of-octave enharmonics
      expect(CanonicalPitchNotationCodec.noteNameToMidi('Cb4'), equals(59));
      expect(CanonicalPitchNotationCodec.noteNameToMidi('B#3'), equals(60));
      expect(CanonicalPitchNotationCodec.noteNameToMidi('--'), isNull);

      // MIDI exporter delegates cleanly to the unified codec
      expect(CanonicalMidiExporter.noteNameToMidiPitch('B4'), equals(71));
      expect(CanonicalMidiExporter.noteNameToMidiPitch('b4'), equals(71));
      expect(CanonicalMidiExporter.noteNameToMidiPitch('Bb4'), equals(70));
      expect(CanonicalMidiExporter.noteNameToMidiPitch('Sib4'), equals(70));
    });

    test('CanonicalPitchNotationCodec converts MIDI <-> frequency and flat/sharp spelling', () {
      expect(CanonicalPitchNotationCodec.midiToFrequency(69), closeTo(440.0, 1e-6));
      expect(CanonicalPitchNotationCodec.frequencyToMidi(440.0), equals(69));
      expect(CanonicalPitchNotationCodec.midiToSolfege(70, preferFlats: true), equals('Sib4'));
      expect(CanonicalPitchNotationCodec.midiToSolfege(70, preferFlats: false), equals('La#4'));
      expect(CanonicalPitchNotationCodec.midiToEnglish(70, preferFlats: true), equals('Bb4'));
      expect(CanonicalPitchNotationCodec.midiToEnglish(70, preferFlats: false), equals('A#4'));
    });

    test('RhythmicQuantizer supports dotted figures (3, 6, 12 sub-ticks)', () {
      expect(RhythmicQuantizer.canonicalDurations, equals(const [1, 2, 3, 4, 6, 8, 12, 16]));
      expect(RhythmicQuantizer.quantizeDuration(1), equals(1));
      expect(RhythmicQuantizer.quantizeDuration(2), equals(2));
      expect(RhythmicQuantizer.quantizeDuration(3), equals(3));
      expect(RhythmicQuantizer.quantizeDuration(4), equals(4));
      expect(RhythmicQuantizer.quantizeDuration(6), equals(6));
      expect(RhythmicQuantizer.quantizeDuration(8), equals(8));
      expect(RhythmicQuantizer.quantizeDuration(12), equals(12));
      expect(RhythmicQuantizer.quantizeDuration(16), equals(16));
    });
  });
}
