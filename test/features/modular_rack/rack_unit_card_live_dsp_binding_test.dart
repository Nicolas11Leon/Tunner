import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/features/modular_rack/domain/rack_module_entity.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';
import 'package:tunner/features/modular_rack/presentation/rack_unit_card.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RackUnitCard Live DSP & ViewModel Binding Tests (ADR 0070 & UC 80)', () {
    late ModularRackViewModel rackViewModel;
    late TunerViewModel tunerViewModel;

    setUp(() {
      rackViewModel = ModularRackViewModel();
      tunerViewModel = TunerViewModel();
    });

    tearDown(() {
      if (tunerViewModel.isMetronomePlaying) {
        tunerViewModel.stopSong();
      }
      rackViewModel.dispose();
      tunerViewModel.dispose();
    });

    Widget createTestHarness(RackModuleEntity module) {
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

    testWidgets('Strobe Tuner card reflects live note and deviation from TunerViewModel', (tester) async {
      final module = RackModuleEntity.standard(RackModuleType.strobeTuner, 0);

      await tester.pumpWidget(createTestHarness(module));
      await tester.pumpAndSettle();

      expect(find.text('NOTA ACTIVA'), findsOneWidget);
      expect(find.text('DESVIACIÓN EN CENTS'), findsOneWidget);
      expect(find.text('EN ESPERA DE SEÑAL'), findsOneWidget);
    });

    testWidgets('Metronome card displays live BPM and interactive controls', (tester) async {
      final module = RackModuleEntity.standard(RackModuleType.metronome, 0);

      await tester.pumpWidget(createTestHarness(module));
      await tester.pumpAndSettle();

      expect(find.textContaining('TEMPO: ${tunerViewModel.bpm} BPM'), findsOneWidget);
      expect(find.text('TAP TEMPO'), findsOneWidget);
      expect(find.byTooltip('Iniciar Metrónomo'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('Score notation card displays active score title and action buttons', (tester) async {
      final module = RackModuleEntity.standard(RackModuleType.scoreNotation, 0);

      await tester.pumpWidget(createTestHarness(module));
      await tester.pumpAndSettle();

      expect(find.text(tunerViewModel.activePackage.title), findsOneWidget);
      expect(find.text('NUEVA'), findsOneWidget);
      expect(find.text('IMPORTAR'), findsOneWidget);
      expect(find.byTooltip('Editar en Editor Canónico SMuFL'), findsOneWidget);
    });

    testWidgets('Recorder card displays standby state and action buttons', (tester) async {
      final module = RackModuleEntity.standard(RackModuleType.practiceRecorder, 0);

      await tester.pumpWidget(createTestHarness(module));
      await tester.pumpAndSettle();

      expect(find.text('GRABADOR DE ESTUDIO EN ESPERA'), findsOneWidget);
      expect(find.byTooltip('Iniciar Grabación de Práctica'), findsOneWidget);
      expect(find.byTooltip('Sin grabaciones en sesión'), findsOneWidget);
    });

    testWidgets('AutoTune card displays retune speed, scale, and toggles active state', (tester) async {
      final module = RackModuleEntity.standard(RackModuleType.vocalAutoTune, 0);

      await tester.pumpWidget(createTestHarness(module));
      await tester.pumpAndSettle();

      expect(find.textContaining('VELOCIDAD:'), findsOneWidget);
      expect(find.textContaining('ESCALA:'), findsOneWidget);
      expect(find.text('CONFIGURAR AUTOTUNE'), findsOneWidget);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      final initialActive = tunerViewModel.isAutoTuneActive;
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tunerViewModel.isAutoTuneActive, equals(!initialActive));
    });

    testWidgets('Harmonic Drone card displays fundamental, fifth info and controls', (tester) async {
      final module = RackModuleEntity.standard(RackModuleType.harmonicDrone, 0);

      await tester.pumpWidget(createTestHarness(module));
      await tester.pumpAndSettle();

      expect(find.textContaining('FUNDAMENTAL:'), findsOneWidget);
      expect(find.byTooltip('Activar Tono Pedal'), findsOneWidget);
      expect(find.byTooltip('Configuración Avanzada de Dron'), findsOneWidget);
    });

    testWidgets('Chord Analyzer card toggles live polyphonic recognition', (tester) async {
      final module = RackModuleEntity.standard(RackModuleType.chordAnalyzer, 0);

      await tester.pumpWidget(createTestHarness(module));
      await tester.pumpAndSettle();

      expect(find.textContaining('ACORDE:'), findsOneWidget);
      final toggleBtn = find.byTooltip('Activar Reconocimiento');
      expect(toggleBtn, findsOneWidget);

      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      expect(tunerViewModel.isChordRecognitionActive, isTrue);
    });

    testWidgets('Guided Lessons card renders lesson status and action button', (tester) async {
      final module = RackModuleEntity.standard(RackModuleType.guidedLessons, 0);

      await tester.pumpWidget(createTestHarness(module));
      await tester.pumpAndSettle();

      expect(find.text('SIN LECCIÓN ACTIVA'), findsOneWidget);
      expect(find.text('ELEGIR'), findsOneWidget);
    });

    testWidgets('Ear Trainer card renders training button', (tester) async {
      final module = RackModuleEntity.standard(RackModuleType.earTrainer, 0);

      await tester.pumpWidget(createTestHarness(module));
      await tester.pumpAndSettle();

      expect(find.text('ENTRENAMIENTO A CIEGAS'), findsOneWidget);
      expect(find.text('ENTRENAR'), findsOneWidget);
    });
  });
}
