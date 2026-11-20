import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/dj_console/domain/dj_harmonic_camelot_engine.dart';
import 'package:tunner/features/dj_console/domain/dj_performance_orchestrator.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_modal.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_pro_workstation_panel.dart';

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

  group('DjProWorkstation UI Tests', () {
    testWidgets('Toggling Pro Studio opens DjProWorkstationPanel with RGB Waveforms & Controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      expect(find.byType(DjProWorkstationPanel), findsNothing);

      await tester.tap(find.byKey(const Key('toggle_pro_workstation_btn')));
      await tester.pump();

      expect(viewModel.isProWorkstationActive, isTrue);
      expect(find.byType(DjProWorkstationPanel), findsOneWidget);
      expect(find.byKey(const Key('parallel_rgb_waveform_canvas')), findsOneWidget);
      expect(find.byKey(const Key('camelot_compatibility_badge')), findsOneWidget);
    });

    testWidgets('Interacting with 4-Stems, Key-Sync, Auto-Loop, Slip Mode, Sampler & Split-Cue', (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      viewModel.toggleProWorkstation();
      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      // 1. Toggle Vocal Stem on Deck A
      await tester.tap(find.byKey(const Key('deck_A_stem_vocals_btn')));
      await tester.pump();
      expect(viewModel.deckA.stems.isVocalMuted, isTrue);

      // Instant Acapella preset
      await tester.tap(find.byKey(const Key('deck_A_acapella_btn')));
      await tester.pump();
      expect(viewModel.deckA.stems.isVocalMuted, isFalse);
      expect(viewModel.deckA.stems.isBassMuted, isTrue);

      // 2. Harmonic Key Sync on Deck B
      await tester.tap(find.byKey(const Key('deck_B_key_sync_btn')));
      await tester.pump();
      expect(
        viewModel.harmonicCompatibility,
        equals(CamelotCompatibility.perfectUnison),
      );

      // 3. Auto-Loop + Halve + Slip Mode on Deck A
      await tester.tap(find.byKey(const Key('deck_A_loop_toggle_btn')));
      await tester.pump();
      expect(viewModel.deckA.isLoopActive, isTrue);

      await tester.tap(find.byKey(const Key('deck_A_loop_halve_btn')));
      await tester.pump();
      expect(viewModel.deckA.loopBeats, equals(2.0));

      await tester.tap(find.byKey(const Key('deck_A_slip_btn')));
      await tester.pump();
      expect(viewModel.deckA.isSlipModeActive, isTrue);

      // 4. Trigger Sampler Pad & Split-Cue
      await tester.tap(find.byKey(const Key('sampler_pad_whiteNoiseRiser')));
      await tester.pump();
      expect(viewModel.sampler.triggerSequence, equals(1));
      expect(viewModel.lastSamplerBuffer, isNotNull);

      await tester.tap(find.byKey(const Key('split_cue_mono_chip')));
      await tester.pump();
      expect(viewModel.cueMonitor.isSplitCueActive, isTrue);

      // 5. Smart Automix
      await tester.tap(find.byKey(const Key('smart_automix_btn')));
      await tester.pump();
      expect(viewModel.automix.isActive, isTrue);

      viewModel.cancelSmartAutomix();
      if (viewModel.deckA.isPlaying) viewModel.togglePlay('A');
      if (viewModel.deckB.isPlaying) viewModel.togglePlay('B');
      await tester.pump();
      expect(viewModel.automix.isActive, isFalse);
    });
  });
}
