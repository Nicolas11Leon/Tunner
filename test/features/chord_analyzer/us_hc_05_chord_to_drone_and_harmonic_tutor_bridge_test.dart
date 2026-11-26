import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/chord_analyzer/presentation/chord_analyzer_modal.dart';
import 'package:tunner/features/harmonic_tutor/domain/harmonic_role_entity.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/data/json_local_persistence_service.dart';
import 'package:tunner/features/practice_evaluator/data/practice_evaluator_service.dart';
import 'package:tunner/features/practice_recorder/data/audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/data/practice_recorder_service.dart';
import 'package:tunner/features/instrument/data/instrument_transposition_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class _FakePitchService extends IPitchDetectorService {
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

/// Sintetiza una tríada mayor pura para disparar el reconocimiento polifónico.
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

Widget _createTestApp(TunerViewModel viewModel) {
  return MaterialApp(
    home: ChangeNotifierProvider<TunerViewModel>.value(
      value: viewModel,
      child: Scaffold(
        body: ChordAnalyzerModal(viewModel: viewModel),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TunerViewModel viewModel;
  late MemoryAudioSynthesizerService fakeAudioSynthesizer;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tunner_us_hc_05_test_');
    final persistenceService = JsonLocalPersistenceService(
      documentsPathProvider: () async => tempDir.path,
    );
    fakeAudioSynthesizer = MemoryAudioSynthesizerService();

    viewModel = TunerViewModel(
      seedDefaults: false,
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

  group('US-HC-05: Puente Acústico de 1 Clic desde ChordAnalyzerModal', () {
    testWidgets(
      'Prueba 1: Pulsar btn_chord_lock_harmonic_drone fija includeFifth=true, actualiza rootNoteIndex a la fundamental del acorde y activa el dron',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Configurar estado previo distinto al acorde esperado (Re sin 5ta y dron apagado)
        await viewModel.setDroneConfig(
          viewModel.droneConfig.copyWith(
            rootNoteIndex: 2,
            includeFifth: false,
          ),
        );
        expect(viewModel.droneConfig.includeFifth, isFalse);
        expect(viewModel.isDronePlaying, isFalse);

        // Activar reconocimiento e inyectar tríada de Sol Mayor (G4=392.00, B4=493.88, D5=587.33 -> rootNoteIndex = 7)
        viewModel.setChordRecognitionActive(true);
        viewModel.processChordSamples(
          _synthesizeTriad(rootHz: 392.00, thirdHz: 493.88, fifthHz: 587.33),
        );
        expect(viewModel.recognizedChord.isRecognized, isTrue);
        final expectedRootIdx = viewModel.recognizedChord.rootNoteIndex;

        await tester.pumpWidget(_createTestApp(viewModel));
        await tester.pump();

        final lockDroneBtn = find.byKey(const Key('btn_chord_lock_harmonic_drone'));
        expect(lockDroneBtn, findsOneWidget);

        await tester.ensureVisible(lockDroneBtn);
        await tester.tap(lockDroneBtn);
        await tester.pumpAndSettle();

        expect(viewModel.droneConfig.includeFifth, isTrue);
        expect(viewModel.droneConfig.rootNoteIndex, expectedRootIdx);
        expect(viewModel.isDronePlaying, isTrue);
        expect(fakeAudioSynthesizer.isDroneLoopPlaying, isTrue);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'Prueba 2: btn_chord_open_harmonic_tutor está presente y abre HarmonicTutorModal pre-configurado con la nota fundamental',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        // Inyectar tríada de Do Mayor (C4=261.63, E4=329.63, G4=392.00 -> rootNoteIndex = 0, 'Do')
        viewModel.setChordRecognitionActive(true);
        viewModel.processChordSamples(
          _synthesizeTriad(rootHz: 261.63, thirdHz: 329.63, fifthHz: 392.00),
        );
        expect(viewModel.recognizedChord.isRecognized, isTrue);
        final rootIdx = viewModel.recognizedChord.rootNoteIndex.clamp(0, 11);
        const noteNames = [
          'Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si',
        ];
        final expectedNoteName = noteNames[rootIdx];
        final expectedFreq =
            viewModel.referencePitch * math.pow(2.0, (60 + rootIdx - 69) / 12.0);

        await tester.pumpWidget(_createTestApp(viewModel));
        await tester.pump();

        final openTutorBtn = find.byKey(const Key('btn_chord_open_harmonic_tutor'));
        expect(openTutorBtn, findsOneWidget);

        await tester.ensureVisible(openTutorBtn);
        await tester.tap(openTutorBtn);
        await tester.pumpAndSettle();

        final tutorFinder = find.byType(HarmonicTutorModal);
        expect(tutorFinder, findsOneWidget);

        final tutorModal = tester.widget<HarmonicTutorModal>(tutorFinder);
        expect(tutorModal.viewModel.session.rootNoteName, expectedNoteName);
        expect(
          tutorModal.viewModel.session.rootFrequency,
          closeTo(expectedFreq, 0.01),
        );
        expect(
          tutorModal.viewModel.session.chordType,
          HarmonicChordType.majorTriad,
        );
      },
    );

    testWidgets(
      'Fallback sin acorde reconocido: fija dron en La (índice 9) con 5ta y abre Tutor JI en La (A4)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        expect(viewModel.recognizedChord.isRecognized, isFalse);

        await tester.pumpWidget(_createTestApp(viewModel));
        await tester.pump();

        final lockDroneBtn = find.byKey(const Key('btn_chord_lock_harmonic_drone'));
        await tester.ensureVisible(lockDroneBtn);
        await tester.tap(lockDroneBtn);
        await tester.pumpAndSettle();

        expect(viewModel.droneConfig.rootNoteIndex, 9);
        expect(viewModel.droneConfig.includeFifth, isTrue);
        expect(viewModel.isDronePlaying, isTrue);

        final openTutorBtn = find.byKey(const Key('btn_chord_open_harmonic_tutor'));
        await tester.ensureVisible(openTutorBtn);
        await tester.tap(openTutorBtn);
        await tester.pumpAndSettle();

        final tutorModal = tester.widget<HarmonicTutorModal>(
          find.byType(HarmonicTutorModal),
        );
        expect(tutorModal.viewModel.session.rootNoteName, 'La');
        expect(
          tutorModal.viewModel.session.rootFrequency,
          closeTo(viewModel.referencePitch, 0.01),
        );
      },
    );
  });
}
