import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/instrument/data/instrument_transposition_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/metronome/presentation/tap_tempo_modal.dart';
import 'package:tunner/features/persistence/data/json_local_persistence_service.dart';
import 'package:tunner/features/practice_evaluator/data/practice_evaluator_service.dart';
import 'package:tunner/features/practice_recorder/data/audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/data/practice_recorder_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TunerViewModel viewModel;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tunner_tap_tempo_test_');
    final persistenceService = JsonLocalPersistenceService(
      documentsPathProvider: () async => tempDir.path,
    );

    viewModel = TunerViewModel(
      pitchService: _FakePitchService(),
      metronomeService: _FakeMetroService(),
      evaluatorService: PracticeEvaluatorService(),
      transpositionService: InstrumentTranspositionService(),
      recorderService: PracticeRecorderService(),
      playbackService: AudioPlaybackService(),
      persistenceService: persistenceService,
      audioSynthesizerService: MemoryAudioSynthesizerService(),
    );
  });

  tearDown(() async {
    viewModel.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget buildTestApp(Widget child) {
    return MaterialApp(
      home: ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: Scaffold(body: child),
      ),
    );
  }

  group('Tap Tempo UI Tests', () {
    testWidgets('TapTempoModal renders pad, BPM display, and initial diagnostic state', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(TapTempoModal(viewModel: viewModel)));
      await tester.pump();

      expect(find.text('Calibración Rítmica Tap Tempo'), findsOneWidget);
      expect(find.byKey(const Key('tap_tempo_bpm_display')), findsOneWidget);
      expect(find.byKey(const Key('tap_tempo_mark_text')), findsOneWidget);
      expect(find.byKey(const Key('tap_tempo_pad')), findsOneWidget);
      expect(find.byKey(const Key('tap_tempo_jitter_text')), findsOneWidget);
      expect(find.text('-- ms'), findsOneWidget);
      expect(find.text('Pulsa rítmicamente al menos 2 veces para calibrar el tempo.'), findsOneWidget);
    });

    testWidgets('Tapping pad calculates BPM, updates jitter and shows reset button', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(TapTempoModal(viewModel: viewModel)));
      await tester.pump();

      // First tap (timestamp = 1000)
      viewModel.recordTapTempo(1000);
      await tester.pump();
      expect(find.byKey(const Key('reset_tap_tempo_btn')), findsNothing);

      // Second tap 500 ms later (timestamp = 1500) -> 120 BPM
      viewModel.recordTapTempo(1500);
      await tester.pump();

      expect(viewModel.bpm, equals(120));
      expect(find.byKey(const Key('reset_tap_tempo_btn')), findsOneWidget);
      expect(find.text('120'), findsWidgets);
      expect(find.text('±0.0 ms'), findsOneWidget);

      // Third tap 500 ms later (timestamp = 2000) -> 120 BPM
      viewModel.recordTapTempo(2000);
      await tester.pump();

      expect(viewModel.bpm, equals(120));
      expect(find.text('3 pulsaciones'), findsOneWidget);

      // Reset
      await tester.tap(find.byKey(const Key('reset_tap_tempo_btn')));
      await tester.pump();

      expect(viewModel.lastTapTempoResult, isNull);
      expect(find.byKey(const Key('reset_tap_tempo_btn')), findsNothing);
      expect(find.text('-- ms'), findsOneWidget);
    });

    testWidgets('Tapping tap_tempo_modal_btn in TunerScreen opens TapTempoModal', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const TunerScreen()));
      await tester.pump();

      final tapBtn = find.byKey(const Key('tap_tempo_modal_btn'));
      expect(tapBtn, findsOneWidget);

      await tester.tap(tapBtn);
      await tester.pump(); // Start sheet animation
      await tester.pump(const Duration(milliseconds: 300)); // Complete sheet animation

      expect(find.text('Calibración Rítmica Tap Tempo'), findsOneWidget);
      expect(find.byKey(const Key('tap_tempo_pad')), findsOneWidget);
    });
  });
}
