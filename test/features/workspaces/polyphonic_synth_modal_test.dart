import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/workspaces/presentation/polyphonic_synth_modal.dart';

void main() {
  group('PolyphonicSynthModal Widget Tests', () {
    late TunerViewModel viewModel;

    setUp(() {
      viewModel = TunerViewModel();
    });

    testWidgets('renders all waveform chips, ADSR sliders, and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PolyphonicSynthModal(
              viewModel: viewModel,
              palette: TunnerThemePalette.obsidianStudio,
            ),
          ),
        ),
      );
      await tester.pump();

      // Check header
      expect(find.text('SINTETIZADOR POLIFÓNICO SMuFL'), findsOneWidget);
      expect(find.text('FORMA DE ONDA DEL OSCILADOR'), findsOneWidget);
      expect(find.text('ENVOLVENTE ACÚSTICA ADSR'), findsOneWidget);

      // Check waveform chips
      expect(find.byKey(const Key('synth_waveform_sine')), findsOneWidget);
      expect(find.byKey(const Key('synth_waveform_sawtooth')), findsOneWidget);
      expect(find.byKey(const Key('synth_waveform_pulse')), findsOneWidget);
      expect(find.byKey(const Key('synth_waveform_triangle')), findsOneWidget);

      // Check sliders
      expect(find.byKey(const Key('adsr_attack_slider')), findsOneWidget);
      expect(find.byKey(const Key('adsr_decay_slider')), findsOneWidget);
      expect(find.byKey(const Key('adsr_sustain_slider')), findsOneWidget);
      expect(find.byKey(const Key('adsr_release_slider')), findsOneWidget);
      expect(find.byKey(const Key('synth_master_gain_slider')), findsOneWidget);

      // Check buttons
      expect(find.byKey(const Key('synth_test_chord_btn')), findsOneWidget);
      expect(find.byKey(const Key('synth_panic_btn')), findsOneWidget);
    });

    testWidgets('switching waveform updates pool waveform property', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PolyphonicSynthModal(
              viewModel: viewModel,
              palette: TunnerThemePalette.obsidianStudio,
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap on Sawtooth chip
      await tester.tap(find.byKey(const Key('synth_waveform_sawtooth')));
      await tester.pump();
      expect(viewModel.polyphonicVoicePool.waveform, SynthWaveform.sawtooth);

      // Tap on Sine chip
      await tester.tap(find.byKey(const Key('synth_waveform_sine')));
      await tester.pump();
      expect(viewModel.polyphonicVoicePool.waveform, SynthWaveform.sine);
    });

    testWidgets('tapping test chord triggers active voices and panic silences them', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PolyphonicSynthModal(
              viewModel: viewModel,
              palette: TunnerThemePalette.obsidianStudio,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(viewModel.polyphonicVoicePool.activeVoiceCount, 0);

      // Tap test chord
      await tester.tap(find.byKey(const Key('synth_test_chord_btn')));
      await tester.pump();

      expect(viewModel.polyphonicVoicePool.activeVoiceCount, 3);

      // Tap panic
      await tester.tap(find.byKey(const Key('synth_panic_btn')));
      await tester.pump();

      expect(viewModel.polyphonicVoicePool.activeVoiceCount, 0);

      // Flush remaining chord timer
      await tester.pump(const Duration(milliseconds: 700));
    });
  });
}
