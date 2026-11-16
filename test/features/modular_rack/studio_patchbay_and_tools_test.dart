import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';
import 'package:tunner/features/modular_rack/presentation/rack_unit_card.dart';
import 'package:tunner/features/modular_rack/presentation/studio_patchbay_modal.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

void main() {
  group('Studio Patchbay and Modular Tools UI Tests', () {
    late ModularRackViewModel rackVm;
    late TunerViewModel tunerVm;

    setUp(() {
      rackVm = ModularRackViewModel();
      tunerVm = TunerViewModel();
    });

    Widget createTestWidget(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ModularRackViewModel>.value(value: rackVm),
          ChangeNotifierProvider<TunerViewModel>.value(value: tunerVm),
        ],
        child: StudioThemeScope(
          controller: StudioThemeController(initialTokens: StudioDesignTokens.studioDark),
          child: MaterialApp(
            home: Scaffold(body: child),
          ),
        ),
      );
    }

    testWidgets('RackUnitCard renders custom title, edit icon, export button, and clickable port badges', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mod = rackVm.activeModules.first;

      await tester.pumpWidget(createTestWidget(
        RackUnitCard(
          module: mod,
          viewModel: rackVm,
          index: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Verify title and edit icon
      expect(find.text(mod.title.toUpperCase()), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      // Verify export tool preset button
      expect(find.byIcon(Icons.save_alt), findsOneWidget);

      // Verify port badges rendered
      expect(find.text('IN: '), findsOneWidget);
      expect(find.text('audio_in'), findsOneWidget);
      expect(find.text('OUT: '), findsOneWidget);
      expect(find.text('pitch_out'), findsOneWidget);
    });

    testWidgets('Tapping title in RackUnitCard opens rename dialog and renames tool', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mod = rackVm.activeModules.first;

      await tester.pumpWidget(createTestWidget(
        RackUnitCard(
          module: mod,
          viewModel: rackVm,
          index: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap on title area
      await tester.tap(find.text(mod.title.toUpperCase()));
      await tester.pumpAndSettle();

      // Assert dialog opened
      expect(find.text('RENOMBRAR HERRAMIENTA'), findsOneWidget);

      // Enter new name
      await tester.enterText(find.byType(TextField), 'Afinador Lead Principal');
      await tester.pumpAndSettle();

      // Tap Guardar
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();

      // Assert renamed in ViewModel
      expect(rackVm.activeModules.first.title, equals('Afinador Lead Principal'));
    });

    testWidgets('StudioPatchbayModal displays active routes and allows connecting outputs to inputs', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        StudioPatchbayModal(viewModel: rackVm),
      ));
      await tester.pumpAndSettle();

      // Assert patchbay title and active routes badge
      expect(find.text('MATRIZ DE CONECTORES Y PATCHBAY VIRTUAL'), findsOneWidget);
      expect(find.textContaining('RUTAS ACTIVAS'), findsOneWidget);
      expect(find.text('CONEXIONES Y CABLES ACTIVOS'), findsOneWidget);
    });
  });
}
