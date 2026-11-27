# Plan de Implementación Maestro: Segunda Auditoría UI/UX y Manipulación Directa (Ola 7: US-UX-11 a US-UX-18)

Este documento formaliza el plan maestro de ingeniería, el backlog canónico y la hoja de ruta paso a paso para la **Ola 7** del proyecto **Tunner**, resolviendo los ocho hallazgos de la segunda auditoría UI/UX: sincronización de transporte A-B y paletas de tema (`US-UX-11`), nota fantasma SMuFL en hover (`US-UX-12`), inspector contextual por pestaña y panel lateral de herramientas (`US-UX-13`), jerarquía de aprendizaje en 3 etapas y puentes inline de laboratorio (`US-UX-14`), módulos vivos en el Rack y tokenización de `StudioRotaryKnob` (`US-UX-15`), lanzador de bóveda, presets de stems y snap magnético central en Consola DJ (`US-UX-16`), pre-escucha inline y regla de scrubbing en Bóveda Multimedia (`US-UX-17`), y las 12 tónicas cromáticas con comparación JI vs 12-TET y Bypass A/B en AutoTune (`US-UX-18`).

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-UX-WAVE7-SECOND-AUDIT-2026-0203`
- **Título de la Implementación:** `Ola 7: Refinamientos de Segunda Auditoría UI/UX, Manipulación Directa sobre Lienzos y Cobertura Cromática Completa`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `Propuesto`
- **ADR Relacionado:**
  - [ADR 0203: Transporte Unificado de Bucle A-B en ViewModel y Sincronía de Paletas](../04_adrs/0203_viewmodel_ab_loop_transport_and_theme_palette_sync.md)
  - [ADR 0204: Nota Fantasma SMuFL en Hover sobre el Lienzo de Partitura](../04_adrs/0204_smufl_ghost_note_hover_preview_in_score_canvas.md)
  - [ADR 0205: Inspector Contextual Consciente de Pestaña y Panel Lateral de Herramientas](../04_adrs/0205_tab_aware_contextual_inspector_and_sidebar_tools.md)
  - [ADR 0206: Jerarquía de Aprendizaje en 3 Etapas y Puentes Inline de Laboratorio](../04_adrs/0206_three_stage_learning_hierarchy_and_lab_inline_bridges.md)
  - [ADR 0207: Módulos Vivos en RackUnitCard y Tokenización de StudioRotaryKnob](../04_adrs/0207_live_rack_unit_modules_and_tokenized_rotary_knob.md)
  - [ADR 0208: Lanzador de Bóveda, Presets de Stems y Snap de Crossfader en Consola DJ](../04_adrs/0208_dj_workstation_vault_launcher_stem_presets_and_crossfader_snap.md)
  - [ADR 0209: Pre-escucha Inline de Activos y Regla de Scrubbing en Bóveda Multimedia](../04_adrs/0209_media_vault_inline_asset_preview_and_timeline_scrub_ruler.md)
  - [ADR 0210: 12 Tónicas Cromáticas en Tutor Armónico, Comparación JI vs 12-TET y Bypass A/B en AutoTune](../04_adrs/0210_harmonic_tutor_12_chromatic_roots_ji_compare_and_autotune_ab.md)
- **Documento Funcional Base:**
  - [Especificación Técnica de la Segunda Auditoría UI/UX](../03_technical_specifications/second_ux_audit_direct_manipulation_specification.md)
  - [UC-211 (US-UX-11)](../02_use_cases/211_uc_viewmodel_ab_loop_transport_and_theme_palette_sync.md)
  - [UC-212 (US-UX-12)](../02_use_cases/212_uc_smufl_ghost_note_hover_preview_in_score_canvas.md)
  - [UC-213 (US-UX-13)](../02_use_cases/213_uc_tab_aware_contextual_inspector_and_sidebar_tools.md)
  - [UC-214 (US-UX-14)](../02_use_cases/214_uc_three_stage_learning_hierarchy_and_lab_inline_bridges.md)
  - [UC-215 (US-UX-15)](../02_use_cases/215_uc_live_rack_unit_modules_and_tokenized_rotary_knob.md)
  - [UC-216 (US-UX-16)](../02_use_cases/216_uc_dj_workstation_vault_launcher_stem_presets_and_crossfader_snap.md)
  - [UC-217 (US-UX-17)](../02_use_cases/217_uc_media_vault_inline_asset_preview_and_timeline_scrub_ruler.md)
  - [UC-218 (US-UX-18)](../02_use_cases/218_uc_harmonic_tutor_12_chromatic_roots_ji_compare_and_autotune_ab.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario

Cerrar las ocho brechas de usabilidad, consistencia de diseño, manipulación directa y cobertura musical detectadas en la segunda auditoría UI/UX de **Tunner**, asegurando que el usuario disponga de retroalimentación inmediata en lienzos y controles hardware/pedagógicos bajo arquitectura 100% local (Offline-First) y fiel a Clean Architecture.

### 1.2 Backlog Canónico de la Ola 7 (`US-UX-11` a `US-UX-18`)

| ID Historia | Caso de Uso | ADR | Título de la Historia de Usuario | Widgets / Keys Canónicos Verificables | Suite de Pruebas Automatizadas Planificada |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `US-UX-11` | [UC-211](../02_use_cases/211_uc_viewmodel_ab_loop_transport_and_theme_palette_sync.md) | [ADR 0203](../04_adrs/0203_viewmodel_ab_loop_transport_and_theme_palette_sync.md) | Sincronización de Transporte de Bucle A-B en `TunerViewModel` y Paletas/Skins de Tema | `btn_set_loop_point_a`, `btn_set_loop_point_b`, `chip_ab_loop_status`, `btn_clear_ab_loop`, `studio_theme_switcher_dropdown` | `test/features/tuner/us_ux_11_ab_loop_transport_and_theme_sync_test.dart` |
| `US-UX-12` | [UC-212](../02_use_cases/212_uc_smufl_ghost_note_hover_preview_in_score_canvas.md) | [ADR 0204](../04_adrs/0204_smufl_ghost_note_hover_preview_in_score_canvas.md) | Previsualización de Nota Fantasma SMuFL (`Ghost Note`) en Hover sobre Lienzo de Partitura | `score_interactive_canvas_gesture`, `score_ghost_note_badge` | `test/features/workspaces/us_ux_12_smufl_ghost_note_hover_preview_test.dart` |
| `US-UX-13` | [UC-213](../02_use_cases/213_uc_tab_aware_contextual_inspector_and_sidebar_tools.md) | [ADR 0205](../04_adrs/0205_tab_aware_contextual_inspector_and_sidebar_tools.md) | Inspector Contextual Derecho Consciente de Pestaña y Panel Dedicado de Herramientas Laterales | `inspector_tab_context_section_0` .. `inspector_tab_context_section_5`, `sidebar_mode_tools_btn`, `sidebar_tools_panel` | `test/core/design_system/us_ux_13_tab_aware_inspector_and_sidebar_tools_test.dart` |
| `US-UX-14` | [UC-214](../02_use_cases/214_uc_three_stage_learning_hierarchy_and_lab_inline_bridges.md) | [ADR 0206](../04_adrs/0206_three_stage_learning_hierarchy_and_lab_inline_bridges.md) | Jerarquía de Aprendizaje en 3 Etapas y Puentes Inline en Laboratorio Acústico | `learning_stage_1_tune_listen`, `learning_stage_2_guided_practice`, `learning_stage_3_evaluate_review`, `lab_inline_chord_to_drone_btn`, `lab_inline_autotune_toggle_btn`, `lab_inline_root_key_selector` | `test/features/workspaces/us_ux_14_three_stage_learning_and_lab_inline_bridges_test.dart` |
| `US-UX-15` | [UC-215](../02_use_cases/215_uc_live_rack_unit_modules_and_tokenized_rotary_knob.md) | [ADR 0207](../04_adrs/0207_live_rack_unit_modules_and_tokenized_rotary_knob.md) | Módulos Vivos (`stemMixer` / `djConsole`) en `RackUnitCard` y Tokenización de `StudioRotaryKnob` | `rack_stem_mixer_live_panel`, `rack_dj_console_live_panel`, `rack_unit_card_header` | `test/features/modular_rack/us_ux_15_live_rack_modules_and_tokenized_knob_test.dart` |
| `US-UX-16` | [UC-216](../02_use_cases/216_uc_dj_workstation_vault_launcher_stem_presets_and_crossfader_snap.md) | [ADR 0208](../04_adrs/0208_dj_workstation_vault_launcher_stem_presets_and_crossfader_snap.md) | Lanzador de Bóveda, Presets de 4 Stems en 1 Clic y Snap Magnético Central en Consola DJ | `dj_open_media_vault_launcher_btn`, `dj_stem_preset_A_acapella`, `dj_stem_preset_A_instrumental`, `dj_crossfader_center_snap_btn` | `test/features/dj_console/us_ux_16_dj_vault_launcher_stem_presets_and_crossfader_snap_test.dart` |
| `US-UX-17` | [UC-217](../02_use_cases/217_uc_media_vault_inline_asset_preview_and_timeline_scrub_ruler.md) | [ADR 0209](../04_adrs/0209_media_vault_inline_asset_preview_and_timeline_scrub_ruler.md) | Pre-escucha Inline de Activos y Regla Interactiva de Scrubbing en Bóveda Multimedia | `vault_asset_preview_btn_<id>`, `timeline_scrub_ruler` | `test/features/media_vault/us_ux_17_vault_inline_preview_and_timeline_scrub_test.dart` |
| `US-UX-18` | [UC-218](../02_use_cases/218_uc_harmonic_tutor_12_chromatic_roots_ji_compare_and_autotune_ab.md) | [ADR 0210](../04_adrs/0210_harmonic_tutor_12_chromatic_roots_ji_compare_and_autotune_ab.md) | 12 Tónicas Cromáticas, Comparador JI vs 12-TET en Tutor Armónico y Bypass A/B en AutoTune | `harmonic_tutor_root_chip_<idx>`, `harmonic_tutor_ji_vs_12tet_toggle`, `harmonic_tutor_comparison_card`, `autotune_ab_compare_btn` | `test/features/harmonic_tutor/us_ux_18_chromatic_roots_ji_compare_and_autotune_ab_test.dart` |

### 1.3 Límites del Alcance (Scope Boundaries)

- **Incluido (In-Scope):**
  - Sincronización de transporte A-B en `TunerViewModel` y enlace bidireccional `StudioThemeController` <-> `TunerViewModel` (`US-UX-11`).
  - Cálculo de nota bajo puntero y pintado de nota fantasma SMuFL en `RealSheetMusicPainter` / `CompositionNotationWorkspaceView` (`US-UX-12`).
  - Rediseño del contenido por pestaña del Inspector Derecho en `MainAppShell` y slot `customSidebarTools` en `StudioDesktopAppShell` (`US-UX-13`).
  - Reorganización en 3 etapas de `LearningPracticeWorkspaceView` y puentes inline en `ProductionAcousticLabWorkspaceView` (`US-UX-14`).
  - Tokenización de `StudioRotaryKnob` y `RackUnitCard` con paneles interactivos para `stemMixer` y `djConsole` (`US-UX-15`).
  - Lanzador de Bóveda Multimedia, presets de 4 stems y snap magnético central en `DjStudioWorkstationView` / `DjConsoleViewModel` (`US-UX-16`).
  - Botón inline de pre-escucha en activos y regla temporal clicable/arrastrable en `MediaVaultWorkspaceModal` / `TimelineArrangementPainter` (`US-UX-17`).
  - Ampliación a 12 tónicas cromáticas + comparador JI vs 12-TET en `HarmonicTutorModal` y conmutador Bypass A/B en `VocalAutoTuneModal` (`US-UX-18`).
- **Excluido (Out-of-Scope):**
  - Modificaciones a algoritmos C/Rust FFI o incorporación de servicios remotos/en la nube (prohibido por [AGENTS.md](../../AGENTS.md)).
  - Alteraciones destructivas de keys verificadas en las Olas 5 y 6 (`us_ux_05`..`us_ux_10` y `us_hc_01`..`us_hc_08`).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x` (null-safety estricto, dominio 100% Pure Dart).
  - Flutter SDK: Canal estable oficial (Linux y Windows Desktop).
  - Gestión de estado: `provider`, `ChangeNotifier` y `ValueListenableBuilder` sin añadir paquetes externos.
- **Riesgo Tecnológico:**
  - **Introduce dependencias nativas o FFI?** No. Toda la lógica matemática y de interacción reside en Pure Dart y `CustomPainter`.
  - **Afecta el rendimiento del bucle principal de Flutter?** No; el hover de partitura y el scrub del timeline filtran notificaciones repetidas en la misma celda cuantizada y emplean `RepaintBoundary` donde corresponde.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Contratos Puros)
- [ ] Verificar e integrar el soporte de presets `DjStemPreset` en `lib/features/dj_console/domain/dj_stem_isolation_entity.dart` y el cálculo de zona muerta magnética del crossfader.
- [ ] Añadir soporte inmutable de bypass A/B en `AutoTuneConfigEntity` (`lib/features/vocal_autotune/domain/autotune_config_entity.dart`).
- [ ] Exponer el catálogo de 12 tónicas cromáticas y comparación cuantitativa JI vs 12-TET en `HarmonicTutorViewModel` y `JustIntonationCalculator`.
- [ ] Validar el mapeo inverso de altura diatónica según `InstrumentClef` en `RealSheetMusicPainter.resolveNoteAtOffset`.

### Paso 2: Capa de Infraestructura / Orquestación de ViewModels y Temas
- [ ] Unificar en `TunerViewModel` (`setAbLoopRange`, `clearAbLoop`, `nextMeasure`, `previousMeasure`) la lógica de bucle A-B sincronizada con `ScorePlaybackCoordinator`.
- [ ] Conectar bidireccionalmente `StudioThemeController` y `TunerViewModel` en `MainAppShell` con guarda anti-reentrancia.
- [ ] Añadir `applyStemPreset`, `snapCrossfaderWithMagneticDeadzone` y `centerCrossfader` en `DjConsoleViewModel`.

### Paso 3: Capa de Presentación (UI Canvas, Shell, Rack, Consola DJ, Bóveda y Modales)
- [ ] Conectar `CompositionNotationWorkspaceView` con los métodos A-B de `TunerViewModel`, añadir `MouseRegion.onHover` / `onExit`, badge `score_ghost_note_badge` y pintado de nota fantasma SMuFL (`US-UX-11`, `US-UX-12`).
- [ ] Implementar `customSidebarTools` en `StudioDesktopAppShell` y el Inspector Derecho *tab-aware* + panel lateral de herramientas en `MainAppShell` (`US-UX-13`).
- [ ] Estructurar `LearningPracticeWorkspaceView` en 3 etapas y agregar controles inline en `ProductionAcousticLabWorkspaceView` (`US-UX-14`).
- [ ] Tokenizar `StudioRotaryKnob` y `RackUnitCard` e implementar los paneles vivos para `stemMixer` y `djConsole` (`US-UX-15`).
- [ ] Añadir en `DjStudioWorkstationView` el lanzador de Bóveda, botones de preset de stems y el snap/botón central de crossfader (`US-UX-16`).
- [ ] Añadir en `MediaVaultWorkspaceModal` y `TimelineArrangementPainter` el botón inline de pre-escucha por activo y la regla interactiva de scrubbing (`US-UX-17`).
- [ ] Ampliar `HarmonicTutorModal` a 12 tónicas cromáticas + comparador JI vs 12-TET y añadir `autotune_ab_compare_btn` en `VocalAutoTuneModal` (`US-UX-18`).

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Implementar y ejecutar las 8 suites nuevas (`us_ux_11` a `us_ux_18`).
- [ ] Re-ejecutar las suites de regresión de las Olas 5 y 6 (`us_ux_05`..`us_ux_10`, `us_hc_01`..`us_hc_08`).
- [ ] Ejecutar `flutter analyze --no-fatal-infos` verificando `0 issues`.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

Cada historia (`US-UX-11` a `US-UX-18`) se diseña de manera incremental y desacoplada:
- **Punto de Restauración Git:** Commit estable posterior al cierre documental de la Ola 6 (`US-HC-01` a `US-HC-08`).
- **Mitigación Inmediata:**
  - En `US-UX-11`, si el bucle A-B no está activo (`!isAbLoopActive`), `nextMeasure()` y `previousMeasure()` conservan el comportamiento modular clásico sobre `totalMeasures`.
  - En `US-UX-12`, la nota fantasma es opcional (`ghostNoteName == null` por defecto en `RealSheetMusicPainter`).
  - En `US-UX-13`, `customSidebarTools` es un parámetro opcional en `StudioDesktopAppShell` con fallback al árbol estándar.
  - En `US-UX-14` a `US-UX-18`, todas las keys heredadas de Olas 5 y 6 se mantienen intactas para evitar regresiones en pruebas existentes.

---

## 5. Criterios de Aceptación (Definition of Done)

Para que este plan se considere completado y listo para merge:
- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md) (Pure Dart en dominio, Offline-First, cero emojis en documentación).
- [ ] Cero `busy-waiting` loops en Isolates, timers de reloj y manejadores de puntero.
- [ ] Las 8 suites de pruebas (`us_ux_11` a `us_ux_18`) y suites de regresión pasando al 100%.
- [ ] `flutter analyze --no-fatal-infos` sin advertencias ni errores.
- [ ] Los 8 ADRs (`0203` a `0210`), los 8 Casos de Uso (`211` a `218`) y la Especificación Técnica de la Segunda Auditoría aprobados y verificados en `docs/`.
- [ ] Aprobación explícita del creador/mantenedor principal.
