import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/molecules/studio_workspace_tab_bar.dart';
import 'package:tunner/core/design_system/organisms/studio_desktop_app_shell.dart';
import 'package:tunner/features/navigation/presentation/modals/studio_automations_modal.dart';
import 'package:tunner/features/navigation/presentation/home_dashboard_screen.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UX Wave 2 - StudioWorkspaceTabBar 6 Tabs Tests', () {
    testWidgets('Barra de pestanas renderiza las 6 pestanas DAW en orden y emite seleccion', (tester) async {
      int? selectedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioWorkspaceTabBar(
              activeIndex: 0,
              onTabSelected: (idx) {
                selectedIndex = idx;
              },
            ),
          ),
        ),
      );

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Afinador'), findsOneWidget);
      expect(find.text('Aprender'), findsOneWidget);
      expect(find.text('Rack Modular'), findsOneWidget);
      expect(find.text('Partituras'), findsOneWidget);
      expect(find.text('Consola DJ'), findsOneWidget);

      // Clic en Consola DJ (Indice 5)
      await tester.tap(find.text('Consola DJ'));
      await tester.pumpAndSettle();

      expect(selectedIndex, equals(5));

      // Clic en Afinador (Indice 1)
      await tester.tap(find.text('Afinador'));
      await tester.pumpAndSettle();

      expect(selectedIndex, equals(1));
    });
  });

  group('UX Wave 2 - StudioDesktopAppShell Window Menu Tests', () {
    testWidgets('Menu Window contiene las 6 pestanas y navega al indice correcto', (tester) async {
      int? navIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioDesktopAppShell(
              currentBreadcrumb: 'tunner / Test',
              activeItemId: 'item1',
              navigationSections: const [],
              currentTabIndex: 0,
              activeView: const SizedBox(),
              onNavigateToTabIndex: (idx) {
                navIndex = idx;
              },
              onOpenSearch: () {},
              onOpenShortcuts: () {},
            ),
          ),
        ),
      );

      // Abrir menu Window
      final windowMenuFinder = find.text('Window');
      expect(windowMenuFinder, findsOneWidget);
      await tester.tap(windowMenuFinder);
      await tester.pumpAndSettle();

      // Verificar que aparecen las 6 opciones
      expect(find.textContaining('1. Inicio'), findsOneWidget);
      expect(find.textContaining('2. Afinador'), findsOneWidget);
      expect(find.textContaining('3. Conservatorio'), findsOneWidget);
      expect(find.textContaining('4. Rack Modular'), findsOneWidget);
      expect(find.textContaining('5. Biblioteca'), findsOneWidget);
      expect(find.textContaining('6. Consola DJ'), findsOneWidget);

      // Seleccionar Consola DJ
      await tester.tap(find.textContaining('6. Consola DJ'));
      await tester.pumpAndSettle();

      expect(navIndex, equals(5));
    });
  });

  group('UX Wave 2 - HomeDashboardScreen Templates Tests', () {
    testWidgets('Plantillas rapidas configuran estado fidedigno en TunerViewModel', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final vm = TunerViewModel();
      int? navigatedTab;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TunerViewModel>.value(
            value: vm,
            child: Scaffold(
              body: HomeDashboardScreen(
                onNavigateToTab: (tab) {
                  navigatedTab = tab;
                },
                onOpenTerminal: () {},
              ),
            ),
          ),
        ),
      );

      // 1. Clic en plantilla Afinacion Filarmonica (442 Hz)
      final philharmonicCard = find.byKey(const Key('template_preset_philharmonic'));
      expect(philharmonicCard, findsOneWidget);
      await tester.ensureVisible(philharmonicCard);
      await tester.tap(philharmonicCard);
      await tester.pumpAndSettle();

      expect(vm.referencePitch, equals(442.0));
      expect(navigatedTab, equals(1)); // Navega a Afinador

      // 2. Clic en plantilla DJ Elisa (126 BPM)
      final djElisaCard = find.byKey(const Key('template_dj_elisa'));
      expect(djElisaCard, findsOneWidget);
      await tester.ensureVisible(djElisaCard);
      await tester.tap(djElisaCard);
      await tester.pumpAndSettle();

      expect(vm.bpm, equals(126));
      expect(navigatedTab, equals(5)); // Navega a Consola DJ
    });
  });

  group('UX Wave 2 - StudioAutomationsModal Real Execution Tests', () {
    testWidgets('Activar rampa y calentamiento ejecuta automatizaciones en TunerViewModel', (tester) async {
      final vm = TunerViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => StudioAutomationsModal.show(ctx, vm),
                child: const Text('Abrir Automatizaciones'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Automatizaciones'));
      await tester.pumpAndSettle();

      // Clic en Activar Rampa
      final rampaBtn = find.text('Activar Rampa');
      expect(rampaBtn, findsOneWidget);
      await tester.tap(rampaBtn);
      await tester.pumpAndSettle();

      expect(vm.isBpmRampActive, isTrue);
      expect(vm.isMetronomeActive, isTrue);

      vm.stopProgressiveBpmRamp();
      expect(vm.isBpmRampActive, isFalse);
    });
  });
}
