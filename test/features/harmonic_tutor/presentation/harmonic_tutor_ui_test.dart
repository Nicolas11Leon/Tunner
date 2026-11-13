import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/harmonic_tutor/domain/harmonic_role_entity.dart';
import 'package:tunner/features/harmonic_tutor/domain/just_intonation_calculator.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_beat_gauge.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_tutor_view_model.dart';

Widget createTestApp(HarmonicTutorViewModel viewModel) {
  return MaterialApp(
    home: Scaffold(
      body: HarmonicTutorModal(
        viewModel: viewModel,
        palette: TunnerThemePalette.obsidianStudio,
      ),
    ),
  );
}

void main() {
  late HarmonicTutorViewModel viewModel;

  setUp(() {
    viewModel = HarmonicTutorViewModel();
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('HarmonicTutorModal UI & Interaction Tests', () {
    testWidgets('Renders all initial widgets, gauge, drone button and simulation tools', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      expect(find.text('Tutor de Entonación Armónica Adaptativa'), findsOneWidget);
      expect(find.byType(HarmonicBeatGauge), findsOneWidget);
      expect(find.byKey(const Key('toggle_harmonic_drone_btn')), findsOneWidget);
      expect(find.text('Activar Dron Guía'), findsOneWidget);
      expect(find.byKey(const Key('sim_3rd_just_btn')), findsOneWidget);
      expect(find.byKey(const Key('sim_3rd_tempered_btn')), findsOneWidget);
      expect(find.byKey(const Key('sim_5th_just_btn')), findsOneWidget);
    });

    testWidgets('Tapping toggle_harmonic_drone_btn activates and deactivates reference drone', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      expect(viewModel.session.isDroneActive, isFalse);

      final droneBtn = find.byKey(const Key('toggle_harmonic_drone_btn'));
      await tester.tap(droneBtn);
      await tester.pump();

      expect(viewModel.session.isDroneActive, isTrue);
      expect(find.text('Dron Guía Activo'), findsOneWidget);

      await tester.tap(droneBtn);
      await tester.pump();

      expect(viewModel.session.isDroneActive, isFalse);
      expect(find.text('Activar Dron Guía'), findsOneWidget);
    });

    testWidgets('Simulating pure Major Third achieves Zero Beat Lock (Consonancia Pura)', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      final justBtn = find.byKey(const Key('sim_3rd_just_btn'));
      await tester.tap(justBtn);
      await tester.pump();

      expect(viewModel.session.activeAnalysis?.role, HarmonicRole.majorThird);
      expect(viewModel.session.activeAnalysis?.status, HarmonicLockStatus.pureConsonance);
      expect(find.text('Consonancia Pura (Lock)'), findsOneWidget);
      expect(find.text('M3'), findsOneWidget);
    });

    testWidgets('Simulating 12-TET Major Third triggers acoustic roughness status', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      final tetBtn = find.byKey(const Key('sim_3rd_tempered_btn'));
      await tester.tap(tetBtn);
      await tester.pump();

      expect(viewModel.session.activeAnalysis?.role, HarmonicRole.majorThird);
      expect(viewModel.session.activeAnalysis?.status, HarmonicLockStatus.roughness);
      expect(find.text('Fricción Armónica'), findsOneWidget);
      expect(viewModel.session.activeAnalysis!.beatFrequencyHz, greaterThan(8.0));
    });

    testWidgets('Selecting Re (D4) updates root note and frequency accurately', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(viewModel));
      await tester.pump();

      final reChip = find.text('Re (D4)');
      await tester.tap(reChip);
      await tester.pump();

      expect(viewModel.session.rootNoteName, 'Re (D4)');
      expect(viewModel.session.rootFrequency, closeTo(293.66, 0.01));
    });
  });
}
