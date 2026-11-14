import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_performance_orchestrator.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_modal.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_visual_mapping_overlay.dart';

Widget createTestApp(DjConsoleViewModel viewModel) {
  return MaterialApp(
    home: Scaffold(
      body: DjConsoleModal(
        viewModel: viewModel,
        palette: TunnerThemePalette.obsidianStudio,
      ),
    ),
  );
}

void main() {
  late DjConsoleViewModel viewModel;
  late DjPerformanceOrchestrator orchestrator;

  setUp(() {
    orchestrator = DjPerformanceOrchestrator();
    viewModel = DjConsoleViewModel(orchestrator: orchestrator);
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('DjHardwareConsoleUI Tests', () {
    testWidgets('Toggling hardware view switches between Modular and Hardware overlay', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      // Initially hardware view is OFF
      expect(viewModel.isHardwareViewActive, isFalse);
      expect(find.byType(DjVisualMappingOverlay), findsNothing);

      // Tap toggle hardware view button
      await tester.tap(find.byKey(const Key('toggle_hardware_view_btn')));
      await tester.pump();

      expect(viewModel.isHardwareViewActive, isTrue);
      expect(find.byType(DjVisualMappingOverlay), findsOneWidget);
      expect(find.byKey(const Key('gamepad_chip_Xbox_A')), findsOneWidget);
    });

    testWidgets('Switching skins via dropdown updates active skin in ViewModel', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Start with hardware view active
      viewModel.toggleHardwareView();

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      expect(viewModel.activeSkin.id, equals('pioneer_ddj_flx4'));

      // Change skin directly via ViewModel
      viewModel.selectSkin('pioneer_cdj_3000');
      await tester.pump();

      expect(viewModel.activeSkin.id, equals('pioneer_cdj_3000'));
      expect(viewModel.activeSkin.name, contains('CDJ-3000'));

      viewModel.selectSkin('traktor_kontrol_s4');
      await tester.pump();

      expect(viewModel.activeSkin.id, equals('traktor_kontrol_s4'));
      expect(viewModel.activeSkin.name, contains('Traktor'));
    });

    testWidgets('Tapping Xbox Gamepad simulator chips triggers DJ actions', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      viewModel.toggleHardwareView();

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      // Tap Xbox_A -> Deck A Play
      expect(viewModel.deckA.isPlaying, isFalse);
      await tester.tap(find.byKey(const Key('gamepad_chip_Xbox_A')));
      await tester.pump();
      expect(viewModel.deckA.isPlaying, isTrue);

      // Tap Xbox_B -> Deck B Play
      expect(viewModel.deckB.isPlaying, isFalse);
      await tester.tap(find.byKey(const Key('gamepad_chip_Xbox_B')));
      await tester.pump();
      expect(viewModel.deckB.isPlaying, isTrue);

      // Scroll horizontal simulator bar to ensure Xbox_LS is visible
      await tester.ensureVisible(find.byKey(const Key('gamepad_chip_Xbox_LS')));
      await tester.pumpAndSettle();

      // Tap Xbox_LS -> Crossfader hard left
      await tester.tap(find.byKey(const Key('gamepad_chip_Xbox_LS')));
      await tester.pump();
      expect(viewModel.crossfader.position, closeTo(-1.0, 1e-4));

      // Scroll and Tap Xbox_RS -> Crossfader hard right
      await tester.ensureVisible(find.byKey(const Key('gamepad_chip_Xbox_RS')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gamepad_chip_Xbox_RS')));
      await tester.pump();
      expect(viewModel.crossfader.position, closeTo(1.0, 1e-4));

      // Scroll and Tap Xbox_Select -> Crossfader center
      await tester.ensureVisible(find.byKey(const Key('gamepad_chip_Xbox_Select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gamepad_chip_Xbox_Select')));
      await tester.pump();
      expect(viewModel.crossfader.position, closeTo(0.0, 1e-4));
    });

    testWidgets('Toggling Learn Mode updates mode banner and allows zone selection', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      viewModel.toggleHardwareView();

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      expect(viewModel.isLearnModeActive, isFalse);

      // Tap Learn Mode button in overlay
      await tester.tap(find.byKey(const Key('toggle_learn_mode_btn')));
      await tester.pump();

      expect(viewModel.isLearnModeActive, isTrue);
      expect(find.textContaining('MODO MAPEO'), findsOneWidget);

      // Select a zone for mapping
      final playZone = viewModel.activeSkin.findZonesByAction(DjAction.deckAPlayPause).first;
      viewModel.selectZoneForMapping(playZone);
      await tester.pump();

      expect(viewModel.selectedZoneForMapping?.id, equals(playZone.id));
      expect(find.textContaining('ASIGNANDO'), findsOneWidget);

      // Exit learn mode
      await tester.tap(find.byKey(const Key('toggle_learn_mode_btn')));
      await tester.pump();

      expect(viewModel.isLearnModeActive, isFalse);
      expect(viewModel.selectedZoneForMapping, isNull);
    });
  });
}
