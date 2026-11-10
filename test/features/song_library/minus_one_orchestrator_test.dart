import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/mixer/domain/mixer_track_entity.dart';
import 'package:tunner/features/practice_evaluator/domain/note_evaluation_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/minus_one_orchestrator.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';

void main() {
  const orchestrator = MinusOneOrchestrator();

  final dummyScore = HierarchicalScore(
    title: 'Test Score',
    measures: const [],
  );

  final dummyPackage = SongPackage(
    id: 'bach_inv_1',
    title: 'Invención 1 en Do Mayor',
    composer: 'J.S. Bach',
    genre: MusicGenre.baroque,
    difficulty: SongDifficulty.intermediate,
    defaultBpm: 96,
    score: dummyScore,
    tracks: const [
      AudioTrack(id: 'lead_voice', title: 'Voz Superior', instrumentIcon: 'flute'),
      AudioTrack(id: 'bass_voice', title: 'Bajo Continuo', instrumentIcon: 'piano'),
    ],
  );

  group('MinusOneOrchestrator Domain Logic', () {
    test('detectUserTrack correctly matches by track id or icon', () {
      expect(orchestrator.detectUserTrack(dummyPackage, 'lead_voice'), 'lead_voice');
      expect(orchestrator.detectUserTrack(dummyPackage, 'flute'), 'lead_voice');
      expect(orchestrator.detectUserTrack(dummyPackage, 'piano'), 'bass_voice');
      expect(orchestrator.detectUserTrack(dummyPackage, 'unknown_instrument'), 'lead_voice');
    });

    test('getAccompanimentStems filters out user track', () {
      final stems = orchestrator.getAccompanimentStems(dummyPackage, 'lead_voice');
      expect(stems.length, 1);
      expect(stems.first.id, 'bass_voice');
    });

    test('isSingleTrackWork detects whether package has accompaniment stems', () {
      expect(orchestrator.isSingleTrackWork(dummyPackage), isFalse);

      final singleTrackPackage = dummyPackage.copyWith(
        tracks: const [AudioTrack(id: 'solo', title: 'Solo', instrumentIcon: 'violin')],
      );
      expect(orchestrator.isSingleTrackWork(singleTrackPackage), isTrue);
    });

    test('configureMinusOneMixer mutes user track and sets guide volume if specified', () {
      final console = MixerConsoleEntity.defaultSetup();
      final configured = orchestrator.configureMinusOneMixer(
        console,
        'voice',
        muteUserTrack: true,
        guideVolume: 0.15,
      );

      final voiceTrack = configured.stems.firstWhere((t) => t.id == 'voice');
      expect(voiceTrack.isMuted, isTrue);
      expect(voiceTrack.volume, 0.15);

      final pianoTrack = configured.stems.firstWhere((t) => t.id == 'piano');
      expect(pianoTrack.isMuted, isFalse);
    });

    test('restoreFullEnsembleMixer un-mutes user track and restores volume', () {
      final console = MixerConsoleEntity.defaultSetup();
      final configured = orchestrator.configureMinusOneMixer(console, 'voice', muteUserTrack: true);
      final restored = orchestrator.restoreFullEnsembleMixer(configured, 'voice', standardVolume: 0.9);

      final voiceTrack = restored.stems.firstWhere((t) => t.id == 'voice');
      expect(voiceTrack.isMuted, isFalse);
      expect(voiceTrack.volume, 0.9);
    });
  });

  group('MinusOneSessionEntity Analytics', () {
    test('computes metrics accurately with empty and populated evaluations', () {
      final emptySession = orchestrator.createSession(
        package: dummyPackage,
        userTrackId: 'lead_voice',
      );

      expect(emptySession.totalNotesEvaluated, 0);
      expect(emptySession.hitNotesCount, 0);
      expect(emptySession.accuracyPercentage, 0.0);
      expect(emptySession.averageCentsDeviation, 0.0);
      expect(emptySession.overallScore, 0.0);
      expect(orchestrator.calculateSessionGrade(emptySession), 'D');

      const dummyNote = HierarchicalNote(
        startTick: 0,
        durationTicks: 4,
        noteName: 'Do4',
      );

      final eval1 = NoteEvaluationEntity(
        expectedNote: dummyNote,
        soundingExpectedNoteName: 'Do4',
        detectedNoteName: 'Do4',
        detectedFrequency: 261.63,
        centsDeviation: 2.5,
        timingCategory: NoteTimingCategory.onTime,
        timingDeltaMs: 5,
        sustainRatioPercentage: 98.0,
        isPitchAccurate: true,
        pitchScore: 98.0,
        rhythmScore: 95.0,
        sustainScore: 98.0,
        overallScore: 97.0,
      );

      final eval2 = NoteEvaluationEntity(
        expectedNote: dummyNote,
        soundingExpectedNoteName: 'Re4',
        detectedNoteName: 'Re4',
        detectedFrequency: 293.66,
        centsDeviation: -8.0,
        timingCategory: NoteTimingCategory.late,
        timingDeltaMs: 25,
        sustainRatioPercentage: 90.0,
        isPitchAccurate: true,
        pitchScore: 90.0,
        rhythmScore: 80.0,
        sustainScore: 90.0,
        overallScore: 86.0,
      );

      var session = orchestrator.recordEvaluation(emptySession, eval1);
      session = orchestrator.recordEvaluation(session, eval2);

      expect(session.totalNotesEvaluated, 2);
      expect(session.hitNotesCount, 2);
      expect(session.accuracyPercentage, 100.0);
      expect(session.onTimeCount, 1);
      expect(session.draggingCount, 1);
      expect(session.rushingCount, 0);
      expect(session.averageCentsDeviation, 5.25); // (2.5 + 8.0) / 2
      expect(session.overallScore, 91.5); // (97 + 86) / 2
      expect(orchestrator.calculateSessionGrade(session), 'A');
    });
  });
}
