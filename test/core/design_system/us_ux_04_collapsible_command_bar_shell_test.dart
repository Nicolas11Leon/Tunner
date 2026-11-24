import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';

void main() {
  final testSuggestions = [
    PromptSuggestion(
      id: 'help',
      trigger: '/',
      command: '/help',
      title: 'Ayuda',
      description: 'Mostrar ayuda del sistema',
      category: 'Sistema',
      icon: Icons.help_outline,
      onExecute: (_) {},
    ),
  ];

  Widget buildShell({
    bool initialCommandPromptVisible = true,
    List<PromptSuggestion>? promptSuggestions,
  }) {
    return MaterialApp(
      home: StudioDesktopAppShell(
        currentBreadcrumb: 'tunner / Partituras / Ensayo',
        activeItemId: 'item_score',
        navigationSections: const [
          StudioTreeSection(
            title: 'Projects',
            folders: [],
          ),
        ],
        activeView: Container(
          key: const Key('test_active_view'),
          color: Colors.transparent,
          child: const Center(child: Text('LIENZO ACTIVO')),
        ),
        onOpenSearch: () {},
        onOpenShortcuts: () {},
        promptSuggestions: promptSuggestions,
        initialCommandPromptVisible: initialCommandPromptVisible,
      ),
    );
  }

  group('US-UX-04: Collapsible Command Prompt Bar in StudioDesktopAppShell', () {
    testWidgets(
      'renders btn_toggle_command_prompt_bar and shows StudioCommandPromptBar by default',
      (tester) async {
        await tester.pumpWidget(buildShell(promptSuggestions: testSuggestions));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('btn_toggle_command_prompt_bar')),
          findsOneWidget,
        );
        expect(find.text('CLI'), findsOneWidget);
        expect(find.byIcon(Icons.terminal), findsOneWidget);
        expect(
          find.byTooltip('Ocultar Barra de Comandos CLI'),
          findsOneWidget,
        );
        expect(find.byType(StudioCommandPromptBar), findsOneWidget);
        expect(find.text('Tartini DSP 2.1'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping btn_toggle_command_prompt_bar collapses StudioCommandPromptBar, frees >=44px for activeView, and restores on second tap',
      (tester) async {
        await tester.pumpWidget(buildShell(promptSuggestions: testSuggestions));
        await tester.pumpAndSettle();

        expect(find.byType(StudioCommandPromptBar), findsOneWidget);
        final initialHeight =
            tester.getSize(find.byKey(const Key('test_active_view'))).height;

        // Colapsar barra CLI
        await tester.tap(find.byKey(const Key('btn_toggle_command_prompt_bar')));
        await tester.pumpAndSettle();

        expect(find.byType(StudioCommandPromptBar), findsNothing);
        expect(
          find.byTooltip('Mostrar Barra de Comandos CLI'),
          findsOneWidget,
        );
        final expandedHeight =
            tester.getSize(find.byKey(const Key('test_active_view'))).height;
        expect(expandedHeight, greaterThan(initialHeight));
        expect(expandedHeight - initialHeight, greaterThanOrEqualTo(44.0));

        // Volver a desplegar barra CLI
        await tester.tap(find.byKey(const Key('btn_toggle_command_prompt_bar')));
        await tester.pumpAndSettle();

        expect(find.byType(StudioCommandPromptBar), findsOneWidget);
        expect(
          find.byTooltip('Ocultar Barra de Comandos CLI'),
          findsOneWidget,
        );
        final restoredHeight =
            tester.getSize(find.byKey(const Key('test_active_view'))).height;
        expect(restoredHeight, equals(initialHeight));
      },
    );

    testWidgets(
      'initialCommandPromptVisible: false starts hidden and expands on tap',
      (tester) async {
        await tester.pumpWidget(
          buildShell(
            initialCommandPromptVisible: false,
            promptSuggestions: testSuggestions,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(StudioCommandPromptBar), findsNothing);
        expect(
          find.byTooltip('Mostrar Barra de Comandos CLI'),
          findsOneWidget,
        );

        final shellState = tester.state<StudioDesktopAppShellState>(
          find.byType(StudioDesktopAppShell),
        );
        expect(shellState.isCommandPromptVisible, isFalse);

        // Desplegar tocando el chip CLI en la barra de estado
        await tester.tap(find.byKey(const Key('btn_toggle_command_prompt_bar')));
        await tester.pumpAndSettle();

        expect(shellState.isCommandPromptVisible, isTrue);
        expect(find.byType(StudioCommandPromptBar), findsOneWidget);
        expect(
          find.byTooltip('Ocultar Barra de Comandos CLI'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'View menu item toggles the command prompt bar visibility',
      (tester) async {
        await tester.pumpWidget(buildShell(promptSuggestions: testSuggestions));
        await tester.pumpAndSettle();

        expect(find.byType(StudioCommandPromptBar), findsOneWidget);

        await tester.tap(find.text('View'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ocultar Barra de Comandos CLI'));
        await tester.pumpAndSettle();

        expect(find.byType(StudioCommandPromptBar), findsNothing);

        await tester.tap(find.text('View'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mostrar Barra de Comandos CLI'));
        await tester.pumpAndSettle();

        expect(find.byType(StudioCommandPromptBar), findsOneWidget);
      },
    );
  });
}
