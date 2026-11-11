import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_evaluator/domain/note_evaluation_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/presentation/song_decomposer_modal.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class FakePitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}

  @override
  Future<void> stopRecording() async {}
}

class FakeMetroService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TunerViewModel viewModel;

  setUp(() {
    viewModel = TunerViewModel(
      pitchService: FakePitchService(),
      metronomeService: FakeMetroService(),
    );
  });

  group('Minus-One ViewModel Integration', () {
    test('toggleMinusOneMode activates and mutes active user track', () {
      expect(viewModel.isMinusOneActive, isFalse);

      viewModel.toggleMinusOneMode();

      expect(viewModel.isMinusOneActive, isTrue);
      final session = viewModel.activeMinusOneSession;
      expect(session, isNotNull);

      // Verify that user track is muted in the mixer
      final userTrackId = session!.userTrackId;
      final mixerTrack = viewModel.mixerConsole.stems.firstWhere((t) => t.id == userTrackId);
      expect(mixerTrack.isMuted, isTrue);

      // Toggling again deactivates Minus-One and restores mixer track
      viewModel.toggleMinusOneMode();
      expect(viewModel.isMinusOneActive, isFalse);
      final restoredTrack = viewModel.mixerConsole.stems.firstWhere((t) => t.id == userTrackId);
      expect(restoredTrack.isMuted, isFalse);
    });

    test('setMinusOneUserTrack switches target track and updates mixer', () {
      viewModel.toggleMinusOneMode();
      final tracks = viewModel.activePackage.tracks;
      if (tracks.length >= 2) {
        final secondTrackId = tracks[1].id;
        viewModel.setMinusOneUserTrack(secondTrackId);

        expect(viewModel.minusOneUserTrackId, secondTrackId);
        final mutedTrack = viewModel.mixerConsole.stems.firstWhere((t) => t.id == secondTrackId);
        expect(mutedTrack.isMuted, isTrue);
      }
    });

    test('setMinusOneGuideVolume adjusts guide volume and muting', () {
      viewModel.toggleMinusOneMode();
      viewModel.setMinusOneGuideVolume(0.20);

      final session = viewModel.activeMinusOneSession!;
      expect(session.guideTrackVolume, 0.20);
      expect(session.isMutedUserTrack, isFalse);

      final mixerTrack = viewModel.mixerConsole.stems.firstWhere((t) => t.id == session.userTrackId);
      expect(mixerTrack.volume, 0.20);
      expect(mixerTrack.isMuted, isFalse);

      // Back to 0.0
      viewModel.setMinusOneGuideVolume(0.0);
      expect(viewModel.activeMinusOneSession!.isMutedUserTrack, isTrue);
    });

    test('evaluations are recorded and can be reset in session', () {
      viewModel.toggleMinusOneMode();

      const dummyNote = HierarchicalNote(
        startTick: 0,
        durationTicks: 4,
        noteName: 'Do4',
      );

      final eval = NoteEvaluationEntity(
        expectedNote: dummyNote,
        soundingExpectedNoteName: 'Do4',
        detectedNoteName: 'Do4',
        detectedFrequency: 261.63,
        centsDeviation: 1.0,
        timingCategory: NoteTimingCategory.onTime,
        timingDeltaMs: 0,
        sustainRatioPercentage: 100.0,
        isPitchAccurate: true,
        pitchScore: 100.0,
        rhythmScore: 100.0,
        sustainScore: 100.0,
        overallScore: 100.0,
      );

      viewModel.recordMinusOneEvaluation(eval);
      expect(viewModel.activeMinusOneSession!.totalNotesEvaluated, 1);
      expect(viewModel.activeMinusOneSession!.overallScore, 100.0);
      expect(viewModel.activeMinusOneSession!.sessionGrade, 'S');

      viewModel.resetMinusOneEvaluations();
      expect(viewModel.activeMinusOneSession!.totalNotesEvaluated, 0);
    });
  });

  group('Minus-One UI Interaction Tests', () {
    testWidgets('SongDecomposerModal displays Minus-One tab, toggles switch and chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongDecomposerModal(viewModel: viewModel),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap Minus-One tab
      final minusOneTab = find.byKey(const Key('minus_one_tab_btn'));
      expect(minusOneTab, findsOneWidget);
      await tester.tap(minusOneTab);
      await tester.pumpAndSettle();

      // Verify header and switch
      expect(find.text("Ensamble Virtual Minus-One"), findsOneWidget);
      final switchFinder = find.byKey(const Key('minus_one_mode_switch'));
      expect(switchFinder, findsOneWidget);

      // Tap switch to activate
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(viewModel.isMinusOneActive, isTrue);

      // Verify practice button exists
      final practiceBtn = find.byKey(const Key('start_minus_one_practice_btn'));
      expect(practiceBtn, findsOneWidget);
    });
  });
}
