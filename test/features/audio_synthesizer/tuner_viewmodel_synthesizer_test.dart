import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/data/memory_persistence_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner/domain/note_entity.dart';
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
  late _MockMetronomeService mockMetronome;

  setUp(() async {
    memorySynthesizer = MemoryAudioSynthesizerService();
    mockMetronome = _MockMetronomeService();

    viewModel = TunerViewModel(
      pitchService: _MockPitchService(),
      metronomeService: mockMetronome,
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

  group('TunerViewModel Audio Synthesizer Integration Tests', () {
    test('Emits metronome clicks on quarter beat sub-ticks with accent on downbeat', () {
      expect(memorySynthesizer.clickHistory, isEmpty);

      // Simulate measure ticks (4/4 has 16 sub-ticks: 0, 4, 8, 12 are quarter beats)
      mockMetronome.onSubTick!(0); // Downbeat
      expect(memorySynthesizer.clickHistory.length, 1);
      expect(memorySynthesizer.clickHistory.last.isDownbeat, isTrue);

      mockMetronome.onSubTick!(1); // Semicorchea (no click)
      mockMetronome.onSubTick!(2); // Corchea (no click)
      mockMetronome.onSubTick!(3); // Semicorchea (no click)
      expect(memorySynthesizer.clickHistory.length, 1);

      mockMetronome.onSubTick!(4); // Beat 2 (off-beat click)
      expect(memorySynthesizer.clickHistory.length, 2);
      expect(memorySynthesizer.clickHistory.last.isDownbeat, isFalse);

      mockMetronome.onSubTick!(8); // Beat 3
      expect(memorySynthesizer.clickHistory.length, 3);
      expect(memorySynthesizer.clickHistory.last.isDownbeat, isFalse);

      mockMetronome.onSubTick!(12); // Beat 4
      expect(memorySynthesizer.clickHistory.length, 4);
      expect(memorySynthesizer.clickHistory.last.isDownbeat, isFalse);
    });

    test('Muting metronome in mixer suppresses acoustic clicks', () {
      final metroTrack = viewModel.mixerConsole.metronomeTrack;
      viewModel.toggleTrackMute(metroTrack.id);

      mockMetronome.onSubTick!(0);
      mockMetronome.onSubTick!(4);

      expect(memorySynthesizer.clickHistory, isEmpty);
    });

    test('Adjusting metronome volume modifies click gain accordingly', () {
      final metroTrack = viewModel.mixerConsole.metronomeTrack;
      viewModel.setTrackVolume(metroTrack.id, 0.45);

      mockMetronome.onSubTick!(0);
      expect(memorySynthesizer.clickHistory.last.volume, closeTo(0.45, 0.01));
    });

    test('toggleDiapasonTone starts and stops reference pitch tone at calibrated A4', () async {
      viewModel.setReferencePitch(442.0);
      expect(viewModel.isDiapasonPlaying, isFalse);
      expect(memorySynthesizer.isDiapasonPlaying, isFalse);

      await viewModel.toggleDiapasonTone();
      expect(viewModel.isDiapasonPlaying, isTrue);
      expect(memorySynthesizer.isDiapasonPlaying, isTrue);
      expect(memorySynthesizer.activeDiapasonFrequency, 442.0);

      // Changing reference pitch while playing updates tone dynamically
      viewModel.setReferencePitch(432.0);
      expect(memorySynthesizer.activeDiapasonFrequency, 432.0);

      await viewModel.toggleDiapasonTone();
      expect(viewModel.isDiapasonPlaying, isFalse);
      expect(memorySynthesizer.isDiapasonPlaying, isFalse);
    });

    test('playReferenceTone triggers audible diapason at exact note frequency', () {
      viewModel.playReferenceTone('Do4'); // C4 ~ 261.63 Hz
      expect(memorySynthesizer.isDiapasonPlaying, isTrue);
      expect(memorySynthesizer.activeDiapasonFrequency, closeTo(261.63, 0.1));
    });

    test('Plays score notes on sub-tick note onsets with duration and frequency', () {
      expect(viewModel.isScorePlaybackEnabled, isTrue);
      expect(memorySynthesizer.playedNotes, isEmpty);

      // On subTick 0, measure 0 has a note starting at tick 0
      final noteAt0 = viewModel.currentMeasureNotes.firstWhere((n) => n.startTick == 0);
      mockMetronome.onSubTick!(0);

      expect(memorySynthesizer.playedNotes, isNotEmpty);
      final lastPlayed = memorySynthesizer.playedNotes.last;
      final expectedFreq = NoteEntity.frequencyForNote(noteAt0.noteName, a4Ref: viewModel.referencePitch);
      expect(lastPlayed.frequency, closeTo(expectedFreq, 0.1));
      expect(lastPlayed.duration.inMilliseconds, greaterThan(50));
      final leadTrack = viewModel.mixerConsole.stems.first;
      expect(lastPlayed.volume, closeTo(leadTrack.volume, 0.05));
    });

    test('toggleScorePlayback disables note emission during metronome playback', () {
      viewModel.toggleScorePlayback();
      expect(viewModel.isScorePlaybackEnabled, isFalse);

      memorySynthesizer.playedNotes.clear();
      mockMetronome.onSubTick!(0);

      expect(memorySynthesizer.playedNotes, isEmpty);
    });

    test('Muting lead stem in mixer suppresses score note synthesis', () {
      final leadTrack = viewModel.mixerConsole.stems.first;
      viewModel.toggleTrackMute(leadTrack.id);
      memorySynthesizer.playedNotes.clear();

      mockMetronome.onSubTick!(0);
      expect(memorySynthesizer.playedNotes, isEmpty);
    });
  });
}
