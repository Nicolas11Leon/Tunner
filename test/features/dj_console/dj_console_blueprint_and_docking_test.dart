import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/docking/domain/studio_dock_layout_entity.dart';
import 'package:tunner/core/docking/domain/studio_dock_zone.dart';
import 'package:tunner/core/docking/presentation/studio_dockable_panel_entity.dart';
import 'package:tunner/core/docking/presentation/studio_dock_drop_zone_target.dart';
import 'package:tunner/core/docking/presentation/studio_workspace_docking_container.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/dj_console/data/dj_console_blueprint_storage_service.dart';
import 'package:tunner/features/dj_console/data/dj_console_file_codec.dart';
import 'package:tunner/features/dj_console/data/dj_hardware_catalog.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_console_blueprint_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_skin_zone_entity.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_model_builder_modal.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_studio_workstation_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DjConsoleBlueprintEntity & FileCodec Tests', () {
    test('Encodes and decodes blueprint preserving format and all attributes', () {
      const zone = DjSkinZoneEntity(
        id: 'bp_jog_a',
        label: 'JOG A',
        controlType: DjControlType.jogWheel,
        action: DjAction.deckANudgeForward,
        normalizedX: 0.1,
        normalizedY: 0.2,
        normalizedWidth: 0.3,
        normalizedHeight: 0.4,
      );

      final blueprint = DjConsoleBlueprintEntity(
        id: 'test_console_blueprint',
        name: 'Super Controller 2000',
        manufacturer: 'Acme Audio',
        zones: const [zone],
        keyBindings: const {'Key W': DjAction.deckAPlayPause},
      );

      const codec = DjConsoleFileCodec();
      final jsonStr = codec.encodeToJsonString(blueprint);
      expect(jsonStr, contains('tunner.djconsole'));
      expect(jsonStr, contains('Super Controller 2000'));

      final decoded = codec.decodeFromJsonString(jsonStr);
      expect(decoded.id, 'test_console_blueprint');
      expect(decoded.name, 'Super Controller 2000');
      expect(decoded.zones.length, 1);
      expect(decoded.zones.first.label, 'JOG A');
      expect(decoded.keyBindings['Key W'], DjAction.deckAPlayPause);

      // Verify conversion to hardware skin and keymap profile
      final skin = decoded.toHardwareSkin();
      expect(skin.name, 'Super Controller 2000');
      expect(skin.zones.length, 1);

      final keymap = decoded.toKeymapProfile();
      expect(keymap.keyBindings['Key W'], DjAction.deckAPlayPause);
    });

    test('Encodes to bytes and decodes back accurately', () {
      final blueprint = DjConsoleBlueprintEntity(
        id: 'bytes_test',
        name: 'Bytes Console',
        manufacturer: 'Acme',
        zones: const [],
      );

      const codec = DjConsoleFileCodec();
      final bytes = codec.encodeToBytes(blueprint);
      final decoded = codec.decodeFromBytes(bytes);

      expect(decoded.id, 'bytes_test');
      expect(decoded.name, 'Bytes Console');
    });
  });

  group('DjConsoleBlueprintStorageService Tests', () {
    test('Saves blueprint, registers dynamically in DjHardwareCatalog, and deletes', () async {
      final storage = DjConsoleBlueprintStorageService();
      final blueprint = DjConsoleBlueprintEntity(
        id: 'custom_storage_test',
        name: 'Hercules Inpulse Emulated',
        manufacturer: 'Hercules',
        zones: const [],
      );

      await storage.saveBlueprint(blueprint);
      expect(storage.currentBlueprints.length, 1);

      // Verify registered in DjHardwareCatalog
      final found = DjHardwareCatalog.findById('custom_storage_test');
      expect(found.name, 'Hercules Inpulse Emulated');

      // Verify deletion
      await storage.deleteBlueprint('custom_storage_test');
      expect(storage.currentBlueprints.isEmpty, isTrue);
    });
  });

  group('StudioDockLayoutEntity Tests', () {
    test('movePanel moves panel between zones and clears from origin', () {
      final layout = StudioDockLayoutEntity.defaultLayout(
        centerPanelIds: ['panel_a', 'panel_b'],
        rightPanelIds: ['panel_c'],
      );

      expect(layout.findZoneOfPanel('panel_b'), StudioDockZone.center);

      final updated = layout.movePanel('panel_b', StudioDockZone.bottom);
      expect(updated.findZoneOfPanel('panel_b'), StudioDockZone.bottom);
      expect(updated.zonePanelIds[StudioDockZone.center], equals(['panel_a']));
      expect(updated.zonePanelIds[StudioDockZone.bottom], equals(['panel_b']));
    });

    test('updateRatio clamps ratios within safe boundaries', () {
      final layout = StudioDockLayoutEntity.defaultLayout();
      final updated = layout.updateRatio(left: 0.95, right: 0.05);

      expect(updated.leftSplitRatio, 0.60); // Clamped max
      expect(updated.rightSplitRatio, 0.15); // Clamped min
    });
  });

  group('StudioWorkspaceDockingContainer UI Tests', () {
    testWidgets('Renders multi-panel split view and allows moving panel', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final panels = [
        StudioDockablePanelEntity(
          id: 'panel_main',
          title: 'Panel Principal',
          icon: Icons.album,
          currentZone: StudioDockZone.center,
          builder: (ctx) => const Center(child: Text('CONTENIDO PRINCIPAL')),
        ),
        StudioDockablePanelEntity(
          id: 'panel_side',
          title: 'Panel Lateral',
          icon: Icons.tune,
          currentZone: StudioDockZone.right,
          builder: (ctx) => const Center(child: Text('CONTENIDO LATERAL')),
        ),
      ];

      final layout = StudioDockLayoutEntity(
        zonePanelIds: {
          StudioDockZone.center: ['panel_main'],
          StudioDockZone.right: ['panel_side'],
          StudioDockZone.left: [],
          StudioDockZone.bottom: [],
          StudioDockZone.floating: [],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioWorkspaceDockingContainer(
              panels: panels,
              initialLayout: layout,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Panel Principal'), findsOneWidget);
      expect(find.text('CONTENIDO PRINCIPAL'), findsOneWidget);
      expect(find.text('Panel Lateral'), findsOneWidget);
      expect(find.text('CONTENIDO LATERAL'), findsOneWidget);

      // Verify presence of DropZoneTarget
      expect(find.byType(StudioDockDropZoneTarget), findsNWidgets(2));

      // Verify Layout Presets Bar
      expect(find.text('DISPOSICIÓN DAW:'), findsOneWidget);
      expect(find.text('Club Clásico'), findsOneWidget);
      expect(find.text('Consola Fiel'), findsOneWidget);
      expect(find.text('Estudio Stems'), findsOneWidget);
      expect(find.text('3 Columnas'), findsOneWidget);

      // Tap preset 3 Columnas
      await tester.tap(find.text('3 Columnas'));
      await tester.pumpAndSettle();

      // Double-tap header to toggle maximize
      final headerTitle = find.text('Panel Principal').last;
      await tester.tap(headerTitle);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(headerTitle);
      await tester.pumpAndSettle();
    });
  });

  group('DjConsoleViewModel Tactile LED Synchronization Tests', () {
    test('activeLitActions synchronizes Play, Cue momentary pulse, Sync, and Hot Cues', () async {
      final vm = DjConsoleViewModel();

      // Initially no playback
      expect(vm.activeLitActions.contains(DjAction.deckAPlayPause), isFalse);

      // Play Deck A -> LED lights up
      vm.togglePlay('A');
      expect(vm.deckA.isPlaying, isTrue);
      expect(vm.activeLitActions.contains(DjAction.deckAPlayPause), isTrue);

      // Trigger Cue -> momentary pulse lights up Cue action
      vm.triggerCue('A');
      expect(vm.momentaryLitAction, DjAction.deckACue);
      expect(vm.activeLitActions.contains(DjAction.deckACue), isTrue);

      // Sync Deck A -> lights up Sync
      vm.syncBpm('A');
      expect(vm.deckA.isSyncActive, isTrue);
      expect(vm.activeLitActions.contains(DjAction.deckASync), isTrue);

      // Trigger Hot Cue 1 -> lights up hot cue action
      vm.triggerHotCue('A', 0);
      expect(vm.activeLitActions.contains(DjAction.deckAHotCue1), isTrue);

      vm.dispose();
    });
  });

  group('DjConsoleModelBuilderModal UI Tests', () {
    testWidgets('Renders console builder, adds controls, and saves console', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final vm = DjConsoleViewModel();
      final storage = DjConsoleBlueprintStorageService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DjConsoleModelBuilderModal(
              viewModel: vm,
              palette: TunnerThemePalette.obsidianStudio,
              storageService: storage,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Constructor y Emulador Universal de Consolas DJ'), findsOneWidget);
      expect(find.text('Mi Consola Emulada'), findsOneWidget);

      // Add a Pitch Fader control
      final addFaderBtn = find.text('Fader Pitch A');
      expect(addFaderBtn, findsOneWidget);
      await tester.tap(addFaderBtn);
      await tester.pumpAndSettle();

      expect(find.text('8 controles configurados'), findsOneWidget);

      // Scroll down list to find newly added control
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.textContaining('TEMPO A (FADER)'), findsOneWidget);

      // Tap Save and Emulate
      final saveBtn = find.byKey(const Key('save_and_emulate_btn'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(storage.currentBlueprints.length, 1);
      expect(storage.currentBlueprints.first.name, 'Mi Consola Emulada');

      vm.dispose();
    });
  });

  group('DjStudioWorkstationView Docking Mode Tests', () {
    testWidgets('Switches to Docking DAW mode and opens console builder', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final vm = DjConsoleViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: DjStudioWorkstationView(
            viewModel: vm,
            initialViewMode: 'modular',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check presence of new buttons
      final dockingBtn = find.text('Docking DAW (Arrastrar)');
      expect(dockingBtn, findsOneWidget);
      await tester.ensureVisible(dockingBtn);
      await tester.tap(dockingBtn);
      await tester.pumpAndSettle();

      // Verify StudioWorkspaceDockingContainer is rendered
      expect(find.byType(StudioWorkspaceDockingContainer), findsOneWidget);

      // Tap EMULAR CONSOLA (+) to open builder dialog
      final builderBtn = find.byKey(const Key('open_console_builder_btn'));
      expect(builderBtn, findsOneWidget);
      await tester.ensureVisible(builderBtn);
      await tester.tap(builderBtn);
      await tester.pumpAndSettle();

      expect(find.text('Constructor y Emulador Universal de Consolas DJ'), findsOneWidget);

      vm.dispose();
    });
  });
}
