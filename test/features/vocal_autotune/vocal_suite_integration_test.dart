import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/data/memory_persistence_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/vocal_autotune/domain/autotune_config_entity.dart';

class _MockPitchService extends IPitchDetectorService {
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
  Future<String?> stopRecording() async => '/tmp/mock_vocal_take.wav';
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
  group('Vocal Suite & Melodyne Mode Integration Tests (UC-60)', () {
    late TunerViewModel viewModel;
    late MemoryAudioSynthesizerService memorySynthesizer;
    late _MockPitchService mockPitch;

    setUp(() async {
      memorySynthesizer = MemoryAudioSynthesizerService();
      mockPitch = _MockPitchService();

      viewModel = TunerViewModel(
        pitchService: mockPitch,
        metronomeService: _MockMetroService(),
        recorderService: _MockRecorderService(),
        playbackService: _MockPlaybackService(),
        persistenceService: MemoryPersistenceService(),
        audioSynthesizerService: memorySynthesizer,
      );
      await viewModel.isInitialized;
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('Initial Vocal Suite state has no converted package', () {
      expect(viewModel.lastConvertedVocalPackage, isNull);
      expect(viewModel.lastVocalConversionResult, isNull);
    });

    test('Converts live vocal recording into editable SongPackage (Melodyne Mode)', () async {
      // 1. Activar AutoTune en Do Mayor
      viewModel.updateAutoTuneConfig(
        const AutoTuneConfigEntity(
          isEnabled: true,
          scaleRoot: 0, // Do
          scaleType: VocalScaleType.major,
          retuneSpeedMs: 0.0,
        ),
      );

      // 2. Registrar una toma vocal con muestras procesadas por AutoTune
      final take = PracticeTakeEntity(
        id: 'take_vocal_live',
        name: 'Toma La4 en Vivo',
        timestamp: DateTime.now(),
        duration: const Duration(milliseconds: 600),
        filePath: '/tmp/vocal_live.wav',
        waveformPeaks: const [0.6],
        pitchTrack: List.generate(
          15,
          (i) => TimedPitchSample(
            timeMs: i * 20,
            frequencyHz: 435.0,
            centsDeviation: -20.0,
            targetNoteName: 'La4',
            correctedPitchHz: 440.0,
            isAutoTuned: true,
          ),
        ),
        spectralTrack: const [],
      );

      viewModel.multiTrackSession.takes.add(take);

      // 3. Convertir la toma a partitura
      final result = viewModel.convertActiveRecordingToScorePackage(
        takeId: 'take_vocal_live',
        preferCorrectedPitch: true,
      );

      expect(result, isNotNull);
      expect(result!.totalNotes, greaterThanOrEqualTo(1));
      expect(result.autoTunedNotesCount, equals(1));
      expect(viewModel.lastConvertedVocalPackage, equals(result.package));
      expect(viewModel.activePackage.score.measures.first.notes.first.isRest, isFalse);
      expect(viewModel.activePackage.score.measures.first.notes.first.noteName, equals('La4'));
    });

    test('Snaps active score to scale with 1-tap snap', () {
      // Crear manualmente una toma con nota fuera de escala
      final take = PracticeTakeEntity(
        id: 'take_test_snap',
        name: 'Toma Cromática',
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 2),
        filePath: '/tmp/test.wav',
        waveformPeaks: const [0.5],
        pitchTrack: List.generate(
          12,
          (i) => TimedPitchSample(
            timeMs: i * 20,
            frequencyHz: 369.99, // Fa#4 (fuera de Do Mayor)
            centsDeviation: 0.0,
            targetNoteName: 'Fa#4',
          ),
        ),
        spectralTrack: const [],
      );

      viewModel.multiTrackSession.takes.add(take);

      final result = viewModel.convertActiveRecordingToScorePackage(
        takeId: 'take_test_snap',
        autoLoadAsActivePackage: true,
      );

      expect(result, isNotNull);
      final rawNote = viewModel.activePackage.score.measures.first.notes.first.noteName;
      expect(rawNote, equals('Fa#4'));

      // Ejecutar 1-tap snap a Do Mayor
      viewModel.snapActiveScoreToScale(
        rootKey: 0, // Do
        scaleType: VocalScaleType.major,
      );

      final snappedNote = viewModel.activePackage.score.measures.first.notes.first.noteName;
      expect(snappedNote == 'Fa4' || snappedNote == 'Sol4', isTrue);
    });
  });
}
