import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_evaluator/data/practice_evaluator_service.dart';
import 'package:tunner/features/instrument/data/instrument_transposition_service.dart';
import 'mock_recorder_services.dart';

class MockPitchService implements IPitchDetectorService {
  @override
  Function(double p1)? onPitchDetected;
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

class MockMetronomeService implements IMetronomeService {
  @override
  Function(int p1)? onSubTick;
  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPracticeRecorderService mockRecorder;
  late MockAudioPlaybackService mockPlayback;
  late TunerViewModel viewModel;

  setUp(() {
    mockRecorder = MockPracticeRecorderService();
    mockPlayback = MockAudioPlaybackService();

    viewModel = TunerViewModel(
      pitchService: MockPitchService(),
      metronomeService: MockMetronomeService(),
      evaluatorService: const PracticeEvaluatorService(),
      transpositionService: const InstrumentTranspositionService(),
      recorderService: mockRecorder,
      playbackService: mockPlayback,
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('TunerViewModel Practice Recorder & Loopback Playback Tests', () {
    test('Initial state has no active recording and not recording', () {
      expect(viewModel.isAudioRecording, false);
      expect(viewModel.activeRecording, isNull);
      expect(viewModel.recordingHistory, isEmpty);
      expect(viewModel.currentWaveformPeaks, isEmpty);
      expect(viewModel.isPlayingAudio, false);
    });

    test('startPracticeRecording initializes recording state and path', () async {
      await viewModel.startPracticeRecording();

      expect(viewModel.isAudioRecording, true);
      expect(mockRecorder.isRecording, true);
      expect(mockRecorder.lastDestinationPath, isNotNull);
    });

    test('Emitted amplitude peaks update currentWaveformPeaks', () async {
      await viewModel.startPracticeRecording();

      mockRecorder.emitAmplitude(0.25);
      mockRecorder.emitAmplitude(0.75);
      mockRecorder.emitAmplitude(0.90);

      await Future<void>.delayed(Duration.zero);

      expect(viewModel.currentWaveformPeaks, equals([0.25, 0.75, 0.90]));
    });

    test('stopPracticeRecording saves recording when duration is valid', () async {
      await viewModel.startPracticeRecording();
      mockRecorder.emitAmplitude(0.5);

      // Simulamos tick de grabación
      await Future<void>.delayed(const Duration(milliseconds: 1050));

      await viewModel.stopPracticeRecording();

      expect(viewModel.isAudioRecording, false);
      expect(mockRecorder.isRecording, false);
      expect(viewModel.activeRecording, isNotNull);
      expect(viewModel.activeRecording!.songTitle, viewModel.activePackage.title);
      expect(viewModel.recordingHistory.length, 1);
    });

    test('togglePracticeRecording toggles between start and stop', () async {
      expect(viewModel.isAudioRecording, false);

      await viewModel.togglePracticeRecording();
      expect(viewModel.isAudioRecording, true);

      await viewModel.togglePracticeRecording();
      expect(viewModel.isAudioRecording, false);
    });

    test('playActiveRecording triggers playback service', () async {
      await viewModel.startPracticeRecording();
      await Future<void>.delayed(const Duration(milliseconds: 1050));
      await viewModel.stopPracticeRecording();

      final rec = viewModel.activeRecording;
      expect(rec, isNotNull);

      await viewModel.playActiveRecording();
      expect(viewModel.isPlayingAudio, true);
      expect(mockPlayback.isPlaying, true);
      expect(mockPlayback.currentFilePath, rec!.filePath);
    });

    test('pause, stop and seek playback update playback state', () async {
      await viewModel.startPracticeRecording();
      await Future<void>.delayed(const Duration(milliseconds: 1050));
      await viewModel.stopPracticeRecording();

      await viewModel.playActiveRecording();
      expect(viewModel.isPlayingAudio, true);

      await viewModel.pauseActiveRecording();
      expect(viewModel.isPlayingAudio, false);

      await viewModel.seekPlayback(const Duration(seconds: 15));
      expect(viewModel.playbackPosition, const Duration(seconds: 15));

      await viewModel.setPlaybackSpeed(1.25);
      expect(viewModel.playbackSpeed, 1.25);
      expect(mockPlayback.currentRate, 1.25);

      await viewModel.stopActiveRecordingPlayback();
      expect(viewModel.playbackPosition, Duration.zero);
    });

    test('discardActiveRecording clears active recording and removes it from history', () async {
      await viewModel.startPracticeRecording();
      await Future<void>.delayed(const Duration(milliseconds: 1050));
      await viewModel.stopPracticeRecording();

      expect(viewModel.activeRecording, isNotNull);
      expect(viewModel.recordingHistory.length, 1);

      viewModel.discardActiveRecording();

      expect(viewModel.activeRecording, isNull);
      expect(viewModel.recordingHistory, isEmpty);
    });

    test('Practice report automatically attaches active recording', () async {
      await viewModel.startPracticeRecording();
      await Future<void>.delayed(const Duration(milliseconds: 1050));
      await viewModel.stopPracticeRecording();

      final activeRec = viewModel.activeRecording;
      expect(activeRec, isNotNull);

      // Activamos modo práctica y emitimos una evaluación
      viewModel.togglePracticeMode();
      viewModel.startSongWithCountIn();

      // Completamos sesión
      viewModel.completeManualPracticeSession();

      if (viewModel.lastReport != null) {
        expect(viewModel.lastReport!.recording, activeRec);
      }
    });
  });
}
