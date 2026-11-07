import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/persistence/domain/i_local_persistence_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/navigation/presentation/main_app_shell.dart';
import 'package:tunner/features/navigation/presentation/quick_action_dock_widget.dart';
import 'package:tunner/features/navigation/presentation/pro_command_palette_modal.dart';
import 'package:tunner/features/navigation/presentation/keyboard_shortcuts_modal.dart';

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

Widget createTestApp({required TunerViewModel viewModel, int initialIndex = 0}) {
  return MaterialApp(
    home: ChangeNotifierProvider<TunerViewModel>.value(
      value: viewModel,
      child: MainAppShell(initialIndex: initialIndex),
    ),
  );
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

  group('Quick Action Dock & Pro Shortcuts UI Tests', () {
    testWidgets('Renders QuickActionDockWidget with play, rec, tap and spotlight buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      await tester.pumpWidget(createTestApp(viewModel: viewModel));
      await tester.pump();

      expect(find.byType(QuickActionDockWidget), findsOneWidget);
      expect(find.byKey(const Key('quick_dock_play_btn')), findsOneWidget);
      expect(find.byKey(const Key('quick_dock_rec_btn')), findsOneWidget);
      expect(find.byKey(const Key('quick_dock_tap_btn')), findsOneWidget);
      expect(find.byKey(const Key('quick_dock_command_palette_btn')), findsOneWidget);
      expect(find.byKey(const Key('quick_dock_shortcuts_btn')), findsOneWidget);
    });

    testWidgets('Tapping play button in dock toggles metronome state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      await tester.pumpWidget(createTestApp(viewModel: viewModel));
      await tester.pump();

      expect(viewModel.isMetronomeActive, isFalse);

      await tester.tap(find.byKey(const Key('quick_dock_play_btn')));
      await tester.pump();

      expect(viewModel.isMetronomeActive, isTrue);

      await tester.tap(find.byKey(const Key('quick_dock_play_btn')));
      await tester.pump();

      expect(viewModel.isMetronomeActive, isFalse);
    });

    testWidgets('Tapping tap tempo button in dock calculates new BPM', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      await tester.pumpWidget(createTestApp(viewModel: viewModel));
      await tester.pump();

      await tester.tap(find.byKey(const Key('quick_dock_tap_btn')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('quick_dock_tap_btn')));
      await tester.pump();

      expect(viewModel.bpm, greaterThan(0));
    });

    testWidgets('Collapsing dock displays expand mini-FAB and restores dock on tap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      await tester.pumpWidget(createTestApp(viewModel: viewModel));
      await tester.pump();

      expect(find.byKey(const Key('quick_dock_collapse_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick_dock_collapse_btn')));
      await tester.pump();

      expect(find.byKey(const Key('quick_dock_collapse_btn')), findsNothing);
      expect(find.byKey(const Key('quick_dock_expand_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick_dock_expand_btn')));
      await tester.pump();

      expect(find.byKey(const Key('quick_dock_play_btn')), findsOneWidget);
    });

    testWidgets('Tapping command palette button opens ProCommandPaletteModal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      await tester.pumpWidget(createTestApp(viewModel: viewModel));
      await tester.pump();

      await tester.tap(find.byKey(const Key('quick_dock_command_palette_btn')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ProCommandPaletteModal), findsOneWidget);
      expect(find.byKey(const Key('command_palette_search_input')), findsOneWidget);

      // Filtrar comandos
      await tester.enterText(find.byKey(const Key('command_palette_search_input')), 'Afinador');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('command_item_tab_tuner')), findsOneWidget);
    });

    testWidgets('Tapping keyboard shortcuts button opens KeyboardShortcutsCheatSheetModal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      await tester.pumpWidget(createTestApp(viewModel: viewModel));
      await tester.pump();

      await tester.tap(find.byKey(const Key('quick_dock_shortcuts_btn')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(KeyboardShortcutsCheatSheetModal), findsOneWidget);
      expect(find.text('Atajos de Teclado y Gestos Rápidos'), findsOneWidget);
    });
  });
}
