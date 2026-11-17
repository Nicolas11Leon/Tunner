# Plan de Implementación: Sistema de Diseño Atomizado Estilo Adobe Studio

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-DESIGN-SYSTEM-2026-069`
- **Título de la Implementación:** `Sistema de Diseño Atomizado Adobe Spectrum y Refactor Visual de Media Vault & DJ Console`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `Aprobado`
- **ADR Relacionado:** [ADR-0065](../04_adrs/0065_atomized_studio_design_system_adobe_spectrum.md)
- **Documento Funcional Base:** [DOC-UI-2026-071](../01_product_vision/doc_adobe_spectrum_atomized_design_system.md)

---

## 1. Alcance y Objetivos

### 1.1 Objetivo Primario
Implementar un sistema de diseño atomizado (`StudioDesignTokens` + átomos UI) con estética profesional estilo **Adobe Photoshop / Audition**, desacoplado de las funciones de negocio, y aplicarlo en `MediaVaultWorkspaceModal` y `DjConsoleModal` garantizando 100% de pruebas pasando.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido:**
  - `lib/core/design_system/studio_design_tokens.dart`
  - `lib/core/design_system/studio_theme_provider.dart`
  - `lib/core/design_system/atoms/` (`studio_panel.dart`, `studio_button.dart`, `studio_badge.dart`, `studio_toolbar.dart`)
  - Refactorización visual de `media_vault` (`media_vault_workspace_modal.dart`, `timeline_arrangement_painter.dart`) y `dj_console` (`dj_console_modal.dart`, `dj_pro_workstation_panel.dart`)
  - Selector de tema en vivo independiente de funciones y reparación de los 2 tests pendientes en `dj_console_ui_test.dart`.
- **Excluido:**
  - Cambios en lógica de dominio o motores DSP.

---

## 2. Plan Paso a Paso

### Paso 1: Design Tokens, Theme Scope y Átomos UI (`lib/core/design_system/`)
- [ ] Crear `studio_design_tokens.dart` con presets `adobeSpectrumDark`, `adobeSpectrumDarkest`, `adobeSpectrumLight`.
- [ ] Crear `studio_theme_provider.dart` (`StudioThemeController` + `StudioThemeScope`).
- [ ] Crear átomos (`studio_panel.dart`, `studio_button.dart`, `studio_badge.dart`, `studio_toolbar.dart`).

### Paso 2: Migración Visual Atomizada
- [ ] Migrar `media_vault_workspace_modal.dart` y `timeline_arrangement_painter.dart` a estética Adobe Audition/Premiere usando átomos y tokens.
- [ ] Migrar cabecera y paneles de `dj_console_modal.dart` y `dj_pro_workstation_panel.dart` a estética Adobe Studio sin emojis y corrigiendo el scroll/visibilidad de `open_keymap_editor_btn`.

### Paso 3: Verificación Integral y Documentación
- [ ] Ejecutar `flutter analyze` (0 issues).
- [ ] Ejecutar `flutter test` completo (100% pasando).
- [ ] Actualizar documentación y realizar commit.
