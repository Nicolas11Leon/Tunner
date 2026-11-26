import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/design_system/atoms/studio_rotary_knob.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';
import 'package:tunner/features/modular_rack/presentation/modular_studio_rack_view.dart';
import 'package:tunner/features/modular_rack/presentation/studio_smart_controls_macro_bar.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

void main() {
  group(
    'US-HC-02: Enlace Bidireccional en Tiempo Real de las 6 Macro-Perillas de StudioSmartControlsMacroBar',
    () {
      testWidgets(
        'Prueba 1 (Flujo TunerViewModel -> SmartControls): Mutaciones externas en TunerViewModel actualizan reactivamente las macro-perillas',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1200, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final tunerVm = TunerViewModel();
          final rackVm = ModularRackViewModel(tunerViewModel: tunerVm);
          addTearDown(() {
            rackVm.dispose();
            tunerVm.dispose();
          });

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<TunerViewModel>.value(value: tunerVm),
                ChangeNotifierProvider<ModularRackViewModel>.value(
                  value: rackVm,
                ),
              ],
              child: const MaterialApp(
                home: Scaffold(
                  body: StudioSmartControlsMacroBar(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Estado inicial sincronizado con TunerViewModel (440 Hz)
          expect(find.text('440 Hz'), findsOneWidget);

          // Invocacion externa de setReferencePitch(442.0) y updateBpm(140)
          tunerVm.setReferencePitch(442.0);
          tunerVm.updateBpm(140);
          await tester.pump();

          final a4Knob = tester.widget<StudioRotaryKnob>(
            find.byKey(const Key('smart_knob_a4_pitch')),
          );
          final tempoKnob = tester.widget<StudioRotaryKnob>(
            find.byKey(const Key('smart_knob_master_tempo')),
          );

          expect(a4Knob.value, closeTo(442.0, 0.01));
          expect(tempoKnob.value, closeTo(140.0, 0.01));
          expect(find.text('442 Hz'), findsOneWidget);
          expect(find.text('140 BPM'), findsOneWidget);

          // Invocacion externa de setDroneConfig y updateAutoTuneConfig
          await tunerVm.setDroneConfig(
            tunerVm.droneConfig.copyWith(volume: 0.85),
          );
          tunerVm.updateAutoTuneConfig(
            tunerVm.autoTuneConfig.copyWith(retuneSpeedMs: 12.0),
          );
          await tester.pump();

          final droneKnob = tester.widget<StudioRotaryKnob>(
            find.byKey(const Key('smart_knob_drone_mix')),
          );
          final retuneKnob = tester.widget<StudioRotaryKnob>(
            find.byKey(const Key('smart_knob_retune_speed')),
          );

          expect(droneKnob.value, closeTo(85.0, 0.01));
          expect(retuneKnob.value, closeTo(12.0, 0.01));
          expect(find.text('85%'), findsOneWidget);
          expect(find.text('12 ms'), findsOneWidget);
        },
      );

      testWidgets(
        'Prueba 2 (Flujo SmartControls -> TunerViewModel & ModularRackViewModel): Presets, perillas y reset actualizan motores DSP reales',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1200, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final tunerVm = TunerViewModel();
          final rackVm = ModularRackViewModel(tunerViewModel: tunerVm);
          addTearDown(() {
            rackVm.dispose();
            tunerVm.dispose();
          });

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<TunerViewModel>.value(value: tunerVm),
                ChangeNotifierProvider<ModularRackViewModel>.value(
                  value: rackVm,
                ),
              ],
              child: MaterialApp(
                home: ModularStudioRackView(viewModel: rackVm),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Aplicar preset Barroco 415 Hz
          final baroquePreset = find.byKey(
            const Key('smart_preset_baroque_ensemble'),
          );
          expect(baroquePreset, findsOneWidget);
          await tester.tap(baroquePreset);
          await tester.pumpAndSettle();

          expect(tunerVm.referencePitch, closeTo(415.0, 0.01));
          expect(rackVm.customization.referencePitchA4, closeTo(415.0, 0.01));
          expect(rackVm.lastReferenceA4Hz, closeTo(415.0, 0.01));

          // Gate -45 dB -> 10^(-45/20) ≈ 0.005623
          final expectedBaroqueGate = math.pow(10.0, -45.0 / 20.0).toDouble();
          expect(
            tunerVm.micProfile.noiseGateThreshold,
            closeTo(expectedBaroqueGate, 0.0005),
          );
          expect(tunerVm.droneConfig.volume, closeTo(0.80, 0.01));
          expect(tunerVm.autoTuneConfig.retuneSpeedMs, closeTo(15.0, 0.01));
          expect(rackVm.customization.resonanceFactor, closeTo(0.30, 0.01));

          // 2. Ajustar perillas individuales directamente
          tester
              .widget<StudioRotaryKnob>(
                find.byKey(const Key('smart_knob_noise_gate')),
              )
              .onChanged(-30.0);
          tester
              .widget<StudioRotaryKnob>(
                find.byKey(const Key('smart_knob_drone_mix')),
              )
              .onChanged(64.0);
          tester
              .widget<StudioRotaryKnob>(
                find.byKey(const Key('smart_knob_retune_speed')),
              )
              .onChanged(40.0);
          tester
              .widget<StudioRotaryKnob>(
                find.byKey(const Key('smart_knob_room_reverb')),
              )
              .onChanged(75.0);
          await tester.pump();

          final expected30DbGate = math.pow(10.0, -30.0 / 20.0).toDouble();
          expect(
            tunerVm.micProfile.noiseGateThreshold,
            closeTo(expected30DbGate, 0.0005),
          );
          expect(tunerVm.droneConfig.volume, closeTo(0.64, 0.01));
          expect(tunerVm.autoTuneConfig.retuneSpeedMs, closeTo(40.0, 0.01));
          expect(rackVm.customization.resonanceFactor, closeTo(0.75, 0.01));

          // 3. Reset restaura todos los valores por defecto en TunerViewModel y ModularRackViewModel
          final resetBtn = find.byKey(
            const Key('smart_controls_reset_defaults_btn'),
          );
          await tester.tap(resetBtn);
          await tester.pumpAndSettle();

          final expectedDefaultGate = math.pow(10.0, -42.0 / 20.0).toDouble();
          expect(tunerVm.referencePitch, closeTo(440.0, 0.01));
          expect(tunerVm.bpm, equals(120));
          expect(
            tunerVm.micProfile.noiseGateThreshold,
            closeTo(expectedDefaultGate, 0.0005),
          );
          expect(tunerVm.droneConfig.volume, closeTo(0.50, 0.01));
          expect(tunerVm.autoTuneConfig.retuneSpeedMs, closeTo(25.0, 0.01));
          expect(rackVm.customization.referencePitchA4, closeTo(440.0, 0.01));
          expect(rackVm.customization.resonanceFactor, closeTo(0.18, 0.01));
        },
      );
    },
  );
}
