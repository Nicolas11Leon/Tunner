import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';
import 'package:tunner/features/acoustic_lab/presentation/harmonic_spectrogram_modal.dart';
import 'package:tunner/features/chord_analyzer/presentation/chord_analyzer_modal.dart';
import 'package:tunner/features/drone/presentation/harmonic_drone_modal.dart';
import 'package:tunner/features/ear_training/presentation/blind_ear_trainer_modal.dart';
import 'package:tunner/features/exercise_generator/presentation/exercise_generator_modal.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_tutor_view_model.dart';
import 'package:tunner/features/metronome/presentation/tap_tempo_modal.dart';
import 'package:tunner/features/pedagogy_profiles/presentation/learner_profile_selector_modal.dart';
import 'package:tunner/features/pedagogy_report/presentation/pedagogical_report_modal.dart';
import 'package:tunner/features/practice_recorder/domain/spectral_comparator_service.dart';
import 'package:tunner/features/practice_recorder/presentation/practice_recorder_dock.dart';
import 'package:tunner/features/practice_recorder/presentation/spectral_comparator_modal.dart';
import 'package:tunner/features/practice_recorder/presentation/spectral_comparator_painter.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

void main() {
  Widget wrapWithOledScope({
    required TunerViewModel viewModel,
    required Widget child,
    StudioThemeController? controller,
  }) {
    final themeController = controller ??
        StudioThemeController(
          initialTokens: StudioDesignTokens.studioOledMonochrome,
        );
    return StudioThemeScope(
      controller: themeController,
      child: ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  group('US-7.3: OLED Monochrome & StudioIcon migration across studio/acoustic/pedagogy modules', () {
    late TunerViewModel vm;

    setUp(() {
      vm = TunerViewModel(seedDefaults: false);
    });

    tearDown(() {
      vm.dispose();
    });

    testWidgets('ExerciseGeneratorModal renders with OLED Monochrome tokens and StudioIcon, and reacts to theme hot-swap', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = StudioThemeController(
        initialTokens: StudioDesignTokens.studioOledMonochrome,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapWithOledScope(
          viewModel: vm,
          controller: controller,
          child: const ExerciseGeneratorModal(),
        ),
      );
      await tester.pump();

      expect(find.text('GENERADOR DE EJERCICIOS Y ESCALAS'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ExerciseGeneratorModal),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, StudioDesignTokens.studioOledMonochrome.panelBackground);

      // Hot-swap to Studio Light
      controller.setTokens(StudioDesignTokens.studioLight);
      await tester.pump();

      final updatedContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(ExerciseGeneratorModal),
          matching: find.byType(Container),
        ).first,
      );
      final updatedDecoration = updatedContainer.decoration as BoxDecoration;
      expect(updatedDecoration.color, StudioDesignTokens.studioLight.panelBackground);
    });

    testWidgets('HarmonicDroneModal renders with StudioThemeScope and StudioIcon', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithOledScope(
          viewModel: vm,
          child: const HarmonicDroneModal(),
        ),
      );
      await tester.pump();

      expect(find.text('Estudio de Dron Armónico'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);
    });

    testWidgets('TapTempoModal renders with StudioThemeScope and StudioIcon', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithOledScope(
          viewModel: vm,
          child: TapTempoModal(viewModel: vm),
        ),
      );
      await tester.pump();

      expect(find.text('Calibración Rítmica Tap Tempo'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);
    });

    testWidgets('HarmonicSpectrogramModal renders with StudioThemeScope and StudioIcon', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithOledScope(
          viewModel: vm,
          child: const HarmonicSpectrogramModal(),
        ),
      );
      await tester.pump();

      expect(find.text('LABORATORIO DE TIMBRE Y ARMÓNICOS'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);
    });

    testWidgets('ChordAnalyzerModal renders with StudioThemeScope and StudioIcon', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithOledScope(
          viewModel: vm,
          child: ChordAnalyzerModal(viewModel: vm),
        ),
      );
      await tester.pump();

      expect(find.text('Reconocimiento Polifónico'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);
    });

    testWidgets('BlindEarTrainerModal renders with StudioThemeScope and StudioIcon', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithOledScope(
          viewModel: vm,
          child: BlindEarTrainerModal(viewModel: vm),
        ),
      );
      await tester.pump();

      expect(find.text('ENTRENADOR A CIEGAS'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);

      // Cleanly dispose internal stimulus timers before test completion
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('HarmonicTutorModal renders with StudioThemeScope and StudioIcon without requiring palette', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tutorVm = HarmonicTutorViewModel();
      addTearDown(tutorVm.dispose);

      await tester.pumpWidget(
        wrapWithOledScope(
          viewModel: vm,
          child: HarmonicTutorModal(viewModel: tutorVm),
        ),
      );
      await tester.pump();

      expect(find.text('Tutor de Entonación Armónica Adaptativa'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);
    });

    testWidgets('LearnerProfileSelectorModal renders with StudioThemeScope and StudioIcon', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithOledScope(
          viewModel: vm,
          child: const LearnerProfileSelectorModal(),
        ),
      );
      await tester.pump();

      expect(find.text('Perfil Pedagógico y Andamiaje'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);
    });

    testWidgets('PedagogicalReportModal renders with StudioThemeScope and StudioIcon', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithOledScope(
          viewModel: vm,
          child: const PedagogicalReportModal(),
        ),
      );
      await tester.pump();

      expect(find.text('Reporte Pedagógico y Certificado PDF'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);
    });

    testWidgets('SpectralComparatorModal and PracticeRecorderDock render with StudioThemeScope and StudioIcon', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithOledScope(
          viewModel: vm,
          child: Column(
            children: [
              const PracticeRecorderDock(),
              Expanded(child: SpectralComparatorModal(viewModel: vm)),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('AUTO-ESCUCHA'), findsOneWidget);
      expect(find.text('COMPARADOR ESPECTRAL DE TOMAS'), findsOneWidget);
      expect(find.byType(StudioIcon), findsWidgets);
    });

    test('SpectralComparatorPainter defaults to StudioDesignTokens OLED Monochrome colors and paints cleanly', () {
      const comparison = SpectralComparisonResult(
        takeAId: 'take_a',
        takeBId: 'take_b',
        takeAName: 'Toma A',
        takeBName: 'Toma B',
        meanPitchDeviationA: 4.0,
        meanPitchDeviationB: 1.5,
        pitchStabilityDelta: 2.5,
        inTunePercentageA: 72.0,
        inTunePercentageB: 89.0,
        centroidDeltaHz: 110.0,
        meanCentroidA: 980.0,
        meanCentroidB: 1090.0,
        comparisonPoints: [
          SpectralComparisonPoint(timeMs: 0, centsA: 6.0, centsB: 1.5, centroidA: 980.0, centroidB: 1090.0),
          SpectralComparisonPoint(timeMs: 100, centsA: -4.0, centsB: 0.5, centroidA: 990.0, centroidB: 1100.0),
        ],
        pedagogicalSummary: 'Estabilidad mejorada en Toma B.',
      );

      final painter = SpectralComparatorPainter(
        comparison: comparison,
        currentPlaybackPositionNormalized: 0.4,
      );

      expect(painter.tokens, StudioDesignTokens.studioOledMonochrome);
      expect(painter.colorTakeA, StudioDesignTokens.studioOledMonochrome.accentPrimary);
      expect(painter.colorTakeB, StudioDesignTokens.studioOledMonochrome.accentWarning);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(420, 220)), returnsNormally);
    });

    test('Migrated module files contain zero dynamic palette casts and zero hardcoded neon colors', () {
      const migratedFiles = <String>[
        'lib/features/exercise_generator/presentation/exercise_generator_modal.dart',
        'lib/features/drone/presentation/harmonic_drone_modal.dart',
        'lib/features/metronome/presentation/tap_tempo_modal.dart',
        'lib/features/acoustic_lab/presentation/harmonic_spectrogram_modal.dart',
        'lib/features/chord_analyzer/presentation/chord_analyzer_modal.dart',
        'lib/features/ear_training/presentation/blind_ear_trainer_modal.dart',
        'lib/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart',
        'lib/features/pedagogy_profiles/presentation/learner_profile_selector_modal.dart',
        'lib/features/pedagogy_report/presentation/pedagogical_report_modal.dart',
        'lib/features/practice_recorder/presentation/spectral_comparator_modal.dart',
        'lib/features/practice_recorder/presentation/spectral_comparator_painter.dart',
        'lib/features/practice_recorder/presentation/practice_recorder_dock.dart',
      ];

      for (final path in migratedFiles) {
        final content = File(path).readAsStringSync();
        expect(content.contains('dynamic palette'), isFalse, reason: 'Found dynamic palette in $path');
        expect(content.contains('0xFF00E5FF'), isFalse, reason: 'Found neon cyan in $path');
        expect(content.contains('0xFF00E676'), isFalse, reason: 'Found neon green in $path');
        expect(content.contains('0xFFFFD700'), isFalse, reason: 'Found neon gold in $path');
        expect(content.contains('StudioThemeScope.of(context)') || path.endsWith('painter.dart'), isTrue,
            reason: 'Expected StudioThemeScope.of(context) in $path');
      }
    });
  });
}
