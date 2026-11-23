# Reporte de Auditoría Forense MCP 17: Persistencia, Workspaces, Navegación, Personalización y Composición Raíz

## Metadatos de Auditoría

- **ID del Reporte:** `AUDIT-MCP-2026-17`
- **Módulos Auditados:** `lib/features/persistence/`, `lib/features/workspaces/`, `lib/features/navigation/`, `lib/features/customization/` y `lib/app/`
- **Total de Archivos `.dart` Auditados:** 30 (4 en `persistence/`, 6 en `workspaces/`, 15 en `navigation/`, 2 en `customization/`, 3 en `app/`)
- **Casos de Uso Asociados:** `UC-11`, `UC-13`, `UC-22`, `UC-35`, `UC-46`, `UC-50`, `UC-51`, `UC-52`, `UC-56`, `UC-71`..`UC-77`, `UC-89`, `UC-101`, `UC-122`, `UC-123`, `UC-126`, `UC-137`, `UC-138`, `UC-172`, `UC-173`, `UC-174`, `UC-182`, `UC-183`, `UC-186`
- **Estado de Preparación Headless (Pure Dart):** `Bloqueado por acoplamientos críticos` (requiere desacoplar `AppUserSettingsEntity` de `tunner_theme.dart`, eliminar `path_provider` de `JsonLocalPersistenceService` y extraer `HeadlessCompositionRoot` desde `StudioCompositionRoot`)

---

## 1. Inventario Archivo por Archivo

### 1.1 Persistencia (`lib/features/persistence/`) — 4 archivos

| Archivo | Clases / Enums Principales | Métodos / Propiedades Clave | Casos de Uso |
| :--- | :--- | :--- | :--- |
| `lib/features/persistence/domain/i_local_persistence_service.dart` | `ILocalPersistenceService`, `InMemoryLocalPersistenceService` | `loadSettings()`, `saveSettings(AppUserSettingsEntity)`, `clearSettings()` | `UC-13`, `UC-126`, `UC-172` |
| `lib/features/persistence/domain/app_user_settings_entity.dart` | `AppDisplayMode`, `AppUserSettingsEntity` | 28 propiedades de configuración global (pitch A4, tema, instrumento, BPM, temperamento, paletas custom, historial de sesiones/grabaciones, multipista, presets, `workspaceScores`, `learnerProfile`, `activeWorkspace`, calibración mic/rigor, motor DSP, FPS, precisión cents, `workspaceConfiguration`, Ebbinghaus, tareas, lecciones, mixer, `activeScoreId`); `copyWith()`, `toMap()`, `fromMap()`, `toJson()`, `fromJson()` | `UC-11`, `UC-13`, `UC-22`, `UC-35`, `UC-172`, `UC-183` |
| `lib/features/persistence/data/json_local_persistence_service.dart` | `JsonLocalPersistenceService` | `loadSettings()`, `saveSettings(...)` con serialización encadenada (`_pendingSaveOperation`) y escritura atómica `.tmp` + `rename`, `clearSettings()` con limpieza de temporales huérfanos | `UC-13`, `UC-126`, `UC-172` |
| `lib/features/persistence/data/memory_persistence_service.dart` | `MemoryPersistenceService` | Implementación en memoria determinista de `ILocalPersistenceService` para tests y entornos sin disco | `UC-13`, `UC-126` |

### 1.2 Workspaces (`lib/features/workspaces/`) — 6 archivos

| Archivo | Clases / Enums Principales | Métodos / Propiedades Clave | Casos de Uso |
| :--- | :--- | :--- | :--- |
| `lib/features/workspaces/domain/workspace_type.dart` | `WorkspaceType`, `WorkspaceConfigurationEntity` | `WorkspaceType` (`learning`, `composition`, `production`), `displayName`, `tagline`, `serializedKey`, `fromSerializedKey()`; `WorkspaceConfigurationEntity.defaultFor()`, `toMap()`, `fromMap()`, `copyWith()` | `UC-35`, `UC-172`, `UC-182` |
| `lib/features/workspaces/presentation/learning_practice_workspace_view.dart` | `LearningPracticeWorkspaceView` | Vista del espacio Aprender: afinador estroboscópico, perfil pedagógico, metrónomo, grabadora, autotune | `UC-35`, `UC-182` |
| `lib/features/workspaces/presentation/composition_notation_workspace_view.dart` | `CompositionNotationWorkspaceView` | Vista del espacio Componer: lienzo SMuFL, transporte, editor de partituras, descompositor, exportación MIDI/WAV | `UC-35`, `UC-182` |
| `lib/features/workspaces/presentation/production_acoustic_lab_workspace_view.dart` | `ProductionAcousticLabWorkspaceView` | Vista del espacio Producir: calibración A4, temperamentos, espectrograma FFT, analizador de acordes, autotune | `UC-35`, `UC-182` |
| `lib/features/workspaces/presentation/polyphonic_synth_modal.dart` | `PolyphonicSynthModal` | Modal de control tímbrico del `polyphonicVoicePool` acoplado al pentagrama SMuFL | `UC-105`, `UC-149` |
| `lib/features/workspaces/presentation/workspace_switch_bar.dart` | `WorkspaceSwitchBar` | Conmutador visual de `WorkspaceType` (`learning`, `composition`, `production`) | `UC-35`, `UC-182` |

### 1.3 Navegación (`lib/features/navigation/`) — 15 archivos

| Archivo | Clases / Enums Principales | Métodos / Propiedades Clave | Casos de Uso |
| :--- | :--- | :--- | :--- |
| `lib/features/navigation/domain/app_tool_item.dart` | `AppToolCategory`, `AppToolItem`, `AppToolCatalog` | 7 categorías, 21 herramientas registradas en `AppToolCatalog.tools`, `searchTools(String)` con normalización diacrítica | `UC-46`, `UC-56` |
| `lib/features/navigation/presentation/app_tool_item_ui_ext.dart` | `AppToolCategoryUiExt`, `AppToolItemUiExt` | Resolución de `iconKey` a `IconData` Material | `UC-46` |
| `lib/features/navigation/presentation/contextual_help_sheet.dart` | `ToolHelpItem`, `ToolHelpCatalog`, modal de ayuda | Catálogo de ayuda pedagógica/técnica con fórmulas acústicas y atajos de teclado | `UC-51` |
| `lib/features/navigation/presentation/home_dashboard_screen.dart` | `HomeDashboardScreen` | Hub Pro-DAW con 5 módulos principales, métricas de calibración y lanzadores rápidos | `UC-46`, `UC-101`, `UC-174` |
| `lib/features/navigation/presentation/keyboard_shortcuts_modal.dart` | `KeyboardShortcutsCheatSheetModal` | Matriz visual de atajos de teclado estándar de la industria | `UC-50`, `UC-51`, `UC-52` |
| `lib/features/navigation/presentation/main_app_shell.dart` | `MainAppShell`, `_MainAppShellState` | Shell maestro de 1489 líneas: pestañas, `StudioDesktopAppShell`, `TunnerOsKernel`, atajos globales, docking, terminal drawer y composición de ViewModels | `UC-46`, `UC-72`, `UC-81`, `UC-138`, `UC-173`, `UC-182` |
| `lib/features/navigation/presentation/pro_command_palette_modal.dart` | `CommandItem`, `ProCommandPaletteModal` | Paleta de comandos estilo Spotlight con navegación por teclado | `UC-50`, `UC-137` |
| `lib/features/navigation/presentation/quick_action_dock_widget.dart` | `QuickActionDockWidget` | Barra flotante colapsable de transporte rápido, metrónomo, grabación y paleta | `UC-50` |
| `lib/features/navigation/presentation/studio_command_catalog_builder.dart` | `StudioCommandCatalogBuilder` | Constructor declarativo de 25+ `CommandItem` ejecutables | `UC-50`, `UC-124`, `UC-137` |
| `lib/features/navigation/presentation/studio_keyboard_intents.dart` | 20+ subclases de `Intent` | Intenciones de teclado DAW (`TogglePlayIntent`, `IncrementBpmIntent`, `CalibrateReferencePitchIntent`, `PanicMuteIntent`, etc.) | `UC-50`, `UC-52`, `UC-137` |
| `lib/features/navigation/presentation/studio_prompt_suggestions_builder.dart` | `StudioPromptSuggestionsBuilder` | Constructor de sugerencias `/comando` (`/afinar`, `/metro`, `/bpm`, `/calibrar`, `/grabar`, etc.) | `UC-74`, `UC-137` |
| `lib/features/navigation/presentation/tool_search_modal.dart` | `ToolSearchModal` | Buscador Spotlight sobre `AppToolCatalog.searchTools()` y despachador de modales | `UC-46` |
| `lib/features/navigation/presentation/modals/studio_automations_modal.dart` | `StudioAutomationsModal` | Configuración de rutinas autónomas (rampas de tempo, calentamiento, auto-grabación) | `UC-138`, `UC-172` |
| `lib/features/navigation/presentation/modals/studio_customizations_modal.dart` | `StudioCustomizationsModal` | Configuración técnica: `dspEngineName`, `targetRenderFps`, `centsPrecision` | `UC-172`, `UC-173` |
| `lib/features/navigation/presentation/modals/studio_settings_modal.dart` | `StudioSettingsModal` | Preferencias base: A4, temperamento, enlaces a calibración de micrófono e instrumentos | `UC-13`, `UC-173` |

### 1.4 Personalización (`lib/features/customization/`) — 2 archivos

| Archivo | Clases Principales | Métodos / Propiedades Clave | Casos de Uso |
| :--- | :--- | :--- | :--- |
| `lib/features/customization/presentation/theme_customization_modal.dart` | `ThemeCustomizationModal` | Selección de 7 estéticas curadas, gestión de paletas custom, importar/exportar tema en JSON | `UC-11`, `UC-89` |
| `lib/features/customization/presentation/theme_editor_dialog.dart` | `ThemeEditorDialog` | Editor interactivo de `TunnerThemePalette` (base dark/oled/wood/light y acentos primario/secundario) | `UC-11`, `UC-89` |

### 1.5 Composición Raíz (`lib/app/`) — 3 archivos

| Archivo | Clases Principales | Métodos / Propiedades Clave | Casos de Uso |
| :--- | :--- | :--- | :--- |
| `lib/app/studio_composition_root.dart` | `StudioCompositionRoot` | `create({platformFileGateway, isolatedServices})`, `createTunerViewModel()`, `createDjConsoleViewModel()`, `createMediaVaultViewModel()`, `createModularRackViewModel()`, `dspBridge`, `dispose()` | `UC-123`, `UC-130`, `UC-183` |
| `lib/app/studio_workspace_seed_provider.dart` | `StudioWorkspaceSeedProvider` | Implementa `IWorkspaceSeedProvider.buildSeedBinaryFiles()` generando 2 archivos WAV semilla en memoria (100% Pure Dart) | `UC-75`, `UC-91`, `UC-183` |
| `lib/app/terminal_feature_adapters.dart` | `ScorePlaybackTerminalAdapter`, `TunerProjectTerminalAdapter`, `EbbinghausTerminalAdapter`, `VocalPedagogyTerminalAdapter` | Implementan puertos `ITerminalScorePort`, `ITerminalProjectPort`, `ITerminalEarTrainingPort`, `ITerminalVocalPedagogyPort` | `UC-108`, `UC-109`, `UC-173` |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Bloqueantes Críticos para Ejecución Headless Pure Dart

Se verificó mediante inspección directa y `grep` la cadena de imports bloqueantes (`package:flutter/`, `dart:ui`, `path_provider`, `shared_preferences`):

1. **`AppUserSettingsEntity` contamina el dominio con `package:flutter/material.dart` (Bloqueante S0):**
   - `lib/features/persistence/domain/app_user_settings_entity.dart:2` importa `../../../core/theme/tunner_theme.dart`.
   - `lib/core/theme/tunner_theme.dart:1` importa `package:flutter/material.dart` porque `TunnerThemePalette` almacena campos `Color` y `Brightness`.
   - Consecuencia: **Ningún proceso Pure Dart CLI (`dart run bin/tunner_mcp_server.dart`) puede importar `AppUserSettingsEntity` ni `ILocalPersistenceService`**.
   - Solución exacta: Extraer un DTO puro `ThemePaletteData` (con colores `int` ARGB32 y `bool isDark`, idéntico al patrón ya aplicado en `VisualInterfaceProfile`) en `lib/core/theme/domain/theme_palette_data.dart` y hacer que `AppUserSettingsEntity.customPalettes` use `List<ThemePaletteData>`, delegando la conversión a `Color`/`Brightness` a una extensión UI en `presentation/`.

2. **`JsonLocalPersistenceService` importa `package:path_provider/path_provider.dart` (Bloqueante S0):**
   - `lib/features/persistence/data/json_local_persistence_service.dart:4` importa `path_provider`, el cual depende de `package:flutter/services.dart` y `dart:ui`.
   - Aunque el constructor ya acepta `documentsPathProvider` inyectado, el import estático rompe la compilación en Dart puro.
   - Solución exacta: Extraer `AtomicJsonFilePersistenceService` (Pure Dart, usando solo `dart:io`, `dart:convert`, `dart:async` con `directoryPathProvider` obligatorio) y dejar `JsonLocalPersistenceService` como adaptador Flutter que inyecta `getApplicationDocumentsDirectory` sobre esa clase base.

3. **`StudioCompositionRoot` arrastra todo el grafo de Flutter UI y plugins de plataforma (Bloqueante S0):**
   - Dependencias directas bloqueantes en `lib/app/studio_composition_root.dart`:
     - `PlatformFileGateway` (`lib/core/file_system/data/platform_file_gateway.dart:4` -> `path_provider`).
     - `LocalDiskStudioFileSystemRepository` (`lib/core/file_system/data/local_disk_studio_file_system_repository.dart:2-3` -> `flutter/foundation.dart`, `path_provider`).
     - `StudioAudioHardwarePersistenceService` (`lib/core/audio/infrastructure/studio_audio_hardware_persistence_service.dart:4` -> `path_provider`).
     - `StudioAudioInputEngine` (`lib/core/audio/infrastructure/studio_audio_input_engine.dart:3` -> `flutter/foundation.dart`).
     - `StudioMasterClockService` (`lib/core/audio/infrastructure/studio_master_clock_service.dart:2` -> `flutter/foundation.dart`).
     - `StudioThemeController` y `StudioThemeCatalogService` (`flutter/material.dart`, `flutter/foundation.dart`).
     - `TunerViewModel`, `DjConsoleViewModel`, `MediaVaultViewModel`, `ModularRackViewModel` (`ChangeNotifier` de `flutter/foundation.dart`).

4. **`terminal_feature_adapters.dart` mezcla adaptadores Pure Dart con `TunerViewModel` (Bloqueante S1):**
   - `lib/app/terminal_feature_adapters.dart:8` importa `../features/tuner_viewmodel.dart` exclusivamente por `TunerProjectTerminalAdapter`.
   - Los otros 3 adaptadores (`ScorePlaybackTerminalAdapter`, `EbbinghausTerminalAdapter`, `VocalPedagogyTerminalAdapter`) podrían reutilizarse directamente en el servidor MCP si se separan en un archivo Pure Dart (`headless_terminal_adapters.dart`) y se reemplaza `TunerProjectTerminalAdapter` por un `HeadlessProjectTerminalAdapter` sobre un estado de proyecto puro.

5. **Conocimiento de Dominio Atrapado en la Capa de Presentación (Brecha Funcional):**
   - `ToolHelpCatalog` (`lib/features/navigation/presentation/contextual_help_sheet.dart`) contiene descripciones técnicas, fórmulas acústicas y tips pedagógicos, pero vive en `presentation/` e importa `flutter/material.dart` y `tunner_theme.dart`. Mover `ToolHelpItem` y `ToolHelpCatalog` a `navigation/domain/` permite exponerlos como recurso MCP `tunner://help/tools`.
   - `AppToolCatalog` (`lib/features/navigation/domain/app_tool_item.dart`) sí es 100% Pure Dart, pero su texto dice `"Guitarra, Bajo, Trompeta en Si♭, Violín, Cello, Flauta y 21 más"` (desactualizado frente a los 40 instrumentos de `UC-171`) y sus `actionId` solo son interpretados por un `switch` UI dentro de `ToolSearchModal`.
   - `StudioCommandCatalogBuilder` y `StudioPromptSuggestionsBuilder` están acoplados a `BuildContext` y `IconData`; no existe un registro de comandos headless agnóstico de UI (aunque `TunnerOsKernel` cubre el DSL).

6. **Ausencia de `shared_preferences`:**
   - Confirmado mediante `grep`: ninguno de los 53 archivos auditados usa `shared_preferences`. Toda la persistencia de usuario se basa en archivos JSON atómicos en disco (`JsonLocalPersistenceService`), lo cual facilita enormemente la migración a Pure Dart una vez removido `path_provider`.

### 2.2 Arquitectura de Desacoplamiento: `HeadlessCompositionRoot` (Pure Dart)

Para el servidor MCP (`bin/tunner_mcp_server.dart`), **no** se debe instanciar `StudioCompositionRoot`. Se debe introducir `lib/app/headless_composition_root.dart` con cero imports de `flutter` ni plugins:

```text
StudioCompositionRoot (Flutter Desktop/Mobile)
  ├── Reutiliza: HeadlessCompositionRoot (core puro)
  └── Añade capa Flutter:
        ├── PlatformFileGateway (path_provider / file_picker)
        ├── StudioThemeController / StudioThemeCatalogService
        ├── StudioAudioEngine / StudioAudioInputEngine (hardware I/O)
        └── ViewModels (TunerViewModel, DjConsoleViewModel, MediaVaultViewModel, ModularRackViewModel)

HeadlessCompositionRoot (Pure Dart — bin/tunner_mcp_server.dart)
  ├── PosixFileGateway (implements IPlatformFileGateway usando dart:io + workspaceRoot)
  ├── AtomicJsonFilePersistenceService (implements ILocalPersistenceService en <workspaceRoot>/.tunner/)
  ├── NativeDspFfiBridge (implements INativeDspBridge — dart:ffi puro, con fallback Dart)
  ├── StudioMasterDspChain (bridge: nativeDspBridge)
  ├── StudioWorkspaceSeedProvider (implements IWorkspaceSeedProvider — ya Pure Dart)
  ├── HeadlessWorkspaceFileSystemRepository (dart:io puro, sin ChangeNotifier ni path_provider)
  ├── TunnerPackageCodecService (serialización lossless .tunner)
  ├── UniversalScoreImporterService (MusicXML / MIDI / ABC)
  ├── InstrumentCatalogService + InstrumentTranspositionService + SmartInstrumentDetector
  ├── EbbinghausSpacedRepetitionEngine + VocalStabilityEvaluator + PedagogicalCertificatePdfGenerator
  ├── TunnerOsKernel (con HeadlessProjectTerminalAdapter + adaptadores puros)
  └── HeadlessStudioSessionState (estado inmutable/reactivo vía StreamController en lugar de ChangeNotifier)
```

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON Retornada |
| :--- | :--- | :--- |
| `tunner://settings/current` | Configuración global persistida del usuario (`AppUserSettingsEntity` desacoplada de Flutter). | `{ "referencePitch": 440.0, "selectedThemeId": "obsidian_studio", "activeStudioThemeId": "studio_oled_monochrome", "selectedInstrumentId": "flute", "bpm": 68, "isSmartWaitEnabled": false, "displayMode": "conservatoryPro", "selectedTemperamentId": "equal", "temperamentRootKey": 0, "activeWorkspace": "learning", "dspEngineName": "Tartini DSP 2.1", "targetRenderFps": 60, "centsPrecision": 0.1, "activeScoreId": "string|null", "workspaceConfiguration": { ... }, "learnerProfile": { ... }, "micCalibrationProfile": { ... }, "acousticRigorProfile": { ... } }` |
| `tunner://workspace/active` | Estado del espacio de trabajo activo (`WorkspaceType`), visibilidad de herramientas (`WorkspaceConfigurationEntity`) y resumen de partituras/archivos cargados. | `{ "activeWorkspace": "learning|composition|production", "displayName": "string", "tagline": "string", "configuration": { "showMetronome": true, "showStrobeTuner": true, "showSheetMusicCanvas": true, "showAcousticSpectrogram": false, "showChordAnalyzer": false }, "workspaceScoresCount": int, "activeScoreId": "string|null" }` |
| `tunner://catalog/tools` | Catálogo global de herramientas navegables de Tunner (`AppToolCatalog.tools`) para descubrimiento de capacidades por agentes IA. | `{ "count": 21, "categories": [ ... ], "tools": [ { "id": "string", "title": "string", "subtitle": "string", "category": "string", "keywords": ["..."], "targetTabIndex": "int|null", "actionId": "string|null" } ] }` |
| `tunner://help/tools` | Base de conocimiento pedagógica y fórmulas acústicas (`ToolHelpCatalog.items`, tras migración a dominio puro). | `{ "items": [ { "id": "string", "title": "string", "category": "string", "description": "string", "pedagogicalTip": "string", "acousticFormula": "string|null", "shortcutKeys": ["..."] } ] }` |
| `tunner://themes/palettes` | Paletas de tema personalizadas guardadas en `AppUserSettingsEntity.customPalettes` y tema activo (formato `ThemePaletteData` con colores hex ARGB32). | `{ "selectedThemeId": "string", "activeStudioThemeId": "string", "customPalettes": [ { "id": "string", "displayName": "string", "isDark": true, "primaryAccentHex": "0xFF...", "secondaryAccentHex": "0xFF...", "scaffoldBackgroundHex": "0xFF..." } ] }` |
| `tunner://runtime/capabilities` | Diagnóstico de `HeadlessCompositionRoot`: estado de `NativeDspFfiBridge`, ruta de persistencia activa, modo IPC con GUI Desktop y servicios montados. | `{ "mode": "headless", "ffiNativeLoaded": bool, "persistencePath": "string", "ipcGuiConnected": bool, "loadedServices": ["..."] }` |

### 3.2 Tools (`tunner_*`)

| Nombre de Tool | Parámetros (JSON Schema Resumido) | Salida JSON | Mapeo Exacto en Código Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_get_user_settings` | `{ "sections": "string[]? (ej: ['audio','workspace','pedagogy','themes'])" }` | Snapshot JSON completo o filtrado de `AppUserSettingsEntity` | `ILocalPersistenceService.loadSettings()` -> `AppUserSettingsEntity.toMap()` |
| `tunner_update_user_settings` | `{ "referencePitch": "number (415-466)?", "bpm": "int (20-300)?", "selectedInstrumentId": "string?", "selectedTemperamentId": "string?", "temperamentRootKey": "int (0-11)?", "isSmartWaitEnabled": "bool?", "displayMode": "'essential'\|'conservatoryPro'?", "dspEngineName": "string?", "centsPrecision": "number (0.1-1.0)?" }` | `{ "updated": true, "settings": AppUserSettingsJSON, "persistedAtomically": true }` | `ILocalPersistenceService.loadSettings()` -> `AppUserSettingsEntity.copyWith(...)` -> `saveSettings(...)` |
| `tunner_reset_user_settings` | `{ "confirm": "bool (required true)" }` | `{ "reset": true, "settings": AppUserSettingsEntity.defaultSettings }` | `ILocalPersistenceService.clearSettings()` |
| `tunner_switch_workspace` | `{ "workspace": "'learning' \| 'composition' \| 'production'", "configurationOverrides": "{ showMetronome?, showStrobeTuner?, showSheetMusicCanvas?, showAcousticSpectrogram?, showChordAnalyzer? }?" }` | `{ "activeWorkspace": "string", "configuration": WorkspaceConfigurationJSON, "ipcNotified": bool }` | `WorkspaceType.fromSerializedKey()` + `WorkspaceConfigurationEntity.defaultFor().copyWith()` + `ILocalPersistenceService.saveSettings()` |
| `tunner_search_tools` | `{ "query": "string", "category": "string?" }` | `{ "query": "string", "matches": [ ...AppToolItemJSON ] }` | `AppToolCatalog.searchTools(query)` |
| `tunner_manage_custom_theme` | `{ "action": "'list' \| 'upsert' \| 'delete' \| 'select'", "themeId": "string?", "paletteData": "ThemePaletteDataJSON?" }` | `{ "selectedThemeId": "string", "activeStudioThemeId": "string", "customPalettesCount": int, "palette": "ThemePaletteDataJSON|null" }` | `AppUserSettingsEntity.customPalettes` + `selectedThemeId` / `activeStudioThemeId` vía `ILocalPersistenceService` |
| `tunner_seed_workspace_assets` | `{ "targetDirectory": "string", "overwrite": "bool (default false)" }` | `{ "filesCreated": [ { "relativePath": "string", "bytes": int } ] }` | `StudioWorkspaceSeedProvider.buildSeedBinaryFiles()` + escritura atómica vía `PosixFileGateway` |

### 3.3 Prompts Guiados para Agentes IA

1. **`tunner_configure_studio_session`**
   - *Objetivo:* Preparar el entorno completo de estudio para un objetivo musical específico (e.g., ensayo barroco a 415 Hz en modo producción o sesión de práctica para principiante en modo aprendizaje).
   - *Flujo:* Lee `tunner://settings/current` y `tunner://workspace/active`, invoca `tunner_update_user_settings` y `tunner_switch_workspace`, y confirma coherencia de instrumento, temperamento y tolerancia en cents.
2. **`tunner_discover_workflow_tools`**
   - *Objetivo:* Guiar a un músico o agente sobre qué módulos y herramientas de Tunner encadenar para una tarea compleja (e.g., transcribir audio, editar partitura y exportar stems).
   - *Flujo:* Consulta `tunner://catalog/tools` y `tunner://help/tools`, invoca `tunner_search_tools` y construye un plan paso a paso con fórmulas y herramientas MCP correspondientes.
3. **`tunner_backup_and_migrate_settings`**
   - *Objetivo:* Auditar, respaldar o restablecer de forma segura las preferencias, presets y paletas del usuario antes de cambios mayores.
   - *Flujo:* Invoca `tunner_get_user_settings`, valida integridad de campos y ejecuta `tunner_update_user_settings` o `tunner_manage_custom_theme` según requerimiento.

---

## 4. Plan de Ajustes Técnicos Previos (Pre-MCP Refactoring)

1. **Desacoplar `AppUserSettingsEntity` de `package:flutter/material.dart` (`P0` — Bloqueante):**
   - Crear `lib/core/theme/domain/theme_palette_data.dart` (Pure Dart, colores como `int` ARGB32 y `bool isDark`, con `toJson()` / `fromJson()`).
   - Migrar `AppUserSettingsEntity.customPalettes` de `List<TunnerThemePalette>` a `List<ThemePaletteData>` (con adaptador bidireccional en `lib/core/theme/tunner_theme.dart` para mantener 100% retrocompatibilidad en UI).
   - Verificar con `dart analyze` que `lib/features/persistence/domain/` tiene cero imports transitivos de `flutter` o `dart:ui`.

2. **Extraer Persistencia JSON Pure Dart sin `path_provider` (`P0` — Bloqueante):**
   - Crear `lib/features/persistence/data/atomic_json_persistence_service.dart` (Pure Dart, solo `dart:io`, `dart:convert`, `dart:async`) recibiendo `required Future<String> Function() directoryPathProvider`.
   - Refactorizar `JsonLocalPersistenceService` para delegar toda la lógica atómica en `AtomicJsonFilePersistenceService`, conservando `path_provider` únicamente en el wrapper Flutter.

3. **Construir `HeadlessCompositionRoot` y `PosixFileGateway` (`P0` — Bloqueante):**
   - Crear `lib/core/file_system/data/posix_file_gateway.dart` (Pure Dart, implementa `IPlatformFileGateway` usando `dart:io` y un `workspaceRoot` configurable).
   - Crear `lib/app/headless_composition_root.dart` instanciando exclusivamente servicios Pure Dart (`PosixFileGateway`, `AtomicJsonFilePersistenceService`, `NativeDspFfiBridge`, `StudioMasterDspChain`, `StudioWorkspaceSeedProvider`, `TunnerPackageCodecService`, motores de dominio de instrumentos, partituras, pedagogía y `TunnerOsKernel`).
   - Hacer que `StudioCompositionRoot` componga `HeadlessCompositionRoot` internamente para eliminar duplicación de ensamblaje entre GUI y MCP.

4. **Separar Adaptadores de Terminal Puros de `TunerViewModel` (`P1`):**
   - Dividir `lib/app/terminal_feature_adapters.dart` en:
     - `lib/app/headless_terminal_adapters.dart` (Pure Dart: `ScorePlaybackTerminalAdapter`, `EbbinghausTerminalAdapter`, `VocalPedagogyTerminalAdapter` y un nuevo `HeadlessProjectTerminalAdapter` sin dependencia de `TunerViewModel`).
     - `lib/app/flutter_terminal_adapters.dart` (`TunerProjectTerminalAdapter` ligado a `TunerViewModel`).

5. **Promover Metadatos de Navegación y Ayuda a Dominio Puro (`P2`):**
   - Extraer `ToolHelpItem` y `ToolHelpCatalog` desde `lib/features/navigation/presentation/contextual_help_sheet.dart` hacia `lib/features/navigation/domain/tool_help_catalog.dart` (Pure Dart con `toJson()`).
   - Agregar `toJson()` a `AppToolItem` y `AppToolCategory` en `lib/features/navigation/domain/app_tool_item.dart`, y actualizar el subtítulo obsoleto de `instrument_selector` de `"21 más"` a `"40 instrumentos"`.
