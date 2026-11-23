import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/channels/domain/studio_channel_bus.dart';
import 'package:tunner/core/channels/data/studio_patchbay_routing_service.dart';
import 'package:tunner/core/channels/presentation/studio_channel_modals.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_template_catalog.dart';
import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';
import 'package:tunner/core/terminal/presentation/studio_dsl_terminal_panel_widget.dart';
import 'package:tunner/core/terminal/presentation/tunner_os_terminal_drawer.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/navigation/presentation/main_app_shell.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/persistence/domain/i_local_persistence_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/domain/workspace_type.dart';
import 'package:tunner/features/workspaces/presentation/workspace_switch_bar.dart';

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

  group('US-9.2 - StudioWorkspaceTabSpec Domain Specification', () {
    test('exposes exactly 6 canonical DAW tabs in order with unique keys', () {
      final tabs = StudioWorkspaceTabSpec.canonicalTabs;
      expect(tabs.length, equals(6));
      expect(
        tabs.map((t) => t.id).toList(),
        equals(['home', 'tuner', 'learning', 'studio', 'library', 'dj']),
      );
      expect(tabs.map((t) => t.index).toList(), equals([0, 1, 2, 3, 4, 5]));
      expect(tabs.map((t) => t.navKey).toSet().length, equals(6));
      expect(tabs.map((t) => t.activeItemId).toSet().length, equals(6));
    });

    test('byIndex and findById resolve deterministically', () {
      expect(StudioWorkspaceTabSpec.byIndex(5).id, equals('dj'));
      expect(StudioWorkspaceTabSpec.byIndex(-1).id, equals('home'));
      expect(StudioWorkspaceTabSpec.byIndex(99).id, equals('home'));

      expect(StudioWorkspaceTabSpec.findById('TUNER')?.index, equals(1));
      expect(StudioWorkspaceTabSpec.findById('library')?.index, equals(4));
      expect(StudioWorkspaceTabSpec.findById('nonexistent'), isNull);
    });

    test('StudioWorkspaceTabBar.defaultTabs mirrors StudioWorkspaceTabSpec', () {
      final tabItems = StudioWorkspaceTabBar.defaultTabs;
      expect(tabItems.length, equals(StudioWorkspaceTabSpec.canonicalTabs.length));
      for (int i = 0; i < tabItems.length; i++) {
        expect(tabItems[i].index, equals(StudioWorkspaceTabSpec.canonicalTabs[i].index));
        expect(tabItems[i].label, equals(StudioWorkspaceTabSpec.canonicalTabs[i].desktopLabel));
        expect(tabItems[i].iconId, equals(StudioWorkspaceTabSpec.canonicalTabs[i].iconId));
      }
    });
  });

  group('US-7.2 & US-9.2 - MainAppShell CLI Theme Sync & Terminal Output', () {
    late TunerViewModel viewModel;
    late StudioThemeController themeController;

    setUp(() {
      viewModel = TunerViewModel(
        pitchService: _FakePitchService(),
        metronomeService: _FakeMetronomeService(),
        recorderService: _FakeRecorderService(),
        playbackService: _FakePlaybackService(),
        persistenceService: _FakePersistenceService(),
      );
      themeController = StudioThemeController(
        initialTokens: StudioDesignTokens.studioOledMonochrome,
      );
    });

    tearDown(() {
      viewModel.dispose();
      themeController.dispose();
    });

    testWidgets(
      'onCommandSubmitted with "theme set studio_light" updates StudioThemeController and displays output in TunnerOsTerminalDrawer',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          StudioThemeScope(
            controller: themeController,
            child: ChangeNotifierProvider<TunerViewModel>.value(
              value: viewModel,
              child: const MaterialApp(
                home: MainAppShell(),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(themeController.tokens.id, equals('studio_oled_monochrome'));
        expect(find.byType(TunnerOsTerminalDrawer), findsNothing);

        final desktopShell = tester.widget<StudioDesktopAppShell>(
          find.byType(StudioDesktopAppShell),
        );
        expect(desktopShell.onCommandSubmitted, isNotNull);

        desktopShell.onCommandSubmitted!('theme set studio_light');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(themeController.tokens.id, equals('studio_light'));
        expect(find.byType(TunnerOsTerminalDrawer), findsOneWidget);
        expect(find.text('theme set studio_light'), findsOneWidget);
        expect(
          find.textContaining("[OK] Tema cambiado a: 'studio_light'"),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'mobile NavigationBar renders all 6 StudioWorkspaceTabSpec destinations with StudioIcon',
      (tester) async {
        tester.view.physicalSize = const Size(800, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          StudioThemeScope(
            controller: themeController,
            child: ChangeNotifierProvider<TunerViewModel>.value(
              value: viewModel,
              child: const MaterialApp(
                home: MainAppShell(),
              ),
            ),
          ),
        );
        await tester.pump();

        for (final spec in StudioWorkspaceTabSpec.canonicalTabs) {
          expect(find.byKey(Key(spec.navKey)), findsOneWidget);
        }
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.byType(StudioIcon),
          ),
          findsNWidgets(6),
        );
      },
    );
  });

  group('US-7.2 - OLED Migration for Terminal DSL, Channels & Workspaces', () {
    testWidgets(
      'StudioDslTerminalPanelWidget exposes TunnerDslTemplateCatalog templates and loads canonical code',
      (tester) async {
        final kernel = TunnerOsKernel();
        final themeController = StudioThemeController(
          initialTokens: StudioDesignTokens.studioOledMonochrome,
        );
        addTearDown(() {
          kernel.dispose();
          themeController.dispose();
        });

        await tester.pumpWidget(
          StudioThemeScope(
            controller: themeController,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 800,
                  height: 600,
                  child: StudioDslTerminalPanelWidget(kernel: kernel),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('dsl_catalog_templates_menu')), findsOneWidget);
        await tester.tap(find.byKey(const Key('dsl_catalog_templates_menu')));
        await tester.pumpAndSettle();

        for (final template in TunnerDslTemplateCatalog.allTemplates) {
          expect(find.byKey(Key('dsl_template_${template.id}')), findsOneWidget);
        }

        await tester.tap(find.byKey(const Key('dsl_template_ambient_chords')));
        await tester.pumpAndSettle();

        expect(find.textContaining('tempo 72;'), findsOneWidget);
        expect(find.byType(StudioIcon), findsWidgets);
      },
    );

    testWidgets(
      'StudioCreateChannelModal and StudioRenameChannelModal use StudioThemeScope and StudioIcon',
      (tester) async {
        final routingService = StudioPatchbayRoutingService();
        final themeController = StudioThemeController(
          initialTokens: StudioDesignTokens.studioLight,
        );
        addTearDown(() {
          routingService.dispose();
          themeController.dispose();
        });

        await tester.pumpWidget(
          StudioThemeScope(
            controller: themeController,
            child: MaterialApp(
              home: Scaffold(
                body: StudioCreateChannelModal(routingService: routingService),
              ),
            ),
          ),
        );
        await tester.pump();

        final createDialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(createDialog.backgroundColor, equals(StudioDesignTokens.studioLight.panelBackground));
        expect(find.byType(StudioIcon), findsWidgets);

        final channel = StudioChannelBus(
          id: 'ch_test',
          name: 'Voz',
          shortCode: 'VZ',
          colorHex: StudioChannelPalette.presetColors.first,
        );
        await tester.pumpWidget(
          StudioThemeScope(
            controller: themeController,
            child: MaterialApp(
              home: Scaffold(
                body: StudioRenameChannelModal(
                  routingService: routingService,
                  channel: channel,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final renameDialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(renameDialog.backgroundColor, equals(StudioDesignTokens.studioLight.panelBackground));
        expect(find.byType(StudioIcon), findsWidgets);
      },
    );

    testWidgets(
      'WorkspaceSwitchBar uses StudioThemeScope tokens and StudioIcon',
      (tester) async {
        final themeController = StudioThemeController(
          initialTokens: StudioDesignTokens.studioOledMonochrome,
        );
        addTearDown(themeController.dispose);

        WorkspaceType selected = WorkspaceType.learning;

        await tester.pumpWidget(
          StudioThemeScope(
            controller: themeController,
            child: MaterialApp(
              home: Scaffold(
                body: WorkspaceSwitchBar(
                  activeWorkspace: selected,
                  onWorkspaceSelected: (ws) => selected = ws,
                  palette: TunnerThemePalette.obsidianStudio,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(StudioIcon), findsNWidgets(WorkspaceType.values.length));
        await tester.tap(find.byKey(const Key('workspace_tab_production')));
        await tester.pump();
        expect(selected, equals(WorkspaceType.production));
      },
    );
  });
}
