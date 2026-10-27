import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/presentation/concert_pitch_selector_modal.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/persistence/domain/i_local_persistence_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';

class _FakePitchService implements IPitchDetectorService {
  @override
  Function(double)? onPitchDetected;
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
  AppUserSettingsEntity _settings = AppUserSettingsEntity.defaultSettings;

  @override
  Future<AppUserSettingsEntity> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppUserSettingsEntity settings) async {
    _settings = settings;
  }

  @override
  Future<void> clearSettings() async {
    _settings = AppUserSettingsEntity.defaultSettings;
  }
}

void main() {
  group('ConcertPitchSelectorModal Widget Tests', () {
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

    Widget createTestApp() {
      return ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: const MaterialApp(
          home: Scaffold(
            body: ConcertPitchSelectorModal(),
          ),
        ),
      );
    }

    testWidgets('Renders concert pitch calibration title, presets and value', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      expect(find.text('Calibración de Concierto A4'), findsOneWidget);
      expect(find.text('440.0'), findsOneWidget);
      expect(find.text('432 Hz'), findsOneWidget);
      expect(find.text('440 Hz'), findsOneWidget);
      expect(find.text('442 Hz'), findsOneWidget);
      expect(find.text('444 Hz'), findsOneWidget);
    });

    testWidgets('Tapping 442 Hz preset updates referencePitch to 442.0', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      final preset442Finder = find.text('442 Hz');
      expect(preset442Finder, findsOneWidget);

      await tester.tap(preset442Finder);
      await tester.pump();

      expect(viewModel.referencePitch, equals(442.0));
      expect(find.text('442.0'), findsOneWidget);
    });

    testWidgets('Tapping step buttons increments and decrements reference pitch', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      final plusStepFinder = find.text('+0.5');
      expect(plusStepFinder, findsOneWidget);

      await tester.tap(plusStepFinder);
      await tester.pump();

      expect(viewModel.referencePitch, equals(440.5));
      expect(find.text('440.5'), findsOneWidget);

      final minusStepFinder = find.text('-0.5');
      expect(minusStepFinder, findsOneWidget);

      await tester.tap(minusStepFinder);
      await tester.pump();

      expect(viewModel.referencePitch, equals(440.0));
      expect(find.text('440.0'), findsOneWidget);
    });
  });
}
