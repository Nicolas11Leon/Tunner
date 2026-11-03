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
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TunerViewModel viewModel;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tunner_pdf_export_ui_test_');
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

    // Cargar partitura de prueba en el ViewModel
    viewModel.addSongPackage(
      SongPackage(
        id: 'pkg_export_test',
        title: 'Preludio en Sol',
        composer: 'J.S. Bach',
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.beginner,
        defaultBpm: 100,
        score: const HierarchicalScore(
          title: 'Preludio en Sol',
          baseBpm: 100,
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature(4, 4),
              notes: [
                HierarchicalNote(startTick: 0, durationTicks: 4, noteName: 'G4'),
                HierarchicalNote(startTick: 4, durationTicks: 4, noteName: 'B4'),
                HierarchicalNote(startTick: 8, durationTicks: 4, noteName: 'D5'),
                HierarchicalNote(startTick: 12, durationTicks: 4, noteName: 'G5'),
              ],
            ),
          ],
        ),
        tracks: const [],
      ),
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

  group('PDF Sheet Music Export UI Tests', () {
    testWidgets('ScoreEditorModal renders PDF export button and exports valid PDF', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const ScoreEditorModal()));
      await tester.pumpAndSettle();

      // Verificar existencia de los 4 botones de exportación
      expect(find.byKey(const Key('export_musicxml_btn')), findsOneWidget);
      expect(find.byKey(const Key('export_midi_btn')), findsOneWidget);
      expect(find.byKey(const Key('export_abc_btn')), findsOneWidget);
      expect(find.byKey(const Key('export_pdf_btn')), findsOneWidget);

      final pdfBtn = find.byKey(const Key('export_pdf_btn'));
      expect(find.text('PDF Imprimible'), findsOneWidget);

      // Tocar el botón de exportación PDF
      await tester.tap(pdfBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar que se muestre el SnackBar confirmando la exportación a PDF
      expect(find.textContaining('Partitura exportada a PDF vectorial'), findsOneWidget);
    });
  });
}
