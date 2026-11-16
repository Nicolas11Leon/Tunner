import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/atoms/studio_rotary_knob.dart';
import 'package:tunner/core/design_system/atoms/studio_stereo_vu_meter.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_studio_workstation_view.dart';
import 'package:tunner/features/dj_console/presentation/dj_track_loader_modal.dart';
import 'package:tunner/features/dj_console/presentation/dj_vertical_channel_strip.dart';

void main() {
  group('Studio Rotary Knob & Stereo VU Meter Tests', () {
    testWidgets('StudioRotaryKnob renders label, value and updates on vertical drag', (tester) async {
      double value = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return StudioRotaryKnob(
                  label: 'MID',
                  value: value,
                  min: 0.0,
                  max: 1.5,
                  defaultValue: 1.0,
                  onChanged: (newVal) => setState(() => value = newVal),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('MID'), findsOneWidget);
      expect(find.text('0 dB'), findsOneWidget);

      // Drag up to increase value
      await tester.drag(find.byType(StudioRotaryKnob), const Offset(0, -60));
      await tester.pumpAndSettle();

      expect(value, greaterThan(1.0));

      // Double tap resets to default (1.0 = 0 dB)
      await tester.tap(find.byType(StudioRotaryKnob));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(StudioRotaryKnob));
      await tester.pumpAndSettle();

      expect(value, equals(1.0));
      expect(find.text('0 dB'), findsOneWidget);
    });

    testWidgets('StudioStereoVuMeter paints both channels without exceptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudioStereoVuMeter(
              levelLeft: 0.75,
              levelRight: 0.65,
              peakLeft: 0.85,
              peakRight: 0.70,
            ),
          ),
        ),
      );

      expect(find.byType(StudioStereoVuMeter), findsOneWidget);
    });
  });

  group('DjVerticalChannelStrip Tests', () {
    late DjConsoleViewModel vm;

    setUp(() {
      vm = DjConsoleViewModel();
    });

    tearDown(() {
      vm.dispose();
    });

    testWidgets('renders CH A, EQ bands, KILL buttons, CUE monitor and Volume fader', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: 600,
                child: DjVerticalChannelStrip(
                  deckId: 'A',
                  deck: vm.deckA,
                  viewModel: vm,
                  accentColor: const Color(0xFF00E5FF),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CH A'), findsOneWidget);
      expect(find.text('TRIM'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('MID'), findsOneWidget);
      expect(find.text('LOW'), findsOneWidget);
      expect(find.text('FILTER'), findsOneWidget);
      expect(find.text('CUE'), findsOneWidget);
      expect(find.text('KILL'), findsNWidgets(3));

      // Tap Low KILL button
      await tester.tap(find.text('KILL').last);
      await tester.pumpAndSettle();

      expect(vm.deckA.isKillLow, isTrue);
    });
  });

  group('DjTrackLoaderModal Tests', () {
    late DjConsoleViewModel vm;

    setUp(() {
      vm = DjConsoleViewModel();
    });

    tearDown(() {
      vm.dispose();
    });

    Widget createTestWidget(Widget child) {
      return StudioThemeScope(
        controller: StudioThemeController(initialTokens: StudioDesignTokens.studioDark),
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('renders preset library and loads track into Deck A', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        DjTrackLoaderModal(deckId: 'A', viewModel: vm),
      ));
      await tester.pumpAndSettle();

      expect(find.text('BIBLIOTECA DE PISTAS & STEMS DE ESTUDIO'), findsOneWidget);
      expect(find.text('Midnight Cyber Synthwave'), findsOneWidget);
      expect(find.text('Deep Horizon House & Groove'), findsOneWidget);

      // Tap CARGAR EN A
      await tester.tap(find.text('CARGAR EN A').first);
      await tester.pumpAndSettle();

      expect(vm.deckA.trackTitle, equals('Midnight Cyber Synthwave'));
      expect(vm.deckA.bpm, greaterThan(60.0));
    });
  });

  group('DjStudioWorkstationView Full Screen Tests', () {
    testWidgets('renders full DAW workstation layout (Decks, Club Mixer, Stems, Sampler)', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        StudioThemeScope(
          controller: StudioThemeController(initialTokens: StudioDesignTokens.studioDark),
          child: const MaterialApp(
            home: DjStudioWorkstationView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CONSOLA DJ PRO STUDIO'), findsOneWidget);
      expect(find.text('MEZCLADOR DUAL CLUB'), findsOneWidget);
      expect(find.text('DECK A'), findsNWidgets(2)); // header & panel
      expect(find.text('DECK B'), findsNWidgets(2));
      expect(find.text('CROSSFADER'), findsOneWidget);
      expect(find.text('SMART AUTOMIX (BASS-SWAP)'), findsOneWidget);
      expect(find.textContaining('AISLAMIENTO DE 4-STEMS'), findsOneWidget);
      expect(find.text('BANCO DE SAMPLER TÁCTIL (ONE-SHOTS DE CLUB)'), findsOneWidget);
    });
  });
}
