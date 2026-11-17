# Implementation Plan: Neutralización de Marcas Comerciales y Adopción de Tunner Studio Design System

Este documento define la erradicación estricta de cualquier referencia a marcas comerciales registradas ajenas (específicamente la marca "Adobe"), renombrando tokens visuales, temas y textos de la interfaz a la nomenclatura propia del proyecto: **Tunner Studio Design System**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-BRANDING-2026-0079`
- **Título de la Implementación:** Neutralización de Marcas Comerciales y Adopción de Tunner Studio Design System
- **Fase del Proyecto:** `Fase 3` (Consolidación de Arquitectura de Audio y Estación de Trabajo Desktop)
- **Estado:** `Aprobado`
- **ADR Relacionado:** [0069_rename_proprietary_branding_to_tunner_studio.md](../04_adrs/0069_rename_proprietary_branding_to_tunner_studio.md)
- **Documento Funcional Base:** [79_uc_neutralize_proprietary_branding.md](../02_use_cases/79_uc_neutralize_proprietary_branding.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Reemplazar cualquier uso de nombres de marca comercial de terceros en la interfaz de usuario, tokens de diseño y código fuente:
- `Adobe Dark` $\rightarrow$ `Studio Dark`
- `Adobe Darkest` $\rightarrow$ `Studio Obsidian`
- `Adobe Light` $\rightarrow$ `Studio Light`
- `Adobe Dark Slate` $\rightarrow$ `Studio Slate Dark`
- `adobeSpectrumDark` / `adobeSpectrumDarkest` / `adobeSpectrumLight` $\rightarrow$ `studioDark` / `studioObsidian` / `studioLight`
- Eliminar menciones a marcas de terceros en comentarios y descripciones de UI.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Actualización de `lib/core/design_system/studio_design_tokens.dart`
  - Actualización de `lib/core/design_system/studio_theme_provider.dart`
  - Actualización de `lib/core/design_system/atoms/studio_theme_switcher.dart`
  - Actualización de `lib/features/media_vault/presentation/timeline_arrangement_painter.dart`
  - Actualización de `lib/features/customization/presentation/theme_editor_dialog.dart`
  - Actualización de pruebas unitarias y de widgets en `test/`
- **Excluido (Out-of-Scope):**
  - Cambios en los valores de color hexadecimal o contraste acústico (los valores numéricos matemáticos de color y ergonomía se preservan intactos).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Documentación Canónica
- [x] Redacción del Plan de Implementación formal.
- [x] Redacción del Caso de Uso 79 con diagramas Mermaid.
- [x] Redacción del ADR 0069.

### Paso 2: Refactorización de Tokens y Nombres
- [x] Renombrar tokens en `studio_design_tokens.dart` (`studioDark`, `studioObsidian`, `studioLight`).
- [x] Actualizar `StudioThemeController` y `StudioThemeScope` en `studio_theme_provider.dart`.
- [x] Reemplazar textos de visualización en `theme_editor_dialog.dart`.
- [x] Reemplazar referencias en `timeline_arrangement_painter.dart` y átomos visuales.

### Paso 3: Validación y Pruebas
- [x] Ejecutar `flutter analyze lib/ test/` asegurando 0 advertencias.
- [x] Ejecutar suite de pruebas de diseño y navegación.
- [x] Compilar y relanzar aplicación en pantalla `DISPLAY=:0`.
- [x] Git commit y push a la rama de trabajo.
