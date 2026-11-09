# Template: Implementation Plan (Plantilla Plan de Implementación)

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE5-TASK-TAXONOMY-2026-054`
- **Título de la Implementación:** `Implementación del Sistema Canónico de Taxonomía de Tareas (TTC), Índice O(1), UI Atómica Heredable y Salto Rápido ('J')`
- **Fase del Proyecto:** `Fase 5 & Milestone 1.0 Global`
- **Estado:** `En Progreso`
- **ADR Relacionado:** `docs/04_adrs/0050_canonical_task_taxonomy_and_atomic_pedagogy_architecture.md`
- **Documento Funcional Base:** `docs/01_product_vision/doc_canonical_task_taxonomy_and_rapid_jump_architecture.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Crear un sistema unificado, atómico y altamente optimizado para la clasificación, indexación y acceso instantáneo de miles de tareas y ejercicios pedagógicos en Tunner, dotándolo de componentes UI/UX heredables y del atajo de teclado de salto rápido (*Jump to Task* vía tecla `J`).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Value Object inmutable `TaskTaxonomyCode` en Pure Dart (`lib/features/guided_lessons/domain/task_taxonomy_code.dart`).
  - Contrato base y entidades atómicas para tareas pedagógicas (`lib/features/guided_lessons/domain/pedagogical_task_contract.dart`).
  - Motor de indexación en memoria con tiempo de acceso $O(1)$ (`lib/features/guided_lessons/domain/task_catalog_index.dart`).
  - Componentes atómicos visuales y widgets base heredables (`task_badge_atom.dart`, `task_card_base.dart`).
  - Modal interactivo de navegación y salto por teclado `TaskQuickJumpModal` (`lib/features/guided_lessons/presentation/task_quick_jump_modal.dart`).
  - Integración en `MainAppShell` (atajos `J` y `Cmd+J`) y Command Palette.
  - Pruebas unitarias de dominio y de widgets pasando al 100%.
- **Excluido (Out-of-Scope):**
  - Servidores remotos o sincronización en la nube (respeta el principio 100% Offline-First de AGENTS.md).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: Stable `>=3.0.0 <4.0.0`.
  - Flutter SDK: Stable.
  - Cero dependencias externas adicionales.
- **Riesgo Tecnológico:**
  - Sin dependencias nativas complejas; operaciones algorítmicas de indexación y comparación en memoria principal.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Pure Dart)
- [x] Documentación funcional (`doc_canonical_task_taxonomy...`, Caso de uso 56, ADR 0050, Plan 54).
- [ ] Creación de `TaskTaxonomyCode` con parsing, validación regex y `Comparable`.
- [ ] Creación de `PedagogicalTaskContract` con inmutabilidad, estados de completitud (`TaskStatus`) y grados (`PerformanceGrade`).
- [ ] Creación de `TaskCatalogIndex` con búsquedas prefijales, multifacéticas y catálogo semilla curado.
- [ ] Pruebas unitarias en `test/features/guided_lessons/task_taxonomy_code_test.dart` y `task_catalog_index_test.dart`.

### Paso 2: Capa de Presentación (UI Atómica Heredable & Modal Jump)
- [ ] Creación de `TaskBadgeAtom` y `TaskCardBase` (jerarquía de widgets reutilizable y heredable).
- [ ] Implementación de `TaskQuickJumpModal` con atajos de teclado, navegación con flechas y lanzamiento directo.
- [ ] Integración de `JumpToTaskIntent` en `MainAppShell`.
- [ ] Pruebas de widgets en `test/features/guided_lessons/task_quick_jump_modal_test.dart`.

### Paso 3: Verificación y QA
- [ ] Ejecución de `flutter analyze` verificando 0 advertencias y 0 errores.
- [ ] Ejecución de `flutter test` verificando 100% de éxito en toda la suite.

---

## 4. Estrategia de Rollback
- Si se detecta alguna regresión, se puede revertir al commit base de `main` (`d176cc7`).

---

## 5. Criterios de Aceptación (Definition of Done)
- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md).
- [ ] Dominio 100% Pure Dart sin imports de Flutter UI.
- [ ] Pruebas unitarias y de widgets pasando al 100%.
