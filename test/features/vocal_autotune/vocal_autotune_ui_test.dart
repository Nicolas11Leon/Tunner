import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';
import 'package:tunner/features/vocal_autotune/domain/autotune_config_entity.dart';
import 'package:tunner/features/vocal_autotune/presentation/vocal_autotune_modal.dart';
import 'package:tunner/features/workspaces/presentation/production_acoustic_lab_workspace_view.dart';
import 'package:tunner/features/workspaces/presentation/learning_practice_workspace_view.dart';

class _FakePitchService implements IPitchDetectorService {
  @override
  Function(double pitchHz)? onPitchDetected;
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

class _FakeMetroService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;
  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vocal AutoTune Presentation & UI Tests', () {
    late TunerViewModel viewModel;
    late _FakePitchService fakePitchService;
    late _FakeMetroService fakeMetroService;

    setUp(() {
      fakePitchService = _FakePitchService();
      fakeMetroService = _FakeMetroService();

      viewModel = TunerViewModel(
        pitchService: fakePitchService,
        metronomeService: fakeMetroService,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    Widget createTestApp(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<TunerViewModel>.value(
            value: viewModel,
            child: child,
          ),
        ),
      );
    }

    testWidgets('Renders VocalAutoTuneModal elements correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const VocalAutoTuneModal()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('vocal_autotune_modal')), findsOneWidget);
      expect(find.text('Vocal AutoTune & Corrección Tonal'), findsOneWidget);
      expect(find.byKey(const Key('autotune_master_toggle')), findsOneWidget);
      expect(find.byKey(const Key('preset_natural_studio')), findsOneWidget);
      expect(find.byKey(const Key('preset_hard_tune')), findsOneWidget);
      expect(find.byKey(const Key('retune_speed_slider')), findsOneWidget);
      expect(find.byKey(const Key('correction_amount_slider')), findsOneWidget);
    });

    testWidgets('Tapping master switch toggles isAutoTuneActive', (tester) async {
      await tester.pumpWidget(createTestApp(const VocalAutoTuneModal()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.isAutoTuneActive, isFalse);

      await tester.tap(find.byKey(const Key('autotune_master_toggle')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.isAutoTuneActive, isTrue);
      expect(find.text('MONITOR DE AFINACIÓN VOCAL EN VIVO'), findsOneWidget);

      await tester.tap(find.byKey(const Key('autotune_master_toggle')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.isAutoTuneActive, isFalse);
    });

    testWidgets('Tapping Hard Tune preset activates 0 ms retune speed', (tester) async {
      await tester.pumpWidget(createTestApp(const VocalAutoTuneModal()));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('preset_hard_tune')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.autoTuneConfig.isEnabled, isTrue);
      expect(viewModel.autoTuneConfig.retuneSpeedMs, equals(0.0));
      expect(viewModel.autoTuneConfig.correctionAmount, equals(1.0));
    });

    testWidgets('Tapping scale root chip updates scaleRoot to Re (D)', (tester) async {
      await tester.pumpWidget(createTestApp(const VocalAutoTuneModal()));
      await tester.pump(const Duration(milliseconds: 100));

      // Chip index 2 is Re (D)
      await tester.tap(find.byKey(const Key('autotune_root_chip_2')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.autoTuneConfig.scaleRoot, equals(2));
      expect(viewModel.autoTuneConfig.rootNoteDisplayName, contains('Re'));
    });

    testWidgets('Post-production: Afinar button creates an autotuned take', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Add a dummy take with pitch samples to the multitrack session
      final take = PracticeTakeEntity(
        id: 'take_vocal_lead_01',
        name: 'Toma Voz Principal',
        timestamp: DateTime.now(),
        duration: const Duration(seconds: 5),
        filePath: '/tmp/take1.wav',
        pitchTrack: const [
          TimedPitchSample(timeMs: 0, frequencyHz: 445.0, centsDeviation: 19.5, targetNoteName: 'La4'),
        ],
      );

      viewModel.addPracticeTake(take);
      viewModel.updateAutoTuneConfig(const AutoTuneConfigEntity(isEnabled: true));

      await tester.pumpWidget(createTestApp(const VocalAutoTuneModal()));
      await tester.pump(const Duration(milliseconds: 100));

      final initialTakeCount = viewModel.multiTrackSession.takes.length;

      // Tap on the Afinar button for this take
      final afinarBtn = find.byKey(Key('autotune_take_btn_${take.id}'));
      expect(afinarBtn, findsOneWidget);

      await tester.tap(afinarBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.multiTrackSession.takes.length, equals(initialTakeCount + 1));
      final tunedTake = viewModel.multiTrackSession.takes.last;
      expect(tunedTake.name, contains('AutoTuned'));
    });

    testWidgets('ProductionAcousticLabWorkspaceView contains lab_vocal_autotune_card and opens modal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<TunerViewModel>.value(
              value: viewModel,
              child: SingleChildScrollView(
                child: ProductionAcousticLabWorkspaceView(
                  viewModel: viewModel,
                  palette: TunnerThemePalette.obsidianStudio,
                  onOpenMixerModal: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final cardFinder = find.byKey(const Key('lab_vocal_autotune_card'));
      expect(cardFinder, findsOneWidget);

      await tester.tap(cardFinder);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('vocal_autotune_modal')), findsOneWidget);
    });

    testWidgets('LearningPracticeWorkspaceView contains open_vocal_autotune_chip and opens modal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<TunerViewModel>.value(
              value: viewModel,
              child: SingleChildScrollView(
                child: LearningPracticeWorkspaceView(
                  viewModel: viewModel,
                  palette: TunnerThemePalette.obsidianStudio,
                  onOpenInstrumentModal: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final chipFinder = find.byKey(const Key('open_vocal_autotune_chip'));
      expect(chipFinder, findsOneWidget);

      await tester.tap(chipFinder);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('vocal_autotune_modal')), findsOneWidget);
    });
  });
}
