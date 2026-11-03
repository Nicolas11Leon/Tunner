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
import 'package:tunner/features/score_editor/presentation/score_editor_modal.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/universal_importer/presentation/score_import_tab_view.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TunerViewModel viewModel;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tunner_formats_ui_test_');
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

  group('Universal Importer & Exporter Formats UI Tests', () {
    testWidgets('ScoreImportTabView renders ABC preset button and handles ABC import', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(ScoreImportTabView(viewModel: viewModel)));
      await tester.pump();

      expect(find.byKey(const Key('load_sample_abc_btn')), findsOneWidget);
      expect(find.text('Greensleeves (ABC)'), findsOneWidget);

      // Tap Greensleeves (ABC) preset
      await tester.tap(find.byKey(const Key('load_sample_abc_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(viewModel.activePackage.title, equals('Greensleeves (ABC)'));
      expect(viewModel.activePackage.composer, equals('Tradicional Inglesa'));
      expect(viewModel.activePackage.score.measures, isNotEmpty);
    });

    testWidgets('ScoreEditorModal renders ABC export button and triggers copy', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const ScoreEditorModal()));
      await tester.pump();

      final exportAbcBtn = find.byKey(const Key('export_abc_btn'));
      expect(exportAbcBtn, findsOneWidget);

      await tester.tap(exportAbcBtn);
      await tester.pump();

      expect(find.text('Partitura copiada en formato ABC Notation'), findsOneWidget);
    });
  });
}
