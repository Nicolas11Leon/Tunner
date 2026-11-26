# Plan de Implementación Maestro: Excelencia UX Pro-Workstation (Ola 5: US-UX-05 a US-UX-10)

Este documento formaliza el plan maestro de ingeniería, el backlog canónico y la hoja de ruta de implementación para la Ola 5 de Excelencia UX Pro-Workstation de **Tunner**, abarcando el Panel Inspector Contextual Derecho y Hover Info View (`US-UX-05`), la Barra Enfocada del Afinador y Monitor Melodyne Pitch Blobs (`US-UX-06`), los Modos de Tarea Dorico y Popover Rápido de Notación (`US-UX-07`), el Coloreado de Notas en Vivo Estilo Yousician y Bucle A-B (`US-UX-08`), la Barra Macro Smart Controls Estilo Logic Pro en el Rack Modular (`US-UX-09`) y la Paleta de Comandos Universal Unificada con Filtros de Categoría (`US-UX-10`).

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-UX-WAVE5-PRO-WORKSTATION-2026-0190`
- **Título de la Implementación:** `Excelencia UX Pro-Workstation: Inspector Contextual, Afinador Enfocado con Pitch Blobs, Modos Dorico, Feedback Yousician A-B, Smart Controls y Paleta Universal`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `Aprobado`
- **ADR Relacionado:**
  - [ADR 0189: Panel Inspector Contextual Derecho y Barra de Ayuda Viva (Hover Info View)](../04_adrs/0189_contextual_right_inspector_and_hover_info_view.md)
  - [ADR 0190: Barra de Herramientas Enfocada del Afinador y Monitor de Cápsulas de Afinación Estilo Melodyne](../04_adrs/0190_focused_tuner_toolbar_and_melodyne_pitch_blobs.md)
  - [ADR 0191: Modos de Tarea Estilo Dorico en el Espacio de Partituras y Popover Rápido de Notación](../04_adrs/0191_dorico_score_task_modes_and_quick_popover.md)
  - [ADR 0192: Coloreado Pedagógico de Notas en Vivo Estilo Yousician y Bucle de Práctica de Compases A-B](../04_adrs/0192_yousician_live_note_coloring_and_ab_measure_loop.md)
  - [ADR 0193: Barra Macro de 8 Controles Inteligentes Estilo Logic Pro Smart Controls en el Rack Modular](../04_adrs/0193_logic_pro_smart_controls_macro_bar_in_rack.md)
  - [ADR 0194: Paleta de Comandos Universal Unificada con Filtros de Categoría e Indexación de Activos](../04_adrs/0194_unified_universal_command_palette_and_category_filters.md)
- **Documento Funcional Base:**
  - [Especificación HCI Pro-Workstation](../03_technical_specifications/pro_workstation_ux_hci_specification.md)
  - [UC-197 (US-UX-05)](../02_use_cases/197_uc_contextual_right_inspector_and_hover_info_view.md)
  - [UC-198 (US-UX-06)](../02_use_cases/198_uc_focused_tuner_toolbar_and_melodyne_pitch_blobs.md)
  - [UC-199 (US-UX-07)](../02_use_cases/199_uc_dorico_score_task_modes_and_quick_popover.md)
  - [UC-200 (US-UX-08)](../02_use_cases/200_uc_yousician_live_note_coloring_and_ab_measure_loop.md)
  - [UC-201 (US-UX-09)](../02_use_cases/201_uc_logic_pro_smart_controls_macro_bar_in_rack.md)
  - [UC-202 (US-UX-10)](../02_use_cases/202_uc_unified_universal_command_palette_and_category_filters.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Consolidar una experiencia de estación de trabajo musical profesional en **Tunner** que reemplace diálogos modales recurrentes y barras saturadas por paneles contextuales no bloqueantes, modos de tarea bien delimitados, visualización histórica y pedagógica de afinación sobre el lienzo, controles macro unificados y búsqueda universal instantánea.

### 1.2 Backlog Canónico de la Ola 5 (`US-UX-05` a `US-UX-10`)

| ID Historia | Caso de Uso | ADR | Título de la Historia de Usuario | Widgets / Keys Canónicos Verificables | Suite de Pruebas Automatizadas |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `US-UX-05` | [UC-197](../02_use_cases/197_uc_contextual_right_inspector_and_hover_info_view.md) | [ADR 0189](../04_adrs/0189_contextual_right_inspector_and_hover_info_view.md) | Panel Inspector Contextual Derecho (Estilo Cubase/Dorico) y Hover Info View (Estilo Ableton Live) | `btn_toggle_right_inspector`, `studio_right_inspector_panel`, `studio_hover_info_view_text` | `test/core/design_system/us_ux_05_contextual_right_inspector_and_hover_info_test.dart` |
| `US-UX-06` | [UC-198](../02_use_cases/198_uc_focused_tuner_toolbar_and_melodyne_pitch_blobs.md) | [ADR 0190](../04_adrs/0190_focused_tuner_toolbar_and_melodyne_pitch_blobs.md) | Barra Enfocada del Afinador (Máximo 5 Acciones) y Monitor de Cápsulas de Afinación Estilo Melodyne | `tuner_focused_concert_pitch_btn`, `tuner_focused_instrument_btn`, `tuner_focused_temperament_btn`, `tuner_focused_drone_btn`, `tuner_focused_more_menu_btn`, `melodyne_pitch_blobs_monitor` | `test/features/tuner/us_ux_06_focused_tuner_toolbar_and_pitch_blobs_test.dart` |
| `US-UX-07` | [UC-199](../02_use_cases/199_uc_dorico_score_task_modes_and_quick_popover.md) | [ADR 0191](../04_adrs/0191_dorico_score_task_modes_and_quick_popover.md) | Modos de Tarea Estilo Dorico en Partitura (`Escribir`, `Reproducir`, `Mezcla Stems`, `Exportar`) y Popover Rápido | `score_task_mode_write_tab`, `score_task_mode_play_tab`, `score_task_mode_stems_tab`, `score_task_mode_export_tab`, `score_quick_popover_btn`, `score_quick_notation_popover`, `score_quick_popover_input` | `test/features/workspaces/us_ux_07_dorico_score_task_modes_and_popover_test.dart` |
| `US-UX-08` | [UC-200](../02_use_cases/200_uc_yousician_live_note_coloring_and_ab_measure_loop.md) | [ADR 0192](../04_adrs/0192_yousician_live_note_coloring_and_ab_measure_loop.md) | Coloreado Pedagógico de Notas en Vivo Estilo Yousician y Bucle de Práctica de Compases A-B | `yousician_live_feedback_badge`, `score_ab_loop_toggle_btn`, `score_ab_loop_set_a_btn`, `score_ab_loop_set_b_btn`, `score_ab_loop_range_label` | `test/features/workspaces/us_ux_08_yousician_live_note_coloring_and_ab_loop_test.dart` |
| `US-UX-09` | [UC-201](../02_use_cases/201_uc_logic_pro_smart_controls_macro_bar_in_rack.md) | [ADR 0193](../04_adrs/0193_logic_pro_smart_controls_macro_bar_in_rack.md) | Barra Macro de 8 Controles Inteligentes Estilo Logic Pro Smart Controls en el Rack Modular | `rack_smart_controls_macro_bar`, `rack_smart_controls_toggle_btn`, `smart_control_macro_0` .. `smart_control_macro_7` | `test/features/modular_rack/us_ux_09_logic_pro_smart_controls_macro_bar_test.dart` |
| `US-UX-10` | [UC-202](../02_use_cases/202_uc_unified_universal_command_palette_and_category_filters.md) | [ADR 0194](../04_adrs/0194_unified_universal_command_palette_and_category_filters.md) | Paleta de Comandos Universal Unificada (`Ctrl+K`) con Filtros de Categoría e Indexación de Activos | `command_palette_filter_all`, `command_palette_filter_actions`, `command_palette_filter_songs`, `command_palette_filter_files`, `command_palette_filter_instruments` | `test/features/navigation/us_ux_10_unified_universal_command_palette_test.dart` |

### 1.3 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Extensión de `StudioDesktopAppShell` y `MainAppShell` para el Inspector Contextual Derecho y el Hover Info View (`US-UX-05`).
  - Refactorización de la barra de acciones de `TunerScreen` a 5 controles enfocados con menú `Más` y widget `MelodynePitchBlobsMonitor` (`US-UX-06`).
  - Organización de `CompositionNotationWorkspaceView` en 4 modos de tarea estilo Dorico y popover rápido de entrada por texto (`US-UX-07`).
  - Motor de coloreado en vivo por cabeza de nota en `RealSheetMusicPainter` / `TunerViewModel` y bucle de compases A-B (`US-UX-08`).
  - Panel `SmartControlsMacroBar` de 8 diales/sliders macro en `ModularStudioRackView` y `ModularRackViewModel` (`US-UX-09`).
  - Filtros de categoría e indexación de canciones, archivos e instrumentos en `ProCommandPaletteModal` y `StudioCommandCatalogBuilder` (`US-UX-10`).
- **Excluido (Out-of-Scope):**
  - Modificaciones a los kernels nativos C/Rust o al algoritmo de detección de frecuencia fundamental YIN/MPM.
  - Cualquier integración con servicios en la nube o APIs externas (estrictamente prohibido por la constitución Offline-First en [AGENTS.md](../../AGENTS.md)).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x` (null-safety estricto, tipos inmutables en dominio).
  - Flutter SDK: Canal estable oficial (soporte completo para Linux y Windows Desktop).
  - Gestión de estado: `provider` (`ChangeNotifier`, `ValueListenableBuilder`) para aislar repintados de alta frecuencia.
- **Riesgo Tecnológico:**
  - **¿Introduce dependencias nativas o FFI?** No. Toda la lógica de UI, buffers circulares de blobs de afinación y aritmética de bucle A-B se ejecuta en Pure Dart y `CustomPainter`.
  - **¿Afecta el rendimiento del bucle principal de Flutter?** No; el monitor de blobs de afinación (`MelodynePitchBlobsMonitor`) utiliza una cola acotada de 24 elementos y `RepaintBoundary`, evitando asignaciones dinámicas innecesarias o bloqueos de frame.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [ ] Definir `PitchBlobTraceEntry` y la lógica de agregación de trazos de afinación en cents con cola FIFO acotada ($N_{\max} = 24$).
- [ ] Definir `LiveNoteHitStatus` (`pending`, `inTune`, `warning`, `outOfTune`), `ScoreTaskMode` (`write`, `play`, `stems`, `export`) y la aritmética de bucle de compases A-B ($M_A, M_B$) en `TunerViewModel`.
- [ ] Definir `SmartControlMacroSpec` y los métodos de ajuste normalizado para los 8 parámetros maestros en `ModularRackViewModel`.
- [ ] Ampliar `StudioCommandCatalogBuilder` con soporte para categorías canónicas (`Acciones`, `Canciones`, `Archivos`, `Instrumentos`).

### Paso 2: Capa de Infraestructura / Orquestación de Shell
- [ ] Implementar en `StudioDesktopAppShell` el soporte del panel lateral derecho colapsable (`studio_right_inspector_panel`, `btn_toggle_right_inspector`, `initialRightInspectorVisible`, `toggleRightInspector()`) y la telemetría de ayuda al pasar el cursor (`studio_hover_info_view_text`, `setHoverInfo()`).
- [ ] Conectar en `MainAppShell` el contenido contextual del Inspector Derecho según la pestaña activa y pasar `fileSystemService` a `StudioCommandCatalogBuilder.build`.

### Paso 3: Capa de Presentación (ViewModels y UI Canvas)
- [ ] Implementar en `TunerScreen` la barra enfocada de 5 controles (`tuner_focused_concert_pitch_btn`, `tuner_focused_instrument_btn`, `tuner_focused_temperament_btn`, `tuner_focused_drone_btn`, `tuner_focused_more_menu_btn`) y el lienzo `MelodynePitchBlobsMonitor` (`melodyne_pitch_blobs_monitor`).
- [ ] Implementar en `CompositionNotationWorkspaceView` los 4 modos de tarea estilo Dorico (`score_task_mode_write_tab`, `score_task_mode_play_tab`, `score_task_mode_stems_tab`, `score_task_mode_export_tab`), el popover rápido de notación (`score_quick_popover_btn`, `score_quick_notation_popover`, `score_quick_popover_input`) y los controles de bucle A-B (`score_ab_loop_toggle_btn`, `score_ab_loop_set_a_btn`, `score_ab_loop_set_b_btn`, `score_ab_loop_range_label`).
- [ ] Actualizar `RealSheetMusicPainter` para colorear cada cabeza de nota según su `LiveNoteHitStatus` y mostrar `yousician_live_feedback_badge`.
- [ ] Incorporar `rack_smart_controls_macro_bar` con los 8 controles macro (`smart_control_macro_0` a `smart_control_macro_7`) en `ModularStudioRackView`.
- [ ] Incorporar los chips de filtro de categoría (`command_palette_filter_all`, `command_palette_filter_actions`, `command_palette_filter_songs`, `command_palette_filter_files`, `command_palette_filter_instruments`) en `ProCommandPaletteModal`.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Ejecutar las 6 nuevas suites de pruebas unitarias y de widgets (`us_ux_05` a `us_ux_10`) junto con las suites de regresión (`us_ux_01` a `us_ux_04`).
- [ ] Ejecutar `flutter analyze` verificando cero advertencias y cero errores de linter.
- [ ] Validar el presupuesto de memoria y CPU sin bucles `busy-waiting`.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

Cada historia de usuario (`US-UX-05` a `US-UX-10`) se diseña de forma modular y retrocompatible:
- **Punto de Restauración Git:** Commit estable posterior a la Ola 4 (`US-UX-01` a `US-UX-04`).
- **Mitigación Inmediata:**
  - En `US-UX-05`, `initialRightInspectorVisible` tiene valor por defecto `false`, por lo que no altera el layout inicial de las pruebas existentes.
  - En `US-UX-06`, todas las acciones secundarias siguen disponibles dentro de `tuner_focused_more_menu_btn` conservando sus callbacks originales.
  - En `US-UX-07` y `US-UX-08`, el modo inicial predeterminado o la selección de pestañas mantiene accesibles todos los controles del editor de partituras y de la barra de stems.
  - En `US-UX-09`, `rack_smart_controls_macro_bar` es colapsable mediante `rack_smart_controls_toggle_btn`.
  - En `US-UX-10`, el filtro inicial `Todo` (`command_palette_filter_all`) preserva el comportamiento de búsqueda global existente en `ProCommandPaletteModal`.

---

## 5. Criterios de Aceptación (Definition of Done)

Para que este plan se considere completado y listo para merge:
- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md) (Pure Dart en dominio, Offline-First, cero emojis en documentación).
- [ ] Cero busy-waiting loops en Isolates, ViewModels y pintores de lienzo.
- [ ] Las 6 suites de pruebas (`us_ux_05` a `us_ux_10`) y las suites de regresión pasando al 100%.
- [ ] Los 6 ADRs (`0189` a `0194`), los 6 Casos de Uso (`197` a `202`) y la Especificación Técnica HCI redactados y verificados en `docs/`.
- [ ] Aprobación explícita del creador/mantenedor principal.
