import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/presentation/composition_notation_workspace_view.dart';

void main() {
  group('US-UX-07: Dorico Task Modes, A-B Measure Loop Bar & Quick Popover', () {
    Widget buildHost(TunerViewModel viewModel) {
      return StudioThemeScope(
        controller: StudioThemeController(),
        child: MaterialApp(
          home: Scaffold(
            body: CompositionNotationWorkspaceView(
              viewModel: viewModel,
              palette: TunnerThemePalette.obsidianStudio,
              onOpenLibraryModal: () {},
              onOpenMixerModal: () {},
            ),
          ),
        ),
      );
    }

    testWidgets(
      'Dorico workflow task mode selector switches between Todo, Write, Mix, and Practice modes',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final viewModel = TunerViewModel();
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(buildHost(viewModel));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('dorico_score_task_mode_selector')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('direct_canvas_edit_toolbar')),
          findsOneWidget,
        );

        // Switch to Mix mode -> hides direct note drawing toolbar to save vertical space
        await tester.tap(find.byKey(const Key('dorico_mode_mix_chip')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('direct_canvas_edit_toolbar')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('inline_stems_minus_one_bar')),
          findsOneWidget,
        );

        // Switch to Practice mode -> shows A-B loop bar and hides direct note drawing toolbar
        await tester.tap(find.byKey(const Key('dorico_mode_practice_chip')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('direct_canvas_edit_toolbar')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('score_ab_measure_loop_bar')),
          findsOneWidget,
        );

        // Switch back to Write mode -> restores direct note drawing toolbar
        await tester.tap(find.byKey(const Key('dorico_mode_write_chip')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('direct_canvas_edit_toolbar')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'A-B Measure Loop controls set loop points A and B and clear loop on demand',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final viewModel = TunerViewModel();
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(buildHost(viewModel));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dorico_mode_practice_chip')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('chip_ab_loop_status')), findsNothing);

        await tester.tap(find.byKey(const Key('btn_set_loop_point_a')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_set_loop_point_b')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('chip_ab_loop_status')), findsOneWidget);
        expect(find.textContaining('LOOP A-B: Compás 1 - 1'), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn_clear_ab_loop')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('chip_ab_loop_status')), findsNothing);
      },
    );

    testWidgets(
      'Dorico Quick Command Popover opens and applies BPM change directly',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final viewModel = TunerViewModel();
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(buildHost(viewModel));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('dorico_quick_command_popover')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('btn_open_dorico_quick_popover')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('dorico_quick_command_popover')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('dorico_popover_input_field')),
          '144',
        );
        await tester.tap(find.byKey(const Key('dorico_popover_apply_btn')));
        await tester.pumpAndSettle();

        expect(viewModel.bpm, 144);
        expect(
          find.byKey(const Key('dorico_quick_command_popover')),
          findsNothing,
        );
      },
    );
  });
}
