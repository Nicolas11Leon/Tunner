# Auditoría Forense MCP: Entrenamiento Auditivo, Generador Algorítmico de Ejercicios y Lecciones Guiadas

**Módulos Auditados:** `lib/features/ear_training/` (5 archivos), `lib/features/exercise_generator/` (3 archivos) y `lib/features/guided_lessons/` (11 archivos)  
**Total de Archivos `.dart` Inspeccionados:** 19  
**Casos de Uso Canónicos Asociados:** `UC-021`, `UC-038`, `UC-045`, `UC-054`, `UC-056`, `UC-057`, `UC-112`, `UC-129`, `UC-135`, `UC-170`, `UC-178`  
**Alcance:** Preparación para ejecución Headless Pure Dart y exposición de capacidades mediante Model Context Protocol (MCP).

---

## 1. Inventario Archivo por Archivo

### 1.1 Módulo `lib/features/ear_training/`

| Archivo `.dart` | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso |
| :--- | :--- | :--- | :--- | :--- |
| `domain/musical_interval.dart` | Domain (Pure Dart) | `MusicalInterval` (13 intervalos: `unison` a `perfectOctave`) | `equalTemperamentRatio`, `justRatio`, `centDifferenceJustVsEqual`, `calculateTargetFrequency()`, `fromSemitones()`, `calculateCentsDeviation()` | `UC-054`, `UC-112` |
| `domain/ear_training_exercise.dart` | Domain (Pure Dart) | `EarTrainingQuestion`, `PerformanceGrade`, `EarTrainingAnswerResult` | `correctInterval`, `EarTrainingAnswerResult.evaluate()` (calificación S/A/B/C/F por cents, tiempo y racha) | `UC-054`, `UC-170` |
| `domain/i_ear_trainer_engine.dart` | Domain (Pure Dart) | `IEarTrainerEngine` | `generateNextQuestion()`, `submitIntervalChoice()`, `submitSungFrequency()`, `resetSession()` | `UC-054`, `UC-170` |
| `domain/blind_ear_trainer_engine.dart` | Domain (Pure Dart) | `EarTrainingConfig`, `BlindEarTrainerEngine` | `EarTrainingConfig.beginner()`, `generateNextQuestion()`, `submitIntervalChoice()`, `submitSungFrequency()`, `accuracyPercentage`, `averageCentsDeviation`, `averageResponseTimeMs` | `UC-054`, `UC-170` |
| `presentation/blind_ear_trainer_modal.dart` | Presentation (Flutter) | `BlindEarTrainerModal`, `_BlindEarTrainerModalState` | `_onLiveTelemetry()`, `_submitSungTone()`, `_playIntervalStimulus()`, atajos de teclado `1-4`, `Space`, `Enter` | `UC-054`, `UC-170` |

### 1.2 Módulo `lib/features/exercise_generator/`

| Archivo `.dart` | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso |
| :--- | :--- | :--- | :--- | :--- |
| `domain/i_exercise_generator.dart` | Domain (Pure Dart) | `IExerciseGenerator` | `generate()` | `UC-021` |
| `domain/algorithmic_exercise_generator.dart` | Domain (Pure Dart) | `ExerciseType` (9 tipos), `ExerciseRhythm` (5 figuras), `AlgorithmicExerciseGenerator` | `generate()` (construye `SongPackage` y `HierarchicalScore` en 4/4 con ortografía enarmónica coherente), `_shouldPreferFlats()`, `_getSemitonePattern()` | `UC-021`, `UC-129` |
| `presentation/exercise_generator_modal.dart` | Presentation (Flutter) | `ExerciseGeneratorModal`, `_ExerciseGeneratorModalState` | Selector UI de tónica, alteración, octava, tipo, ritmo y BPM conectado a `TunerViewModel` | `UC-021` |

### 1.3 Módulo `lib/features/guided_lessons/`

| Archivo `.dart` | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso |
| :--- | :--- | :--- | :--- | :--- |
| `domain/guided_lesson_entity.dart` | Domain (Pure Dart) | `GuidedLessonCategory`, `GuidedLessonStepEntity`, `GuidedLessonEntity`, `GuidedLessonProgressEntity` | `copyWith()`, `stepProgressRatio`, `overallLessonProgressRatio`, `currentStep` | `UC-038`, `UC-045` |
| `domain/curated_guided_lessons.dart` | Domain (Pure Dart) | `CuratedGuidedLessons` | `all` (catálogo curado de 4 lecciones base: iniciación, notas largas, intervalos, tríada mayor) | `UC-038` |
| `domain/guided_lesson_evaluator.dart` | Domain (Pure Dart) | `GuidedLessonEvaluator` | `startLesson()`, `cancelLesson()`, `evaluateSample()`, `jumpToStep()`, `_matchesTargetNote()` | `UC-038`, `UC-178` |
| `domain/instrument_pedagogy_adapter_engine.dart` | Domain (Pure Dart) | `InstrumentPedagogyAdapterEngine` | `adaptLessons()`, `adaptLesson()`, `adaptStep()`, `shiftMidiToInstrumentRange()`, `noteNameToMidi()`, `midiToNoteName()`, `generateFamilyBiomechanicsTip()` | `UC-045`, `UC-135` |
| `domain/task_taxonomy_code.dart` | Domain (Pure Dart) | `TaskDomain`, `TaskLevel`, `TaskSubtype`, `TaskTaxonomyCode` | `TaskTaxonomyCode.parse()`, `tryParse()`, `formatted` (`EAR.01.INTV.001`), `shortCode`, `compareTo()` | `UC-056`, `UC-057` |
| `domain/pedagogical_task_contract.dart` | Domain (Pure Dart) | `TaskCompletionStatus`, `TaskGrade`, `TaskStep`, `TaskInterconnectionLink`, `PedagogicalTaskEntity`, `StandardPedagogicalTask` | `isMultiTool`, `isCompleted`, `totalSteps`, `copyWith()` | `UC-056`, `UC-057`, `UC-170` |
| `domain/i_task_catalog_index.dart` | Domain (Pure Dart) | `ITaskCatalogIndex` | `register()`, `registerAll()`, `getByCode()`, `getByCodeString()`, `searchByQuery()`, `filter()`, `getMultiToolJointTasks()` | `UC-056`, `UC-057` |
| `domain/task_catalog_index.dart` | Domain (Pure Dart) | `TaskCatalogIndex` | Índice en memoria O(1) por TTC + índice invertido de palabras clave + catálogo semilla de tareas simples y multi-herramienta | `UC-056`, `UC-057`, `UC-170` |
| `presentation/atomic_widgets/task_badge_atom.dart` | Presentation (Flutter) | `TaskCodeBadge`, `TaskLevelPill`, badges de estado/grado | Renderizado atómico de códigos TTC y niveles | `UC-056` |
| `presentation/guided_lessons_modal.dart` | Presentation (Flutter) | `GuidedLessonsModal` | `show()`, `build()` (UI reactiva paso a paso conectada a `TunerViewModel`) | `UC-038`, `UC-045` |
| `presentation/task_quick_jump_modal.dart` | Presentation (Flutter) | `TaskQuickJumpModal`, `_TaskQuickJumpModalState` | Paleta de salto rápido por teclado (`J`, `Ctrl/Cmd+J`, flechas, `Enter`) | `UC-056` |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Acoplamientos con `package:flutter/` y `dart:ui`

| Archivo | Import Bloqueante | Impacto en CLI Pure Dart | Severidad |
| :--- | :--- | :--- | :--- |
| `ear_training/domain/*` (4 archivos) | Ninguno (0 imports Flutter/UI) | 100% ejecutable en CLI Pure Dart | Baja (Listo) |
| `exercise_generator/domain/*` (2 archivos) | Ninguno (0 imports Flutter/UI; dependencias `score_tree.dart`, `song_package_entity.dart`, `canonical_pitch_notation_codec.dart` también son Pure Dart) | 100% ejecutable en CLI Pure Dart | Baja (Listo) |
| `guided_lessons/domain/*` (8 archivos) | Ninguno (0 imports Flutter/UI; `instrument_profile_entity.dart` también es Pure Dart) | 100% ejecutable en CLI Pure Dart | Baja (Listo) |
| `ear_training/presentation/blind_ear_trainer_modal.dart` | `package:flutter/material.dart`, `package:flutter/services.dart`, `TunerViewModel` | **CRÍTICO:** Contiene lógica de dominio atrapada en el widget (`_onLiveTelemetry` con ventana de estabilidad de 3 muestras cantadas y puente hacia `EbbinghausSpacedRepetitionEngine` vía `viewModel.recordEarTrainingAnswer`). | Alta |
| `exercise_generator/presentation/*`, `guided_lessons/presentation/*` (4 archivos) | `package:flutter/material.dart`, `package:flutter/services.dart`, `provider` | Exclusivos de UI; no se importan en MCP | Informativa |

### 2.2 Brechas Funcionales y de Orquestación Pedagógica con IA

1. **Desconexión de Dominio entre `BlindEarTrainerEngine` y `EbbinghausSpacedRepetitionEngine`:**
   - Actualmente, `BlindEarTrainerEngine.generateNextQuestion()` elige intervalos con distribución uniforme (`_random.nextInt(intervals.length)`), ignorando por completo qué intervalos están vencidos (`isDue`) o tienen menor retención cognitiva `R(t)` en `EbbinghausSpacedRepetitionEngine`.
   - Asimismo, el registro del resultado en Ebbinghaus ocurre en `TunerViewModel.recordEarTrainingAnswer()` invocado desde `BlindEarTrainerModal` (capa Flutter), no dentro de un servicio de dominio Pure Dart. Un agente IA en CLI quedaría desconectado del motor de memoria espaciada salvo que se unifique en dominio.

2. **Debouncing de Voz Cantada Atrapado en UI (`_BlindEarTrainerModalState`):**
   - La lógica de estabilidad acústica para aceptar una frecuencia cantada (`_consecutiveSungSamples`, 3 muestras consecutivas con deriva `< 50 cents`, promediado) vive dentro de `blind_ear_trainer_modal.dart` (líneas 72-101) en lugar de existir en `BlindEarTrainerEngine` como `ingestLiveFrequencySample()`.

3. **Ausencia de Serialización JSON en Entidades de los 3 Módulos:**
   - `EarTrainingQuestion`, `EarTrainingAnswerResult`, `EarTrainingConfig`, `GuidedLessonEntity`, `GuidedLessonStepEntity`, `GuidedLessonProgressEntity`, `PedagogicalTaskEntity`, `StandardPedagogicalTask`, `TaskStep` y `TaskInterconnectionLink` carecen de `toJson()`/`fromJson()`.

4. **Limitaciones de `AlgorithmicExerciseGenerator`:**
   - Solo genera ejercicios en compás de `4/4` (`TimeSignature.commonTime44`, 16 ticks) y en una sola octava ascendente/descendente (`_getSemitonePattern`).
   - No soporta: modos griegos (dórico, frigio, lidio, mixolidio, locrio), escalas cromáticas, blues, octavas múltiples (`octaves: 1..3`), compases compuestos (`3/4`, `6/8`, `5/4`), ni adaptación automática a la tesitura de un `InstrumentProfileEntity` (a diferencia de `guided_lessons`).
   - No existe exportación directa desde el generador a `GuidedLessonEntity` para practicar inmediatamente una escala generada paso a paso con validación de sostenimiento.

5. **Limitaciones en `GuidedLessonEvaluator` y `TaskCatalogIndex`:**
   - `GuidedLessonEvaluator.evaluateSample()` utiliza `totalAccumulatedAccuracy` en `GuidedLessonProgressEntity` (inicializado en `1.0`), pero **nunca actualiza** `totalAccumulatedAccuracy` durante la evaluación de muestras. Al finalizar una lección no se calcula el error promedio real en cents ni la calificación (`TaskGrade`).
   - `GuidedLessonEvaluator` solo acepta `GuidedLessonEntity`, no directamente `PedagogicalTaskEntity` (aunque `TaskStep` y `GuidedLessonStepEntity` son estructuralmente casi idénticos). En `TunerViewModel.startPedagogicalTask()`, las tareas solo adaptan la lección activa en lugar de convertir `task.steps` en una sesión ejecutable de `GuidedLessonEvaluator`.
   - `TaskCatalogIndex` es puramente en memoria y no expone un método `updateTaskStatus(code, status, grade)` para que un agente IA o el evaluador actualicen el progreso de una tarea TTC.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON |
| :--- | :--- | :--- |
| `tunner://ear-training/intervals` | Catálogo de los 13 intervalos canónicos (`MusicalInterval`) con ratios 12-EDO y JI. | `{ "intervals": [{ "id": "majorThird", "semitones": 4, "shortName": "3M", "displayName": "Tercera Mayor", "justRatio": "5/4", "justCents": 386.31, "centDifferenceJustVsEqual": -13.69 }] }` |
| `tunner://ear-training/session/state` | Estado y métricas de la sesión activa de entrenamiento auditivo (pregunta actual, racha, precisión, cents promedio). | `{ "totalQuestionsAnswered": int, "correctAnswersCount": int, "accuracyPercentage": number, "currentStreak": int, "bestStreak": int, "totalScore": int, "averageCentsDeviation": number, "currentQuestion": { ... }? }` |
| `tunner://lessons/curated` | Catálogo completo de lecciones guiadas curadas (`CuratedGuidedLessons.all`). | `{ "lessons": [{ "id": "lesson_01_master_notes", "title": "...", "category": "fundamentals", "difficulty": "Principiante", "totalSteps": 3, "steps": [...] }] }` |
| `tunner://lessons/session/progress` | Progreso en tiempo real de la sesión activa de `GuidedLessonEvaluator`. | `{ "hasActiveLesson": bool, "lessonId": string, "currentStepIndex": int, "sustainedSeconds": number, "stepProgressRatio": number, "overallLessonProgressRatio": number, "isLessonComplete": bool }` |
| `tunner://tasks/catalog` | Inventario completo del `TaskCatalogIndex` ordenado por código TTC (`[DOM].[LVL].[SUB].[SEQ]`). | `{ "count": int, "tasks": [{ "code": "EAR.01.INTV.001", "title": "...", "domain": "EAR", "level": 1, "isMultiTool": bool, "requiredToolIds": string[], "status": "not_started", "bestGrade": "-" }] }` |
| `tunner://tasks/by-code/{ttc}` | Detalle completo de una tarea pedagógica por su código TTC, incluyendo `steps` y `interconnectionLinks`. | `{ "code": "EAR.01.INTV.001", "title": "...", "description": "...", "steps": [...], "interconnectionLinks": [...] }` |

### 3.2 Tools (`tunner_*`)

| Tool MCP | Parámetros (JSON Schema Resumido) | Salida JSON | Mapeo Exacto a Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_ear_training_configure` | `{ "activeIntervals"?: string[], "onlyAscending"?: bool, "useJustIntonation"?: bool, "minBaseFrequencyHz"?: number, "maxBaseFrequencyHz"?: number, "preset"?: "beginner"|"full" }` | `{ "configured": true, "config": EarTrainingConfigJson }` | `BlindEarTrainerEngine.config` / `EarTrainingConfig.beginner()` |
| `tunner_ear_training_next_question` | `{ "prioritizeEbbinghausDue"?: bool (true) }` | `{ "id": string, "baseNoteName": string, "baseFrequencyHz": number, "targetFrequencyHz": number, "isAscending": bool, "options": string[] }` (nota: oculta `correctOptionIndex` si `blindMode: true`) | `BlindEarTrainerEngine.generateNextQuestion()` |
| `tunner_ear_training_submit_choice` | `{ "selectedInterval": string, "responseTimeMs"?: int, "centsDeviation"?: number, "hasAcousticCents"?: bool, "syncEbbinghaus"?: bool (true) }` | `{ "isCorrect": bool, "grade": "S"|"A"|"B"|"C"|"F", "scoreAwarded": int, "feedbackMessage": string, "ebbinghausUpdate"?: object }` | `BlindEarTrainerEngine.submitIntervalChoice()` |
| `tunner_ear_training_submit_sung_pitch` | `{ "sungFrequencyHz": number, "responseTimeMs"?: int, "syncEbbinghaus"?: bool (true) }` | `{ "isCorrect": bool, "detectedInterval": string, "targetInterval": string, "centsDeviation": number, "grade": string, "feedbackMessage": string }` | `BlindEarTrainerEngine.submitSungFrequency()` |
| `tunner_generate_exercise` | `{ "rootNote": string, "type": "majorScale"|"naturalMinorScale"|"harmonicMinorScale"|"melodicMinorScale"|"pentatonicScale"|"majorArpeggio"|"minorArpeggio"|"thirdsIntervals"|"longTones", "rhythm"?: "quarter"|"eighth"|"sixteenth"|"half"|"whole", "bpm"?: int (80) }` | `{ "id": string, "title": string, "difficulty": string, "defaultBpm": int, "measureCount": int, "notes": [{ "measure": int, "startTick": int, "durationTicks": int, "noteName": string, "isRest": bool }] }` | `AlgorithmicExerciseGenerator.generate()` |
| `tunner_adapt_lesson_to_instrument` | `{ "lessonId": string, "instrumentId": string }` | `GuidedLessonEntity` JSON con `targetNoteName`, `targetFrequencyHz`, `writtenNoteName` y `feedbackTip` biomecánico adaptado. | `InstrumentPedagogyAdapterEngine.adaptLesson()` |
| `tunner_guided_lesson_start` | `{ "lessonId"?: string, "customLesson"?: object, "instrumentId"?: string, "customToleranceCents"?: number }` | `GuidedLessonProgressEntity` JSON inicializado en `stepIndex: 0`. | `GuidedLessonEvaluator.startLesson()` |
| `tunner_guided_lesson_evaluate_sample` | `{ "frequencyHz": number, "cents": number, "detectedNoteName": string, "deltaSeconds": number }` | `GuidedLessonProgressEntity` JSON actualizado (`sustainedSeconds`, `stepProgressRatio`, `isStepComplete`, `isLessonComplete`). | `GuidedLessonEvaluator.evaluateSample()` |
| `tunner_tasks_search` | `{ "query"?: string, "domain"?: string, "level"?: int, "status"?: string, "instrumentId"?: string, "multiToolOnly"?: bool, "limit"?: int (20) }` | `{ "total": int, "tasks": PedagogicalTaskJson[] }` | `TaskCatalogIndex.searchByQuery()`, `filter()`, `getMultiToolJointTasks()` |

### 3.3 Prompts (Flujos Guiados para Agentes IA)

1. **`adaptive_ear_training_session`**:
   - **Objetivo:** Conducir una sesión de 10 ejercicios de entrenamiento auditivo dirigida por la curva de olvido de Ebbinghaus.
   - **Flujo:** Consulta ítems vencidos en Ebbinghaus (`tunner://pedagogy/ebbinghaus/due`) -> configura `tunner_ear_training_configure` con esos intervalos -> ejecuta ciclo `tunner_ear_training_next_question` + evaluación (`tunner_ear_training_submit_choice` o `tunner_ear_training_submit_sung_pitch`) -> cierra con resumen de retención y racha.
2. **`instrument_calibrated_warmup_generator`**:
   - **Objetivo:** Crear una rutina de calentamiento personalizada para el instrumento y perfil del estudiante.
   - **Flujo:** Genera escala/notas largas con `tunner_generate_exercise` -> selecciona y adapta lección con `tunner_adapt_lesson_to_instrument` -> inicia práctica guiada con `tunner_guided_lesson_start` aplicando la tolerancia del perfil pedagógico activo.
3. **`ttc_curriculum_navigator`**:
   - **Objetivo:** Recomendar la siguiente tarea del currículo de conservatorio según debilidades detectadas.
   - **Flujo:** Busca tareas relevantes con `tunner_tasks_search` filtrando por `domain`, `level` e `instrumentId` -> presenta prerrequisitos y enlaces `interconnectionLinks` si `isMultiTool == true`.

---

## 4. Plan de Ajustes Técnicos Previos (Pre-MCP)

1. **Integrar Ebbinghaus y Debouncing Vocal dentro de `BlindEarTrainerEngine`:**
   - Inyectar opcionalmente `EbbinghausSpacedRepetitionEngine` en `BlindEarTrainerEngine` para soportar generación ponderada por ítems vencidos (`generateAdaptiveQuestion()`) y actualización automática al evaluar respuestas.
   - Mover el filtro de estabilidad de 3 muestras cantadas desde `BlindEarTrainerModal._onLiveTelemetry()` hacia `BlindEarTrainerEngine.ingestSungFrequencySample()`.
2. **Corregir Cálculo de Precisión Real y Adaptador TTC en `GuidedLessonEvaluator`:**
   - Acumular el promedio real de `|cents|` y actualizar `totalAccumulatedAccuracy` en `GuidedLessonEvaluator.evaluateSample()`, emitiendo un `TaskGrade` al completar la lección.
   - Crear un conversor canónico `GuidedLessonEntity.fromPedagogicalTask(PedagogicalTaskEntity)` para que cualquier tarea del `TaskCatalogIndex` sea ejecutable en `GuidedLessonEvaluator` de forma headless.
3. **Añadir Mutación de Estado en `ITaskCatalogIndex` / `TaskCatalogIndex`:**
   - Implementar `updateTaskProgress(TaskTaxonomyCode code, {required TaskCompletionStatus status, TaskGrade? bestGrade})` para sincronizar el progreso de tareas TTC sin depender de `_taskStatuses` en `TunerViewModel`.
4. **Serialización JSON Completa en Dominio:**
   - Implementar `toJson()` / `fromJson()` en todas las entidades de `ear_training` y `guided_lessons` (incluyendo `TaskTaxonomyCode`, `TaskStep`, `StandardPedagogicalTask`, `GuidedLessonEntity`, `GuidedLessonProgressEntity`).
5. **Extender `AlgorithmicExerciseGenerator` para Conservatorio:**
   - Añadir parámetros opcionales `octaves`, `timeSignature` y `InstrumentProfileEntity? targetInstrument` (reutilizando `InstrumentPedagogyAdapterEngine.shiftMidiToInstrumentRange`), además de modos griegos y cromático.
