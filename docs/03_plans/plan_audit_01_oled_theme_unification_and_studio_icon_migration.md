# Plan de Implementación 01: Unificación Pro OLED Monochrome, `StudioIcon` y Saneamiento de Rendering

## Metadatos del Plan

- **ID del Plan:** `PLAN-AUDIT-01-UI-OLED-2026`
- **Título de la Implementación:** `Unificación Visual a StudioDesignTokens (OLED Monochrome), Migración a StudioIcon y Corrección de Overflows/Painters`
- **Fase del Proyecto:** `Fase 6 — Hardening Estético v1.0`
- **Estado:** `Propuesto`
- **ADR Relacionado:** [ADR-0166](../04_adrs/0166_pro_oled_monochrome_theme_workbench_and_icon_registry.md)
- **Documento Funcional Base:** [Auditoría Forense Integral](../05_audits/2026-11-23_master_tool_by_tool_forensic_audit.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Eliminar el 100% de la fractura estética entre el sistema legacy (`TunnerThemePalette`) y el sistema Pro (`StudioDesignTokens` OLED Monochrome), erradicar los >400 colores neón hardcoded, consolidar un único gestor de temas, optimizar `StudioIcon` para cero cargas fallidas de assets y corregir todos los `RenderFlex` overflows y `CustomPainter` vulnerables en Flutter.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Migración de todas las vistas y modales a `StudioThemeScope.of(context)` (`tuner`, `dj_console`, `modular_rack`, `channels`, `docking`, `workspaces`, `customization`, `navigation`, `sheet_music`, `score_editor`, `song_library`, `practice_recorder`, `vocal_autotune`, `pedagogy*`, `ear_training`, `guided_lessons`, `harmonic_tutor`, `exercise_generator`, `terminal`, `instrument`).
  - Retiro del gestor de temas duplicado (`features/customization` unificado en `StudioThemeManagerModal`) y corrección de `StudioThemeController.setTokens` + sincronización de `StudioThemeCatalogService` con `studioOledMonochrome`.
  - Optimización de `StudioIcon` usando caché de `AssetManifest` (evitando excepciones/cargas fallidas asíncronas mientras falten PNGs) y migración sistemática de los >300 usos de `Icons.*` a `StudioIcon`.
  - Corrección de `clipRect`, guardas `isFinite`/clamping y overflows `RenderFlex` en painters y modales.
- **Excluido (Out-of-Scope):**
  - Creación artística de los archivos PNG/SVG (en curso por el creador).

---

## 2. Análisis de Dependencias y Tecnologías

- **SDKs:** Flutter/Dart estable del repositorio; cero dependencias externas nuevas.
- **Riesgo Tecnológico:** Bajo en audio/DSP; medio en tests de widget que validen colores o `Icons.*` concretos (deben actualizarse junto con la migración a `StudioIcon`).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Núcleo de Diseño y `StudioIcon` sin Overhead
- [ ] Actualizar `StudioIcon` (`lib/core/design_system/atoms/studio_icon.dart`) para consultar `AssetManifest` en caché antes de invocar `Image.asset`, eliminando intentos fallidos asíncronos cuando el PNG aún no existe.
- [ ] Corregir `StudioThemeController.setTokens()` (`studio_theme_provider.dart:16-19`) para permitir actualizar tokens editados con igual `id`, y alinear `_activeSkin` inicial en `studio_theme_catalog_service.dart:22` a `studioOledMonochrome`.
- [ ] Eliminar colores cian hardcoded en `studio_desktop_app_shell.dart:343-444` (`Archivos`/`Herramientas`) y eliminar `lib/core/design_system/tunner_theme.dart` + `studio_workbench_shell.dart` (código muerto).

### Paso 2: Migración de Shell, Docking, Channels, Workspaces y Customization
- [ ] Migrar `main_app_shell.dart`, `core/docking/*`, `core/channels/presentation/*`, `core/terminal/presentation/*` y `features/workspaces/presentation/*` a `StudioThemeScope.of(context)` eliminando `TunnerThemePalette` y colores `0xFF00E5FF`/`0xFF00E676`.
- [ ] Unificar `features/customization` con `StudioThemeManagerModal` y conectar el comando CLI `theme set` a `StudioThemeController`.

### Paso 3: Migración de Herramientas de Estudio, Pedagogía y Notación + `StudioIcon`
- [ ] Migrar `tuner`, `drone`, `metronome`, `audio_synthesizer`, `acoustic_lab`, `chord_analyzer`, `instrument`, `dj_console`, `modular_rack`, `sheet_music`, `score_editor`, `song_library`, `practice_recorder`, `vocal_autotune` y los 8 módulos pedagógicos a `StudioDesignTokens` y `StudioIcon`.
- [ ] Eliminar cast `dynamic palette` en `exercise_generator_modal.dart:41,310` y firmas `dynamic` en `studio_master_hardware_console_widget.dart`.

### Paso 4: Blindaje de `CustomPainter` y Overflows `RenderFlex`
- [ ] Añadir `canvas.clipRect()`, guardas `isFinite` y clamping positivo en `chord_radar_widget.dart`, `strobe_tuner_widget.dart`, `vector_jog_wheel.dart`, `dj_parallel_waveform_painter.dart` y `_ClipWaveformPainter` (`media_vault_workspace_modal.dart:968`).
- [ ] Cachear `Paint`/`Path`/`TextPainter` fuera de bucles de `paint()` en `real_sheet_music_painter.dart`, `chord_radar_widget.dart`, `spectral_comparator_painter.dart` y `dj_hardware_console_painter.dart`.
- [ ] Corregir overflows `RenderFlex` garantizados en `guided_lessons_modal.dart:218-260`, `exercise_generator_modal.dart:68-99,139-163`, `practice_report_modal.dart:120-158,243-273`, `drum_pads_tactile_widget.dart:48-89`, `studio_desktop_app_shell.dart:162-298` y `studio_dockable_window_card.dart:46-219`.

### Paso 5: Verificación
- [ ] `flutter analyze --no-fatal-infos` (cero advertencias).
- [ ] Suite completa de tests pasando al 100% + verificación visual en Linux desktop (1280x800 y 680x500).

---

## 4. Estrategia de Rollback
- **Punto de Restauración Git:** Rama `feat/v1-pro-oled-workbench-and-icon-system` previa al plan.
- **Mitigación Inmediata:** Reversión por commits atómicos por bloque de features.

---

## 5. Criterios de Aceptación (Definition of Done)
- [ ] Cero referencias a `TunnerThemePalette` en vistas de producción.
- [ ] Cero colores neón hardcoded fuera de telemetría DSP.
- [ ] 100% de módulos usando `StudioIcon` y 0 overflows en pruebas responsivas.
- [ ] `flutter analyze` y `flutter test` en verde.
