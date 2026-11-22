# Plan de Implementacion US-6.3: Respuesta Cantada, Ebbinghaus Persistido y TaskCatalogIndex Ejecutable

- **Issue:** #167
- **Rama:** `feature/us-6.3-blind-ear-sung-ebbinghaus-and-tasks`
- **Base:** `qa`
- **Estado:** Completado (Validado con `flutter analyze --no-fatal-infos` 0 issues y 83/83 tests aprobados)

## 1. Objetivo

Completar la respuesta cantada y persistencia Ebbinghaus en `BlindEarTrainerModal`, poblar pasos reales y estado inicial limpio en las 17 tareas de `TaskCatalogIndex`, ejecutar tareas desde `TaskQuickJumpModal` y persistir lecciones completadas.

## 2. Archivos a Modificar

1. `lib/features/persistence/domain/app_user_settings_entity.dart`
   - Agregar `earTrainingItemsJson`, `taskStatuses` y `completedLessonIds` con `copyWith`, `toJson`/`fromJson` (o `toMap`/`fromMap`).
2. `lib/features/pedagogy/domain/ear_training_item_entity.dart` & `ebbinghaus_spaced_repetition_engine.dart`
   - Agregar `toJson`/`fromJson` en `EarTrainingItemEntity` y restauracion en `EbbinghausSpacedRepetitionEngine`.
3. `lib/features/ear_training/domain/blind_ear_trainer_engine.dart` & `lib/features/ear_training/presentation/blind_ear_trainer_modal.dart`
   - Permitir `centsDeviation: double?` en `submitIntervalChoice` / `EarTrainingAnswerResult` para no mostrar `0.0 cents` en botones.
   - Agregar modo `"Responder Cantando / Tocando (Micrófono)"` conectado a `TunerViewModel.frequency` -> `submitSungFrequency` y registrar en `TunerViewModel.recordEarTrainingAnswer`.
4. `lib/features/guided_lessons/domain/task_catalog_index.dart`
   - Inicializar las 17 tareas con `TaskCompletionStatus.notStarted`, `TaskGrade.none` y `steps` reales (`List<TaskStep>`).
5. `lib/features/vocal_autotune/presentation/vocal_pedagogy_controller.dart`, `lib/features/tuner/presentation/tuner_viewmodel.dart`, `lib/features/navigation/presentation/main_app_shell.dart`, `lib/features/navigation/presentation/studio_command_catalog_builder.dart`
   - Implementar `startPedagogicalTask(task)` y persistencia de `completedLessonIds` y `taskStatuses`.
6. Pruebas: `test/features/ear_training/us_6_3_blind_ear_and_tasks_test.dart`

## 3. Criterios de Verificacion

- `flutter analyze --no-fatal-infos` -> `No issues found!`
- `flutter test --no-pub test/features/ear_training/ test/features/guided_lessons/ test/features/pedagogy/ test/core/architecture/arch_1_clean_architecture_boundaries_test.dart` -> 100% aprobado.
