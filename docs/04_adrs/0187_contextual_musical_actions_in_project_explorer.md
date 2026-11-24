# ADR 0187: Acciones Musicales Contextuales por Tipo de Archivo en el Explorador de Proyecto

- **Estado:** Aprobado
- **Fecha:** 2026-11-24
- **Autor:** Nicolás León
- **Caso de Uso Relacionado:** [UC-195](../02_use_cases/195_uc_contextual_musical_actions_in_project_explorer.md)

---

## 1. Contexto

Tras habilitar la apertura perezosa desde disco y el enrutamiento dual (`ADR 0183`), hacer clic sobre un archivo en `StudioVsCodeExplorerWidget` disparaba únicamente una acción implícita única (`_fileSystemService.onOpenFile(file)`). Esto generaba ambigüedad para archivos polivalentes dentro del estudio:

1. **Audio (`.wav`, `.mp3`, `.flac`, etc.):** Un mismo archivo de audio puede utilizarse para transcribirlo a partitura con sus 4 Stems, cargarlo en el `Deck A` o cargarlo en el `Deck B` de la Consola DJ para mezcla en vivo. El menú contextual de `StudioFileTreeTile` (`lib/core/file_system/presentation/studio_file_tree_tile.dart`) solo ofrecía operaciones genéricas de sistema de archivos (`open_in_explorer`, `rename`, `move`, `delete`).
2. **Partituras y Notación (`.musicxml`, `.mid`, `.abc`, `.pdf`, etc.):** El usuario necesitaba abrir explícitamente una partitura en el Editor de Partituras o enrutarla hacia su procesamiento de Stems sin depender de recordar el comportamiento por defecto del clic simple.
3. **Restricción de Clean Architecture (`AGENTS.md`):** `lib/core/file_system/` pertenece a la infraestructura/núcleo transversal del sistema de archivos y **no puede importar** `TunerViewModel`, `DjConsoleViewModel`, `MainAppShell` ni ningún módulo de `lib/features/`.

---

## 2. Decisión

Se define un contrato puro de **Acciones Musicales Contextuales** desacoplado por callback entre el núcleo del sistema de archivos y la capa de orquestación del shell:

1. **Enumeración y Callback de Dominio en `IStudioWorkspaceFileSystem` (`lib/core/file_system/domain/i_studio_workspace_file_system.dart`):**
   - Se introduce el enum puro `StudioFileMusicalAction` con las intenciones musicales explícitas:
     - `transformToScoreAndStems`: Transcribir/descomponer el archivo hacia el Editor de Partituras y sus 4 Stems.
     - `loadInDjDeckA`: Cargar la pista en el `Deck A` de la Consola DJ.
     - `loadInDjDeckB`: Cargar la pista en el `Deck B` de la Consola DJ.
     - `openInScoreEditor`: Abrir directamente la partitura en el Editor de Notación SMuFL.
   - Se define el typedef `StudioFileMusicalActionCallback = void Function(StudioFileEntity file, StudioFileMusicalAction action)` y la propiedad `StudioFileMusicalActionCallback? onExecuteMusicalAction` en `IStudioWorkspaceFileSystem` (con implementación por defecto nula/no-op en `NoOpStudioWorkspaceFileSystem` y en los servicios concretos).

2. **Menú Contextual Filtrado por `StudioFileType` en `StudioFileTreeTile`:**
   - `StudioFileTreeTile._buildContextMenu` evalúa `file.fileType` para exponer únicamente las acciones musicales semánticamente válidas junto a las operaciones de disco:
     - Para `StudioFileType.audioWav`: expone `transformToScoreAndStems`, `loadInDjDeckA` y `loadInDjDeckB`.
     - Para `StudioFileType.score`: expone `openInScoreEditor` (y `transformToScoreAndStems` cuando aplique descomposición/adaptación a Stems).
     - Para otros tipos (`tuningPreset`, `djBlueprint`, `rackTool`, `project`, `genericFile`): conserva únicamente las operaciones de gestión de archivos sin contaminar el menú con acciones incompatibles.
   - Al seleccionar una acción musical, `StudioFileTreeTile` selecciona el nodo e invoca `service.onExecuteMusicalAction?.call(file, action)` manteniendo `core/file_system` completamente libre de dependencias hacia `features/`.

3. **Despacho Centralizado en `MainAppShell._handleFileMusicalAction`:**
   - `MainAppShell` (`lib/features/navigation/presentation/main_app_shell.dart`) vincula `_fileSystemService.onExecuteMusicalAction = _handleFileMusicalAction` en su ciclo de inicialización (y lo limpia en `dispose`).
   - `_handleFileMusicalAction(StudioFileEntity file, StudioFileMusicalAction action)` reutiliza la infraestructura de resolución perezosa desde disco (`_resolveFileBytes(file)`) y transcodificación FFmpeg (`_audioTranscoder.transcodeToWav16BitPcm`) establecida en `ADR 0183`:
     - **`transformToScoreAndStems`:** Transcodifica si es audio comprimido, invoca `vm.importScoreFromBytes(...)` (o `vm.loadSongPackage(...)` si ya es `SongPackage`) y navega al Editor de Partituras / Stems (`_navigateToTab(4)` o vista de composición).
     - **`loadInDjDeckA` / `loadInDjDeckB`:** Carga los bytes WAV PCM en `_djConsoleViewModel.loadDeckTrack(deckId: 'A' | 'B', ...)` y navega a la Consola DJ (`_navigateToTab(5)`).
     - **`openInScoreEditor`:** Abre la partitura en `TunerViewModel` y navega al Editor de Partituras (`_navigateToTab(4)`).

---

## 3. Consecuencias

### 3.1 Positivas
- **Desambiguación Total para el Usuario:** El músico decide explícitamente si un `.mp3` o `.wav` del proyecto va al `Deck A`, al `Deck B` o a transcripción en partitura y 4 Stems.
- **Inversión de Dependencias Estricta:** `lib/core/file_system/` solo conoce el enum `StudioFileMusicalAction` y `StudioFileEntity`; todo el conocimiento de tabs, `TunerViewModel` y `DjConsoleViewModel` reside en `MainAppShell`.
- **Reutilización de Pipeline Seguro:** No se duplica lógica de lectura en disco ni transcodificación FFmpeg; `_handleFileMusicalAction` comparte la resolución segura `_resolveFileBytes` con `_handleOpenFile`.

### 3.2 Compromisos y Mitigaciones
- **Sincronización de Limpieza de Callbacks:** Al igual que `onOpenFile`, `MainAppShell.dispose()` debe limpiar `onExecuteMusicalAction` únicamente si sigue apuntando a `_handleFileMusicalAction`, evitando fugas de memoria en pruebas de widgets secuenciales.

---

## 4. Verificación

- **Caso de Uso Funcional:** [UC-195](../02_use_cases/195_uc_contextual_musical_actions_in_project_explorer.md).
- **Plan de Implementación Asociado:** [Plan Maestro de Rediseño UI/UX](../05_implementation_plans/plan_ux_unified_musical_workflow_redesign.md).
- **Suite de Pruebas Objetivo (`US-UX-03`):** `test/core/file_system/us_ux_03_contextual_musical_file_actions_test.dart`, validando:
  - Filtrado de acciones en `StudioFileTreeTile` según `StudioFileType.audioWav` vs `StudioFileType.score` vs `StudioFileType.genericFile`.
  - Disparo del callback `IStudioWorkspaceFileSystem.onExecuteMusicalAction` con la variante correcta de `StudioFileMusicalAction`.
  - Enrutamiento en `MainAppShell._handleFileMusicalAction` hacia `Deck A`, `Deck B` y Editor de Partituras / Stems.
