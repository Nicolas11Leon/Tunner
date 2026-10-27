import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/tuner_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';

class _MockPitchService implements IPitchDetectorService {
  @override
  Function(double)? onPitchDetected;
  bool isRecording = false;
  @override
  Future<void> startRecording() async => isRecording = true;
  @override
  Future<void> stopRecording() async => isRecording = false;
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
  Future<void> setPlaybackRate(double speed) async {}
  @override
  void dispose() {}
}

void main() {
  group('Live Transcription UI Tests', () {
    late TunerViewModel viewModel;

    setUp(() {
      viewModel = TunerViewModel(
        pitchService: _MockPitchService(),
        metronomeService: _MockMetronomeService(),
        recorderService: _MockRecorderService(),
        playbackService: _MockPlaybackService(),
      );
    });

    Widget createWidgetUnderTest() {
      return ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: const MaterialApp(
          home: TunerScreen(),
        ),
      );
    }

    testWidgets('Toggles live transcription state and displays feedback', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Find the live transcription button
      final micBtn = find.byTooltip('Iniciar Transcripción de Micrófono a Partitura');
      expect(micBtn, findsOneWidget);
      expect(viewModel.isLiveTranscriptionActive, isFalse);

      // Tap to start live transcription
      await tester.tap(micBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(viewModel.isLiveTranscriptionActive, isTrue);
      expect(find.byTooltip('Detener Transcripción en Vivo'), findsOneWidget);
      expect(find.textContaining('Transcripción acústica en vivo iniciada'), findsWidgets);

      // Tap to stop live transcription
      final stopBtn = find.byTooltip('Detener Transcripción en Vivo');
      await tester.tap(stopBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(viewModel.isLiveTranscriptionActive, isFalse);
      expect(find.byTooltip('Iniciar Transcripción de Micrófono a Partitura'), findsOneWidget);
      expect(find.textContaining('finalizada y volcada'), findsWidgets);
    });
  });
}
