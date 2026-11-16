import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';
import 'package:tunner/core/design_system/molecules/studio_automations_modal.dart';
import 'package:tunner/core/design_system/molecules/studio_customizations_modal.dart';
import 'package:tunner/core/design_system/molecules/studio_settings_modal.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/modular_rack/presentation/modular_rack_viewmodel.dart';
import 'package:tunner/features/modular_rack/presentation/modular_studio_rack_view.dart';
import 'package:tunner/features/modular_rack/domain/rack_module_entity.dart';

void main() {
  group('Studio Desktop Menus & Modals Tests (ADR 0068 & UC 78)', () {
    late StudioThemeController themeController;

    setUp(() {
      themeController = StudioThemeController();
    });

    tearDown(() {
      themeController.dispose();
    });

    testWidgets('Top Menu items (Tunner, Workspace, View, Window) open popups and fire callbacks', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool newScoreFired = false;
      bool importFired = false;
      int? navigatedTabIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: StudioThemeScope(
            controller: themeController,
            child: StudioDesktopAppShell(
              currentBreadcrumb: 'tunner / Tests',
              navigationSections: const [],
              activeItemId: 'none',
              activeView: const Text('Viewport Content'),
              onOpenSearch: () {},
              onOpenShortcuts: () {},
              onMenuNewScore: () => newScoreFired = true,
              onMenuImportFile: () => importFired = true,
              onNavigateToTabIndex: (idx) => navigatedTabIndex = idx,
            ),
          ),
        ),
      );

      expect(find.text('Tunner'), findsOneWidget);
      expect(find.text('Workspace'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Window'), findsOneWidget);

      // 1. Abrir menú Workspace
      await tester.tap(find.text('Workspace'));
      await tester.pumpAndSettle();

      expect(find.text('Nueva Partitura...'), findsOneWidget);
      expect(find.text('Importar Archivo Universal...'), findsOneWidget);

      // Seleccionar Nueva Partitura
      await tester.tap(find.text('Nueva Partitura...'));
      await tester.pumpAndSettle();
      expect(newScoreFired, isTrue);

      // 2. Abrir menú Window y navegar a Afinador
      await tester.tap(find.text('Window'));
      await tester.pumpAndSettle();

      expect(find.text('1. Afinador Estroboscópico Pro'), findsOneWidget);
      await tester.tap(find.text('1. Afinador Estroboscópico Pro'));
      await tester.pumpAndSettle();
      expect(navigatedTabIndex, equals(1));
    });

    testWidgets('StudioAutomationsModal opens and displays automated practice routines', (tester) async {
      final vm = TunerViewModel();
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: StudioThemeScope(
            controller: themeController,
            child: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => StudioAutomationsModal.show(ctx, vm),
                  child: const Text('Abrir Automatizaciones'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Automatizaciones'));
      await tester.pumpAndSettle();

      expect(find.text('AUTOMATIZACIONES DE ESTUDIO'), findsOneWidget);
      expect(find.text('Rampa Progresiva de Metrónomo'), findsOneWidget);
      expect(find.text('Detección y Auto-Grabación WAV'), findsOneWidget);
      expect(find.text('Calentamiento Técnico Guiado'), findsOneWidget);

      // Cerrar modal limpiamente
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('AUTOMATIZACIONES DE ESTUDIO'), findsNothing);
    });

    testWidgets('StudioCustomizationsModal allows toggling DSP engine, FPS, and precision', (tester) async {
      final vm = TunerViewModel();
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: StudioThemeScope(
            controller: themeController,
            child: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => StudioCustomizationsModal.show(ctx, vm),
                  child: const Text('Abrir Personalización'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Personalización'));
      await tester.pumpAndSettle();

      expect(find.text('PERSONALIZACIÓN TÉCNICA DEL ESTUDIO'), findsOneWidget);
      expect(find.text('Tartini DSP 2.1 (Recomendado)'), findsOneWidget);
      expect(find.text('120 FPS Ultra Fluid'), findsOneWidget);

      // Seleccionar 120 FPS
      await tester.tap(find.text('120 FPS Ultra Fluid'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aplicar Cambios'));
      await tester.pumpAndSettle();
      expect(find.text('PERSONALIZACIÓN TÉCNICA DEL ESTUDIO'), findsNothing);
    });

    testWidgets('StudioSettingsModal modifies concert pitch and historic temperament', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final vm = TunerViewModel();
      addTearDown(vm.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: StudioThemeScope(
            controller: themeController,
            child: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => StudioSettingsModal.show(ctx, vm),
                  child: const Text('Abrir Ajustes'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Ajustes'));
      await tester.pumpAndSettle();

      expect(find.text('PREFERENCIAS Y CONFIGURACIÓN DEL ESTUDIO'), findsOneWidget);
      expect(find.text('442 Hz Orquestal'), findsOneWidget);

      // Cambiar a 442 Hz
      await tester.tap(find.text('442 Hz Orquestal'));
      await tester.pumpAndSettle();
      expect(vm.referencePitch, equals(442.0));

      // Seleccionar Entonación Justa
      final justFinder = find.text('Entonación Justa');
      await tester.ensureVisible(justFinder);
      await tester.pumpAndSettle();
      await tester.tap(justFinder);
      await tester.pumpAndSettle();
      expect(vm.selectedTemperament.id, equals('just_intonation'));

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
    });

    testWidgets('ModularStudioRackView preserves injected ModularRackViewModel state', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final rackVM = ModularRackViewModel();
      expect(rackVM.activeModules.length, equals(4)); // 4 módulos estándar por defecto

      rackVM.addModule(RackModuleType.chordAnalyzer);
      expect(rackVM.activeModules.length, equals(5));

      await tester.pumpWidget(
        MaterialApp(
          home: StudioThemeScope(
            controller: themeController,
            child: Scaffold(
              body: ModularStudioRackView(viewModel: rackVM),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(rackVM.activeModules.any((m) => m.moduleType == RackModuleType.chordAnalyzer), isTrue);

      // Agregar un sexto módulo directamente en el VM
      rackVM.addModule(RackModuleType.harmonicDrone);
      await tester.pumpAndSettle();

      expect(rackVM.activeModules.any((m) => m.moduleType == RackModuleType.harmonicDrone), isTrue);
      expect(rackVM.activeModules.length, equals(6));

      rackVM.dispose();
    });
  });
}
