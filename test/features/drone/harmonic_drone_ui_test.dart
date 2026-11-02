import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/drone/domain/drone_timbre.dart';
import 'package:tunner/features/drone/presentation/harmonic_drone_modal.dart';
import 'package:tunner/features/instrument/data/instrument_transposition_service.dart';
import 'package:tunner/features/persistence/data/json_local_persistence_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/practice_evaluator/data/practice_evaluator_service.dart';
import 'package:tunner/features/practice_recorder/data/audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/data/practice_recorder_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class _FakePitchService extends IPitchDetectorService {
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
  late MemoryAudioSynthesizerService fakeAudioSynthesizer;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tunner_drone_test_');
    final persistenceService = JsonLocalPersistenceService(
      documentsPathProvider: () async => tempDir.path,
    );

    fakeAudioSynthesizer = MemoryAudioSynthesizerService();

    viewModel = TunerViewModel(
      pitchService: _FakePitchService(),
      metronomeService: _FakeMetroService(),
      evaluatorService: PracticeEvaluatorService(),
      transpositionService: InstrumentTranspositionService(),
      recorderService: PracticeRecorderService(),
      playbackService: AudioPlaybackService(),
      persistenceService: persistenceService,
      audioSynthesizerService: fakeAudioSynthesizer,
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

  group('Harmonic Drone UI Tests', () {
    testWidgets('HarmonicDroneModal renders controls, note chips, sliders and toggles', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const HarmonicDroneModal()));
      await tester.pump();

      expect(find.text('Estudio de Dron Armónico'), findsOneWidget);
      expect(find.byKey(const Key('active_drone_note_label')), findsOneWidget);
      expect(find.text('Do3'), findsOneWidget);
      expect(find.byKey(const Key('toggle_drone_playback_btn')), findsOneWidget);
      expect(find.text('ACTIVAR'), findsOneWidget);

      // 12 root note buttons exist
      expect(find.byKey(const Key('drone_root_note_0')), findsOneWidget); // Do
      expect(find.byKey(const Key('drone_root_note_2')), findsOneWidget); // Re
      expect(find.byKey(const Key('drone_root_note_9')), findsOneWidget); // La

      // Octave selectors
      expect(find.byKey(const Key('drone_octave_2')), findsOneWidget);
      expect(find.byKey(const Key('drone_octave_3')), findsOneWidget);
      expect(find.byKey(const Key('drone_octave_4')), findsOneWidget);

      // Harmonic switches
      expect(find.byKey(const Key('drone_toggle_fifth_switch')), findsOneWidget);
      expect(find.byKey(const Key('drone_toggle_octave_switch')), findsOneWidget);

      // Timbres
      expect(find.byKey(const Key('drone_timbre_pureSine')), findsOneWidget);
      expect(find.byKey(const Key('drone_timbre_warmFlute')), findsOneWidget);
      expect(find.byKey(const Key('drone_timbre_richCello')), findsOneWidget);
      expect(find.byKey(const Key('drone_timbre_organ')), findsOneWidget);

      // Sliders
      expect(find.byKey(const Key('drone_volume_slider')), findsOneWidget);
      expect(find.byKey(const Key('drone_balance_slider')), findsOneWidget);
    });

    testWidgets('Tapping root note Re (index 2) updates droneConfig and display to Re3', (tester) async {
      await tester.pumpWidget(buildTestApp(const HarmonicDroneModal()));
      await tester.pump();

      // Tap on Re (index 2)
      await tester.tap(find.byKey(const Key('drone_root_note_2')));
      await tester.pump();

      expect(viewModel.droneConfig.rootNoteIndex, equals(2));
      expect(viewModel.droneConfig.rootDisplayName, equals('Re3'));
      expect(find.text('Re3'), findsOneWidget);
    });

    testWidgets('Tapping toggle_drone_playback_btn toggles drone playing state', (tester) async {
      await tester.pumpWidget(buildTestApp(const HarmonicDroneModal()));
      await tester.pump();

      expect(viewModel.isDronePlaying, isFalse);
      expect(fakeAudioSynthesizer.isDroneLoopPlaying, isFalse);

      // Start drone
      await tester.tap(find.byKey(const Key('toggle_drone_playback_btn')));
      await tester.pump();

      expect(viewModel.isDronePlaying, isTrue);
      expect(fakeAudioSynthesizer.isDroneLoopPlaying, isTrue);
      expect(find.text('DETENER'), findsOneWidget);

      // Stop drone
      await tester.tap(find.byKey(const Key('toggle_drone_playback_btn')));
      await tester.pump();

      expect(viewModel.isDronePlaying, isFalse);
      expect(fakeAudioSynthesizer.isDroneLoopPlaying, isFalse);
      expect(find.text('ACTIVAR'), findsOneWidget);
    });

    testWidgets('Tapping timbre card changes drone timbre', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const HarmonicDroneModal()));
      await tester.pump();

      await tester.tap(find.byKey(const Key('drone_timbre_richCello')));
      await tester.pump();

      expect(viewModel.droneConfig.timbre, equals(DroneTimbre.richCello));
    });

    testWidgets('TunerScreen displays drone chip in Essential and Pro modes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: const TunerScreen(),
          ),
        ),
      );
      await tester.pump();

      // Initial state: Conservatory Pro mode
      expect(find.byKey(const Key('pro_drone_modal_btn')), findsOneWidget);

      // Switch to Essential mode
      viewModel.setDisplayMode(AppDisplayMode.essential);
      await tester.pump();

      expect(find.byKey(const Key('essential_drone_modal_btn')), findsOneWidget);

      // Ensure any pending timer (such as silence debounce) is flushed before tearDown
      await tester.pump(const Duration(milliseconds: 70));
    });
  });
}
