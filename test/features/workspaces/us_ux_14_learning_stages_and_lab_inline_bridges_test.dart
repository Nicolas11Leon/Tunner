import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/harmonic_tutor/domain/harmonic_role_entity.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart';
import 'package:tunner/features/instrument/data/instrument_transposition_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/data/json_local_persistence_service.dart';
import 'package:tunner/features/practice_evaluator/data/practice_evaluator_service.dart';
import 'package:tunner/features/practice_recorder/data/audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/data/practice_recorder_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/domain/workspace_type.dart';
import 'package:tunner/features/workspaces/presentation/learning_practice_workspace_view.dart';
import 'package:tunner/features/workspaces/presentation/production_acoustic_lab_workspace_view.dart';

class _FakePitchService extends IPitchDetectorService {
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> startRecording() async {
    startCount++;
  }

  @override
  Future<void> stopRecording() async {
    stopCount++;
  }
}

class _FakeMetroService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}

List<double> _synthesizeTriad({
  required double rootHz,
  required double thirdHz,
  required double fifthHz,
}) {
  const sampleRate = 44100.0;
  const numSamples = 2048;
  return List<double>.generate(numSamples, (i) {
    final t = i / sampleRate;
    return 0.35 * math.sin(2 * math.pi * rootHz * t) +
        0.28 * math.sin(2 * math.pi * thirdHz * t) +
        0.24 * math.sin(2 * math.pi * fifthHz * t);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-UX-14: Learning 3-Stage Hierarchy & Lab Inline Bridges', () {
    late Directory tempDir;
    late _FakePitchService pitchService;
    late MemoryAudioSynthesizerService fakeAudioSynthesizer;
    late TunerViewModel viewModel;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tunner_us_ux_14_test_');
      final persistenceService = JsonLocalPersistenceService(
        documentsPathProvider: () async => tempDir.path,
      );
      pitchService = _FakePitchService();
      fakeAudioSynthesizer = MemoryAudioSynthesizerService();
      viewModel = TunerViewModel(
        seedDefaults: false,
        pitchService: pitchService,
        metronomeService: _FakeMetroService(),
        evaluatorService: PracticeEvaluatorService(),
        transpositionService: InstrumentTranspositionService(),
        recorderService: PracticeRecorderService(),
        playbackService: AudioPlaybackService(),
        persistenceService: persistenceService,
        audioSynthesizerService: fakeAudioSynthesizer,
      );
    });

    tearDown(() {
      viewModel.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Widget wrapWithTestShell(Widget Function() builder) {
      return ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) => builder(),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'Prueba 1: LearningPracticeWorkspaceView muestra barra de 3 etapas y CTA superior de micrófono sin hacer scroll',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          wrapWithTestShell(
            () => LearningPracticeWorkspaceView(
              viewModel: viewModel,
              palette: TunnerThemePalette.obsidianStudio,
              onOpenInstrumentModal: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.byKey(const Key('learning_three_stage_flow_bar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('practice_stage_prepare_badge')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('practice_stage_execute_badge')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('practice_stage_evaluate_badge')),
          findsOneWidget,
        );
        expect(find.text('1. PREPARAR (Instrumento & Dron)'), findsOneWidget);
        expect(find.text('2. EJECUTAR (Afinación & Metrónomo)'), findsOneWidget);
        expect(find.text('3. EVALUAR (Grabación & Reporte)'), findsOneWidget);

        final quickStartMicFinder =
            find.byKey(const Key('learning_top_quick_start_mic_btn'));
        expect(quickStartMicFinder, findsOneWidget);
        expect(find.text('Iniciar Afinación'), findsOneWidget);
        expect(viewModel.isRecording, isFalse);

        // Tap directo sin hacer scroll (visible en viewport 800x600)
        await tester.tap(quickStartMicFinder);
        await tester.pump();

        expect(viewModel.isRecording, isTrue);
        expect(pitchService.startCount, equals(1));
        expect(find.text('Detener Mic'), findsOneWidget);

        // Segundo tap detiene el micrófono
        await tester.tap(quickStartMicFinder);
        await tester.pump();

        expect(viewModel.isRecording, isFalse);
        expect(pitchService.stopCount, equals(1));
        expect(find.text('Iniciar Afinación'), findsOneWidget);
      },
    );

    testWidgets(
      'Prueba 2: ProductionAcousticLabWorkspaceView expone puentes inline para fijar Dron con 5ta justa y abrir Tutor Armónico JI',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        viewModel.setWorkspace(WorkspaceType.production);

        // Configurar estado inicial distinto del acorde esperado
        await viewModel.setDroneConfig(
          viewModel.droneConfig.copyWith(
            rootNoteIndex: 2,
            includeFifth: false,
          ),
        );
        expect(viewModel.droneConfig.includeFifth, isFalse);
        expect(viewModel.isDronePlaying, isFalse);

        // Activar reconocimiento polifónico e inyectar tríada de Sol Mayor (G4, B4, D5)
        viewModel.setChordRecognitionActive(true);
        viewModel.processChordSamples(
          _synthesizeTriad(rootHz: 392.00, thirdHz: 493.88, fifthHz: 587.33),
        );
        expect(viewModel.recognizedChord.isRecognized, isTrue);
        final expectedRootIdx =
            viewModel.recognizedChord.rootNoteIndex.clamp(0, 11);

        await tester.pumpWidget(
          wrapWithTestShell(
            () => ProductionAcousticLabWorkspaceView(
              viewModel: viewModel,
              palette: TunnerThemePalette.obsidianStudio,
              onOpenMixerModal: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        final lockDroneBtn =
            find.byKey(const Key('lab_inline_lock_drone_btn'));
        final openTutorBtn =
            find.byKey(const Key('lab_inline_open_harmonic_tutor_btn'));
        expect(lockDroneBtn, findsOneWidget);
        expect(openTutorBtn, findsOneWidget);
        expect(find.text('Fijar Dron en Acorde'), findsOneWidget);
        expect(find.text('Tutor Armónico JI'), findsOneWidget);

        // Pulsar botón inline de Dron Armónico
        await tester.ensureVisible(lockDroneBtn);
        await tester.tap(lockDroneBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(viewModel.droneConfig.includeFifth, isTrue);
        expect(viewModel.droneConfig.rootNoteIndex, equals(expectedRootIdx));
        expect(viewModel.isDronePlaying, isTrue);
        expect(fakeAudioSynthesizer.isDroneLoopPlaying, isTrue);

        // Pulsar botón inline de Tutor Armónico JI
        await tester.ensureVisible(openTutorBtn);
        await tester.tap(openTutorBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final tutorFinder = find.byType(HarmonicTutorModal);
        expect(tutorFinder, findsOneWidget);
        final tutorModal = tester.widget<HarmonicTutorModal>(tutorFinder);
        const noteNames = [
          'Do',
          'Do#',
          'Re',
          'Re#',
          'Mi',
          'Fa',
          'Fa#',
          'Sol',
          'Sol#',
          'La',
          'La#',
          'Si',
        ];
        expect(
          tutorModal.viewModel.session.rootNoteName,
          equals(noteNames[expectedRootIdx]),
        );
        expect(
          tutorModal.viewModel.session.chordType,
          equals(HarmonicChordType.majorTriad),
        );
      },
    );
  });
}
