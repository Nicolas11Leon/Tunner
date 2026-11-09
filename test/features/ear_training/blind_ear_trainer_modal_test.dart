import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/ear_training/presentation/blind_ear_trainer_modal.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/persistence/domain/i_local_persistence_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('BlindEarTrainerModal Widget Tests', () {
    testWidgets('Renders header, metrics, stimulus box, and 4 interval options with shortcuts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlindEarTrainerModal(viewModel: viewModel),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));

      // Header y subtítulo
      expect(find.text('ENTRENADOR A CIEGAS'), findsOneWidget);
      expect(find.text('Discriminación de Intervalos sin Apoyo Visual'), findsOneWidget);

      // Estadísticas
      expect(find.text('RACHA'), findsOneWidget);
      expect(find.text('PUNTAJE'), findsOneWidget);
      expect(find.text('PRECISIÓN'), findsOneWidget);

      // Estímulo acústico y botón de reproducción
      expect(find.byKey(const Key('ear_trainer_stimulus_box')), findsOneWidget);
      expect(find.byKey(const Key('btn_replay_stimulus')), findsOneWidget);

      // Por defecto en Modo a Ciegas
      expect(find.text('Modo a Ciegas'), findsOneWidget);
      expect(find.text('🔒 PANTALLA A CIEGAS: CONFÍA EN TU PERCEPCIÓN AUDITIVA'), findsOneWidget);

      // 4 opciones de intervalos
      expect(find.byKey(const Key('btn_interval_option_0')), findsOneWidget);
      expect(find.byKey(const Key('btn_interval_option_1')), findsOneWidget);
      expect(find.byKey(const Key('btn_interval_option_2')), findsOneWidget);
      expect(find.byKey(const Key('btn_interval_option_3')), findsOneWidget);

      // Badges numéricos [1]..[4]
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('Toggles Blind Mode to reveal base note details', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlindEarTrainerModal(viewModel: viewModel),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));

      final toggleBtn = find.byKey(const Key('btn_toggle_blind_mode'));
      expect(toggleBtn, findsOneWidget);

      // Conmutar a modo visible
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      expect(find.text('Modo Visible'), findsOneWidget);
      expect(find.textContaining('Nota Base:'), findsOneWidget);
    });

    testWidgets('Submitting answer shows evaluation banner and next question button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlindEarTrainerModal(viewModel: viewModel),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));

      // Pulsar la primera opción
      final option0 = find.byKey(const Key('btn_interval_option_0'));
      await tester.tap(option0);
      await tester.pumpAndSettle();

      // Debe aparecer el banner de resultado y el botón siguiente
      expect(find.byKey(const Key('ear_trainer_result_banner')), findsOneWidget);
      final nextBtn = find.byKey(const Key('btn_next_question'));
      expect(nextBtn, findsOneWidget);

      // Pulsar botón siguiente para avanzar al nuevo ejercicio
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pump(const Duration(milliseconds: 1500));

      // El banner de resultado se oculta para la nueva pregunta
      expect(find.byKey(const Key('ear_trainer_result_banner')), findsNothing);
    });
  });
}
