# ADR 0185: Unificación del Espacio de Trabajo de Partituras y Barra Integrada en Línea de Stems y Minus-One

- **Estado:** Aprobado
- **Fecha:** 2026-11-24
- **Autor:** Nicolás León
- **Caso de Uso Relacionado:** [UC-193](../02_use_cases/193_uc_unified_score_workspace_and_inline_stems_dock.md)

---

## 1. Contexto

En `CompositionNotationWorkspaceView` (`lib/features/workspaces/presentation/composition_notation_workspace_view.dart`), la selección de obras musicales y el control de mezcla de pistas (4 Stems y modo Minus-One) dependían de múltiples diálogos modales desconectados (`TunerLibraryModal`, `TunerMixerModal`, `SongDecomposerModal`):

1. **Fragmentación del Selector de Obra y Repertorio:** El encabezado de la partitura mostraba el título de `viewModel.activePackage`, pero delegaba toda selección de repertorio curado, partituras del espacio de trabajo e importación externa hacia `widget.onOpenLibraryModal`, obligando al usuario a abandonar el contexto visual del pentagrama para cambiar de canción o importar un archivo del disco.
2. **Fricción Operativa en el Control de Stems y Minus-One:** Para silenciar o aislar uno de los 4 Stems (`lead_stem`, `harmony_stem`, `bass_stem`, `rhythm_stem`) o activar la práctica Minus-One (`toggleMinusOneMode`), el músico debía abrir repetidamente el modal completo `TunerMixerModal`, perdiendo visibilidad simultánea de la partitura SMuFL y de los controles de transporte (`startSongWithCountIn`, `stopSong`, `toggleScorePlayback`).
3. **Necesidad de Continuidad Visual y Ergonomía Offline:** Siguiendo `AGENTS.md`, la experiencia pedagógica y de lectura de partituras debe minimizar la latencia cognitiva y mantener 100% local la conmutación de pistas sin superponer ventanas modales bloqueantes.

---

## 2. Decisión

Se adopta un diseño de **Espacio de Trabajo Unificado de Partitura con Selector Rápido y Dock en Línea de Stems / Minus-One** dentro de `CompositionNotationWorkspaceView`:

1. **Selector Interactivo Unificado de Repertorio y Proyecto (`score_workspace_song_picker_btn`):**
   - El chip/botón de cabecera de obra (`Key('score_workspace_song_picker_btn')`) despliega un selector contextual unificado (hoja/pop-over ligero de selección rápida) que agrupa:
     - Las obras del espacio de trabajo actual (`viewModel.workspaceScores`) y piezas del repertorio curado (`viewModel.curatedLibrary`).
     - Una acción directa de ingesta desde disco identificada con `Key('song_picker_import_from_disk_btn')`, conectada a `viewModel.importScoreFromFilePicker()` (o flujo equivalente de importación unificada), permitiendo cargar archivos `.mp3`, `.wav`, `.flac`, `.mid`, `.musicxml` o `.pdf` sin navegar fuera del espacio de composición.
   - Al seleccionar una obra del selector, se invoca directamente `viewModel.loadSongPackage(package)` manteniendo el contexto de edición y lectura sobre el lienzo SMuFL.

2. **Barra Integrada en Línea de 4 Stems y Minus-One (`inline_stems_minus_one_bar`):**
   - Se incorpora un dock compacto horizontal (`Key('inline_stems_minus_one_bar')`) directamente acoplado al flujo de `CompositionNotationWorkspaceView`, eliminando la dependencia obligatoria de abrir modales superpuestos durante el ensayo:
     - **Conmutador Directo Minus-One (`Key('inline_minus_one_toggle_chip')`):** Expone el estado `viewModel.isMinusOneActive` y dispara `viewModel.toggleMinusOneMode()` en un solo clic, atenuando la pista guía del usuario (`viewModel.minusOneUserTrackId`) mientras mantiene el acompañamiento activo.
     - **Chips de Conmutación por Stem (`Key('inline_stem_toggle_<id>')`):** Itera sobre `viewModel.mixerConsole.stems` renderizando un chip interactivo por cada pista/stem (`inline_stem_toggle_${track.id}`, cubriendo los 4 Stems canónicos `lead_stem`, `harmony_stem`, `bass_stem`, `rhythm_stem` o pistas de la partitura activa) con estado visual claro de activo/silenciado (`track.isMuted`) y disparo directo de `viewModel.toggleTrackMute(track.id)`.
   - Se conserva el acceso opcional a `TunerMixerModal` (`widget.onOpenMixerModal`) para ajustes avanzados de ganancia fina y panorama por canal, evitando duplicar controles pesados en la barra en línea.

3. **Preservación de Clean Architecture:**
   - Toda la lógica de estado de mezcla (`MixerConsoleEntity`, `AudioStemTrack`) y sesiones Minus-One (`MinusOneSessionEntity`) permanece en `lib/domain` y `TunerViewModel`; `CompositionNotationWorkspaceView` únicamente proyecta el estado reactivo y despacha intenciones al ViewModel.

---

## 3. Consecuencias

### 3.1 Positivas
- **Cero Modales Superpuestos en Flujo Principal:** Cambiar de canción, importar desde disco, alternar Minus-One y silenciar stems individuales ocurre sin ocultar el pentagrama tipográfico SMuFL.
- **Retroalimentación Inmediata para Ensayo y Transcripción:** Tras transcribir un audio a partitura de 4 Stems (`US-FS-02`), el usuario visualiza y controla inmediatamente cada Stem desde la misma vista del pentagrama.
- **Alineación con Modo Compacto y Pantallas Desktop:** Los controles en línea usan desplazamiento horizontal seguro (`SingleChildScrollView` / `Wrap`) evitando desbordamientos (`RenderFlex overflow`) en ventanas estrechas.

### 3.2 Compromisos y Mitigaciones
- **Densidad Vertical en el Lienzo del Pentagrama:** Añadir una barra en línea consume altura vertical. Se mitiga manteniendo la barra compacta (`visualDensity: VisualDensity.compact`) y combinándola con el despeje vertical del shell de escritorio (`ADR 0188`).

---

## 4. Verificación

- **Caso de Uso Funcional:** [UC-193](../02_use_cases/193_uc_unified_score_workspace_and_inline_stems_dock.md).
- **Plan de Implementación Asociado:** [Plan Maestro de Rediseño UI/UX](../05_implementation_plans/plan_ux_unified_musical_workflow_redesign.md).
- **Suite de Pruebas Objetivo (`US-UX-01`):** `test/features/workspaces/us_ux_01_unified_score_and_stems_flow_test.dart`, validando:
  - Apertura del selector `score_workspace_song_picker_btn`, selección de repertorio y acción `song_picker_import_from_disk_btn`.
  - Renderizado de `inline_stems_minus_one_bar`, conmutación de `inline_minus_one_toggle_chip` y silenciamiento individual mediante `inline_stem_toggle_<id>`.
