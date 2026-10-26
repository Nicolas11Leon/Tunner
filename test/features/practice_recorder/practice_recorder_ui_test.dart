import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/practice_recorder/presentation/practice_recorder_dock.dart';
import 'package:tunner/features/practice_recorder/presentation/practice_recording_player_modal.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_evaluator/data/practice_evaluator_service.dart';
import 'package:tunner/features/instrument/data/instrument_transposition_service.dart';
import 'mock_recorder_services.dart';

class MockPitchService implements IPitchDetectorService {
  @override
  Function(double p1)? onPitchDetected;
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

class MockMetronomeService implements IMetronomeService {
  @override
  Function(int p1)? onSubTick;
  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}
  @override
  Future<void> stop() async {}
}

Widget createTestApp(TunerViewModel viewModel) {
  return ChangeNotifierProvider<TunerViewModel>.value(
    value: viewModel,
    child: const MaterialApp(
      home: Scaffold(
        body: Center(
          child: PracticeRecorderDock(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPracticeRecorderService mockRecorder;
  late MockAudioPlaybackService mockPlayback;
  late TunerViewModel viewModel;

  setUp(() {
    mockRecorder = MockPracticeRecorderService();
    mockPlayback = MockAudioPlaybackService();

    viewModel = TunerViewModel(
      pitchService: MockPitchService(),
      metronomeService: MockMetronomeService(),
      evaluatorService: const PracticeEvaluatorService(),
      transpositionService: const InstrumentTranspositionService(),
      recorderService: mockRecorder,
      playbackService: mockPlayback,
      recordingPathProvider: () async => "/test/take_ui.m4a",
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('PracticeRecorderDock & Player Modal UI Tests', () {
    testWidgets('renders PracticeRecorderDock in idle state', (tester) async {
      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      expect(find.byType(PracticeRecorderDock), findsOneWidget);
      expect(find.text("AUTO-ESCUCHA"), findsOneWidget);
      expect(find.text("Micrófono listo"), findsOneWidget);
      expect(find.byKey(const Key('practice_record_button')), findsOneWidget);
    });

    testWidgets('tapping record button transitions to GRABANDO TOMA', (tester) async {
      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      await tester.tap(find.byKey(const Key('practice_record_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.isAudioRecording, true);
      expect(find.text("GRABANDO TOMA"), findsOneWidget);

      // Limpiar temporizador deteniendo grabación
      await viewModel.stopPracticeRecording();
      await tester.pump();
    });

    testWidgets('stopping recording renders "Escuchar" button and opens player modal', (tester) async {
      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      // Iniciar
      await tester.tap(find.byKey(const Key('practice_record_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Simular tiempo de grabación (1 segundo para cumplir el umbral de 500ms)
      await tester.pump(const Duration(milliseconds: 1100));

      // Detener
      await tester.tap(find.byKey(const Key('practice_record_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.isAudioRecording, false);
      expect(viewModel.activeRecording, isNotNull);
      expect(find.byKey(const Key('open_practice_player_button')), findsOneWidget);

      // Abrir modal de auto-escucha
      await tester.tap(find.byKey(const Key('open_practice_player_button')));
      await tester.pumpAndSettle();

      expect(find.byType(PracticeRecordingPlayerModal), findsOneWidget);
      expect(find.text("Auto-Escucha de Práctica"), findsOneWidget);
      expect(find.byKey(const Key('play_pause_take_button')), findsOneWidget);
      expect(find.text("0.75x"), findsOneWidget);
      expect(find.text("1.0x"), findsOneWidget);
      expect(find.text("1.25x"), findsOneWidget);

      // Tocar reproducir
      await tester.tap(find.byKey(const Key('play_pause_take_button')));
      await tester.pump();

      expect(viewModel.isPlayingAudio, true);

      // Tocar descartar
      await tester.tap(find.byKey(const Key('discard_take_button')));
      await tester.pumpAndSettle();

      expect(viewModel.activeRecording, isNull);
    });
  });
}
