import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/guided_lessons/domain/pedagogical_task_contract.dart';
import 'package:tunner/features/guided_lessons/domain/task_catalog_index.dart';
import 'package:tunner/features/guided_lessons/presentation/task_quick_jump_modal.dart';

void main() {
  group('TaskQuickJumpModal Widget Tests', () {
    late TaskCatalogIndex catalogIndex;

    setUp(() {
      catalogIndex = TaskCatalogIndex();
    });

    testWidgets('Renders search input, TTC badges, and task list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskQuickJumpModal(
              palette: TunnerThemePalette.obsidianStudio,
              catalogIndex: catalogIndex,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('task_quick_jump_modal')), findsOneWidget);
      expect(find.byKey(const Key('task_quick_jump_input')), findsOneWidget);
      expect(find.text('JUMP [J]'), findsOneWidget);
      expect(find.textContaining('tareas encontradas'), findsOneWidget);

      // Primer resultado visible
      expect(find.byKey(const Key('task_quick_jump_item_0')), findsOneWidget);
    });

    testWidgets('Typing query filters tasks in real-time', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskQuickJumpModal(
              palette: TunnerThemePalette.obsidianStudio,
              catalogIndex: catalogIndex,
            ),
          ),
        ),
      );

      final input = find.byKey(const Key('task_quick_jump_input'));
      await tester.enterText(input, 'EAR.01');
      await tester.pumpAndSettle();

      // Debe mostrar tareas de oído
      expect(find.textContaining('Unísono vs. Quinta Justa'), findsOneWidget);
      expect(find.textContaining('Tercera Mayor vs. Tercera Menor'), findsOneWidget);

      // No debe mostrar tareas de ritmo
      expect(find.textContaining('Polirritmia 3 contra 4'), findsNothing);
    });

    testWidgets('Selecting a task via tap triggers callback and closes modal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));

      PedagogicalTaskEntity? selectedTask;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => TaskQuickJumpModal.show(
                  context: ctx,
                  palette: TunnerThemePalette.obsidianStudio,
                  catalogIndex: catalogIndex,
                  onTaskSelected: (task) => selectedTask = task,
                ),
                child: const Text('Open Jump'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Jump'));
      await tester.pumpAndSettle();

      // Tocar el primer resultado
      await tester.tap(find.byKey(const Key('task_quick_jump_item_0')));
      await tester.pumpAndSettle();

      // El modal se cierra y el callback recibe la tarea seleccionada
      expect(find.byKey(const Key('task_quick_jump_modal')), findsNothing);
      expect(selectedTask, isNotNull);
      expect(selectedTask!.code.formatted, startsWith('EAR.01'));
    });
  });
}
