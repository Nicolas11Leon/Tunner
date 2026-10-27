import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/persistence/data/memory_persistence_service.dart';
import 'package:tunner/features/song_library/presentation/song_decomposer_modal.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/universal_importer/data/universal_score_importer_service.dart';
import 'package:tunner/features/universal_importer/presentation/score_import_tab_view.dart';

class _MockPitchService implements IPitchDetectorService {
  @override
  Function(double)? onPitchDetected;
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

class _MockMetronomeService implements IMetronomeService {
  @override
  Function(int)? onSubTick;
  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}
  @override
  Future<void> stop() async {}
}

class _MockRecorderService implements IPracticeRecorderService {
  @override
  Stream<double> get amplitudeStream => const Stream.empty();
  @override
  bool get isRecording => false;
  @override
  Future<void> startRecording({required String destinationPath}) async {}
  @override
  Future<void> pauseRecording() async {}
  @override
  Future<void> resumeRecording() async {}
  @override
  Future<String?> stopRecording() async => null;
  @override
  void dispose() {}
}

class _MockPlaybackService implements IAudioPlaybackService {
  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();
  @override
  Stream<Duration> get onDurationChanged => const Stream.empty();
  @override
  Stream<void> get onPlayerComplete => const Stream.empty();
  @override
  bool get isPlaying => false;
  @override
  Future<void> play(String filePath) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setPlaybackRate(double rate) async {}
  @override
  void dispose() {}
}

void main() {
  late TunerViewModel viewModel;

  setUp(() async {
    viewModel = TunerViewModel(
      pitchService: _MockPitchService(),
      metronomeService: _MockMetronomeService(),
      recorderService: _MockRecorderService(),
      playbackService: _MockPlaybackService(),
      persistenceService: MemoryPersistenceService(),
      scoreImporterService: UniversalScoreImporterService(),
    );
    await viewModel.isInitialized;
  });

  tearDown(() {
    viewModel.dispose();
  });

  Widget createWidgetUnderTest(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    );
  }

  group('ScoreImportTabView Widget Tests', () {
    testWidgets('Renders importer banner, sample buttons and direct XML input', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          ScoreImportTabView(viewModel: viewModel),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Importador Universal Offline'), findsOneWidget);
      expect(find.text('Seleccionar Archivo Local (.xml / .mid)'), findsOneWidget);
      expect(find.text('Beethoven (MusicXML)'), findsOneWidget);
      expect(find.text('Arpegio (MIDI)'), findsOneWidget);
      expect(find.text('O PEGAR CÓDIGO XML DIRECTO'), findsOneWidget);
      expect(find.text('Decodificar y Montar en Pentagrama'), findsOneWidget);
    });

    testWidgets('Tapping Beethoven MusicXML demo imports score and updates activePackage', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          ScoreImportTabView(viewModel: viewModel),
        ),
      );
      await tester.pumpAndSettle();

      final beethovenBtn = find.text('Beethoven (MusicXML)');
      await tester.tap(beethovenBtn);
      await tester.pumpAndSettle();

      expect(viewModel.activePackage.title, 'Himno a la Alegría (MusicXML)');
      expect(viewModel.activePackage.composer, 'L. v. Beethoven');
      expect(viewModel.bpm, 116);
    });

    testWidgets('Tapping Arpegio MIDI demo imports score and updates activePackage', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          ScoreImportTabView(viewModel: viewModel),
        ),
      );
      await tester.pumpAndSettle();

      final arpegioBtn = find.text('Arpegio (MIDI)');
      await tester.tap(arpegioBtn);
      await tester.pumpAndSettle();

      expect(viewModel.activePackage.title, 'arpegio_estudio');
      expect(viewModel.bpm, 120);
    });

    testWidgets('Invokes injected filePicker when file button is tapped', (tester) async {
      bool pickerInvoked = false;

      await tester.pumpWidget(
        createWidgetUnderTest(
          ScoreImportTabView(
            viewModel: viewModel,
            filePicker: () async {
              pickerInvoked = true;
              return null; // Cancelled
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fileBtn = find.text('Seleccionar Archivo Local (.xml / .mid)');
      expect(fileBtn, findsOneWidget);
      await tester.tap(fileBtn);
      await tester.pumpAndSettle();

      expect(pickerInvoked, isTrue);
    });
  });

  group('SongDecomposerModal Tab Navigation Integration', () {
    testWidgets('Can switch to Importar (.xml / .mid) tab inside SongDecomposerModal', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongDecomposerModal(viewModel: viewModel),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial tab is Editor
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('Plantillas'), findsOneWidget);
      expect(find.text('Importar (.xml / .mid)'), findsOneWidget);

      // Tap on Importar tab
      await tester.tap(find.text('Importar (.xml / .mid)'));
      await tester.pumpAndSettle();

      // Should now display ScoreImportTabView contents
      expect(find.text('Importador Universal Offline'), findsOneWidget);
      expect(find.text('Beethoven (MusicXML)'), findsOneWidget);
    });
  });
}
