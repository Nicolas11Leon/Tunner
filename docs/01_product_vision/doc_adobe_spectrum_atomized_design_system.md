# Especificación Técnica: Sistema de Diseño Atomizado Estilo Estudio (Adobe Spectrum / Pro-DAW)

## Metadatos del Documento

- **ID del Documento:** `DOC-UI-2026-071`
- **Título Oficial:** `Sistema de Diseño Atomizado Independiente de la Lógica Funcional (Estilo Adobe Studio / Pro-DAW)`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-11-15`
- **Última Modificación:** `2026-11-15`
- **Fase Asociada:** `Global - Capa de Presentación y Diseño`
- **Autor / Revisor Principal:** `Equipo Tunner`

---

## 1. Resumen Ejecutivo (Executive Summary)

Este documento define el **Sistema de Diseño Atomizado de Estudio (`StudioDesignTokens` + Átomos UI)** para **Tunner**, inspirado en las interfaces profesionales de escritorio de **Adobe Creative Cloud (Photoshop, Audition, Premiere Pro)** y estaciones de trabajo de audio digital (DAW).

El objetivo es erradicar estilos hardcodeados, bordes redondeados excesivos, colores inconsistentes y emojis en la interfaz, reemplazándolos por una arquitectura visual **100% atomizada e independiente de la lógica funcional**. Cualquier tema o skin (`Adobe Spectrum Dark`, `Adobe Darkest`, `Adobe Light`) puede intercambiarse en tiempo real sin modificar una sola línea de dominio, ViewModels o servicios DSP.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Las vistas actuales mezclaban estilos visuales (`Color(0xFF...)`, `Card`, `ElevatedButton`, radios grandes) directamente dentro de los widgets funcionales (`dj_console_modal.dart`, `media_vault_workspace_modal.dart`). Esto generaba:
- Aspecto visual inconsistente y poco profesional.
- Imposibilidad de cambiar el estilo global de un módulo sin editar la lógica de presentación de cada pantalla.

### 2.2 Principios Visuales (Adobe Studio / Pro-DAW)
- **Jerarquía por Superficies Mate y Bordes Hairline de 1px:** En lugar de sombras pesadas o tarjetas flotantes, los paneles acoplados se separan mediante fondos escalonados (`canvasBackground` -> `panelBackground` -> `elevatedSurface`) y bordes finos de `1.0 px` (`borderHairline`).
- **Radios Geométricos Precisos (`2.0 px` – `4.0 px`):** Estética técnica de precisión, maximizando el área útil de trabajo.
- **Tipografía Compacta y Tabular (`tabularFigures`):** Etiquetas de sección en mayúsculas compactas (`10.5 px`, tracking `0.8`), y métricas numéricas (BPM, segundos, dB, Hz) en fuente monoespaciada tabular para evitar saltos visuales al actualizar a 60 FPS.
- **Cero Emojis:** Toda iconografía se limita a vectores limpios y etiquetas técnicas objetivas.

---

## 3. Arquitectura Atomizada (Atomic Design + Clean Separation)

### 3.1 Tokens de Diseño (`lib/core/design_system/studio_design_tokens.dart`)
- `StudioDesignTokens`: Objeto inmutable puro con:
  - Superficies (`canvasBackground`, `panelBackground`, `panelHeaderBackground`, `elevatedSurface`, `inputSurface`).
  - Bordes (`borderHairline`, `borderFocus`).
  - Acentos (`accentPrimary` #1473E6 Adobe Blue, `accentSecondary`, `accentSuccess`, `accentWarning`, `accentDanger`).
  - Tipografía (`textPrimary`, `textSecondary`, `textMuted`).
  - Geometría (`radiusSmall = 2.0`, `radiusMedium = 4.0`, `borderWidth = 1.0`, `toolbarHeight = 38.0`).
- Presets integrados: `adobeSpectrumDark`, `adobeSpectrumDarkest`, `adobeSpectrumLight`.

### 3.2 Proveedor de Estilo Desacoplado (`studio_theme_provider.dart`)
- `StudioThemeController` (`ChangeNotifier`) + `StudioThemeScope` (`InheritedNotifier`).
- Permite cambiar el preset visual de forma independiente a cualquier `ViewModel` funcional.

### 3.3 Átomos Reutilizables (`lib/core/design_system/atoms/`)
- `StudioPanel` & `StudioPanelHeader`: Contenedor acoplado con borde 1px y barra de título técnica.
- `StudioToolbar`: Barra de opciones superior compacta estilo Photoshop/Audition.
- `StudioButton` & `StudioToggleChip`: Botones planos de precisión (`primary`, `secondary`, `ghost`, `danger`).
- `StudioBadge`: Etiqueta técnica tabular para BPM, Camelot, estado o formato.

---

## 4. Plan de Pruebas y Validación (QA)

- [ ] Pruebas unitarias y de widget para intercambio dinámico de `StudioDesignTokens` sin alterar el estado funcional.
- [ ] `flutter analyze` con 0 issues.
- [ ] Suite completa de pruebas (`flutter test`) al 100% incluyendo `dj_console_ui_test.dart` y `media_vault_ui_test.dart`.
