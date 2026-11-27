import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/design_system/atoms/studio_rotary_knob.dart';
import 'package:tunner/core/design_system/studio_design_tokens.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/features/modular_rack/domain/rack_module_entity.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';
import 'package:tunner/features/modular_rack/presentation/rack_unit_card.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-UX-15: Live Rack Units (DJ/StemMixer) & Tokenized StudioRotaryKnob', () {
    late ModularRackViewModel rackViewModel;
    late TunerViewModel tunerViewModel;

    setUp(() {
      rackViewModel = ModularRackViewModel();
      tunerViewModel = TunerViewModel(seedDefaults: false);
    });

    tearDown(() {
      if (tunerViewModel.isMetronomePlaying) {
        tunerViewModel.stopSong();
      }
      rackViewModel.dispose();
      tunerViewModel.dispose();
    });

    Widget createRackCardHarness(RackModuleEntity module) {
      return ChangeNotifierProvider<TunerViewModel>.value(
        value: tunerViewModel,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RackUnitCard(
                module: module,
                viewModel: rackViewModel,
                index: 0,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'Prueba 1: RackUnitCard con RackModuleType.djConsole renderiza panel vivo y +2 BPM incrementa viewModel.bpm en +2',
      (tester) async {
        final module = RackModuleEntity.standard(RackModuleType.djConsole, 0);
        final initialBpm = tunerViewModel.bpm;

        await tester.pumpWidget(createRackCardHarness(module));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('rack_unit_dj_console_live_panel')), findsOneWidget);
        expect(
          find.text(
            'SYNC TEMPO: $initialBpm BPM • A4: ${tunerViewModel.referencePitch.toStringAsFixed(1)} Hz',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('rack_dj_nudge_minus_btn')), findsOneWidget);
        expect(find.byKey(const Key('rack_dj_nudge_plus_btn')), findsOneWidget);
        expect(find.byKey(const Key('rack_dj_open_modal_btn')), findsOneWidget);

        await tester.tap(find.byKey(const Key('rack_dj_nudge_plus_btn')));
        await tester.pumpAndSettle();

        expect(tunerViewModel.bpm, equals(initialBpm + 2));
        expect(
          find.text(
            'SYNC TEMPO: ${initialBpm + 2} BPM • A4: ${tunerViewModel.referencePitch.toStringAsFixed(1)} Hz',
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('rack_dj_nudge_minus_btn')));
        await tester.pumpAndSettle();

        expect(tunerViewModel.bpm, equals(initialBpm));
      },
    );

    testWidgets(
      'Prueba 2: RackUnitCard con RackModuleType.stemMixer renderiza panel vivo, chips de mute y Minus-One activa viewModel.isMinusOneActive',
      (tester) async {
        final module = RackModuleEntity.standard(RackModuleType.stemMixer, 0);
        final mixer = tunerViewModel.mixerConsole;
        final expectedTracks = [mixer.metronomeTrack, ...mixer.stems];

        await tester.pumpWidget(createRackCardHarness(module));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('rack_unit_stem_mixer_live_panel')), findsOneWidget);
        for (final track in expectedTracks) {
          expect(find.byKey(Key('rack_stem_mute_${track.id}')), findsOneWidget);
        }
        expect(find.byKey(const Key('rack_stem_minus_one_btn')), findsOneWidget);
        expect(find.byKey(const Key('rack_stem_open_mixer_modal_btn')), findsOneWidget);

        // Verificar toggle mute de un canal específico
        final targetTrack = expectedTracks.first;
        final initialMuted = targetTrack.isMuted;
        await tester.tap(find.byKey(Key('rack_stem_mute_${targetTrack.id}')));
        await tester.pumpAndSettle();
        final updatedTracks = [
          tunerViewModel.mixerConsole.metronomeTrack,
          ...tunerViewModel.mixerConsole.stems,
        ];
        final updatedTarget = updatedTracks.firstWhere((t) => t.id == targetTrack.id);
        expect(updatedTarget.isMuted, equals(!initialMuted));

        // Verificar activación de Minus-One
        expect(tunerViewModel.isMinusOneActive, isFalse);
        await tester.tap(find.byKey(const Key('rack_stem_minus_one_btn')));
        await tester.pumpAndSettle();
        expect(tunerViewModel.isMinusOneActive, isTrue);
      },
    );

    testWidgets(
      'Prueba 3: StudioRotaryKnob dentro de StudioThemeScope con skin_conservatory_ivory usa tokens oscuros textPrimary/textSecondary',
      (tester) async {
        final controller = StudioThemeController();
        controller.selectById('skin_conservatory_ivory');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          StudioThemeScope(
            controller: controller,
            child: MaterialApp(
              home: Scaffold(
                body: StudioRotaryKnob(
                  label: 'GAIN',
                  value: 1.0,
                  min: 0.0,
                  max: 1.5,
                  defaultValue: 1.0,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final labelText = tester.widget<Text>(find.text('GAIN'));
        final valueText = tester.widget<Text>(find.text('0 dB'));

        expect(
          labelText.style?.color,
          equals(StudioDesignTokens.conservatoryIvory.textSecondary),
        );
        expect(
          valueText.style?.color,
          equals(StudioDesignTokens.conservatoryIvory.textPrimary),
        );
        expect(labelText.style?.color, isNot(equals(Colors.white70)));
        expect(valueText.style?.color, isNot(equals(Colors.white)));
        expect(valueText.style?.color, isNot(equals(Colors.white38)));
      },
    );
  });
}
