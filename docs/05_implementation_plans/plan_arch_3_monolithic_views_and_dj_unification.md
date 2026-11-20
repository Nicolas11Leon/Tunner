# Plan de Implementación: Decomposición de Vistas Monolíticas y Unificación de Dominio DJ (ARCH-3)

## Metadatos del Plan
- **ID del Plan:** `PLAN-ARCH-3-VIEWS-2026-01`
- **Título de la Implementación:** `Extracción de Catálogo de Comandos, Sub-Widgets DJ/Tuner y Normalización de Hot Cues`
- **Fase del Proyecto:** `Pre-Release v1.0.0 — Ola ARCH-3`
- **Estado:** `En Progreso`
- **ADR Relacionado:** `docs/04_adrs/0132_arch_3_monolithic_views_and_dj_unification.md`
- **Documento Funcional Base:** `docs/02_use_cases/143_uc_arch_3_monolithic_views_and_dj_unification.md`

## 1. Alcance y Objetivos de la Implementación
### 1.1 Objetivo Primario
Descomponer secciones extensas de `MainAppShell`, `TunerScreen` y las vistas DJ en componentes reutilizables cohesivos, unificando el manejo de ranuras de Hot Cues.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `StudioCommandCatalogBuilder` extraído de `MainAppShell`.
  - `DjHotCuePadGrid` compartido entre `DjStudioWorkstationView` y `DjConsoleModal`.
  - `EssentialTunerPanel` extraído de `TunerScreen`.
  - Helper unificado de LEDs de Hot Cues en `DjConsoleViewModel`.
- **Excluido (Out-of-Scope):**
  - Aislamiento DSP en Isolates (pertenece a `ARCH-4`).

## 2. Análisis de Dependencias y Tecnologías
- Flutter widgets puros sin nuevas dependencias.

## 3. Plan Paso a Paso de Ejecución
- [ ] **Paso 1:** Extraer `StudioCommandCatalogBuilder` de `MainAppShell`.
- [ ] **Paso 2:** Extraer `DjHotCuePadGrid` y unificar el helper de Hot Cues en `DjConsoleViewModel`.
- [ ] **Paso 3:** Extraer `EssentialTunerPanel` de `TunerScreen`.
- [ ] **Paso 4:** Escribir pruebas unitarias/widget de verificación y ejecutar `flutter analyze --no-fatal-infos` + `flutter test`.

## 4. Estrategia de Rollback
- **Punto de Restauración Git:** Commit `430e5d6` en rama `qa`.

## 5. Criterios de Aceptación (Definition of Done)
- [ ] `flutter analyze --no-fatal-infos` en 0 incidencias y 100% de pruebas pasando.
