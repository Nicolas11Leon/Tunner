# ADR-0144: Persistencia Ebbinghaus, Respuesta Cantada y Catalogo de Tareas Ejecutable

- **Estado:** Aceptado
- **Fecha:** 2026-11-22
- **Historia de Usuario:** US-6.3 (EPIC-06)
- **Issue:** #167

## Contexto

`BlindEarTrainerModal` no conectaba `submitSungFrequency` al microfono, pasaba `0.0 cents` en elecciones por boton, no actualizaba ni persistia `EbbinghausSpacedRepetitionEngine`, `TaskCatalogIndex` tenia 17 tareas con `steps: const []` y calificaciones falsas (`mastered`/`TaskGrade.s`), `TaskQuickJumpModal` solo cambiaba de tab, y `VocalPedagogyController` no persistia lecciones completadas.

## Decision

1. **Separacion clara entre eleccion teorica y ejecucion vocal:** Hacer `centsDeviation` opcional (`double?`) en `submitIntervalChoice` / `EarTrainingAnswerResult` para omitir medicion de cents cuando se responde por boton, mientras `submitSungFrequency` reporta el error medido en cents desde `TunerViewModel.frequency`.
2. **Motor Ebbinghaus compartido y serializable en `TunerViewModel`:** Exponer `ebbinghausEngine` en `TunerViewModel`, restaurarlo desde `AppUserSettingsEntity.earTrainingItemsJson` y persistirlo tras cada respuesta.
3. **Catalogo limpio y ejecutable:** Inicializar las 17 tareas de `TaskCatalogIndex` en `notStarted`/`none` con secuencias `TaskStep` musicales reales y conectar `TunerViewModel.startPedagogicalTask(task)` + persistencia de `completedTaskIds`/`completedLessonIds`.

## Consecuencias

- **Positivas:**
  - Progreso autentico de memoria espaciada (Ebbinghaus) y tareas guiadas entre sesiones.
  - Cero calificaciones falsas pre-llenadas o pasos vacios en `TaskCatalogIndex`.
- **Negativas / Compensaciones:**
  - `AppUserSettingsEntity` incorpora tres campos opcionales retrocompatibles en JSON (`earTrainingItemsJson`, `taskStatuses`, `completedLessonIds`).
