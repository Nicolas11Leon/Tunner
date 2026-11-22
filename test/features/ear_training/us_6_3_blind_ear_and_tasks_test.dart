import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/ear_training/presentation/blind_ear_trainer_modal.dart';
import 'package:tunner/features/guided_lessons/domain/pedagogical_task_contract.dart';
import 'package:tunner/features/guided_lessons/domain/task_catalog_index.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/persistence/domain/i_local_persistence_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class _InMemoryPersistenceService implements ILocalPersistenceService {
  AppUserSettingsEntity _settings = AppUserSettingsEntity.defaultSettings;
  int saveCount = 0;

  @override
  Future<void> clearSettings() async {
    _settings = AppUserSettingsEntity.defaultSettings;
  }

  @override
  Future<AppUserSettingsEntity> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppUserSettingsEntity settings) async {
    _settings = settings;
    saveCount++;
  }
}

void main() {
  test('US-6.3: TaskCatalogIndex inicializa 17 tareas en notStarted/none con TaskSteps reales', () {
    final catalog = TaskCatalogIndex();
    final tasks = catalog.allTasks;
    expect(tasks.length, greaterThanOrEqualTo(17));
    for (final task in tasks) {
      expect(task.status, TaskCompletionStatus.notStarted, reason: '${task.code.formatted} debe iniciar notStarted');
      expect(task.bestGrade, TaskGrade.none, reason: '${task.code.formatted} debe iniciar bestGrade.none');
      expect(task.steps.isNotEmpty, isTrue, reason: '${task.code.formatted} debe tener pasos reales');
    }
  });

  test('US-6.3: TunerViewModel.startPedagogicalTask y markLessonCompleted persisten progreso', () async {
    final persistence = _InMemoryPersistenceService();
    final vm = TunerViewModel(
      seedDefaults: false,
      persistenceService: persistence,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final task = TaskCatalogIndex().allTasks.first;
    vm.startPedagogicalTask(task);
    expect(vm.activePedagogicalTask?.code, task.code);
    expect(vm.taskStatuses[task.code.formatted], TaskCompletionStatus.inProgress.name);

    vm.markLessonCompleted('lesson_test_1');
    expect(vm.completedLessonIds, contains('lesson_test_1'));
    expect(persistence._settings.completedLessonIds, contains('lesson_test_1'));
    expect(persistence._settings.taskStatuses[task.code.formatted], TaskCompletionStatus.completed.name);
    vm.dispose();
  });

  testWidgets('US-6.3: BlindEarTrainerModal soporta respuesta cantada por microfono, omite 0.0 cents en botones y persiste Ebbinghaus', (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final persistence = _InMemoryPersistenceService();
    final vm = TunerViewModel(
      seedDefaults: false,
      persistenceService: persistence,
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlindEarTrainerModal(viewModel: vm),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('btn_sung_response_mode')), findsOneWidget);

    // Respuesta por boton no debe mostrar "0.0 cents"
    await tester.tap(find.byKey(const Key('btn_interval_option_0')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('0.0 cents'), findsNothing);
    expect(persistence.saveCount, greaterThanOrEqualTo(1));

    // Siguiente pregunta y activar modo cantado por microfono
    await tester.tap(find.byKey(const Key('btn_next_question')));
    await tester.pump(const Duration(milliseconds: 1500));

    await tester.tap(find.byKey(const Key('btn_sung_response_mode')));
    await tester.pump(const Duration(milliseconds: 100));
    vm.emitTelemetryForTesting(frequency: 440.0);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('ear_trainer_result_banner')), findsOneWidget);
    expect(persistence._settings.earTrainingItemsJson, isNotEmpty);

    vm.dispose();
  });
}
