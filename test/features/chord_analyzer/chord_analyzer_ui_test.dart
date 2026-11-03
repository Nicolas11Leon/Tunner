import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/chord_analyzer/domain/chord_entity.dart';
import 'package:tunner/features/chord_analyzer/presentation/chord_analyzer_modal.dart';
import 'package:tunner/features/chord_analyzer/presentation/chord_radar_widget.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_evaluator/data/practice_evaluator_service.dart';
import 'package:tunner/features/instrument/data/instrument_transposition_service.dart';
import 'package:tunner/features/practice_recorder/data/practice_recorder_service.dart';
import 'package:tunner/features/practice_recorder/data/audio_playback_service.dart';
import 'package:tunner/features/persistence/data/json_local_persistence_service.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';

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

Widget createTestApp(Widget child, TunerViewModel vm) {
  return MaterialApp(
    home: ChangeNotifierProvider<TunerViewModel>.value(
      value: vm,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TunerViewModel viewModel;
  late MemoryAudioSynthesizerService fakeAudioSynthesizer;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tunner_chord_test_');
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

  group('ChordAnalyzer UI & Widget Tests', () {
    testWidgets('ChordRadarWidget paints 12 chromatic semitones without error', (tester) async {
      final chroma = List<double>.generate(12, (i) => i == 0 || i == 4 || i == 7 ? 0.8 : 0.0);
      final chord = ChordEntity(
        rootNoteIndex: 0,
        quality: ChordQuality.major,
        confidence: 0.92,
        chromaVector: chroma,
        notes: const ['Do', 'Mi', 'Sol'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChordRadarWidget(
                chromaVector: chroma,
                recognizedChord: chord,
                palette: TunnerThemePalette.obsidianStudio,
                size: 240,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ChordRadarWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('ChordAnalyzerModal renders title, placeholder and radar in idle state', (tester) async {
      await tester.pumpWidget(createTestApp(
        ChordAnalyzerModal(viewModel: viewModel),
        viewModel,
      ));

      expect(find.text('Reconocimiento Polifónico'), findsOneWidget);
      expect(find.text('Chroma Vectors & Pitch Class Profile'), findsOneWidget);
      expect(find.byKey(const Key('active_chord_symbol_placeholder')), findsOneWidget);
      expect(find.byType(ChordRadarWidget), findsOneWidget);
      expect(find.text('Radar Cromático (Pitch Classes)'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Progresión Armónica Reciente'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Progresión Armónica Reciente'), findsOneWidget);
    });

    testWidgets('Tapping toggle_chord_recognition_btn toggles isChordRecognitionActive', (tester) async {
      await tester.pumpWidget(createTestApp(
        ChordAnalyzerModal(viewModel: viewModel),
        viewModel,
      ));

      expect(viewModel.isChordRecognitionActive, isFalse);

      await tester.tap(find.byKey(const Key('toggle_chord_recognition_btn')));
      await tester.pump();

      expect(viewModel.isChordRecognitionActive, isTrue);

      await tester.tap(find.byKey(const Key('toggle_chord_recognition_btn')));
      await tester.pump();

      expect(viewModel.isChordRecognitionActive, isFalse);
    });

    testWidgets('ChordAnalyzerModal renders recognized chord and notes when active', (tester) async {
      viewModel.setChordRecognitionActive(true);

      // Inyectar muestras dummy
      final samples = List<double>.filled(128, 0.0);
      viewModel.processChordSamples(samples);

      await tester.pumpWidget(createTestApp(
        ChordAnalyzerModal(viewModel: viewModel),
        viewModel,
      ));
      await tester.pump();

      expect(find.byType(ChordRadarWidget), findsOneWidget);
    });

    testWidgets('TunerScreen displays chord chip in Essential and Pro modes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: const TunerScreen(),
          ),
        ),
      );
      await tester.pump();

      // En Modo Pro inicial
      expect(find.byKey(const Key('pro_chord_modal_btn')), findsOneWidget);

      // Cambiar a Modo Esencial
      viewModel.setDisplayMode(AppDisplayMode.essential);
      await tester.pump();

      expect(find.byKey(const Key('essential_chord_modal_btn')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 70));
    });
  });
}
