import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/instrument/domain/instrument_profile_entity.dart';
import 'package:tunner/features/persistence/data/json_local_persistence_service.dart';
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
  Future<void> setPlaybackRate(double rate) async {}
  @override
  void dispose() {}
}

void main() {
  group('TunerViewModel Persistence and Concert Pitch Tests', () {
    late Directory tempDir;
    late JsonLocalPersistenceService persistenceService;
    late _MockPitchService pitchService;
    late _MockMetronomeService metronomeService;
    late _MockRecorderService recorderService;
    late _MockPlaybackService playbackService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tunner_vm_persist_test_');
      persistenceService = JsonLocalPersistenceService(
        documentsPathProvider: () async => tempDir.path,
        fileName: 'vm_settings_test.json',
      );
      pitchService = _MockPitchService();
      metronomeService = _MockMetronomeService();
      recorderService = _MockRecorderService();
      playbackService = _MockPlaybackService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('setReferencePitch clamps between 415 and 466 Hz and recalculates note', () async {
      final vm = TunerViewModel(
        pitchService: pitchService,
        metronomeService: metronomeService,
        recorderService: recorderService,
        playbackService: playbackService,
        persistenceService: persistenceService,
      );

      // Simular pitch detectado a 442.0 Hz
      pitchService.onPitchDetected?.call(442.0);
      expect(vm.frequency, equals(442.0));
      // Con A4 = 440 Hz por defecto, 442 Hz tiene ~7.8 cents
      expect(vm.cents, greaterThan(7.0));

      // Calibrar afinación de concierto a 442.0 Hz
      vm.setReferencePitch(442.0);
      expect(vm.referencePitch, equals(442.0));
      // La nota recalculada debe dar 0.0 cents
      expect(vm.cents.abs(), lessThan(0.01));
      expect(vm.noteName, equals('La4'));

      // Clamping inferior y superior
      vm.setReferencePitch(400.0);
      expect(vm.referencePitch, equals(415.0));

      vm.setReferencePitch(500.0);
      expect(vm.referencePitch, equals(466.0));

      vm.dispose();
    });

    test('Auto-saves state to disk and loads correctly in new ViewModel instance', () async {
      final vm1 = TunerViewModel(
        pitchService: pitchService,
        metronomeService: metronomeService,
        recorderService: recorderService,
        playbackService: playbackService,
        persistenceService: persistenceService,
      );

      await vm1.isInitialized;

      // Modificar afinación de concierto, instrumento y tema
      vm1.setReferencePitch(442.0);
      vm1.setInstrumentProfile(InstrumentProfileEntity.bbTrumpet);
      vm1.setPalette(TunnerThemePalette.nordicFrost);

      // Guardar y sincronizar con el disco atómicamente
      await vm1.savePersistedState();

      // Instanciar un segundo ViewModel con el mismo servicio de persistencia
      final vm2 = TunerViewModel(
        pitchService: pitchService,
        metronomeService: metronomeService,
        recorderService: recorderService,
        playbackService: playbackService,
        persistenceService: persistenceService,
      );

      await vm2.isInitialized;
      await vm2.loadPersistedState();

      expect(vm2.referencePitch, equals(442.0));
      expect(vm2.activeInstrument.id, equals('bb_trumpet'));
      expect(vm2.currentPalette.id, equals(TunnerThemePalette.nordicFrost.id));

      vm1.dispose();
      vm2.dispose();
    });
  });
}
