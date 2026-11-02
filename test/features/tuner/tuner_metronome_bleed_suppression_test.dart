import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/instrument/data/instrument_transposition_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/data/json_local_persistence_service.dart';
import 'package:tunner/features/practice_evaluator/data/practice_evaluator_service.dart';
import 'package:tunner/features/practice_recorder/data/audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/data/practice_recorder_service.dart';
import 'package:tunner/features/tuner/domain/acoustic_echo_suppressor.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class _MockPitchService extends IPitchDetectorService {
  @override
  Function(double)? onPitchDetected;

  @override
  Future<void> startRecording() async {}

  @override
  Future<void> stopRecording() async {}
}

class _MockMetroService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  group('TunerViewModel Metronome Bleed & Acoustic Echo Suppression Tests', () {
    late _MockPitchService pitchService;
    late _MockMetroService metroService;
    late MemoryAudioSynthesizerService synthService;
    late AcousticEchoSuppressor echoSuppressor;
    late TunerViewModel viewModel;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tunner_aes_test_');
      pitchService = _MockPitchService();
      metroService = _MockMetroService();
      synthService = MemoryAudioSynthesizerService();
      echoSuppressor = AcousticEchoSuppressor(blankingDurationMs: 70);

      viewModel = TunerViewModel(
        pitchService: pitchService,
        metronomeService: metroService,
        audioSynthesizerService: synthService,
        echoSuppressor: echoSuppressor,
        evaluatorService: PracticeEvaluatorService(),
        transpositionService: InstrumentTranspositionService(),
        recorderService: PracticeRecorderService(),
        playbackService: AudioPlaybackService(),
        persistenceService: JsonLocalPersistenceService(
          documentsPathProvider: () async => tempDir.path,
        ),
      );

      await viewModel.isInitialized;
    });

    tearDown(() async {
      viewModel.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Metronome click tick triggers echo suppressor notification', () {
      expect(synthService.clickHistory.length, equals(0));

      // Trigger metronome beat (subTick 0 = beat 1)
      metroService.onSubTick?.call(0);

      expect(synthService.clickHistory.length, equals(1));
    });

    test('Suppresses microphone click bleed when metronome ticks', () {
      // Simulate metronome click at t0
      metroService.onSubTick?.call(0);

      // Microphone immediately captures 2200 Hz click sound from speaker
      pitchService.onPitchDetected?.call(2200.0);

      // The frequency in the ViewModel must remain 0.0 (suppressed) rather than jumping to Do#7 (2200 Hz)
      expect(viewModel.frequency, equals(0.0));
      expect(viewModel.noteName, equals('--'));
    });

    test('Allows legitimate musical pitch played through the metronome click', () {
      // User is already playing A4 (440 Hz) before the metronome clicks
      pitchService.onPitchDetected?.call(440.0);
      expect(viewModel.frequency, equals(440.0));
      expect(viewModel.noteName, equals('La4'));

      // Metronome clicks on the beat
      metroService.onSubTick?.call(0);

      // User continues playing A4 (440.5 Hz) during the click window
      pitchService.onPitchDetected?.call(440.5);

      // Sustained pitch must be smoothly accepted without interruption
      expect(viewModel.frequency, equals(440.5));
      expect(viewModel.noteName, equals('La4'));
    });

    test('Allows new notes played after the click blanking window expires', () {
      // Simulate click
      metroService.onSubTick?.call(0);

      // Advance past blanking window by resetting or triggering after 80ms
      echoSuppressor.reset();

      // User plays C4 (261.63 Hz)
      pitchService.onPitchDetected?.call(261.63);

      expect(viewModel.frequency, equals(261.63));
      expect(viewModel.noteName, equals('Do4'));
    });
  });
}
