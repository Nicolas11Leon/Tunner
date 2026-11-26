import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/ear_training/domain/ear_training_exercise.dart';
import 'package:tunner/features/ear_training/domain/musical_interval.dart';
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
      seedDefaults: false,
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

  group('US-HC-07: BlindEarTrainerModal + Ebbinghaus Adaptive Bridge', () {
    testWidgets(
      'Muestra toggle adaptativo activo por defecto, badge con intervalos fallados y prioriza el intervalo débil',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Registrar fallo explícito en Tritono antes de abrir el modal
        final wrongTritoneResult = EarTrainingAnswerResult.evaluate(
          selected: MusicalInterval.perfectFifth,
          target: MusicalInterval.tritone,
          centsDeviation: 100.0,
          responseTimeMs: 2500,
          currentStreak: 0,
          hasAcousticCents: false,
        );
        viewModel.recordEarTrainingAnswer(
          MusicalInterval.tritone,
          wrongTritoneResult,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BlindEarTrainerModal(viewModel: viewModel),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1500));

        // 1. Chip adaptativo presente y activo por defecto
        final toggleFinder = find.byKey(const Key('toggle_ebbinghaus_adaptive_mode'));
        expect(toggleFinder, findsOneWidget);
        final chip = tester.widget<FilterChip>(toggleFinder);
        expect(chip.selected, isTrue);
        expect(find.text('Priorizar Intervalos Débiles (Ebbinghaus)'), findsOneWidget);
        expect(find.text('Modo Adaptativo'), findsOneWidget);

        // 2. Badge refleja el intervalo fallado en primer lugar
        final badgeFinder = find.byKey(const Key('ebbinghaus_due_intervals_badge'));
        expect(badgeFinder, findsOneWidget);
        expect(
          find.descendant(
            of: badgeFinder,
            matching: find.textContaining('Intervalos por reforzar:'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: badgeFinder,
            matching: find.textContaining('Tritono'),
          ),
          findsOneWidget,
        );

        // 3. La pregunta generada en modo adaptativo prioriza el intervalo débil (Tritono)
        final tritoneOption = find.text('TT');
        expect(tritoneOption, findsOneWidget);
        await tester.tap(tritoneOption);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('ear_trainer_result_banner')), findsOneWidget);
        expect(find.text('¡CORRECTO!'), findsOneWidget);
      },
    );

    testWidgets(
      'Al pulsar toggle_ebbinghaus_adaptive_mode alterna entre modo adaptativo Ebbinghaus y modo aleatorio libre',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1100);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Marcar todos los intervalos como recién acertados para verificar también estado "Al día"
        final now = DateTime.now();
        for (final item in viewModel.ebbinghausEngine.allItems) {
          viewModel.ebbinghausEngine.submitAnswer(
            item.id,
            isCorrect: true,
            centsError: 1.0,
            responseTimeSeconds: 1.0,
            timestamp: now,
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BlindEarTrainerModal(viewModel: viewModel),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1500));

        expect(
          find.descendant(
            of: find.byKey(const Key('ebbinghaus_due_intervals_badge')),
            matching: find.text('Intervalos por reforzar: Al día'),
          ),
          findsOneWidget,
        );

        final toggleFinder = find.byKey(const Key('toggle_ebbinghaus_adaptive_mode'));
        expect(tester.widget<FilterChip>(toggleFinder).selected, isTrue);
        expect(find.text('Modo Adaptativo'), findsOneWidget);

        // Alternar a modo aleatorio libre
        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();

        expect(tester.widget<FilterChip>(toggleFinder).selected, isFalse);
        expect(find.text('Modo Aleatorio Libre'), findsOneWidget);

        // Volver a modo adaptativo Ebbinghaus
        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();

        expect(tester.widget<FilterChip>(toggleFinder).selected, isTrue);
        expect(find.text('Modo Adaptativo'), findsOneWidget);
      },
    );
  });
}
