import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/data/memory_persistence_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner/presentation/concert_pitch_selector_modal.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/universal_importer/data/universal_score_importer_service.dart';

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
  late MemoryAudioSynthesizerService memorySynthesizer;

  setUp(() async {
    memorySynthesizer = MemoryAudioSynthesizerService();
    viewModel = TunerViewModel(
      pitchService: _MockPitchService(),
      metronomeService: _MockMetronomeService(),
      recorderService: _MockRecorderService(),
      playbackService: _MockPlaybackService(),
      persistenceService: MemoryPersistenceService(),
      scoreImporterService: const UniversalScoreImporterService(),
      audioSynthesizerService: memorySynthesizer,
    );
    await viewModel.isInitialized;
  });

  tearDown(() {
    viewModel.dispose();
  });

  Widget createWidgetUnderTest(Widget child) {
    return ChangeNotifierProvider<TunerViewModel>.value(
      value: viewModel,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
    );
  }

  group('Diapason UI Tests in ConcertPitchSelectorModal', () {
    testWidgets('Renders diapason button and toggles audio synthesis on tap', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ConcertPitchSelectorModal(),
        ),
      );
      await tester.pumpAndSettle();

      final diapasonBtn = find.textContaining('Escuchar Diapasón A4');
      expect(diapasonBtn, findsOneWidget);

      // Tap diapason button to start playing tone
      await tester.tap(diapasonBtn);
      await tester.pumpAndSettle();

      expect(viewModel.isDiapasonPlaying, isTrue);
      expect(memorySynthesizer.isDiapasonPlaying, isTrue);
      expect(find.textContaining('Detener Diapasón'), findsOneWidget);

      // Tap again to stop
      await tester.tap(find.textContaining('Detener Diapasón'));
      await tester.pumpAndSettle();

      expect(viewModel.isDiapasonPlaying, isFalse);
      expect(memorySynthesizer.isDiapasonPlaying, isFalse);
      expect(find.textContaining('Escuchar Diapasón A4'), findsOneWidget);
    });

    testWidgets('Tapping confirm button stops diapason tone cleanly', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ConcertPitchSelectorModal(),
        ),
      );
      await tester.pumpAndSettle();

      // Start diapason
      await tester.tap(find.textContaining('Escuchar Diapasón A4'));
      await tester.pumpAndSettle();
      expect(viewModel.isDiapasonPlaying, isTrue);

      // Tap confirm button
      await tester.tap(find.text('Confirmar y Aplicar'));
      await tester.pumpAndSettle();

      expect(viewModel.isDiapasonPlaying, isFalse);
      expect(memorySynthesizer.isDiapasonPlaying, isFalse);
    });
  });
}
