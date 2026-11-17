import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';

void main() {
  group('Studio Workspace Windowing & High-End Shell Tests (ADR 0071 & UC 81)', () {
    testWidgets('StudioSplitter emits deltas on horizontal pan gestures', (tester) async {
      double deltaAccumulator = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: 300,
                child: StudioSplitter(
                  orientation: Axis.horizontal,
                  onDelta: (d) => deltaAccumulator += d,
                ),
              ),
            ),
          ),
        ),
      );

      final splitterFinder = find.byType(StudioSplitter);
      expect(splitterFinder, findsOneWidget);

      await tester.drag(splitterFinder, const Offset(50, 0));
      await tester.pumpAndSettle();

      expect(deltaAccumulator, greaterThan(0.0));
    });

    testWidgets('StudioWorkspaceTabBar renders DAW tabs and triggers selection', (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StudioWorkspaceTabBar(
                activeIndex: selectedIndex,
                onTabSelected: (idx) => selectedIndex = idx,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Aprender'), findsOneWidget);
      expect(find.text('Rack Modular'), findsOneWidget);
      expect(find.text('Partituras'), findsOneWidget);
      expect(find.text('Consola DJ'), findsOneWidget);

      await tester.tap(find.text('Rack Modular'));
      await tester.pumpAndSettle();

      expect(selectedIndex, equals(3));
    });

    testWidgets('StudioDesktopAppShell toggles sidebar visibility and dual split view', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int tabNavigated = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: StudioDesktopAppShell(
            currentBreadcrumb: 'tunner / Estudio / Rack Modular',
            activeItemId: 'item_tuner',
            navigationSections: const [
              StudioTreeSection(title: 'Projects', folders: []),
            ],
            currentTabIndex: 0,
            activeView: const Center(child: Text('PRIMARY_VIEWPORT')),
            secondaryView: const Center(child: Text('SECONDARY_RACK_VIEWPORT')),
            onOpenSearch: () {},
            onOpenShortcuts: () {},
            onNavigateToTabIndex: (idx) => tabNavigated = idx,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sidebar is visible initially
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('PRIMARY_VIEWPORT'), findsOneWidget);

      // 1. Toggle Sidebar Button
      final toggleSidebarBtn = find.byTooltip('Ocultar Barra Lateral (Ctrl+B)');
      expect(toggleSidebarBtn, findsOneWidget);

      await tester.tap(toggleSidebarBtn);
      await tester.pumpAndSettle();

      // Sidebar should now be hidden
      expect(find.text('Projects'), findsNothing);
      expect(find.byTooltip('Mostrar Barra Lateral (Ctrl+B)'), findsOneWidget);

      // Re-enable sidebar
      await tester.tap(find.byTooltip('Mostrar Barra Lateral (Ctrl+B)'));
      await tester.pumpAndSettle();
      expect(find.text('Projects'), findsOneWidget);

      // 2. Toggle Dual Split Mode
      final toggleDualBtn = find.byTooltip('Activar Vista Dividida Dual (Ctrl+Shift+D)');
      expect(toggleDualBtn, findsOneWidget);

      await tester.tap(toggleDualBtn);
      await tester.pumpAndSettle();

      // Both primary and secondary viewports should be visible simultaneously
      expect(find.text('PRIMARY_VIEWPORT'), findsOneWidget);
      expect(find.text('SECONDARY_RACK_VIEWPORT'), findsOneWidget);
      expect(find.text('MODO DUAL SPLIT ACTIVO'), findsOneWidget);

      // 3. Tab switching inside viewport header
      await tester.tap(find.text('Partituras'));
      await tester.pumpAndSettle();
      expect(tabNavigated, equals(4));
    });
  });
}
