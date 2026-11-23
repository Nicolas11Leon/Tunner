# Auditoría Forense MCP: Project Format y Song Library (`06`)

- **Módulos auditados:** `lib/features/project_format/` (7 archivos) y `lib/features/song_library/` (8 archivos)
- **Total de archivos inspeccionados:** 15 archivos `.dart`
- **Objetivo:** Evaluar preparación para ejecución Headless Pure Dart (`dart run`) y especificar la interfaz MCP para persistencia binaria de proyectos (`.tunner`) y presets de herramientas (`.tnt`), biblioteca curada, descompositor de canciones en stems, adaptación instrumental y sesiones Minus-One.

---

## 1. Inventario Archivo por Archivo

### 1.1 `lib/features/project_format/` (7 archivos)

| Archivo | Capa | Clases Principales | Métodos / Funciones Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- | :--- |
| `lib/features/project_format/domain/tunner_project_package.dart` | Domain (Pure Dart) | `TunnerProjectPackage` | `copyWith()`, `toJson()`, `fromJson()` | `UC-082`, `UC-094`, `UC-106` |
| `lib/features/project_format/domain/tunner_tool_preset.dart` | Domain (Pure Dart) | `TunnerToolPreset` | `fromModule()`, `toModuleEntity()`, `toJson()`, `fromJson()` | `UC-082`, `UC-106` |
| `lib/features/project_format/domain/patchbay_routing_connection.dart` | Domain (Pure Dart) | `PatchbayRoutingConnection` | `toJson()`, `fromJson()` | `UC-082`, `UC-106` |
| `lib/features/project_format/domain/i_tunner_binary_codec.dart` | Domain (Pure Dart) | `ITunnerBinaryCodec` | `encodeProject()`, `decodeProject()`, `encodeToolPreset()`, `decodeToolPreset()` | `UC-106`, `UC-126` |
| `lib/features/project_format/domain/project_storage_repository.dart` | Domain (Pure Dart) | `ProjectStorageRepository`, `NoOpProjectStorageRepository` | `saveProject()`, `loadProject()`, `loadProjectFromBytes()`, `encodeProjectToBytes()`, `saveToolPreset()`, `loadToolPreset()`, `encodeToolPresetToBytes()`, `loadToolPresetFromBytes()` | `UC-035`, `UC-082`, `UC-106` |
| `lib/features/project_format/data/tunner_binary_project_codec.dart` | Data (Pure Dart `dart:io` ZLib) | `TunnerBinaryProjectCodec`, `_BoundedByteAccumulatorSink` | `encodeProject()`, `decodeProject()`, `encodeToolPreset()`, `decodeToolPreset()`, magic bytes `TUNP`/`TNTP`, protección anti Zip-Bomb (64 MB) por chunks | `UC-082`, `UC-106`, `UC-126` |
| `lib/features/project_format/data/local_project_storage_repository.dart` | Data (Pure Dart `dart:io`, `dart:isolate`) | `LocalProjectStorageRepository` | Implementación en disco con `Isolate.run` para codificación/decodificación ZLib sin bloqueo | `UC-035`, `UC-082`, `UC-106`, `UC-126` |

### 1.2 `lib/features/song_library/` (8 archivos)

| Archivo | Capa | Clases Principales | Métodos / Funciones Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- | :--- |
| `lib/features/song_library/domain/song_package_entity.dart` | Domain (Pure Dart) | `SongDifficulty`, `MusicGenre`, `SongPackage` | `totalMeasures`, `initialTimeSignature`, `copyWith()`, `toMap()`, `fromMap()` | `UC-008`, `UC-161` |
| `lib/features/song_library/domain/i_song_decomposer_service.dart` | Domain (Pure Dart) | `SongDecompositionTemplate`, `ISongDecomposerService` | `getCuratedLibrary()`, `getDecompositionTemplates()`, `decomposeCustomScore()`, `adaptSongPackageToInstrument()` | `UC-008`, `UC-161` |
| `lib/features/song_library/domain/song_decomposer_service.dart` | Domain (Pure Dart `dart:isolate`) | `SongDecomposerService`, `DefaultSongDecomposerService` | `getCuratedLibrary()`, `getDecompositionTemplates()`, `normalizeNoteName()`, `parseMelodyText()`, `decomposeCustomScore()`, `decomposeCustomScoreAsync()`, `adaptSongPackageToInstrument()`, `adaptScoreToInstrument()` | `UC-008`, `UC-061`, `UC-161` |
| `lib/features/song_library/data/song_decomposer_service.dart` | Data (Re-export Pure Dart) | Re-exporta `../domain/song_decomposer_service.dart` | Compatibilidad retroactiva | `UC-008` |
| `lib/features/song_library/domain/minus_one_session_entity.dart` | Domain (Pure Dart) | `MinusOneSessionEntity` | `totalNotesEvaluated`, `hitNotesCount`, `accuracyPercentage`, `averageCentsDeviation`, `rushingCount`, `draggingCount`, `onTimeCount`, `overallScore`, `sessionGrade`, `copyWith()` | `UC-061` |
| `lib/features/song_library/domain/minus_one_orchestrator.dart` | Domain (Pure Dart) | `MinusOneOrchestrator` | `detectUserTrack()`, `getAccompanimentStems()`, `isSingleTrackWork()`, `configureMinusOneMixer()`, `restoreFullEnsembleMixer()`, `createSession()`, `recordEvaluation()`, `calculateSessionGrade()` | `UC-061` |
| `lib/features/song_library/presentation/song_decomposer_modal.dart` | Presentation (Flutter UI) | `SongDecomposerModal`, `_SongDecomposerModalState` | `show()`, `_applyTemplate()`, `_executeDecomposition()`, `build()` | `UC-008`, `UC-061`, `UC-161` |
| `lib/features/song_library/presentation/studio_assets_modals.dart` | Presentation (Flutter UI) | `StudioAssetsModals` | `showNewScoreDialog()`, `showImportScoreDialog()`, `showNewTuningPresetDialog()` | `UC-075`, `UC-095`, `UC-101` |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Acoplamientos con `package:flutter/` y `dart:ui`

| Archivo | Imports Bloqueantes | Impacto en CLI Pure Dart | Severidad |
| :--- | :--- | :--- | :--- |
| Todos los 7 archivos de `project_format/` | Ninguno (verificado transitivamente `RackModuleEntity` y `SignalType`: 100% Pure Dart) | **100% compatible Headless Pure Dart.** | Ninguna |
| Todos los 6 archivos de `song_library/domain/` y `data/` | Ninguno (verificado transitivamente `AudioTrack`, `InstrumentProfileEntity`, `InstrumentPedagogyAdapterEngine`, `NoteEntity`, `NoteEvaluationEntity`: 100% Pure Dart) | **100% compatible Headless Pure Dart.** | Ninguna |
| `song_decomposer_modal.dart` y `studio_assets_modals.dart` | `package:flutter/material.dart`, `TunerViewModel`, `StudioDesignSystem` | Exclusivos de UI; no se invocan en el servidor MCP. | Ninguna |

### 2.2 Brechas Funcionales y de Seguridad

1. **Contenedor `.tunner` (`TunnerProjectPackage`) sin Campo Tipado para Partituras ni Assets:**
   - `TunnerProjectPackage` serializa `tools` (`List<TunnerToolPreset>`) y `patchConnections`, pero no posee una lista tipada de partituras (`List<SongPackage>`) ni scripts DSL embebidos. Actualmente, guardar una partitura dentro de un `.tunner` obliga a incrustarla como JSON no tipado dentro de `TunnerToolPreset.toolParameters`, dificultando la introspección y validación por agentes IA.
2. **Ausencia de Validación de Fronteras de Sistema de Archivos (Path Traversal) en `LocalProjectStorageRepository`:**
   - `saveProject()`, `loadProject()`, `saveToolPreset()` y `loadToolPreset()` aceptan cualquier `filePath` arbitrario sin validar que permanezca dentro de una raíz de workspace permitida. Al exponerse vía MCP a un agente IA, esto constituye un riesgo de lectura/escritura fuera de sandbox.
3. **Sin Verificación Criptográfica de Integridad ni Listado de Proyectos en Repositorio:**
   - El formato binario `TUNP`/`TNTP` (`4 bytes magic + 1 byte version + payload ZLib`) no incluye checksum SHA-256 ni tabla de metadatos legible sin descomprimir el payload completo.
   - `ProjectStorageRepository` carece de operaciones de descubrimiento (`listProjects(dir)`, `listToolPresets(dir)`, `deleteProject(path)`).
4. **Limitaciones del Descompositor Musical (`SongDecomposerService`):**
   - `parseMelodyText()` solo soporta entradas monofónicas (`Do4:4 Re4:4`); no soporta sintaxis de acordes simultáneos (ej. `[Do4,Mi4,Sol4]:4`) ni silencios/notas que excedan un compás con ligadura automática (`isTied`).
   - `_buildHarmonyMeasures()` construye siempre una tríada mayor fija (`+4`, `+7` semitonos) sobre la primera nota de cada compás, ignorando la tonalidad/modo (en obras menores como *Greensleeves* o *Para Elisa* genera acordes mayores disonantes fuera de escala).
   - `adaptSongPackageToInstrument()` no adapta `package.stemScores` (pierde el mapa `stemScores` al construir el nuevo `SongPackage` en las líneas 600-609) ni aplica la transposición escrita de instrumentos transpositores (`transpositionSemitones`), solo desplaza por octavas a la tesitura física.
   - `MinusOneSessionEntity` no implementa `toJson()` / `fromJson()`, necesario para exponer sesiones evaluadas como Resources MCP y persistirlas.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON |
| :--- | :--- | :--- |
| `tunner://project/active` | Estado serializado del proyecto `.tunner` actualmente cargado en sesión (`TunnerProjectPackage.toJson()`). | `{ "formatVersion": 1, "projectId": "str", "projectName": "str", "author": "str", "masterBpm": 120.0, "referenceA4Hz": 440.0, "musicalKey": "C Major", "tools": [...], "patchConnections": [...], "scores": [...] }` |
| `tunner://projects/workspace` | Listado de archivos `.tunner` y `.tnt` detectados dentro del directorio de workspace autorizado. | `{ "workspaceRoot": "str", "projects": [{ "fileName": "str", "relativePath": "str", "sizeBytes": 4096, "modifiedAt": "iso8601" }], "presets": [...] }` |
| `tunner://library/curated` | Catálogo completo de obras curadas offline retornadas por `SongDecomposerService.getCuratedLibrary()`. | `{ "songs": [{ "id": "pachelbel_canon", "title": "Canon en Re Mayor", "composer": "Johann Pachelbel", "genre": "baroque", "difficulty": "intermediate", "defaultBpm": 68, "totalMeasures": 2, "tracks": [...] }] }` |
| `tunner://library/templates` | Plantillas de descomposición listas para sintetizar stems (`SongDecomposerService.getDecompositionTemplates()`). | `{ "templates": [{ "title": "str", "composer": "str", "genre": "str", "difficulty": "str", "bpm": 100, "timeSignature": "4/4", "melodyNotation": "str" }] }` |
| `tunner://minus-one/session` | Estado y métricas pedagógicas de la sesión Minus-One activa (`MinusOneSessionEntity`). | `{ "songId": "str", "userTrackId": "str", "isMinusOneActive": true, "isMutedUserTrack": true, "guideTrackVolume": 0.0, "totalNotesEvaluated": 16, "accuracyPercentage": 93.75, "averageCentsDeviation": 4.2, "sessionGrade": "A" }` |

### 3.2 Tools (`tunner_*`)

| Tool Name | Parámetros (JSON Schema Resumido) | Salida | Mapeo Exacto en Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_project_save` | `{ relativePath: string, projectName?: string, author?: string, masterBpm?: number, referenceA4Hz?: number, musicalKey?: string, notes?: string }` | `{ savedPath, sizeBytes, formatVersion }` | `LocalProjectStorageRepository.saveProject()` + `TunnerBinaryProjectCodec.encodeProject()` |
| `tunner_project_load` | `{ relativePath: string }` | `{ projectId, projectName, masterBpm, referenceA4Hz, musicalKey, toolsCount, patchConnectionsCount }` | `LocalProjectStorageRepository.loadProject()` + `TunnerBinaryProjectCodec.decodeProject()` |
| `tunner_tool_preset_save` | `{ relativePath: string, moduleTypeCode: string, customTitle: string, toolParameters: object, isPoweredOn?: bool }` | `{ savedPath, sizeBytes, moduleTypeCode }` | `LocalProjectStorageRepository.saveToolPreset()` + `TunnerToolPreset` |
| `tunner_tool_preset_load` | `{ relativePath: string }` | `{ moduleTypeCode, customTitle, defaultViewMode, isPoweredOn, toolParameters }` | `LocalProjectStorageRepository.loadToolPreset()` |
| `tunner_library_load_song` | `{ songId: string }` | `{ id, title, composer, defaultBpm, totalMeasures, tracks[] }` | `SongDecomposerService.getCuratedLibrary()` (`song_decomposer_service.dart`) |
| `tunner_song_decompose` | `{ title: string, composer?: string, bpm: int, timeSignature: string, melodyNotation: string, includeLead?: bool, includePiano?: bool, includeBass?: bool, includeRhythm?: bool }` | `{ id, title, totalMeasures, tracks[], stemIds[] }` | `SongDecomposerService.parseMelodyText()` + `SongDecomposerService.decomposeCustomScore()` |
| `tunner_song_adapt_instrument` | `{ songId?: string, instrumentId: string }` | `{ id, title, adaptedInstrument, totalMeasures, shiftedNotesCount }` | `SongDecomposerService.adaptSongPackageToInstrument()` (`song_decomposer_service.dart`) |
| `tunner_minus_one_configure` | `{ activeInstrumentId: string, muteUserTrack?: bool, guideVolume?: number (0.0..1.0) }` | `{ userTrackId, accompanimentTracks[], isMinusOneActive, session }` | `MinusOneOrchestrator.detectUserTrack()`, `configureMinusOneMixer()`, `createSession()` |
| `tunner_minus_one_restore` | `{ userTrackId: string, standardVolume?: number }` | `{ userTrackId, muted: false, volume }` | `MinusOneOrchestrator.restoreFullEnsembleMixer()` (`minus_one_orchestrator.dart`) |

### 3.3 Prompts

1. **`create_practice_arrangement_package`**:
   - **Propósito:** Crear un paquete de estudio completo a partir de una melodía escrita por el usuario o una plantilla, descomponerla en 4 stems (Lead, Piano, Bajo, Ritmo), adaptarla al instrumento objetivo, configurar una sesión Minus-One y guardar el proyecto en formato `.tunner`.
   - **Flujo guiado:** `tunner_song_decompose` -> `tunner_song_adapt_instrument` -> `tunner_minus_one_configure` -> `tunner_project_save`.
2. **`audit_tunner_project_file`**:
   - **Propósito:** Cargar un archivo `.tunner` existente, inspeccionar sus módulos de rack, conexiones del patchbay, afinación de referencia y partituras asociadas, generando un diagnóstico técnico para el usuario.
   - **Flujo guiado:** `tunner_project_load` -> leer `tunner://project/active` -> validar partituras y conexiones.

---

## 4. Plan de Ajustes Técnicos Previos

1. **Extender `TunnerProjectPackage` (v2 retrocompatible) para Embeber Partituras (`SongPackage`) (Prioridad Crítica):**
   - Agregar `final List<SongPackage> scores;` (default `const []`) y `final Map<String, String> dslScripts;` (default `const {}`) a `TunnerProjectPackage`, serializados con `toMap()` / `fromMap()` manteniendo compatibilidad con proyectos `formatVersion == 1`.
2. **Endurecer Seguridad de Rutas y Descubrimiento en `LocalProjectStorageRepository` (Prioridad Crítica):**
   - Inyectar un `workspaceRootDir` opcional en `LocalProjectStorageRepository` que valide rutas canonizadas (`File(path).resolveSymbolicLinksSync()` / normalización) impidiendo Path Traversal fuera del workspace cuando se opere desde MCP.
   - Agregar métodos `listProjects(String directoryPath)` y `listToolPresets(String directoryPath)`.
   - Añadir verificación de integridad opcional (hash SHA-256 sobre el payload JSON usando `package:crypto`, ya presente en `pubspec.yaml`).
3. **Corregir Armonización, Adaptación de Stems y Sintaxis Polifónica en `SongDecomposerService` (Prioridad Alta):**
   - Preservar y adaptar `stemScores` dentro de `SongDecomposerService.adaptSongPackageToInstrument()` en lugar de descartarlos.
   - Mejorar `_buildHarmonyMeasures()` para aceptar tonalidad/modo (`keySignatureFifths`, mayor/menor) y construir tríadas diatónicas en lugar de tríadas mayores fijas sobre cada primera nota.
   - Extender `parseMelodyText()` para soportar acordes simultáneos (`[Do4,Mi4,Sol4]:4`) y notas ligadas a través de compases.
4. **Serialización JSON Completa para `MinusOneSessionEntity` (Prioridad Media):**
   - Implementar `toJson()` / `fromJson()` en `MinusOneSessionEntity` (y en `NoteEvaluationEntity` si no existiera) para exposición directa en `tunner://minus-one/session` y persistencia en proyectos `.tunner`.
