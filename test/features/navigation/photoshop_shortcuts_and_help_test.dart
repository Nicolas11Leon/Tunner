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
import 'package:tunner/features/navigation/presentation/contextual_help_sheet.dart';
import 'package:tunner/features/navigation/presentation/keyboard_shortcuts_modal.dart';
import 'package:tunner/core/theme/tunner_theme.dart';

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

  group('Photoshop-Grade Shortcuts & Contextual Help Tests', () {
    testWidgets('ContextualHelpBadge opens ContextualHelpSheet with technical and pedagogical content', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ContextualHelpBadge(
                toolId: 'strobe_tuner',
                palette: TunnerThemePalette.obsidianStudio,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ContextualHelpBadge), findsOneWidget);
      expect(find.byKey(const Key('help_badge_strobe_tuner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('help_badge_strobe_tuner')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ContextualHelpSheet), findsOneWidget);
      expect(find.text('Afinador Estroboscópico de Ultra Precisión'), findsOneWidget);
      expect(find.text('Consejo Pedagógico:'), findsOneWidget);
      expect(find.text('ATAJOS RÁPIDOS DE TECLADO:'), findsOneWidget);
    });

    testWidgets('ToolHelpCatalog provides valid data for core tools', (tester) async {
      final tunerHelp = ToolHelpCatalog.getItem('strobe_tuner');
      expect(tunerHelp.title, contains('Estroboscópico'));
      expect(tunerHelp.shortcutKeys, contains('A'));

      final metroHelp = ToolHelpCatalog.getItem('metronome');
      expect(metroHelp.title, contains('Metrónomo'));
      expect(metroHelp.shortcutKeys, contains('M'));

      final fallback = ToolHelpCatalog.getItem('unknown_tool');
      expect(fallback.title, equals('Herramienta de Estudio'));
    });

    testWidgets('Increment and decrement BPM shortcuts work smoothly', (tester) async {
      final initialBpm = viewModel.bpm;

      viewModel.incrementBpm(1);
      expect(viewModel.bpm, equals(initialBpm + 1));

      viewModel.decrementBpm(1);
      expect(viewModel.bpm, equals(initialBpm));

      viewModel.incrementBpm(5);
      expect(viewModel.bpm, equals(initialBpm + 5));

      viewModel.decrementBpm(5);
      expect(viewModel.bpm, equals(initialBpm));
    });

    testWidgets('CheatSheet modal renders all Photoshop-grade shortcut categories', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => KeyboardShortcutsCheatSheetModal.show(
                  context: ctx,
                  palette: TunnerThemePalette.obsidianStudio,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(KeyboardShortcutsCheatSheetModal), findsOneWidget);
      expect(find.text('Matriz de Atajos de Grado Profesional'), findsOneWidget);
      expect(find.text('HERRAMIENTAS DIRECTAS (SINGLE-KEY)'), findsOneWidget);
      expect(find.text('TRANSPORTE, TEMPO Y GRABACIÓN'), findsOneWidget);
    });
  });
}
