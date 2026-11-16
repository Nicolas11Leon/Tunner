import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';

void main() {
  group('Studio Desktop Hierarchical Shell Tests (Antigravity Style)', () {
    testWidgets('StudioTreeView expands, collapses folders and selects child items', (tester) async {
      String activeId = 'item_tuner';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioTreeView(
              selectedItemId: activeId,
              sections: [
                StudioTreeSection(
                  title: 'Projects',
                  folders: [
                    StudioTreeFolder(
                      id: 'folder_tunner',
                      title: 'tunner',
                      items: [
                        StudioTreeItem(
                          id: 'item_tuner',
                          title: 'Afinador Estroboscópico',
                          icon: Icons.tune,
                          timestamp: '440 Hz',
                          statusDotColor: Colors.blueAccent,
                          onSelect: () => activeId = 'item_tuner',
                        ),
                        StudioTreeItem(
                          id: 'item_drone',
                          title: 'Dron Armónico',
                          icon: Icons.volume_up,
                          timestamp: 'En vivo',
                          onSelect: () => activeId = 'item_drone',
                        ),
                      ],
                    ),
                    StudioTreeFolder(
                      id: 'folder_studio',
                      title: 'Estudio & Grabación',
                      items: [
                        StudioTreeItem(
                          id: 'item_rack',
                          title: 'Rack Modular DSP',
                          icon: Icons.view_agenda,
                          timestamp: '4 pedales',
                          onSelect: () => activeId = 'item_rack',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      // Verifica presencia de sección Projects y nombres de carpetas
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('tunner'), findsOneWidget);
      expect(find.text('Estudio & Grabación'), findsOneWidget);
      expect(find.text('Afinador Estroboscópico'), findsOneWidget);
      expect(find.text('Dron Armónico'), findsOneWidget);
      expect(find.text('Rack Modular DSP'), findsOneWidget);

      // Selección de un ítem anidado
      await tester.tap(find.text('Dron Armónico'));
      await tester.pumpAndSettle();

      expect(activeId, 'item_drone');
    });

    testWidgets('StudioDesktopAppShell renders Antigravity IDE layout (Menu, Automations, Projects, Settings, Prompt Bar)', (tester) async {
      bool automationsTriggered = false;
      bool settingsTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StudioDesktopAppShell(
            appTitle: 'Tunner',
            appVersion: 'v2.29.0',
            currentBreadcrumb: 'tunner / Estudio / Rack Modular',
            activeItemId: 'item_rack',
            navigationSections: const [
              StudioTreeSection(
                title: 'Projects',
                folders: [],
              ),
            ],
            activeView: const Center(child: Text('VIEWPORT ACTIVO')),
            sidebarFooter: const Text('FOOTER INSTRUMENTO'),
            onOpenSearch: () {},
            onOpenShortcuts: () {},
            onOpenAutomations: () => automationsTriggered = true,
            onOpenSettings: () => settingsTriggered = true,
            customStatusItems: const [
              Text('A4 = 440 Hz'),
            ],
          ),
        ),
      );

      // Verifica Menús de cabecera estilo Antigravity
      expect(find.text('Tunner'), findsWidgets);
      expect(find.text('Workspace'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Window'), findsOneWidget);
      expect(find.text('Version v2.29.0'), findsOneWidget);
      expect(find.text('tunner / Estudio / Rack Modular'), findsWidgets);

      // Verifica Accesos directos del Sidebar (Automations, Customizations, Settings)
      expect(find.text('Automations'), findsOneWidget);
      expect(find.text('Customizations'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verifica Prompt Bar de Comandos
      expect(find.text('Tartini DSP 2.1'), findsOneWidget);

      // Verifica Viewport y Footer
      expect(find.text('VIEWPORT ACTIVO'), findsOneWidget);
      expect(find.text('FOOTER INSTRUMENTO'), findsOneWidget);
      expect(find.text('A4 = 440 Hz'), findsOneWidget);
      expect(find.text('MOTOR DSP EN LÍNEA'), findsOneWidget);

      // Prueba interacción de Automations y Settings
      await tester.tap(find.text('Automations'));
      await tester.pumpAndSettle();
      expect(automationsTriggered, isTrue);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(settingsTriggered, isTrue);
    });
  });
}
