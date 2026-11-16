import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/dj_console/data/dj_hardware_catalog.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_keymap_profile_entity.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_interactive_keymap_visualizer_modal.dart';
import 'package:tunner/features/dj_console/presentation/dj_studio_workstation_view.dart';
import 'package:tunner/features/dj_console/presentation/dj_vertical_channel_strip.dart';
import 'package:tunner/features/dj_console/presentation/dj_visual_mapping_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DjHardwareCatalog Industrial Models Tests', () {
    test('Catalog contains all 5 authentic DJ hardware console skins', () {
      final skins = DjHardwareCatalog.allSkins();
      expect(skins.length, 5);

      final ids = skins.map((s) => s.id).toList();
      expect(ids, contains('pioneer_ddj_flx4'));
      expect(ids, contains('pioneer_cdj_3000'));
      expect(ids, contains('traktor_kontrol_s4'));
      expect(ids, contains('denon_prime_4'));
      expect(ids, contains('numark_mixtrack_pro_fx'));
    });

    test('Denon DJ Prime 4+ has 4-channel layout and touchscreen zone', () {
      final denon = DjHardwareCatalog.denonPrime4();
      expect(denon.name, contains('Prime 4+'));
      expect(denon.zones.any((z) => z.label.contains('10.1" HD TOUCHSCREEN')), isTrue);
      expect(denon.zones.any((z) => z.label.contains('SWEEP FX')), isTrue);
      expect(denon.zones.any((z) => z.label.contains('FLEX X-FADER')), isTrue);
    });

    test('Numark Mixtrack Pro FX has dual FX paddles and 100mm pitch sliders', () {
      final mixtrack = DjHardwareCatalog.mixtrackProFx();
      expect(mixtrack.name, contains('Mixtrack Pro FX'));
      expect(mixtrack.zones.any((z) => z.label.contains('PADDLE FX A')), isTrue);
      expect(mixtrack.zones.any((z) => z.label.contains('TEMPO 100mm')), isTrue);
    });

    test('findById returns matching skin and defaults safely to ddjFlx4', () {
      final found = DjHardwareCatalog.findById('denon_prime_4');
      expect(found.id, 'denon_prime_4');

      final fallback = DjHardwareCatalog.findById('unknown_nonexistent_model');
      expect(fallback.id, 'pioneer_ddj_flx4');
    });
  });

  group('DjKeymapProfileEntity Industry Standards & Normalization Tests', () {
    test('Standard factory profiles are available', () {
      final presets = DjKeymapProfileEntity.factoryProfiles();
      expect(presets.length, greaterThanOrEqualTo(4));

      final names = presets.map((p) => p.name).toList();
      expect(names, contains('Default Ergonomico (QWERTY)'));
      expect(names, contains('VirtualDJ Estándar'));
      expect(names, contains('Serato DJ Pro Estándar'));
      expect(names, contains('Traktor Pro 3 Estándar'));
    });

    test('cleanKeyLabel standardizes labels accurately', () {
      expect(DjKeymapProfileEntity.cleanKeyLabel('Key W'), 'W');
      expect(DjKeymapProfileEntity.cleanKeyLabel('Digit 1'), '1');
      expect(DjKeymapProfileEntity.cleanKeyLabel('Space'), 'SPACE');
      expect(DjKeymapProfileEntity.cleanKeyLabel(' '), 'SPACE');
      expect(DjKeymapProfileEntity.cleanKeyLabel('Enter'), 'ENTER');
      expect(DjKeymapProfileEntity.cleanKeyLabel('Bracket Left'), '[');
    });

    test('resolveAction resolves key variants robustly', () {
      final profile = DjKeymapProfileEntity.defaultErgonomic();

      // Should resolve 'Key W', 'w', and 'W' to deckAPlayPause
      expect(profile.resolveAction('Key W'), DjAction.deckAPlayPause);
      expect(profile.resolveAction('W'), DjAction.deckAPlayPause);
      expect(profile.resolveAction('w'), DjAction.deckAPlayPause);

      // Should resolve 'Digit 1' and '1' to deckAHotCue1
      expect(profile.resolveAction('Digit 1'), DjAction.deckAHotCue1);
      expect(profile.resolveAction('1'), DjAction.deckAHotCue1);
    });

    test('findKeyBadgeForAction returns primary clean key label', () {
      final profile = DjKeymapProfileEntity.defaultErgonomic();
      final badgePlay = profile.findKeyBadgeForAction(DjAction.deckAPlayPause);
      expect(badgePlay, 'W');

      final badgeCue = profile.findKeyBadgeForAction(DjAction.deckACue);
      expect(badgeCue, 'Q');
    });

    test('bindKey and unbindKey modify bindings immutably', () {
      final profile = DjKeymapProfileEntity.defaultErgonomic();
      final updated = profile.bindKey('Key T', DjAction.deckAToggleDelay);

      expect(updated.resolveAction('T'), DjAction.deckAToggleDelay);
      expect(profile.resolveAction('T'), isNull); // Original remains unchanged

      final removed = updated.unbindKey('Key T');
      expect(removed.resolveAction('T'), isNull);
    });
  });

  group('DjInteractiveKeymapVisualizerModal UI Tests', () {
    testWidgets('Renders QWERTY keyboard keys and switches presets', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final vm = DjConsoleViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DjInteractiveKeymapVisualizerModal(
              viewModel: vm,
              palette: TunnerThemePalette.obsidianStudio,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and key presence
      expect(find.text('Configurador Interactivo de Teclado QWERTY'), findsOneWidget);
      expect(find.byKey(const Key('key_Key W')), findsOneWidget);
      expect(find.byKey(const Key('key_Space')), findsOneWidget);

      // Tap VirtualDJ preset
      final vdjBtn = find.byKey(const Key('preset_virtualdj_standard'));
      expect(vdjBtn, findsOneWidget);
      await tester.ensureVisible(vdjBtn);
      await tester.tap(vdjBtn);
      await tester.pumpAndSettle();

      expect(vm.keymapProfile.id, 'virtualdj_standard');

      // Tap key W and assign action
      await tester.tap(find.byKey(const Key('key_Key W')));
      await tester.pumpAndSettle();

      expect(find.text('TECLA [Key W]'), findsOneWidget);

      vm.dispose();
    });
  });

  group('DjStudioWorkstationView Hardware Console & Global Keyboard Tests', () {
    testWidgets('Renders Split view by default and switches to Consola Hardware and Modular DAW', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final vm = DjConsoleViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: DjStudioWorkstationView(
            viewModel: vm,
            initialViewMode: 'split',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title & presence of Split Híbrido segmented button
      expect(find.text('CONSOLA DJ PRO STUDIO'), findsOneWidget);
      expect(find.text('Split Híbrido'), findsOneWidget);
      expect(find.text('Consola Hardware'), findsOneWidget);
      expect(find.text('Modular DAW'), findsOneWidget);

      // Verify that DjVisualMappingOverlay is present in Split mode
      expect(find.byType(DjVisualMappingOverlay), findsOneWidget);

      // Switch to 'Consola Hardware' mode
      await tester.tap(find.text('Consola Hardware'));
      await tester.pumpAndSettle();
      expect(find.byType(DjVisualMappingOverlay), findsOneWidget);

      // Switch to 'Modular DAW' mode
      await tester.tap(find.text('Modular DAW'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(DjVerticalChannelStrip), matching: find.text('CH A')), findsOneWidget);
      expect(find.descendant(of: find.byType(DjVerticalChannelStrip), matching: find.text('CH B')), findsOneWidget);

      vm.dispose();
    });

    testWidgets('Physical keyboard event via ViewModel toggles Play on Deck A', (tester) async {
      final vm = DjConsoleViewModel();

      expect(vm.deckA.isPlaying, isFalse);

      // Simulate pressing key 'W' (which is mapped to deckAPlayPause in defaultErgonomic)
      final handled = vm.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyW,
          logicalKey: LogicalKeyboardKey.keyW,
          timeStamp: Duration.zero,
        ),
      );

      expect(handled, isTrue);
      expect(vm.deckA.isPlaying, isTrue);

      // Press again to pause
      vm.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyW,
          logicalKey: LogicalKeyboardKey.keyW,
          timeStamp: Duration.zero,
        ),
      );
      expect(vm.deckA.isPlaying, isFalse);

      vm.dispose();
    });
  });
}
