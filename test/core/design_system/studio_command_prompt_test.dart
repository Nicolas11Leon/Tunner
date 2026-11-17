import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_design_system.dart';

void main() {
  group('StudioCommandPromptBar Interactive Autocomplete Tests', () {
    testWidgets('renders prompt input, DSP engine pill and help button', (tester) async {
      bool helpClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioCommandPromptBar(
              suggestions: const [],
              onOpenHelp: () => helpClicked = true,
              engineName: 'Tartini DSP 2.1',
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('studio_command_prompt_input')), findsOneWidget);
      expect(find.byKey(const Key('studio_command_help_btn')), findsOneWidget);
      expect(find.text('Help'), findsOneWidget);
      expect(find.text('Tartini DSP 2.1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('studio_command_help_btn')));
      await tester.pumpAndSettle();

      expect(helpClicked, isTrue);
    });

    testWidgets('typing / shows action suggestions overlay and executes command on select', (tester) async {
      String executedCommand = '';

      final suggestions = [
        PromptSuggestion(
          id: 'cmd_tuner',
          trigger: '/',
          command: '/afinar',
          title: 'Afinador Estroboscópico',
          description: 'Afinación ±0.1c',
          category: 'Afinación',
          shortcut: 'A',
          icon: Icons.tune,
          onExecute: (_) => executedCommand = '/afinar',
        ),
        PromptSuggestion(
          id: 'cmd_metro',
          trigger: '/',
          command: '/metro',
          title: 'Metrónomo Continuo',
          description: 'Alternar pulso rítmico',
          category: 'Transporte',
          shortcut: 'Espacio',
          icon: Icons.access_time,
          onExecute: (_) => executedCommand = '/metro',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioCommandPromptBar(
              suggestions: suggestions,
              onOpenHelp: () {},
              onCommandExecuted: (cmd) => executedCommand = cmd,
            ),
          ),
        ),
      );

      // Tipear / en el input
      await tester.enterText(find.byKey(const Key('studio_command_prompt_input')), '/');
      await tester.pump();

      // Debe desplegar el overlay con el encabezado de sugerencias
      expect(find.text('COMANDOS (2)'), findsOneWidget);
      expect(find.text('/afinar'), findsOneWidget);
      expect(find.text('/metro'), findsOneWidget);

      // Seleccionar /afinar
      await tester.tap(find.text('/afinar'));
      await tester.pumpAndSettle();

      expect(executedCommand, equals('/afinar'));
    });

    testWidgets('typing @ filters module suggestions', (tester) async {
      final suggestions = [
        PromptSuggestion(
          id: 'cmd_tuner',
          trigger: '/',
          command: '/afinar',
          title: 'Afinador Estroboscópico',
          description: 'Afinación ±0.1c',
          category: 'Afinación',
          icon: Icons.tune,
          onExecute: (_) {},
        ),
        PromptSuggestion(
          id: 'mod_studio',
          trigger: '@',
          command: '@estudio',
          title: 'Rack Modular DSP',
          description: 'Estudio de efectos',
          category: 'Módulos',
          icon: Icons.view_agenda,
          onExecute: (_) {},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioCommandPromptBar(
              suggestions: suggestions,
              onOpenHelp: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('studio_command_prompt_input')), '@');
      await tester.pump();

      expect(find.text('COMANDOS (1)'), findsOneWidget);
      expect(find.text('@estudio'), findsOneWidget);
      expect(find.text('/afinar'), findsNothing);
    });
  });
}
