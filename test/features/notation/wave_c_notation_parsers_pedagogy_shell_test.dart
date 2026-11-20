import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/docking/domain/studio_dock_layout_entity.dart';
import 'package:tunner/core/dsl/domain/studio_os_audio_kernel.dart';
import 'package:tunner/core/dsl/domain/tunner_ast_node.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_interpreter.dart';
import 'package:tunner/features/ear_training/domain/blind_ear_trainer_engine.dart';
import 'package:tunner/features/ear_training/domain/musical_interval.dart';
import 'package:tunner/features/pedagogy/domain/ebbinghaus_spaced_repetition_engine.dart';
import 'package:tunner/features/pedagogy_report/domain/pedagogical_report_models.dart';
import 'package:tunner/features/pedagogy_report/domain/pedagogical_report_pdf_generator.dart';
import 'package:tunner/features/practice_evaluator/data/practice_evaluator_service.dart';
import 'package:tunner/features/score_editor/domain/score_editor_domain.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/sheet_music/presentation/real_sheet_music_painter.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
import 'package:tunner/features/transcription/domain/audio_to_score_transcription_engine.dart';
import 'package:tunner/features/universal_importer/data/abc_score_parser.dart';
import 'package:tunner/features/universal_importer/data/musicxml_score_parser.dart';
import 'package:tunner/features/universal_importer/domain/canonical_abc_exporter.dart';
import 'package:tunner/features/universal_importer/domain/canonical_pdf_exporter.dart';

void main() {
  group('Wave C Regression Suite', () {
    test('ScoreEditorOperations preserves tail when splitting a whole note and marks rests', () {
      const ops = ScoreEditorOperations();
      final pkg = SongPackage(
        id: 'test_split',
        title: 'Split Test',
        composer: 'Test',
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.beginner,
        defaultBpm: 120,
        tracks: const [],
        score: HierarchicalScore(
          title: 'Split Test',
          baseBpm: 120,
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.commonTime44,
              notes: [
                HierarchicalNote.note(startTick: 0, durationTicks: 16, noteName: 'Do4'),
              ],
            ),
          ],
        ),
      );

      final updated = ops.insertOrUpdateNote(
        package: pkg,
        measureIndex: 0,
        startTick: 4,
        durationTicks: 4,
        noteName: 'Mi4',
      );
      final notes = updated.score.measures.first.notes;
      expect(notes.length, equals(3));
      expect(notes[0].startTick, equals(0));
      expect(notes[0].durationTicks, equals(4));
      expect(notes[1].startTick, equals(4));
      expect(notes[1].durationTicks, equals(4));
      expect(notes[1].noteName, equals('Mi4'));
      expect(notes[2].startTick, equals(8));
      expect(notes[2].durationTicks, equals(8));
      expect(notes[2].noteName, equals('Do4'));

      final withRest = ops.deleteNoteAt(package: updated, measureIndex: 0, startTick: 4);
      expect(withRest.score.measures.first.notes[1].isRest, isTrue);
    });

    test('CanonicalPdfExporter preserves Spanish flats and hollow noteheads', () {
      const exporter = CanonicalPdfExporter();
      final pkg = SongPackage(
        id: 'pdf_test',
        title: 'Flats & Hollow',
        composer: 'Test',
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.beginner,
        defaultBpm: 100,
        tracks: const [],
        score: HierarchicalScore(
          title: 'Flats & Hollow',
          baseBpm: 100,
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.waltzTime34,
              notes: [
                HierarchicalNote.note(startTick: 0, durationTicks: 8, noteName: 'Mib4'),
                HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'Sib4'),
              ],
            ),
          ],
        ),
      );

      final pdfStr = latin1.decode(exporter.exportToPdf(pkg));
      expect(pdfStr.startsWith('%PDF-1.4'), isTrue);
      expect(pdfStr, contains('(3) Tj'));
      expect('re f'.allMatches(pdfStr).length, equals(1));
    });

    test('PedagogicalReportPdfGenerator emits valid latin1 xref, no arc operator, and honors includeRhythmJitter', () {
      const gen = PedagogicalReportPdfGenerator();
      final session = PedagogicalSessionData(
        sessionTitle: 'Sesión Test',
        sessionDate: DateTime(2026, 11, 19),
        duration: const Duration(minutes: 5),
        totalEvaluatedNotes: 40,
        inTuneNotesCount: 36,
        tuningAccuracyPercentage: 90.0,
        averageCentsDeviation: 2.1,
        centsStabilityDelta: 1.8,
        spectralCentroidHz: 750.0,
        thdPercentage: 8.5,
        harmonicRatios: const [1.0, 0.5],
        rhythmMeanBpm: 100.0,
        rhythmJitterMs: 9.0,
        timedPitchSamples: const [
          TimedCentsSample(timeSec: 0.0, cents: 1.0),
          TimedCentsSample(timeSec: 1.0, cents: -1.0),
        ],
        masteryLevel: 'Avanzado',
        pedagogicalDiagnostic: 'Diagnostico',
        recommendations: const ['Rec 1'],
      );
      const config = PedagogicalReportConfig(
        studentName: 'Estudiante',
        includeRhythmJitter: false,
      );
      final bytes = gen.generateReportPdf(session: session, config: config);
      final text = latin1.decode(bytes);
      expect(text, isNot(contains(' arc ')));
      expect(text, contains('TUNNER ACOUSTIC STUDIO'));
      expect(text, isNot(contains('TUNER ACOUSTIC STUDIO')));
      expect(text, isNot(contains('Jitter de Pulso')));
      final xrefOffsetMatch = RegExp(r'(\d{10}) 00000 n').allMatches(text).first;
      final obj1Offset = int.parse(xrefOffsetMatch.group(1)!);
      expect(text.substring(obj1Offset, obj1Offset + 7), equals('1 0 obj'));
    });

    test('PracticeEvaluatorService accepts enharmonics and BlindEarTrainerEngine rejects 0 Hz silence', () {
      const evaluator = PracticeEvaluatorService();
      final evalResult = evaluator.evaluateNote(
        expectedNote: HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do#4'),
        detectedNoteName: 'Reb4',
        detectedFrequency: 277.18,
        detectedCents: 0.0,
        timingDeltaMs: 0,
        sustainRatio: 1.0,
      );
      expect(evalResult.isPitchAccurate, isTrue);

      final trainer = BlindEarTrainerEngine(
        config: EarTrainingConfig(activeIntervals: [MusicalInterval.unison]),
      );
      trainer.generateNextQuestion();
      final silenceResult = trainer.submitSungFrequency(0.0);
      expect(silenceResult.isCorrect, isFalse);
    });

    test('EbbinghausSpacedRepetitionEngine aligns nextReview with 90% target retention', () {
      final engine = EbbinghausSpacedRepetitionEngine();
      final now = DateTime(2026, 11, 19, 12, 0);
      final item = engine.allItems.first;
      final eval = engine.submitAnswer(
        item.id,
        isCorrect: true,
        centsError: 2.0,
        responseTimeSeconds: 1.0,
        timestamp: now,
      );
      expect(eval.nextRetentionProjected, closeTo(0.90, 0.01));
    });

    test('MusicXmlScoreParser handles Cb/B# octave carry and skips <chord/> and <grace/>', () async {
      const parser = MusicXmlScoreParser();
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list><score-part id="P1"><part-name>Flute</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <note><grace/><pitch><step>D</step><octave>4</octave></pitch><type>16th</type></note>
      <note><pitch><step>C</step><alter>-1</alter><octave>4</octave></pitch><duration>4</duration><type>quarter</type></note>
      <note><chord/><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><type>quarter</type></note>
      <note><pitch><step>B</step><alter>1</alter><octave>3</octave></pitch><duration>4</duration><type>quarter</type></note>
    </measure>
  </part>
</score-partwise>''';
      final parsed = await parser.parseScoreData(
        bytes: Uint8List.fromList(utf8.encode(xml)),
        fileName: 'test.xml',
      );
      final notes = parsed.package.score.measures.first.notes;
      expect(notes[0].noteName, equals('Si3'));
      expect(notes[1].noteName, equals('Do4'));
      expect(notes[1].startTick, equals(4));
    });

    test('CanonicalAbcExporter handles Bb4 and AbcScoreParser applies K: G and strips chords', () async {
      const exporter = CanonicalAbcExporter();
      final abc = exporter.exportScore(
        score: HierarchicalScore(
          title: 'ABC Test',
          baseBpm: 120,
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.waltzTime34,
              notes: [HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Bb4')],
            ),
          ],
        ),
      );
      expect(abc, contains('M: 3/4'));
      expect(abc, contains('_B'));

      const parser = AbcScoreParser();
      const abcIn = 'X:1\nT:KeyG\nM:4/4\nL:1/4\nK:G\n"Am7"!fermata!F G |\n';
      final res = await parser.parseScoreData(
        bytes: Uint8List.fromList(utf8.encode(abcIn)),
        fileName: 'test.abc',
      );
      final notes = res.package.score.measures.first.notes;
      expect(notes[0].noteName, equals('Fa#4'));
      expect(notes[1].noteName, equals('Sol4'));
    });

    test('AudioToScoreTranscriptionEngine handles malformed 0-channel WAV safely', () {
      const engine = AudioToScoreTranscriptionEngine();
      final badWav = Uint8List(44);
      badWav.setRange(0, 4, 'RIFF'.codeUnits);
      badWav.setRange(8, 12, 'WAVE'.codeUnits);
      badWav.setRange(12, 16, 'fmt '.codeUnits);
      badWav[16] = 16;
      badWav.setRange(36, 40, 'data'.codeUnits);
      final score = engine.transcribeAudioFile(audioBytes: badWav);
      expect(score.measures, isNotEmpty);
    });

    test('RealSheetMusicPainter parses lowercase b4 as Si4 and StudioDockLayoutEntity clamps left+right', () {
      final painter = RealSheetMusicPainter(
        notes: const [],
        currentSubTick: 0,
        liveNote: '--',
        liveCents: 0.0,
        history: const {},
        isCountingIn: false,
        countInBeat: 0,
      );
      expect(painter.getNoteStep('b4'), equals(4));

      const layout = StudioDockLayoutEntity(zonePanelIds: {});
      final updated = layout.updateRatio(left: 0.60, right: 0.60);
      expect(updated.leftSplitRatio + updated.rightSplitRatio, lessThanOrEqualTo(0.8501));
    });

    test('TunnerDslInterpreter parses solfege, honors isDryRun, and survives >100 events', () async {
      expect(TunnerDslInterpreter.pitchToMidi('Do4'), equals(60));
      expect(TunnerDslInterpreter.pitchToMidi('Sol#4'), equals(68));

      final kernel = StudioOsAudioKernel();
      final interpreter = TunnerDslInterpreter(defaultKernel: kernel);
      final prog = ProgramNode([
        NoteStatementNode(pitch: 'Do4', durationFraction: '1/4'),
      ]);

      final dryReport = await interpreter.interpret(prog, isDryRun: true);
      expect(dryReport.generatedEvents, isEmpty);
      expect(kernel.eventHistory, isEmpty);

      final bigProg = ProgramNode([
        LoopStatementNode(
          count: 110,
          body: [NoteStatementNode(pitch: 'C4', durationFraction: '1/16')],
        ),
      ]);
      final bigReport = await interpreter.interpret(bigProg);
      expect(bigReport.totalStatementsExecuted, equals(110));
      expect(bigReport.generatedEvents, isNotEmpty);
    });
  });
}
