import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/modular_rack/presentation/modular_studio_rack_view.dart';
import 'package:tunner/features/modular_rack/presentation/studio_smart_controls_macro_bar.dart';

void main() {
  group('US-UX-09: StudioSmartControlsMacroBar (Logic Pro Smart Controls)', () {
    testWidgets(
      'Prueba 1: ModularStudioRackView renderiza StudioSmartControlsMacroBar por defecto con las 6 macro-perillas',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: ModularStudioRackView(),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('studio_smart_controls_macro_bar')),
          findsOneWidget,
        );
        expect(find.byType(StudioSmartControlsMacroBar), findsOneWidget);
        expect(
          find.text('SMART CONTROLS · LOGIC PRO MACRO RACK'),
          findsOneWidget,
        );

        expect(find.byKey(const Key('smart_knob_a4_pitch')), findsOneWidget);
        expect(
          find.byKey(const Key('smart_knob_master_tempo')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('smart_knob_noise_gate')), findsOneWidget);
        expect(find.byKey(const Key('smart_knob_drone_mix')), findsOneWidget);
        expect(
          find.byKey(const Key('smart_knob_retune_speed')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('smart_knob_room_reverb')), findsOneWidget);
      },
    );

    testWidgets(
      'Prueba 2: Seleccionar preset Barroco 415 Hz actualiza A4 PITCH a 415 Hz y reset restaura 440 Hz',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: ModularStudioRackView(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('440 Hz'), findsOneWidget);

        final baroquePreset = find.byKey(
          const Key('smart_preset_baroque_ensemble'),
        );
        expect(baroquePreset, findsOneWidget);
        await tester.tap(baroquePreset);
        await tester.pumpAndSettle();

        expect(find.text('415 Hz'), findsOneWidget);

        final resetBtn = find.byKey(
          const Key('smart_controls_reset_defaults_btn'),
        );
        expect(resetBtn, findsOneWidget);
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        expect(find.text('440 Hz'), findsOneWidget);
      },
    );

    testWidgets(
      'Prueba 3: El botón btn_toggle_smart_controls_bar colapsa y vuelve a desplegar la barra de Smart Controls',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: ModularStudioRackView(),
          ),
        );
        await tester.pumpAndSettle();

        final toggleBtn = find.byKey(
          const Key('btn_toggle_smart_controls_bar'),
        );
        expect(toggleBtn, findsOneWidget);
        expect(
          find.byKey(const Key('studio_smart_controls_macro_bar')),
          findsOneWidget,
        );

        // Colapsar Smart Controls
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('studio_smart_controls_macro_bar')),
          findsNothing,
        );

        // Desplegar Smart Controls nuevamente
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('studio_smart_controls_macro_bar')),
          findsOneWidget,
        );
      },
    );
  });
}
