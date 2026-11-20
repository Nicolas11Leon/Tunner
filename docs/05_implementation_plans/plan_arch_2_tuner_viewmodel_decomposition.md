# Plan de Implementación: Decomposición Modular de TunerViewModel y Atomicidad Reactiva (ARCH-2)

## Metadatos del Plan
- **ID del Plan:** `PLAN-ARCH-2-DECOMP-2026-01`
- **Título de la Implementación:** `Eliminación de part of mediante Controladores Cohesivos, Puertos ISP y ValueListenable Atómico`
- **Fase del Proyecto:** `Pre-Release v1.0.0 — Ola ARCH-2`
- **Estado:** `En Progreso`
- **ADR Relacionado:** `docs/04_adrs/0131_arch_2_tuner_viewmodel_decomposition.md`
- **Documento Funcional Base:** `docs/02_use_cases/142_uc_arch_2_tuner_viewmodel_decomposition.md`

## 1. Alcance y Objetivos de la Implementación
### 1.1 Objetivo Primario
Reemplazar la fragmentación cosmética (`part of`) de `TunerViewModel` por composición real de sub-controladores, añadir puertos ISP, introducir `ValueListenable` atómico para telemetría de afinación y ubicar `TunerViewModel`/`TunerScreen` en `lib/features/tuner/presentation/`.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Extracción de `PracticeRecorderController`, `ScoreEditorController`, `VocalPedagogyController`.
  - Puertos ISP (`IGuidedLessonSessionPort`, `IChordAnalyzerSessionPort`, `IScoreEditorSessionPort`).
  - `TunerAcousticTelemetry` + `ValueNotifier<TunerAcousticTelemetry>` y uso en `TunerScreen`.
  - Reubicación canónica de `TunerViewModel` y `TunerScreen` en `lib/features/tuner/presentation/`.
  - Suite de pruebas unitarias de descomposición y atomicidad (`test/features/tuner/arch_2_viewmodel_decomposition_test.dart`).
- **Excluido (Out-of-Scope):**
  - Refactorización de widgets monolíticos DJ / Shell (pertenece a `ARCH-3`).

## 2. Análisis de Dependencias y Tecnologías
- Dart / Flutter puro (`ValueNotifier` / `ValueListenableBuilder`). Sin nuevas dependencias externas.

## 3. Plan Paso a Paso de Ejecución
- [ ] **Paso 1:** Analizar el estado compartido entre `tuner_viewmodel.dart` y sus 3 `part` files.
- [ ] **Paso 2:** Extraer `PracticeRecorderController`, `ScoreEditorController` y `VocalPedagogyController` eliminando los 3 `part of`.
- [ ] **Paso 3:** Crear `TunerAcousticTelemetry` (`ValueNotifier`) y puertos ISP implementados por `TunerViewModel`.
- [ ] **Paso 4:** Mover `TunerViewModel` y `TunerScreen` a `lib/features/tuner/presentation/` con shims de compatibilidad en `lib/features/`.
- [ ] **Paso 5:** Escribir pruebas de verificación y ejecutar `flutter analyze --no-fatal-infos` + `flutter test`.

## 4. Estrategia de Rollback
- **Punto de Restauración Git:** Commit `e070b35` en rama `qa`.

## 5. Criterios de Aceptación (Definition of Done)
- [ ] 0 archivos con `part` / `part of` en `lib/`.
- [ ] `flutter analyze --no-fatal-infos` en 0 incidencias y 100% de pruebas pasando.
