import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';

void main() {
  group('Studio Desktop Hierarchical Shell Tests', () {
    testWidgets('StudioTreeView expands, collapses and notifies item selection', (tester) async {
      String activeId = 'item_1';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioTreeView(
              selectedItemId: activeId,
              sections: [
                StudioTreeSection(
                  title: 'Acústica',
                  items: [
                    StudioTreeItem(
                      id: 'item_1',
                      title: 'Afinador Estroboscópico',
                      icon: Icons.tune,
                      shortcut: '2',
                      onSelect: () => activeId = 'item_1',
                    ),
                    StudioTreeItem(
                      id: 'item_2',
                      title: 'Espectrograma FFT',
                      icon: Icons.analytics,
                      onSelect: () => activeId = 'item_2',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ACÚSTICA'), findsOneWidget);
      expect(find.text('Afinador Estroboscópico'), findsOneWidget);
      expect(find.text('Espectrograma FFT'), findsOneWidget);

      await tester.tap(find.text('Espectrograma FFT'));
      await tester.pumpAndSettle();

      expect(activeId, 'item_2');
    });

    testWidgets('StudioDesktopAppShell renders top menu, breadcrumb, sidebar and status bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StudioDesktopAppShell(
            currentBreadcrumb: 'tunner / Acústica / Afinador Pro',
            activeItemId: 'item_tuner',
            navigationSections: const [
              StudioTreeSection(
                title: 'Módulos',
                items: [],
              ),
            ],
            activeView: const Center(child: Text('VIEWPORT ACTIVO')),
            sidebarFooter: const Text('FOOTER INSTRUMENTO'),
            onOpenSearch: () {},
            onOpenShortcuts: () {},
            customStatusItems: const [
              Text('A4 = 440 Hz'),
            ],
          ),
        ),
      );

      expect(find.text('TUNNER STUDIO'), findsOneWidget);
      expect(find.text('Archivo'), findsOneWidget);
      expect(find.text('Herramientas'), findsOneWidget);
      expect(find.text('tunner / Acústica / Afinador Pro'), findsOneWidget);
      expect(find.text('VIEWPORT ACTIVO'), findsOneWidget);
      expect(find.text('FOOTER INSTRUMENTO'), findsOneWidget);
      expect(find.text('A4 = 440 Hz'), findsOneWidget);
      expect(find.text('MOTOR DSP: 60 FPS'), findsOneWidget);
    });
  });
}
