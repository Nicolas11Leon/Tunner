import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/harmonic_tutor/domain/harmonic_role_entity.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_tutor_view_model.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/vocal_autotune/presentation/vocal_autotune_modal.dart';

class _FakePitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}

  @override
  Future<void> stopRecording() async {}
}

class _FakeMetroService implements IMetronomeService {
  @override
  Function(int currentSubTick)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-UX-18: 12 Tónicas Cromáticas, Comparador 12-TET vs. JI y AutoTune A/B Bypass', () {
    testWidgets(
      'Prueba 1: HarmonicTutorModal expone las 12 tónicas cromáticas y despliega tutor_12tet_vs_ji_comparison_card con batimientos y dron activo',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        int dronePlayCount = 0;
        final tutorVm = HarmonicTutorViewModel(
          onPlayDroneSamples: (_, _) => dronePlayCount++,
        );
        addTearDown(tutorVm.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HarmonicTutorModal(
                viewModel: tutorVm,
                palette: TunnerThemePalette.obsidianStudio,
              ),
            ),
          ),
        );
        await tester.pump();

        const expectedRoots = <String, double>{
          'Do (C4)': 261.63,
          'Do# (C#4)': 277.18,
          'Re (D4)': 293.66,
          'Re# (Eb4)': 311.13,
          'Mi (E4)': 329.63,
          'Fa (F4)': 349.23,
          'Fa# (F#4)': 369.99,
          'Sol (G3)': 196.00,
          'Sol# (Ab3)': 207.65,
          'La (A3)': 220.00,
          'La# (Bb3)': 233.08,
          'Si (B3)': 246.94,
        };

        for (final rootName in expectedRoots.keys) {
          expect(find.text(rootName), findsOneWidget);
        }

        // Seleccionar alteraciones cromáticas clave
        await tester.tap(find.text('Do# (C#4)'));
        await tester.pump();
        expect(tutorVm.session.rootNoteName, 'Do# (C#4)');
        expect(tutorVm.session.rootFrequency, closeTo(277.18, 0.01));

        await tester.tap(find.text('Fa# (F#4)'));
        await tester.pump();
        expect(tutorVm.session.rootNoteName, 'Fa# (F#4)');
        expect(tutorVm.session.rootFrequency, closeTo(369.99, 0.01));

        await tester.tap(find.text('La# (Bb3)'));
        await tester.pump();
        expect(tutorVm.session.rootNoteName, 'La# (Bb3)');
        expect(tutorVm.session.rootFrequency, closeTo(233.08, 0.01));

        // Volver a Do (C4) para validar batimientos conocidos de Tercera Mayor y Quinta Justa
        await tester.tap(find.text('Do (C4)'));
        await tester.pump();

        expect(find.byKey(const Key('tutor_12tet_vs_ji_comparison_card')), findsNothing);
        expect(tutorVm.session.isDroneActive, isFalse);

        final compareBtn = find.byKey(const Key('btn_tutor_compare_12tet_vs_ji'));
        expect(compareBtn, findsOneWidget);

        await tester.tap(compareBtn);
        await tester.pump();

        // Tarjeta comparativa desplegada y dron de referencia disparado
        expect(find.byKey(const Key('tutor_12tet_vs_ji_comparison_card')), findsOneWidget);
        expect(tutorVm.session.isDroneActive, isTrue);
        expect(dronePlayCount, greaterThanOrEqualTo(1));

        // Desglose 12-TET vs JI visible (Tercera Mayor: -13.7 cents, Quinta Justa: +2.0 cents, Δf en Hz / bat/s)
        expect(find.textContaining('12-TET vs. JI'), findsWidgets);
        expect(find.textContaining('-13.7 cents'), findsWidgets);
        expect(find.textContaining('+2.0 cents'), findsWidgets);
        expect(find.textContaining('bat/s'), findsOneWidget);

        // Cambiar a Séptima Dominante muestra también -31.2 cents
        tutorVm.setChordType(HarmonicChordType.dominantSeventh);
        await tester.pump();
        expect(find.textContaining('-31.2 cents'), findsWidgets);

        // Segundo toque oculta la tarjeta comparativa
        await tester.tap(compareBtn);
        await tester.pump();
        expect(find.byKey(const Key('tutor_12tet_vs_ji_comparison_card')), findsNothing);
      },
    );

    testWidgets(
      'Prueba 2: VocalAutoTuneModal resalta preset activo y conmuta A/B Bypass entre ORIGINAL (DRY) y AUTOTUNE (WET)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final viewModel = TunerViewModel(
          seedDefaults: false,
          pitchService: _FakePitchService(),
          metronomeService: _FakeMetroService(),
        );
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider<TunerViewModel>.value(
                value: viewModel,
                child: const VocalAutoTuneModal(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Estado inicial: WET activo (leadVocalMix = 1.0) y preset 'natural' resaltado
        final abToggleFinder = find.byKey(const Key('btn_autotune_ab_bypass_toggle'));
        expect(abToggleFinder, findsOneWidget);
        expect(find.text('A/B: ESCUCHANDO AUTOTUNE (WET)'), findsOneWidget);
        expect(viewModel.autoTuneConfig.leadVocalMix, greaterThan(0.0));

        final naturalChipInitial = tester.widget<ActionChip>(
          find.byKey(const Key('preset_natural_studio')),
        );
        expect(naturalChipInitial.side?.width, 2.0);

        // Conmutar a ORIGINAL (DRY) -> leadVocalMix == 0.0
        await tester.tap(abToggleFinder);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('A/B: ESCUCHANDO ORIGINAL (DRY)'), findsOneWidget);
        expect(viewModel.autoTuneConfig.leadVocalMix, equals(0.0));

        // Conmutar de vuelta a AUTOTUNE (WET) -> leadVocalMix > 0.0 (restaurado a 1.0)
        await tester.tap(abToggleFinder);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('A/B: ESCUCHANDO AUTOTUNE (WET)'), findsOneWidget);
        expect(viewModel.autoTuneConfig.leadVocalMix, closeTo(1.0, 0.001));

        // Seleccionar Vocal Doubler (0.50 mix) actualiza resaltado activo y preserva su mix al salir del bypass A/B
        await tester.tap(find.byKey(const Key('preset_vocal_doubler')));
        await tester.pump(const Duration(milliseconds: 100));

        final doublerChipActive = tester.widget<ActionChip>(
          find.byKey(const Key('preset_vocal_doubler')),
        );
        final naturalChipInactive = tester.widget<ActionChip>(
          find.byKey(const Key('preset_natural_studio')),
        );
        expect(doublerChipActive.side?.width, 2.0);
        expect(naturalChipInactive.side?.width, 1.0);
        expect(viewModel.autoTuneConfig.leadVocalMix, closeTo(0.50, 0.001));

        await tester.tap(abToggleFinder);
        await tester.pump(const Duration(milliseconds: 100));
        expect(viewModel.autoTuneConfig.leadVocalMix, equals(0.0));

        await tester.tap(abToggleFinder);
        await tester.pump(const Duration(milliseconds: 100));
        expect(viewModel.autoTuneConfig.leadVocalMix, closeTo(0.50, 0.001));
      },
    );
  });
}
