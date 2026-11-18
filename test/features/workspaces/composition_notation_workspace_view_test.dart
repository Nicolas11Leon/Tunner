import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/presentation/composition_notation_workspace_view.dart';
import 'package:tunner/features/workspaces/presentation/polyphonic_synth_modal.dart';

void main() {
  group('CompositionNotationWorkspaceView SMuFL & Polyphonic Tests', () {
    late TunerViewModel viewModel;

    setUp(() {
      viewModel = TunerViewModel();
    });

    testWidgets('renders score interactive canvas and polyphonic synth chip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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
      await tester.pump();

      // Check canvas gesture detector
      expect(find.byKey(const Key('score_interactive_canvas_gesture')), findsOneWidget);

      // Check polyphonic synth action chip
      expect(find.byKey(const Key('poly_synth_settings_btn')), findsOneWidget);

      // Tap on canvas to trigger note selection
      await tester.tapAt(const Offset(200, 200));
      await tester.pump();

      // Tap on poly synth settings button opens modal
      await tester.tap(find.byKey(const Key('poly_synth_settings_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(PolyphonicSynthModal), findsOneWidget);
    });
  });
}
