import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/instrument/data/instrument_transposition_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/data/json_local_persistence_service.dart';
import 'package:tunner/features/practice_evaluator/data/practice_evaluator_service.dart';
import 'package:tunner/features/practice_recorder/data/audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/data/practice_recorder_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/universal_importer/presentation/score_import_tab_view.dart';

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
    tempDir = await Directory.systemTemp.createTemp('tunner_pdf_ui_test_');
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

  group('PDF Sheet Music Ingestion UI Tests', () {
    testWidgets('ScoreImportTabView renders Pentagrama (PDF) sample button and loads score', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(ScoreImportTabView(viewModel: viewModel)));
      await tester.pump();

      // Verificar existencia del botón de muestra PDF
      final pdfBtn = find.byKey(const Key('load_sample_pdf_btn'));
      expect(pdfBtn, findsOneWidget);
      expect(find.text('Pentagrama (PDF)'), findsOneWidget);

      // Tocar el botón de muestra PDF
      await tester.tap(pdfBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que el paquete cargado en el ViewModel corresponda al OMR
      expect(viewModel.activePackage.title, equals('Estudio Pentagrama PDF'));
      expect(viewModel.activePackage.composer, equals('Transcripción PDF (OMR)'));
      expect(viewModel.activePackage.score.measures, isNotEmpty);
      expect(viewModel.activePackage.score.measures.first.notes, isNotEmpty);
    });
  });
}
