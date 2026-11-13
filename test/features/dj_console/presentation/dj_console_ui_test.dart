import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/dj_console/domain/dj_performance_orchestrator.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_modal.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/vector_jog_wheel.dart';

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

  group('DjConsoleModal UI Tests', () {
    testWidgets('Renders Deck A, Deck B, jog wheels and crossfader controls', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      expect(find.text('Consola de DJ Virtual'), findsOneWidget);
      expect(find.text('DECK A'), findsWidgets);
      expect(find.text('DECK B'), findsWidgets);
      expect(find.byType(VectorJogWheel), findsNWidgets(2));
      expect(find.byKey(const Key('crossfader_slider')), findsOneWidget);
      expect(find.byKey(const Key('deck_A_play_btn')), findsOneWidget);
      expect(find.byKey(const Key('deck_B_play_btn')), findsOneWidget);
    });

    testWidgets('Tapping Play button on Deck A toggles playback state and changes button label', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      expect(viewModel.deckA.isPlaying, isFalse);
      expect(find.text('PLAY'), findsNWidgets(2)); // Deck A and Deck B

      final playBtnA = find.byKey(const Key('deck_A_play_btn'));
      await tester.tap(playBtnA);
      await tester.pump();

      expect(viewModel.deckA.isPlaying, isTrue);
      expect(find.text('PAUSE'), findsOneWidget);
    });

    testWidgets('Tapping crossfader buttons updates position accurately', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      // Tap hard right
      final rightBtn = find.byKey(const Key('xfader_hard_right_btn'));
      await tester.tap(rightBtn);
      await tester.pump();
      expect(viewModel.crossfader.position, closeTo(1.0, 0.001));

      // Tap hard left
      final leftBtn = find.byKey(const Key('xfader_hard_left_btn'));
      await tester.tap(leftBtn);
      await tester.pump();
      expect(viewModel.crossfader.position, closeTo(-1.0, 0.001));

      // Tap center
      final centerBtn = find.byKey(const Key('xfader_center_btn'));
      await tester.tap(centerBtn);
      await tester.pump();
      expect(viewModel.crossfader.position, closeTo(0.0, 0.001));
    });

    testWidgets('Tapping Sync button matches tempo to opposite deck', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      final syncBtnA = find.byKey(const Key('deck_A_sync_btn'));
      await tester.tap(syncBtnA);
      await tester.pump();

      expect(viewModel.deckA.isSyncActive, isTrue);
      expect(viewModel.deckA.effectiveBpm, closeTo(viewModel.deckB.effectiveBpm, 0.001));
    });

    testWidgets('Tapping open_keymap_editor_btn opens DjKeymapEditorModal with category filters', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      final keymapBtn = find.byKey(const Key('open_keymap_editor_btn'));
      await tester.tap(keymapBtn);
      await tester.pumpAndSettle();

      expect(find.text('Mapeo Universal de Teclado QWERTY'), findsOneWidget);
      expect(find.text('Deck A: Play / Pausa'), findsOneWidget);
      expect(find.byKey(const Key('reset_keymap_btn')), findsOneWidget);

      // Tap reset
      await tester.tap(find.byKey(const Key('reset_keymap_btn')));
      await tester.pump();
    });
  });
}
