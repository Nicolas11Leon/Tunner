import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/data/memory_persistence_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/score_editor/presentation/score_editor_modal.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
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

  group('ScoreEditorModal Widget Tests', () {
    testWidgets('Renders header, duration chips, note selector and export buttons', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ScoreEditorModal(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ESTUDIO DE EDICIÓN SMuFL'), findsOneWidget);
      expect(find.text('FIGURA RÍTMICA'), findsOneWidget);
      expect(find.text('Negra'), findsOneWidget);
      expect(find.text('Blanca'), findsOneWidget);
      expect(find.text('Redonda'), findsOneWidget);
      expect(find.text('MusicXML'), findsOneWidget);
      expect(find.text('MIDI (SMF)'), findsOneWidget);
    });

    testWidgets('Inserts note into active score and triggers audible synthesis feedback', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ScoreEditorModal(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap note "Sol"
      await tester.tap(find.text('Sol'));
      await tester.pumpAndSettle();

      // Tap "Insertar Sol4"
      final insertBtn = find.textContaining('Insertar Sol4');
      expect(insertBtn, findsOneWidget);

      await tester.ensureVisible(insertBtn);
      await tester.tap(insertBtn);
      await tester.pumpAndSettle();

      // Verify audible feedback was triggered
      expect(memorySynthesizer.playedNotes, isNotEmpty);
      expect(memorySynthesizer.playedNotes.last.frequency, closeTo(392.00, 1.0)); // Sol4 ~ 392 Hz

      // Verify note was inserted into score
      final notes = viewModel.activePackage.score.measures.first.notes;
      expect(notes.any((n) => n.noteName == 'Sol4'), isTrue);

      // Verify undo is now enabled
      expect(viewModel.canUndoScoreEdit, isTrue);
    });

    testWidgets('Exports active score to MusicXML and MIDI without errors', (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          const ScoreEditorModal(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap MusicXML button
      final xmlBtn = find.text('MusicXML');
      await tester.ensureVisible(xmlBtn);
      await tester.tap(xmlBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('MusicXML'), findsWidgets);

      // Tap MIDI button
      final midiBtn = find.text('MIDI (SMF)');
      await tester.ensureVisible(midiBtn);
      await tester.tap(midiBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('MIDI'), findsWidgets);
    });
  });
}
