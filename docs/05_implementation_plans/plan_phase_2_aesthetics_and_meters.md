# Implementation Plan: Phase 2 Premium Visual Aesthetics & Free Time Signature Customization

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-AESTHETICS-AND-METERS-2026-008`
- **Título de la Implementación:** `Motor de Estética Prémium, Temas Visuales y Selector de Métrica de Compás Libre`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `Aprobado`
- **ADR Relacionado:** `N/A`
- **Documento Funcional Base:** `docs/01_product_vision/doc_ui_themes_and_custom_meters.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Elevar la estética visual de **Tunner** a un estándar prémium con un motor de temas intercambiables en vivo y dotar a la plataforma de un selector dinámico de métrica de compás libre ($2/4, 3/4, 4/4, 6/8, 9/8, 12/8, 5/4$) con modal flotante de ajustes.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Motor de temas `TunnerThemePalette` con 4 modos visuales completos.
  - Sincronización de colores en pentagrama, fondo, figuras musicales y cursor playhead en `RealSheetMusicPainter`.
  - Botón de ajustes estéticos y de compás en la barra superior de `TunerScreen`.
  - Modal BottomSheet moderno para selección rápida de tema y métrica.
  - Pruebas unitarias completas del motor de temas y métricas.
- **Excluido (Out-of-Scope):**
  - Edición manual compás por compás de notas individuales (Fase 4).

---

## 2. Criterios de Aceptación (Definition of Done)

- [x] Cambio de tema visual reactivo y fluido sin parpadeos.
- [x] Cambio de métrica de compás actualizando inmediatamente el metrónomo y el lienzo.
- [x] 100% de tests unitarios pasando.
