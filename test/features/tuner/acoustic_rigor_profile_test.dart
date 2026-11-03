import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/tuner/domain/acoustic_rigor_profile.dart';
import 'package:tunner/features/tuner/presentation/microphone_calibration_modal.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/persistence/domain/i_local_persistence_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class _FakePitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

class _FakeMetronomeService implements IMetronomeService {
  @override
  Function(int)? onSubTick;
  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}
  @override
  Future<void> stop() async {}
}

class _FakeRecorderService implements IPracticeRecorderService {
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

class _FakePlaybackService implements IAudioPlaybackService {
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

class _FakePersistenceService implements ILocalPersistenceService {
  AppUserSettingsEntity? savedSettings;
  @override
  Future<AppUserSettingsEntity> loadSettings() async =>
      savedSettings ?? AppUserSettingsEntity.defaultSettings;
  @override
  Future<void> saveSettings(AppUserSettingsEntity settings) async {
    savedSettings = settings;
  }
  @override
  Future<void> clearSettings() async {
    savedSettings = null;
  }
}

void main() {
  group('AcousticRigorProfile Domain Tests', () {
    test('beginner preset prioritizes high sensitivity and immediate response', () {
      final profile = AcousticRigorProfile.fromPreset(AcousticRigorPreset.beginner);

      expect(profile.preset, equals(AcousticRigorPreset.beginner));
      expect(profile.minConsecutiveFrames, equals(1));
      expect(profile.minClarity, equals(0.65));
      expect(profile.maxCentsDeviation, equals(50.0));
      expect(profile.enableInstrumentIsolation, isFalse);
    });

    test('studioRecording preset demands high harmonic clarity for clean takes', () {
      final profile = AcousticRigorProfile.fromPreset(AcousticRigorPreset.studioRecording);

      expect(profile.preset, equals(AcousticRigorPreset.studioRecording));
      expect(profile.minClarity, equals(0.86));
      expect(profile.maxCentsDeviation, equals(25.0));
      expect(profile.minConsecutiveFrames, equals(2));
      expect(profile.enableInstrumentIsolation, isTrue);
    });

    test('noisyStage preset reinforces Tone Lock with 3 frames and higher gate', () {
      final profile = AcousticRigorProfile.fromPreset(
        AcousticRigorPreset.noisyStage,
        baseNoiseGate: 0.005,
      );

      expect(profile.preset, equals(AcousticRigorPreset.noisyStage));
      expect(profile.minConsecutiveFrames, equals(3));
      expect(profile.minClarity, equals(0.88));
      expect(profile.noiseGateThreshold, equals(0.010));
      expect(profile.enableInstrumentIsolation, isTrue);
    });

    test('conservatoryMastery preset enforces surgical pitch tolerance', () {
      final profile = AcousticRigorProfile.fromPreset(AcousticRigorPreset.conservatoryMastery);

      expect(profile.preset, equals(AcousticRigorPreset.conservatoryMastery));
      expect(profile.minClarity, equals(0.92));
      expect(profile.maxCentsDeviation, equals(15.0));
    });

    test('toJson and fromJson preserves all DSP configuration faithfully', () {
      final original = AcousticRigorProfile(
        preset: AcousticRigorPreset.studioRecording,
        isAdvancedMode: true,
        minClarity: 0.89,
        minConsecutiveFrames: 3,
        maxCentsDeviation: 20.0,
        noiseGateThreshold: 0.012,
        digitalGain: 1.5,
        enableDcBlocker: true,
        enableInstrumentIsolation: true,
      );

      final json = original.toJson();
      final decoded = AcousticRigorProfile.fromJson(json);

      expect(decoded.preset, equals(original.preset));
      expect(decoded.isAdvancedMode, equals(original.isAdvancedMode));
      expect(decoded.minClarity, equals(original.minClarity));
      expect(decoded.minConsecutiveFrames, equals(original.minConsecutiveFrames));
      expect(decoded.maxCentsDeviation, equals(original.maxCentsDeviation));
      expect(decoded.noiseGateThreshold, equals(original.noiseGateThreshold));
      expect(decoded.digitalGain, equals(original.digitalGain));
      expect(decoded.enableDcBlocker, equals(original.enableDcBlocker));
      expect(decoded.enableInstrumentIsolation, equals(original.enableInstrumentIsolation));
    });
  });

  group('TunerViewModel & UI Dual-Tier Integration Tests', () {
    late TunerViewModel viewModel;

    setUp(() {
      viewModel = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetronomeService(),
        recorderService: _FakeRecorderService(),
        playbackService: _FakePlaybackService(),
        persistenceService: _FakePersistenceService(),
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('setAcousticRigorPreset updates profile and microphone calibration', () {
      viewModel.setAcousticRigorPreset(AcousticRigorPreset.noisyStage);

      expect(viewModel.acousticRigorProfile.preset, equals(AcousticRigorPreset.noisyStage));
      expect(viewModel.acousticRigorProfile.minConsecutiveFrames, equals(3));
      expect(viewModel.acousticRigorProfile.minClarity, equals(0.88));
      expect(viewModel.isInstrumentIsolationActive, isTrue);
    });

    test('setAcousticRigorAdvancedParameters marks preset as custom and updates values', () {
      viewModel.setAcousticRigorAdvancedParameters(
        minClarity: 0.94,
        maxCentsDeviation: 18.0,
      );

      expect(viewModel.acousticRigorProfile.preset, equals(AcousticRigorPreset.custom));
      expect(viewModel.acousticRigorProfile.minClarity, equals(0.94));
      expect(viewModel.acousticRigorProfile.maxCentsDeviation, equals(18.0));
    });

    testWidgets('MicrophoneCalibrationModal switches between simple presets and advanced controls',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MicrophoneCalibrationModal(viewModel: viewModel),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En vista sencilla, los presets están visibles
      expect(find.byKey(const Key('rigor_preset_card_beginner')), findsOneWidget);
      expect(find.byKey(const Key('rigor_preset_card_studioRecording')), findsOneWidget);
      expect(find.byKey(const Key('rigor_preset_card_noisyStage')), findsOneWidget);

      // Tocar preset Grabación / Estudio
      await tester.tap(find.byKey(const Key('rigor_preset_card_studioRecording')));
      await tester.pumpAndSettle();
      expect(viewModel.acousticRigorProfile.preset, equals(AcousticRigorPreset.studioRecording));

      // Conmutar a Modo Avanzado
      await tester.tap(find.byKey(const Key('mic_tab_advanced_controls')));
      await tester.pumpAndSettle();

      expect(viewModel.acousticRigorProfile.isAdvancedMode, isTrue);
      expect(find.byKey(const Key('advanced_clarity_slider')), findsOneWidget);
      expect(find.byKey(const Key('advanced_cents_slider')), findsOneWidget);
      expect(find.byKey(const Key('advanced_noise_gate_slider')), findsOneWidget);
    });
  });
}
