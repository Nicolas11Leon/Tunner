import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import 'package:tunner/features/guided_lessons/domain/curated_guided_lessons.dart';
import 'package:tunner/features/guided_lessons/presentation/guided_lessons_modal.dart';
import 'package:tunner/features/workspaces/presentation/learning_practice_workspace_view.dart';

class _FakePitchService implements IPitchDetectorService {
  @override
  Function(double pitchHz)? onPitchDetected;
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

class _FakeMetroService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;
  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}
  @override
  Future<void> stop() async {}
}

class _FakeSynthesizerService implements IAudioSynthesizerService {
  double? lastPlayedToneFrequency;
  int playToneCount = 0;

  @override
  Future<void> playMetronomeClick({required bool isDownbeat, double volume = 1.0}) async {}

  @override
  Future<void> startDiapasonTone(double frequency, {double volume = 0.8}) async {
    lastPlayedToneFrequency = frequency;
    playToneCount++;
  }

  @override
  Future<void> stopDiapasonTone() async {}

  @override
  bool get isDiapasonPlaying => false;

  @override
  double get activeDiapasonFrequency => 0.0;

  @override
  Future<void> playNoteTone({
    required double frequency,
    required Duration duration,
    double volume = 0.8,
  }) async {
    lastPlayedToneFrequency = frequency;
    playToneCount++;
  }

  @override
  Future<void> startDroneLoop(Uint8List wavBytes, {double volume = 0.7}) async {}

  @override
  Future<void> stopDroneLoop() async {}

  @override
  bool get isDroneLoopPlaying => false;

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Guided Lessons Presentation & UI Tests', () {
    late TunerViewModel viewModel;
    late _FakePitchService fakePitchService;
    late _FakeMetroService fakeMetroService;
    late _FakeSynthesizerService fakeSynthService;

    setUp(() {
      fakePitchService = _FakePitchService();
      fakeMetroService = _FakeMetroService();
      fakeSynthService = _FakeSynthesizerService();

      viewModel = TunerViewModel(
        pitchService: fakePitchService,
        metronomeService: fakeMetroService,
        audioSynthesizerService: fakeSynthService,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    Widget createTestApp(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: child,
          ),
        ),
      );
    }

    testWidgets('Renders catalog of lessons when no lesson is active', (tester) async {
      await tester.pumpWidget(createTestApp(const GuidedLessonsModal()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('guided_lessons_modal')), findsOneWidget);
      expect(find.text('Lecciones Guiadas de Afinación'), findsOneWidget);
      expect(find.text('Iniciación: Las Tres Notas Maestras'), findsOneWidget);
      expect(find.text('Estabilidad de Embocadura: Notas Largas'), findsOneWidget);
      expect(find.byKey(const Key('start_lesson_lesson_01_master_notes')), findsOneWidget);
    });

    testWidgets('Starting a lesson transitions to active practice dashboard', (tester) async {
      await tester.pumpWidget(createTestApp(const GuidedLessonsModal()));
      await tester.pump(const Duration(milliseconds: 100));

      final startButton = find.byKey(const Key('start_lesson_lesson_01_master_notes'));
      expect(startButton, findsOneWidget);

      await tester.tap(startButton);
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.hasActiveGuidedLesson, isTrue);
      expect(viewModel.activeLessonProgress, isNotNull);

      // Verify active practice elements are rendered
      expect(find.byKey(const Key('lesson_progress_bar')), findsOneWidget);
      expect(find.byKey(const Key('lesson_step_dot_0')), findsOneWidget);
      expect(find.byKey(const Key('lesson_reference_tone_btn')), findsOneWidget);
      expect(find.text('Consejo Pedagógico'), findsOneWidget);
      expect(find.text('Objetivo: Sol4'), findsOneWidget);
    });

    testWidgets('Live pitch frames in tune advance progress bar in UI', (tester) async {
      final lesson = CuratedGuidedLessons.all.first;
      viewModel.startGuidedLesson(lesson);

      await tester.pumpWidget(createTestApp(const GuidedLessonsModal()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sostenido: 0.0s / 2.5s'), findsOneWidget);

      // Emit target pitch Sol4 (392.0 Hz) multiple frames
      fakePitchService.onPitchDetected?.call(392.0);
      await tester.pump(const Duration(milliseconds: 50));
      fakePitchService.onPitchDetected?.call(392.0);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify progress has accumulated and UI reflects it
      expect(viewModel.activeLessonProgress!.sustainedSeconds, greaterThan(0.0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('lesson_progress_bar')), findsOneWidget);
    });

    testWidgets('Tapping step dots jumps between steps accurately', (tester) async {
      final lesson = CuratedGuidedLessons.all.first;
      viewModel.startGuidedLesson(lesson);

      await tester.pumpWidget(createTestApp(const GuidedLessonsModal()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.activeLessonProgress!.currentStepIndex, equals(0));

      // Tap on step 1 (second step: La4)
      await tester.tap(find.byKey(const Key('lesson_step_dot_1')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.activeLessonProgress!.currentStepIndex, equals(1));
      expect(find.text('Objetivo: La4'), findsOneWidget);
    });

    testWidgets('Reference tone button triggers auditory synthesizer', (tester) async {
      final lesson = CuratedGuidedLessons.all.first;
      viewModel.startGuidedLesson(lesson);

      await tester.pumpWidget(createTestApp(const GuidedLessonsModal()));
      await tester.pump(const Duration(milliseconds: 100));

      final refBtn = find.byKey(const Key('lesson_reference_tone_btn'));
      await tester.tap(refBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeSynthService.playToneCount, greaterThan(0));
    });

    testWidgets('Cancel button returns to catalog list view', (tester) async {
      final lesson = CuratedGuidedLessons.all.first;
      viewModel.startGuidedLesson(lesson);

      await tester.pumpWidget(createTestApp(const GuidedLessonsModal()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('switch_or_cancel_lesson_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('switch_or_cancel_lesson_btn')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.hasActiveGuidedLesson, isFalse);
      expect(find.text('Lecciones Guiadas de Afinación'), findsOneWidget);
    });

    testWidgets('LearningPracticeWorkspaceView contains open_guided_lessons_chip', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<TunerViewModel>.value(
              value: viewModel,
              child: SingleChildScrollView(
                child: LearningPracticeWorkspaceView(
                  viewModel: viewModel,
                  palette: TunnerThemePalette.obsidianStudio,
                  onOpenInstrumentModal: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final chipFinder = find.byKey(const Key('open_guided_lessons_chip'));
      expect(chipFinder, findsOneWidget);

      await tester.tap(chipFinder);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('guided_lessons_modal')), findsOneWidget);
    });
  });
}
