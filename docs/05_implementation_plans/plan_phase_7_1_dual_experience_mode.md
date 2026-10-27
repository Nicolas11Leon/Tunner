# Plan de Implementación: Fase 7.1 Experiencia Dual Progresiva

Este documento define el plan estructurado para implementar el modo de experiencia dual en **Tunner**, cumpliendo con [AGENTS.md](AGENTS.md).

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE7-DUAL-UX-2026-001`
- **Título:** Experiencia Dual Progresiva (Modo Esencial vs. Modo Conservatorio Pro)
- **Fase del Proyecto:** Fase 7.1
- **Estado:** `Aprobado`
- **ADR Relacionado:** [ADR-0018](../04_adrs/0018_dual_experience_mode.md)
- **Documento Funcional Base:** [DOC-VANGUARD-ROADMAP-2026-001](../01_product_vision/doc_state_of_the_art_vanguard_roadmap.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Permitir a cualquier músico usar Tunner con máxima simplicidad y legibilidad (Modo Esencial), o alternar con 1 toque al entorno de conservatorio completo (Modo Pro), persistiendo la preferencia en disco.

### 1.2 Límites del Alcance
- **Incluido:**
  - `AppDisplayMode` enum en `AppUserSettingsEntity`.
  - Serialización y deserialización JSON en `JsonLocalPersistenceService`.
  - Getters y métodos de alternancia en `TunerViewModel`.
  - Diseño reactivo en `TunerScreen` con selector en AppBar y vista dedicada para Modo Esencial.
  - Pruebas unitarias y de widgets UI.

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Dominio y Persistencia
- [ ] Actualizar `AppUserSettingsEntity` con `AppDisplayMode`.
- [ ] Actualizar `JsonLocalPersistenceService` para guardar y restaurar `displayMode`.
- [ ] Pruebas unitarias de persistencia.

### Paso 2: Presentación en ViewModel y UI
- [ ] Añadir `displayMode`, `setDisplayMode`, `toggleDisplayMode` a `TunerViewModel`.
- [ ] Crear la visualización del Modo Esencial en `TunerScreen` y el botón de alternancia rápida.
- [ ] Pruebas de widget en `test/features/customization/dual_experience_ui_test.dart`.

### Paso 3: Verificación y Pull Request
- [ ] `flutter analyze` (0 issues).
- [ ] `flutter test` (100% pasando).
- [ ] Commit y Pull Request en GitHub con `gh pr create`.
