# Auditoria Forense MCP-Readiness: Packaging, File System, Logging, Domain, Docking, Design System y Theme

**Fecha:** 2026-11-23  
**Alcance:** `lib/core/packaging/` (5), `lib/core/file_system/` (15), `lib/core/logging/` (2), `lib/core/domain/` (1), `lib/core/docking/` (8), `lib/core/design_system/` (29), `lib/core/theme/` (1) — **Total: 61 archivos `.dart`**  
**Objetivo:** Evaluar la ejecucion Headless Pure Dart de persistencia, empaquetado `.tunner`, logging, sistema de archivos, y definir los eventos IPC requeridos para sincronizar Docking, Design System y Theme con la UI Flutter en vivo desde un servidor MCP.

---

## 1. Inventario Archivo por Archivo

### 1.1 `lib/core/packaging/` (5 archivos)

| Archivo | Clases / Excepciones Principales | Metodos / Contratos Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- |
| `domain/i_tunner_package_codec.dart` | `ITunnerPackageCodec`, `NoOpTunnerPackageCodec` | `encodePackage(TunnerProjectPackageEntity)`, `decodePackage(Uint8List, {verifyHashes})` | UC-082, UC-106, UC-141 |
| `domain/tunner_package_exceptions.dart` | `TunnerPackageInvalidFormatException`, `TunnerPackageCorruptedException` | Excepciones tipadas para corrupcion SHA-256, Zip-Slip o Zip-Bomb | UC-106, UC-126, UC-177 |
| `domain/tunner_project_manifest_entity.dart` | `TunnerProjectManifestEntity` | Metadatos de proyecto, version de esquema, mapa `fileHashes` SHA-256, `toJson()`, `fromJson()`, `serializeJson()` | UC-106 |
| `domain/tunner_project_package_entity.dart` | `TunnerProjectPackageEntity` | Contenedor inmutable (`manifest`, `routingMatrixJson`, `scoreJson`, `synthPresetJson`, `djSessionJson`, `audioFiles`) | UC-106 |
| `infrastructure/tunner_package_codec_service.dart` | `TunnerPackageCodecService` | Compresion DEFLATE (`package:archive`), verificacion SHA-256 bidireccional (`package:crypto`), limite Zip-Bomb `maxDecompressedSizeBytes = 250 MB` y validacion anti-Zip-Slip | UC-082, UC-106, UC-126, UC-177 |

### 1.2 `lib/core/file_system/` (15 archivos)

| Archivo | Clases / Enums Principales | Metodos / Responsabilidades Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- |
| `domain/i_platform_file_gateway.dart` | `PlatformPickedFile`, `IPlatformFileGateway`, `NoOpPlatformFileGateway` | Contrato agnostico de seleccion/guardado nativo de archivos (`pickFile()`, `saveBytes()`) | UC-126, UC-141 |
| `domain/i_studio_workspace_file_system.dart` | `IStudioWorkspaceFileSystem`, `NoOpStudioWorkspaceFileSystem` | Contrato observable del arbol de espacio de trabajo (`initializeWorkspace()`, `refreshFromDisk()`, CRUD de archivos/carpetas, busqueda) | UC-085, UC-101, UC-141 |
| `domain/i_workspace_seed_provider.dart` | `IWorkspaceSeedProvider` | Contrato para sembrar archivos iniciales en un workspace nuevo | UC-101, UC-115 |
| `domain/studio_file_system_node.dart` | `StudioFileSystemNode`, `StudioFileEntity`, `StudioFolderEntity` | Arbol inmutable de archivos/carpetas con `findNode()`, recorrido y metadatos | UC-085, UC-101 |
| `domain/studio_file_system_repository.dart` | `StudioFileSystemRepository`, `NoOpStudioFileSystemRepository` | Repositorio CRUD (`loadRootWorkspace()`, `createFile()`, `createFolder()`, `readFile()`, `readFileBytes()`, `writeFile()`, `writeFileBytes()`, `renameNode()`, `moveNode()`, `deleteNode()`) | UC-085, UC-101, UC-126 |
| `domain/studio_file_type.dart` | `StudioFileType` | Enum de extensiones soportadas (`.tunner`, `.tndsl`, `.musicxml`, `.mid`, `.wav`, `.mp3`, `.sf2`, `.tntheme`, etc.) | UC-085, UC-101 |
| `data/local_disk_studio_file_system_repository.dart` | `LocalDiskStudioFileSystemRepository` | Persistencia fisica en `dart:io` con confinamiento estricto anti-Path Traversal y validacion de symlinks (`_resolveSafePath()`) | UC-085, UC-101, UC-126 |
| `data/memory_studio_file_system_repository.dart` | `MemoryStudioFileSystemRepository` | Repositorio 100% Pure Dart en memoria para pruebas y ejecucion efimera | UC-085, UC-145 |
| `data/platform_file_gateway.dart` | `PlatformFileGateway` | Adaptador de `package:file_picker` y `package:path_provider` | UC-126, UC-141 |
| `data/studio_workspace_file_system_service.dart` | `StudioWorkspaceFileSystemService` | Servicio reactivo de estado del explorador de workspace (seleccion, busqueda `<2ms`, expansion, refresco de disco) | UC-085, UC-101 |
| `presentation/studio_explorer_action_header.dart` | `StudioExplorerActionHeader` | Barra de acciones Flutter del explorador | UC-085, UC-101 |
| `presentation/studio_file_system_modals.dart` | `StudioFileSystemModals` y 4 dialogos internos | Modales Flutter de crear archivo/carpeta, renombrar y mover | UC-085, UC-101 |
| `presentation/studio_file_tree_tile.dart` | `StudioFileTreeTile` | Nodo visual de archivo en arbol | UC-085 |
| `presentation/studio_folder_tree_tile.dart` | `StudioFolderTreeTile` | Nodo visual de carpeta en arbol | UC-085 |
| `presentation/studio_vscode_explorer_widget.dart` | `StudioVsCodeExplorerWidget` | Explorador lateral estilo IDE | UC-085, UC-101 |

### 1.3 `lib/core/logging/` (2 archivos) y `lib/core/domain/` (1 archivo)

| Archivo | Clases / Mixins Principales | Metodos / Responsabilidades Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- |
| `logging/domain/i_studio_logger.dart` | `IStudioLogger`, `NoOpStudioLogger` | Contrato Pure Dart `warning()` y `error()` con `tag`, `message`, `error`, `stackTrace` | UC-122, UC-141 |
| `logging/infrastructure/studio_debug_logger.dart` | `StudioDebugLogger` | Implementacion singleton respaldada por `debugPrint` y `kDebugMode` | UC-122 |
| `domain/i_studio_listenable.dart` | `IStudioListenable`, `StudioPureNotifierMixin` | Patron observable 100% Pure Dart (`addListener()`, `removeListener()`, `notifyListeners()`, `dispose()`) | UC-122, UC-141, UC-176 |

### 1.4 `lib/core/docking/` (8 archivos)

| Archivo | Clases / Enums Principales | Metodos / Responsabilidades Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- |
| `domain/studio_dock_layout_entity.dart` | `StudioDockLayoutEntity` | Presets (`defaultLayout`, `presetClubClassic`, `presetHardwareFocus`, `presetStemsStudio`, `presetThreeColumns`), `movePanel()`, `updateRatio()`, `findZoneOfPanel()` | UC-085, UC-138 |
| `domain/studio_dock_zone.dart` | `StudioDockZone`, `StudioDockZoneExtension` | Enum `left`, `center`, `right`, `bottom`, `floating` | UC-085 |
| `domain/studio_panel_descriptor.dart` | `StudioPanelDescriptor` | Descriptor Pure Dart de panel acoplable (`id`, `title`, `iconId`, `canClose`, `defaultZone`) | UC-085, UC-138 |
| `presentation/studio_dockable_panel_entity.dart` | `StudioDockablePanelEntity` | Envoltorio Flutter que asocia `StudioPanelDescriptor` con un `Widget` | UC-085 |
| `presentation/studio_dockable_window_card.dart` | `StudioDockableWindowCard` | Ventana arrastrable con cabecera | UC-085 |
| `presentation/studio_dock_drop_zone_target.dart` | `StudioDockDropZoneTarget` | Zona de destino drag-and-drop | UC-085 |
| `presentation/studio_splitter_divider.dart` | `StudioSplitterDivider` | Divisor redimensionable de proporciones | UC-085 |
| `presentation/studio_workspace_docking_container.dart` | `StudioWorkspaceDockingContainer` | Contenedor multi-panel DAW en Flutter | UC-085, UC-138 |

### 1.5 `lib/core/design_system/` (29 archivos) y `lib/core/theme/` (1 archivo)

| Grupo / Archivo | Clases Principales | Rol / Relevancia Headless e IPC | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- |
| `design_system/domain/studio_theme_skin_entity.dart` | `StudioThemeSkinEntity` | **Pure Dart.** Catalogo `defaultCatalog`, `toJson()`, `fromJson()` para paquetes `.tntheme` | UC-011, UC-138 |
| `design_system/domain/studio_workspace_tab_spec.dart` | `StudioWorkspaceTabId`, `StudioWorkspaceTabSpec` | **Pure Dart.** Identificadores canonicos de pestanas del estudio para navegacion IPC | UC-101, UC-137, UC-138 |
| `design_system/domain/studio_icon_catalog.dart` | `StudioIconId`, `StudioIconAssetSpec`, `StudioIconCatalog` | **Pure Dart.** Catalogo semantico de iconos vectoriales | UC-138 |
| `design_system/data/studio_theme_catalog_service.dart` | `StudioThemeCatalogService` | Gestiona catalogo de skins, `selectSkin()`, `importThemeFromJson()`, `exportThemeToJson()` | UC-011 |
| `design_system/studio_design_system.dart` | Barrel export | Exporta el sistema de diseno completo (arrastra `flutter/material.dart`) | UC-011, UC-138 |
| `design_system/studio_design_tokens.dart` | `StudioDesignTokens`, `StudioThemeSkinTokensMapper` | Mapeo de `StudioThemeSkinEntity` a `Color` / `ThemeData` Flutter | UC-011 |
| `design_system/studio_theme_provider.dart` | `StudioThemeController`, `StudioThemeScope` | `ChangeNotifier` e `InheritedNotifier` de tema activo en UI | UC-011 |
| `design_system/atoms/` (14 archivos) | `StudioBadge`, `StudioButton`, `StudioToggleChip`, `StudioHairline`, `StudioIcon`, `StudioListenableBuilder`, `StudioMetricDisplay`, `StudioPanel`, `StudioRotaryKnob`, `StudioSplitter`, `StudioStatusLed`, `StudioStereoVuMeter`, `StudioTextControllerScope`, `StudioThemeSwitcher`, `StudioToolbar` | Primitivos visuales Flutter (solo capa UI; consumen estado via `StudioListenableBuilder`) | UC-011, UC-138 |
| `design_system/molecules/` (6 archivos) | `StudioCommandPromptBar`, `StudioSegmentedControl`, `StudioThemeManagerModal`, `StudioTreeView`, `StudioVuMeter`, `StudioWorkspaceTabBar` | Componentes compuestos Flutter (barra de comandos `Ctrl+K`, arbol, pestanas, modal de temas) | UC-101, UC-137, UC-138 |
| `design_system/organisms/` (2 archivos) | `StudioDesktopAppShell`, `StudioWorkbenchShell` | Carcasas principales de escritorio y workbench que deben suscribirse a eventos IPC en vivo | UC-101, UC-138 |
| `theme/tunner_theme.dart` | `TunnerThemeMode`, `TunnerThemePalette` | Paleta base y generacion de `ThemeData` Material 3 (capa Flutter) | UC-011 |

---

## 2. Auditoria de Brechas (Gaps) y Preparacion Headless (MCP-Readiness)

### 2.1 Bloqueos Directos para Ejecucion Pure Dart CLI

1. **`StudioDebugLogger` (`lib/core/logging/infrastructure/studio_debug_logger.dart`) — CRITICO (BLOQUEADOR GLOBAL + RIESGO STDIO MCP):**
   - Importa `package:flutter/foundation.dart` (`debugPrint` y `kDebugMode`).
   - Es invocado mediante singleton estatico `StudioDebugLogger.instance` desde multiples servicios de infraestructura (`audio`, `file_system`, `ffi`).
   - **Riesgo critico de protocolo MCP:** Cuando el servidor MCP opera sobre transporte `stdio`, `stdout` esta reservado exclusivamente para tramas JSON-RPC 2.0. Cualquier salida de log a `stdout` corrompe el stream del cliente IA. El logger headless Pure Dart **debe escribir estrictamente a `stderr`** (`stderr.writeln`).
2. **`LocalDiskStudioFileSystemRepository` (`lib/core/file_system/data/local_disk_studio_file_system_repository.dart`) — CRITICO:**
   - Importa `package:flutter/foundation.dart` (solo para `!kIsWeb`) y `package:path_provider/path_provider.dart` (solo cuando `_customRootPath == null`).
   - Su logica de seguridad anti-Path Traversal y resolucion de symlinks (`_resolveSafePath()`) es excelente y 100% `dart:io`, pero esos 2 imports bloquean su compilacion en Pure Dart CLI.
3. **`StudioWorkspaceFileSystemService` (`lib/core/file_system/data/studio_workspace_file_system_service.dart`) — ALTO:**
   - Extiende `ChangeNotifier` (`package:flutter/foundation.dart`) en lugar de usar `StudioPureNotifierMixin`.
4. **`StudioThemeCatalogService` (`lib/core/design_system/data/studio_theme_catalog_service.dart`) — MEDIO:**
   - Extiende `ChangeNotifier` e importa directamente `studio_design_tokens.dart` y `studio_theme_provider.dart` (ambos `package:flutter/material.dart`), impidiendo gestionar el catalogo `.tntheme` desde CLI Pure Dart.
5. **`PlatformFileGateway` (`lib/core/file_system/data/platform_file_gateway.dart`) — BAJO (ya abstraido):**
   - Depende de `file_picker` y `path_provider`. Al existir `IPlatformFileGateway` y `NoOpPlatformFileGateway`, el servidor MCP solo debe inyectar una implementacion headless basada en rutas autorizadas dentro del sandbox del workspace.

### 2.2 Brechas Funcionales, Concurrencia y Sincronizacion UI en Vivo

1. **Compresion/Descompresion sincrona en `TunnerPackageCodecService`:**
   - `lib/core/packaging/` ya es **100% Pure Dart** y cuenta con proteccion anti-Zip-Slip, cuota anti-Zip-Bomb (250 MB) y verificacion criptografica SHA-256.
   - **Brecha:** `encodePackage()` y `decodePackage()` son sincronos. Empaquetar o abrir un `.tunner` con stems WAV de 100 MB bloqueara el event loop del servidor MCP. Debe exponerse una variante asincrona sobre `Isolate.run`.
2. **Falta de serializacion JSON en `StudioDockLayoutEntity` y `StudioFileSystemNode`:**
   - `StudioDockLayoutEntity` y `StudioPanelDescriptor` no poseen `toJson()` / `fromJson()`, a diferencia de `StudioThemeSkinEntity` que ya los implementa.
   - `StudioFileEntity` y `StudioFolderEntity` tampoco exponen `toJson()`, necesario para serializar el arbol del workspace en `tunner://workspace/tree`.
3. **Ausencia de capa IPC para sincronizacion en vivo de Docking, Theme y Navigation:**
   - Si un agente IA cambia el tema activo (`studio_oled_monochrome` -> `amber_analog`), reordena paneles del docking (`presetThreeColumns`) o crea un archivo `.tndsl` en disco desde el servidor MCP, la instancia Flutter abierta no recibe notificacion a menos que exista un bus IPC local (Unix Domain Socket / Named Pipe / WebSocket localhost efimero) que propague eventos tipados hacia `StudioDesktopAppShell`, `StudioWorkspaceDockingContainer`, `StudioThemeController` y `StudioWorkspaceFileSystemService`.

---

## 3. Especificacion de Primitivos MCP y Contrato de Eventos IPC

### 3.1 Resources (`tunner://...`)

| URI | Descripcion | Estructura JSON |
| :--- | :--- | :--- |
| `tunner://workspace/tree` | Arbol jerarquico completo del workspace sandboxed (`StudioFolderEntity` raiz). | `{ "rootPath": "...", "nodes": [ { "id": "...", "name": "...", "path": "...", "isFolder": true, "fileType": "folder", "children": [...] } ] }` |
| `tunner://workspace/file/{relativePath}` | Contenido textual (o metadatos + tamano/hash si es binario) de un archivo dentro del sandbox del workspace. | `{ "path": "scripts/demo.tndsl", "fileType": "tndsl", "encoding": "utf-8|base64", "sizeBytes": 512, "content": "..." }` |
| `tunner://package/inspect/{relativePath}` | Manifiesto e inventario verificado por SHA-256 de un contenedor `.tunner` sin extraer stems a memoria innecesariamente. | `{ "manifest": { ... }, "hasRoutingMatrix": true, "hasScore": true, "hasSynthPreset": true, "hasDjSession": false, "audioFiles": [ { "path": "...", "sha256": "..." } ], "integrityVerified": true }` |
| `tunner://ui/themes` | Catalogo completo de estéticas `.tntheme` disponibles y la skin actualmente activa. | `{ "activeSkinId": "studio_oled_monochrome", "skins": [ StudioThemeSkinEntity.toJson() ] }` |
| `tunner://ui/docking/layout` | Distribucion actual de paneles por zona (`left`, `center`, `right`, `bottom`, `floating`), proporciones de split y presets disponibles. | `{ "zonePanelIds": { "left": [], "center": [...], "right": [...], "bottom": [...], "floating": [] }, "leftSplitRatio": 0.28, "rightSplitRatio": 0.32, "bottomSplitRatio": 0.35, "presets": ["club_classic", "hardware_focus", "stems_studio", "three_columns"] }` |
| `tunner://ui/navigation/tabs` | Catalogo de pestanas canonicas del estudio (`StudioWorkspaceTabId`) y pestana activa actual. | `{ "activeTabId": "...", "tabs": [ { "id": "...", "label": "...", "shortcut": "..." } ] }` |

### 3.2 Tools (`tunner_*`)

| Tool Name | Parametros (JSON Schema Resumido) | Salida | Mapeo Exacto en Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_fs_list_workspace` | `{ searchQuery?: string }` | Arbol filtrado de `StudioFileSystemNode` | `StudioFileSystemRepository.loadRootWorkspace()` / `IStudioWorkspaceFileSystem` |
| `tunner_fs_read_file` | `{ relativePath: string, asBase64?: boolean }` | `{ relativePath, content, sizeBytes }` | `StudioFileSystemRepository.readFile()` / `readFileBytes()` |
| `tunner_fs_write_file` | `{ relativePath: string, content: string, isBase64?: boolean, createParents?: boolean }` | `{ relativePath, sizeBytes, updated: true }` | `StudioFileSystemRepository.createFile()` / `writeFile()` / `writeFileBytes()` |
| `tunner_fs_manage_node` | `{ action: "create_folder" \| "rename" \| "move" \| "delete", relativePath: string, targetPath?: string, newName?: string }` | `{ action, status: "ok", resultingPath? }` | `StudioFileSystemRepository.createFolder()` / `renameNode()` / `moveNode()` / `deleteNode()` |
| `tunner_package_decode` | `{ relativePath: string, verifyHashes?: boolean (default true) }` | Manifiesto, resumen de artefactos JSON y estado de integridad SHA-256 | `TunnerPackageCodecService.decodePackage()` (via `Isolate.run`) |
| `tunner_package_encode` | `{ outputRelativePath: string, manifest: object, routingMatrixJson?: object, scoreJson?: object, synthPresetJson?: object, djSessionJson?: object, audioFilePaths?: string[] }` | `{ outputRelativePath, sizeBytes, fileHashes }` | `TunnerPackageCodecService.encodePackage()` (via `Isolate.run`) + `StudioFileSystemRepository.writeFileBytes()` |
| `tunner_ui_set_theme` | `{ skinId: string }` | `{ activeSkinId, ipcBroadcastSent: boolean }` | `StudioThemeCatalogService.selectSkin()` + evento IPC `ui.theme.changed` |
| `tunner_ui_import_theme` | `{ themeJson: string }` | `{ importedSkinId, activeSkinId }` | `StudioThemeCatalogService.importThemeFromJson()` + evento IPC `ui.theme.imported` |
| `tunner_ui_set_dock_layout` | `{ preset?: "club_classic" \| "hardware_focus" \| "stems_studio" \| "three_columns", movePanel?: { panelId: string, targetZone: "left" \| "center" \| "right" \| "bottom" \| "floating" }, ratios?: { left?: number, right?: number, bottom?: number } }` | Estado resultante de `StudioDockLayoutEntity` | `StudioDockLayoutEntity.preset*()` / `movePanel()` / `updateRatio()` + evento IPC `ui.docking.layout_changed` |
| `tunner_ui_navigate_tab` | `{ tabId: string }` | `{ activeTabId, ipcBroadcastSent: boolean }` | `StudioWorkspaceTabId` + evento IPC `ui.navigation.tab_changed` |

### 3.3 Eventos IPC Requeridos para Sincronizacion de UI en Vivo

Cuando el servidor MCP opere junto a la aplicacion de escritorio Flutter (modo hibrido), toda mutacion sobre estado visual o archivos del workspace debe emitir una notificacion IPC unidireccional (JSON-RPC Notification sobre Unix Socket / Named Pipe local) hacia los controladores Flutter:

| Evento IPC | Payload JSON | Consumidor Flutter en Vivo |
| :--- | :--- | :--- |
| `ui.theme.changed` | `{ "skinId": "...", "skinJson": { ... } }` | `StudioThemeCatalogService` -> `StudioThemeController.setTokens()` |
| `ui.theme.imported` | `{ "skinJson": { ... } }` | `StudioThemeCatalogService.importThemeFromJson()` |
| `ui.docking.layout_changed` | `{ "zonePanelIds": { ... }, "leftSplitRatio": 0.28, "rightSplitRatio": 0.32, "bottomSplitRatio": 0.35 }` | `StudioWorkspaceDockingContainer` (actualiza `StudioDockLayoutEntity`) |
| `ui.navigation.tab_changed` | `{ "tabId": "score\|dj\|tuner\|rack\|console\|..." }` | `StudioDesktopAppShellState` (conmuta pestana activa) |
| `ui.command_prompt.notify` | `{ "severity": "info\|warning\|error", "message": "..." }` | `StudioCommandPromptBar` / barra de estado del shell |
| `workspace.fs.changed` | `{ "action": "create\|write\|rename\|move\|delete", "relativePath": "..." }` | `StudioWorkspaceFileSystemService.refreshFromDisk()` |
| `workspace.file.open_requested` | `{ "relativePath": "..." }` | `StudioWorkspaceFileSystemService.onOpenFile` |

### 3.4 Prompts Guiados para Agentes IA

1. **`tunner_project_archive_audit`**: Lee `tunner://workspace/tree`, localiza paquetes `.tunner`, ejecuta `tunner_package_decode(verifyHashes: true)` y reporta integridad SHA-256, metadatos del manifiesto, y presencia de partitura, matriz de audio y stems.
2. **`tunner_workspace_layout_personalizer`**: Consulta `tunner://ui/themes`, `tunner://ui/docking/layout` y `tunner://ui/navigation/tabs`, y configura automaticamente el entorno visual (tema, preset de docking y pestana activa) segun la tarea musical solicitada (ensayo vocal, mezcla DJ, composicion DSL o masterizacion).

---

## 4. Plan de Ajustes Tecnicos Previos (Pre-MCP Hardening)

1. **Logger Pure Dart con salida exclusiva a `stderr` (Prioridad S0 — Bloqueador MCP):**
   - Crear `StudioStderrLogger implements IStudioLogger` en `lib/core/logging/infrastructure/` (100% `dart:io`, usando `stderr.writeln`) y reemplazar referencias directas al singleton `StudioDebugLogger.instance` en servicios de infraestructura por inyeccion de `IStudioLogger` (default `NoOpStudioLogger()` o `StudioStderrLogger()`).
   - Esto garantiza que ninguna traza de depuracion contamine `stdout` durante sesiones MCP `stdio`.
2. **Desacoplar `LocalDiskStudioFileSystemRepository` y `StudioWorkspaceFileSystemService` de Flutter (Prioridad S0):**
   - En `LocalDiskStudioFileSystemRepository`: eliminar `import 'package:flutter/foundation.dart'` y `import 'package:path_provider/path_provider.dart'`. Inyectar `Future<String> Function()? rootPathProvider` (con fallback a `Platform.environment['TUNNER_WORKSPACE_ROOT']` o `Directory.systemTemp` en CLI Pure Dart; la app Flutter inyecta `getApplicationDocumentsDirectory`).
   - En `StudioWorkspaceFileSystemService`: migrar `extends ChangeNotifier` a `with StudioPureNotifierMixin` y aceptar `IStudioLogger`.
3. **Separar catalogo Pure Dart de `StudioThemeCatalogService` del binding Flutter (Prioridad S1):**
   - Extraer `StudioThemeCatalogPureService with StudioPureNotifierMixin` (sin importar `StudioThemeController` ni `StudioDesignTokens`), exponiendo `availableSkins`, `activeSkin`, `selectSkin()`, `importThemeFromJson()` y `exportThemeToJson()`.
   - Mantener el adaptador Flutter que escucha `StudioThemeCatalogPureService` y aplica `StudioThemeSkinTokensMapper.toDesignTokens()` sobre `StudioThemeController`.
4. **Serializacion JSON faltante (Prioridad S1):**
   - Implementar `toJson()` y `fromJson()` en `StudioDockLayoutEntity`, `StudioPanelDescriptor`, `StudioFileEntity` y `StudioFolderEntity`.
5. **Offloading a Isolate en `TunnerPackageCodecService` (Prioridad S1):**
   - Agregar `Future<Uint8List> encodePackageAsync(...)` y `Future<TunnerProjectPackageEntity> decodePackageAsync(...)` delegando a `Isolate.run` para evitar bloqueo del servidor MCP con proyectos que contengan stems PCM pesados.
6. **Implementar contrato de bus IPC local (`IStudioUiIpcBridge`) (Prioridad S2):**
   - Definir la interfaz Pure Dart `IStudioUiIpcBridge` en `lib/core/domain/` para emitir los 7 eventos IPC especificados en la Seccion 3.3 sin acoplar el servidor MCP a ningun widget Flutter.
