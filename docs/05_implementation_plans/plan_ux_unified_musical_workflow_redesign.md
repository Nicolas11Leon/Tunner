# Plan de Implementación Maestro: Rediseño UI/UX para Flujo Musical Unificado (US-UX-01 a US-UX-04)

Este documento formaliza el plan maestro de ingeniería UI/UX para unificar los flujos operativos centrales de **Tunner**: el espacio de partitura con selector de repertorio y barra en línea de 4 Stems/Minus-One (`US-UX-01`), la permanencia del afinador en vivo y acceso directo al Laboratorio Acústico en Modo Pro (`US-UX-02`), las acciones musicales contextuales en el Explorador de Proyecto (`US-UX-03`) y el despeje ergonómico vertical del shell de escritorio mediante barra CLI colapsable (`US-UX-04`).

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-UX-UNIFIED-WORKFLOW-2026-0189`
- **Título de la Implementación:** Rediseño UI/UX de Flujo Musical Unificado, Afinador Persistente Pro, Acciones Contextuales del Explorador y Shell Ergonómico
- **Fase del Proyecto:** Fase 2 (Experiencia de Escritorio, Orquestación de Workspaces y Ergonomía Pedagógica)
- **Estado:** Aprobado
- **ADRs Relacionados:**
  - [ADR 0185: Unificación del Espacio de Trabajo de Partituras y Barra Integrada en Línea de Stems y Minus-One](../04_adrs/0185_unified_score_workspace_and_inline_stems_dock.md)
  - [ADR 0186: Afinador Estroboscópico Permanente y Acceso Integrado al Laboratorio Acústico en Modo Pro](../04_adrs/0186_permanent_strobe_tuner_and_integrated_acoustic_lab.md)
  - [ADR 0187: Acciones Musicales Contextuales por Tipo de Archivo en el Explorador de Proyecto](../04_adrs/0187_contextual_musical_actions_in_project_explorer.md)
  - [ADR 0188: Despeje Ergonómico Vertical del Shell de Escritorio y Barra de Comandos CLI Colapsable](../04_adrs/0188_ergonomic_desktop_shell_and_collapsible_command_bar.md)
- **Documentos Funcionales Base:**
  - [UC-193 (US-UX-01)](../02_use_cases/193_uc_unified_score_workspace_and_inline_stems_dock.md)
  - [UC-194 (US-UX-02)](../02_use_cases/194_uc_permanent_strobe_tuner_and_integrated_acoustic_lab.md)
  - [UC-195 (US-UX-03)](../02_use_cases/195_uc_contextual_musical_actions_in_project_explorer.md)
  - [UC-196 (US-UX-04)](../02_use_cases/196_uc_ergonomic_desktop_shell_and_collapsible_command_bar.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Eliminar los saltos de contexto y modales bloqueantes en los cuatro recorridos críticos del usuario (edición/práctica con partitura y stems, afinación continua en modo Pro, enrutamiento explícito desde el explorador de archivos y aprovechamiento de altura vertical en escritorio), garantizando latencia visual fluida (60/120 FPS), operación 100% offline y adherencia estricta a Clean Architecture según [AGENTS.md](../../AGENTS.md).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `US-UX-01` (`CompositionNotationWorkspaceView`): Selector rápido de repertorio/proyecto (`score_workspace_song_picker_btn` + `song_picker_import_from_disk_btn`) y barra integrada en línea de 4 Stems y Minus-One (`inline_stems_minus_one_bar`, `inline_minus_one_toggle_chip`, `inline_stem_toggle_<id>`).
  - `US-UX-02` (`TunerScreen`): Barra persistente de telemetría acústica y control de micrófono (`pro_persistent_tuner_readout_bar`, `pro_persistent_mic_toggle_btn`) en `AppDisplayMode.conservatoryPro`, con botones de foco directo al Laboratorio Acústico (`tuner_quick_focus_pro_lab_btn`) y al Estroboscopio (`tuner_quick_focus_strobe_btn`).
  - `US-UX-03` (`IStudioWorkspaceFileSystem`, `StudioFileTreeTile`, `MainAppShell`): Contrato `StudioFileMusicalAction` (`transformToScoreAndStems`, `loadInDjDeckA`, `loadInDjDeckB`, `openInScoreEditor`), filtrado contextual por `StudioFileType` y despacho en `MainAppShell._handleFileMusicalAction`.
  - `US-UX-04` (`StudioDesktopAppShell`): Parámetro `initialCommandPromptVisible`, método `toggleCommandPromptBar` y botón `btn_toggle_command_prompt_bar` en la barra de estado inferior para liberar espacio vertical en el lienzo central.
- **Excluido (Out-of-Scope):**
  - Modificaciones a los algoritmos DSP de detección de tono (`YIN` / `MPM`), transcodificación FFmpeg o parser de MusicXML/PDF (ya cubiertos en `US-FS-01` a `US-FS-05`).
  - Servicios remotos, telemetría en la nube o sincronización de red (prohibidos por la regla Offline-First en `AGENTS.md`).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x` (null-safety estricto, Pure Dart en `lib/domain` y `lib/core/file_system/domain`).
  - Flutter SDK: Canal estable oficial (Linux y Windows Desktop).
  - Gestión de estado y reactividad: `provider` (`TunerViewModel`) y `ValueListenableBuilder<TunerAcousticTelemetry>` para actualizaciones de 60 Hz sin reconstruir árboles completos de widgets.
- **Riesgo Tecnológico:**
  - **FFI / Hilos nativos:** Ninguna de las cuatro historias introduce nuevos bindings FFI ni bucles `busy-waiting`; toda la actualización visual opera de forma dirigida por eventos y `ValueListenable`.
  - **Rendimiento del bucle principal de Flutter:** La barra persistente `pro_persistent_tuner_readout_bar` encapsula su `ValueListenableBuilder` para evitar repintados del pentagrama SMuFL (`RealSheetMusicPainter`) durante los frames de telemetría del afinador.
  - **Integridad de Capas (Clean Architecture):** `StudioFileMusicalAction` se define en `lib/core/file_system/domain/i_studio_workspace_file_system.dart` usando únicamente tipos puros de dominio, manteniendo cero dependencias de `lib/core/file_system/` hacia `lib/features/`.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio y Contratos Desacoplados
- [ ] **US-UX-03 (`IStudioWorkspaceFileSystem`):** Definir el enum `StudioFileMusicalAction` (`transformToScoreAndStems`, `loadInDjDeckA`, `loadInDjDeckB`, `openInScoreEditor`), el typedef `StudioFileMusicalActionCallback` y la propiedad opcional `onExecuteMusicalAction` en `lib/core/file_system/domain/i_studio_workspace_file_system.dart` y `NoOpStudioWorkspaceFileSystem` (así como implementaciones concretas).
- [ ] Verificar que `TunerViewModel` expone de forma limpia `workspaceScores`, `curatedLibrary`, `loadSongPackage`, `importScoreFromFilePicker`, `isMinusOneActive`, `toggleMinusOneMode`, `mixerConsole.stems`, `toggleTrackMute`, `telemetryListenable`, `toggleRecording` y `setWorkspace`.

### Paso 2: Capa de Orquestación y Shell de Escritorio
- [x] **US-UX-04 (`StudioDesktopAppShell`):** Soporte de `initialCommandPromptVisible`, `StudioDesktopAppShellState.toggleCommandPromptBar()`, `isCommandPromptVisible` y chip interactivo `btn_toggle_command_prompt_bar` en `lib/core/design_system/organisms/studio_desktop_app_shell.dart`.
- [ ] **US-UX-04 (`MainAppShell`):** Evaluar y ajustar el valor inicial de `initialCommandPromptVisible` en la instancia de `StudioDesktopAppShell` dentro de `lib/features/navigation/presentation/main_app_shell.dart` según la ergonomía por defecto de escritorio.
- [ ] **US-UX-03 (`MainAppShell._handleFileMusicalAction`):** Registrar `_fileSystemService.onExecuteMusicalAction = _handleFileMusicalAction` en `initState` (con limpieza segura en `dispose`), reutilizando `_resolveFileBytes` y `_audioTranscoder.transcodeToWav16BitPcm` para despachar hacia `Deck A`, `Deck B` o Editor de Partituras / Stems.

### Paso 3: Capa de Presentación (Workspaces, Afinador Pro y Explorador)
- [ ] **US-UX-01 (`CompositionNotationWorkspaceView`):** Incorporar `Key('score_workspace_song_picker_btn')` con listado de proyecto/repertorio y acción `Key('song_picker_import_from_disk_btn')`; añadir `Key('inline_stems_minus_one_bar')` con `Key('inline_minus_one_toggle_chip')` y `Key('inline_stem_toggle_<id>')` sin provocar desbordamientos horizontales.
- [ ] **US-UX-02 (`TunerScreen`):** Montar `Key('pro_persistent_tuner_readout_bar')` en `AppDisplayMode.conservatoryPro` visible sobre todos los `WorkspaceType`, con `Key('pro_persistent_mic_toggle_btn')`, `Key('tuner_quick_focus_pro_lab_btn')` y `Key('tuner_quick_focus_strobe_btn')`.
- [ ] **US-UX-03 (`StudioFileTreeTile`):** Filtrar en `_buildContextMenu` las acciones de `StudioFileMusicalAction` según `file.fileType` (`audioWav` vs `score` vs otros tipos) y disparar `service.onExecuteMusicalAction?.call(file, action)`.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Implementar y validar `test/features/workspaces/us_ux_01_unified_score_and_stems_flow_test.dart`.
- [ ] Implementar y validar `test/features/tuner/us_ux_02_unified_tuner_pro_lab_flow_test.dart`.
- [ ] Implementar y validar `test/core/file_system/us_ux_03_contextual_musical_file_actions_test.dart`.
- [ ] Implementar y validar `test/core/design_system/us_ux_04_collapsible_command_bar_shell_test.dart`.
- [ ] Ejecutar `flutter analyze` (cero errores y cero advertencias) y `flutter test` sobre todas las suites nuevas y de regresión (`workspaces`, `tuner`, `file_system`, `design_system`, `navigation`).

---

## 4. Estrategia de Rollback (Plan de Contingencia)

Cada historia (`US-UX-01` a `US-UX-04`) está aislada en su propio ADR, Caso de Uso y archivo de pruebas automatizadas:

- **Punto de Restauración Git:** Commit base en `main` previo a la integración individual de cada PR atómico por ADR (`0185`–`0188`).
- **Mitigación Inmediata:**
  - En `US-UX-01`, los callbacks existentes (`onOpenLibraryModal`, `onOpenMixerModal`) permanecen funcionales, permitiendo restaurar el acceso modal completo de inmediato si se detectara alguna regresión en resoluciones extremas.
  - En `US-UX-02`, la barra persistente es aditiva sobre `TunerScreen` y no altera `EssentialTunerPanel` ni `StrobeTunerWidget`.
  - En `US-UX-03`, `onOpenFile` sigue operando como ruta por defecto independiente de `onExecuteMusicalAction`.
  - En `US-UX-04`, `initialCommandPromptVisible` permite revertir la visibilidad inicial por defecto mediante un único booleano de configuración.

---

## 5. Criterios de Aceptación (Definition of Done)

Para considerar completado el rediseño UI/UX:
- [ ] Código adherido estrictamente a [AGENTS.md](../../AGENTS.md) (Pure Dart en dominio, cero busy-waiting, ejecución 100% offline, cero emojis en documentación).
- [ ] Los 4 ADRs (`0185`–`0188`), 4 Casos de Uso (`193`–`196`) y este Plan Maestro revisados y aprobados en `docs/`.
- [ ] Las 4 suites de pruebas (`us_ux_01` a `us_ux_04`) y las suites de regresión de `workspaces`, `tuner`, `file_system`, `design_system` y `navigation` pasando al 100%.
- [ ] `flutter analyze` reportando cero errores y cero advertencias de linter.
- [ ] Aprobación explícita del creador y mantenedor principal.
