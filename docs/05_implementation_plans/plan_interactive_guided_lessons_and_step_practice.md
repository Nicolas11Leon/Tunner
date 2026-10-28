# Plan de Implementación: Módulo de Lecciones Guiadas Interactivas y Práctica Paso a Paso

Este documento define la estructura obligatoria redactada y validada antes de ejecutar cambios en el código fuente de **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-GUIDED-LESSONS-2026-038`
- **Título de la Implementación:** Módulo de Lecciones Guiadas Interactivas y Práctica Paso a Paso
- **Fase del Proyecto:** Fase 3 (Plataforma y Experiencia Integral de Aprendizaje)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0034](docs/04_adrs/0034_interactive_guided_lessons_and_step_practice.md)
- **Documento Funcional Base:** [Caso de Uso 38](docs/02_use_cases/38_uc_interactive_guided_lessons_and_step_practice.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Diseñar e implementar el motor pedagógico y la interfaz de lecciones guiadas interactivas paso a paso en el espacio **Aprender**, permitiendo al usuario practicar objetivos micro-conductuales (sostenimiento de notas, intervalos y escalas) con feedback visual acústico inmediato y adaptación al perfil del estudiante.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades de dominio puras: `GuidedLessonCategory`, `GuidedLessonStepEntity`, `GuidedLessonEntity`, `GuidedLessonProgressEntity`.
  - Catálogo canónico curado de lecciones didácticas: `CuratedGuidedLessons`.
  - Evaluador acústico en Pure Dart: `GuidedLessonEvaluator`.
  - Integración en `TunerViewModel`: estado reactivo de lección activa, métodos `startGuidedLesson()`, `cancelGuidedLesson()`, `evaluateLessonSample()`.
  - Modal interactivo de presentación: `GuidedLessonsModal`.
  - Botón de acceso `open_guided_lessons_chip` en `LearningPracticeWorkspaceView`.
  - Cobertura de pruebas unitarias y de interfaz al 100%.
- **Excluido (Out-of-Scope):**
  - Descargas de lecciones desde servidores remotos (se mantiene el principio 100% Offline-First con lecciones integradas en la aplicación).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`.
  - Flutter SDK: Canal oficial estable.
  - Dependencias añadidas: Cero (0).
- **Riesgo Tecnológico:**
  - ¿Introduce dependencias nativas o FFI?: No.
  - ¿Afecta el rendimiento?: No; la evaluación de progreso utiliza incrementos de tiempo delta sobre llamadas existentes del detector de tono.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Pedagógicos y Evaluador Acústico)
- [x] Crear `lib/features/guided_lessons/domain/guided_lesson_entity.dart` con las entidades de lección, pasos y progreso.
- [x] Implementar `lib/features/guided_lessons/domain/curated_guided_lessons.dart` con el catálogo canónico de lecciones.
- [x] Implementar `lib/features/guided_lessons/domain/guided_lesson_evaluator.dart` para la evaluación de sostenimiento y validación de notas.
- [x] Crear suite de pruebas de dominio `test/features/guided_lessons/guided_lessons_domain_test.dart` y validar el 100% de aserciones.

### Paso 2: Integración en Capa de Datos / ViewModel
- [x] Integrar `GuidedLessonEvaluator` en `TunerViewModel`.
- [x] Conectar la evaluación continua de tonos en `_handlePitchDetected()` y proveer getters reactivos.

### Paso 3: Capa de Presentación (Modal y Acceso en Workspace)
- [x] Diseñar `lib/features/guided_lessons/presentation/guided_lessons_modal.dart` con selector de lecciones, barra de progreso circular y feedback biomecánico.
- [x] Integrar `open_guided_lessons_chip` en `LearningPracticeWorkspaceView`.
- [x] Crear pruebas de UI `test/features/guided_lessons/guided_lessons_ui_test.dart`.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Ejecución de `flutter analyze` (cero advertencias).
- [x] Ejecución completa de `flutter test` verificando que todas las pruebas pasen al 100%.
- [x] Merge limpio de la rama feature hacia `main`.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit base previo en rama `main` (`ecdc9f0`).
- **Mitigación Inmediata:** Desactivación del chip en la vista de aprendizaje o reversión del commit de merge.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Código adherido estrictamente a las reglas de [AGENTS.md](AGENTS.md).
- [x] Cero emojis en código, commits y comentarios.
- [x] 100% Clean Architecture (capa de dominio en Pure Dart).
- [x] Pruebas unitarias y de integración pasando al 100%.
- [x] Documentación técnica, caso de uso 38 y ADR 0034 redactados.
