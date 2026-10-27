import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/acoustic_lab/presentation/harmonic_spectrogram_modal.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';

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
  Future<void> setPlaybackRate(double speed) async {}
  @override
  void dispose() {}
}

void main() {
  group('HarmonicSpectrogramModal Widget Tests', () {
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
          home: Scaffold(
            body: HarmonicSpectrogramModal(),
          ),
        ),
      );
    }

    testWidgets('Renders 8 harmonic bars, spectral centroid and THD cards', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('LABORATORIO DE TIMBRE Y ARMÓNICOS'), findsOneWidget);

      // Verify Harmonic Bars (H1 to H8)
      for (int k = 1; k <= 8; k++) {
        expect(find.text('H$k'), findsOneWidget);
      }

      // Verify Psicoacoustic Metrics Cards
      expect(find.text('CENTROIDE ESPECTRAL'), findsOneWidget);
      expect(find.text('ENERGÍA DE SOBRETONOS'), findsOneWidget);
      expect(find.text('CUALIDAD DEL TIMBRE'), findsOneWidget);
    });
  });
}
