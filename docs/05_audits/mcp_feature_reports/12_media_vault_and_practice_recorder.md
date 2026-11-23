# Auditoría Forense MCP-Readiness: Bóveda Multimedia y Grabadora de Práctica (`media_vault` + `practice_recorder`)

## Metadatos del Reporte

- **ID del Reporte:** `AUDIT-MCP-2026-012`
- **Módulos Auditados:** `lib/features/media_vault/` (12 archivos `.dart`) y `lib/features/practice_recorder/` (12 archivos `.dart`)
- **Total de Archivos Inspeccionados:** 24 archivos `.dart`
- **Referencia MCP:** `UC-186` (`docs/02_use_cases/186_uc_tunner_mcp_server_orchestration.md`)
- **Estado de Preparación Headless:** Alta madurez en `domain/` (ambos módulos tienen contratos DIP, modelos con serialización JSON y `UniversalMediaIoService` 100% Pure Dart). Los bloqueos principales son acoplamientos ligeros (`package:flutter/foundation.dart` en los ViewModels/Controladores, `audioplayers`/`record` en servicios de hardware de `practice_recorder`) y brechas de soporte WAV estéreo/24-bit y análisis offline de archivos grabados.

---

## 1. Inventario Archivo por Archivo

### 1.1 `lib/features/media_vault/domain/` (6 archivos)

| Archivo `.dart` | Clases / Tipos Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
|---|---|---|---|
| `lib/features/media_vault/domain/i_media_io_port.dart` | `IMediaIoService`, `IMediaVaultRepository`, `NoOpMediaIoService` | `importBytes`, `exportTimeline`; contrato CRUD de repositorio (`getAll`, `findById`, `upsert`, `upsertAll`, `remove`, `clear`) | `UC-070`, `UC-122`, `UC-141` |
| `lib/features/media_vault/domain/in_memory_media_vault_repository.dart` | `InMemoryMediaVaultRepository` | Implementación en memoria de `IMediaVaultRepository` con materialización diferida (lazy) de 4 activos semilla offline (`seed_house_groove`, `seed_vocal_stem`, `seed_flute_score`, `seed_bassline_midi`) | `UC-070`, `UC-144`, `UC-166` |
| `lib/features/media_vault/domain/media_asset_entity.dart` | `MediaAssetKind` (enum), `MediaAssetKindMetadata`, `MediaAssetEntity` | `matchesFilter`, `copyWith`, `toMetadataJson` (con opción `includeRawBytes`), `fromMetadataJson` | `UC-070`, `UC-140`, `UC-166` |
| `lib/features/media_vault/domain/media_synergy_target.dart` | `MediaSynergyTarget` (enum), `MediaExportFormat` (enum), `MediaImportResult`, `MediaExportResult` | Destinos de sinergia (`djDeckA`, `djDeckB`, `djSamplerPad`, `scoreEditor`, `mixerChannel`) y 6 formatos de exportación (`wavMixdown`, `cueSheet`, `tunnerBundleJson`, `midi`, `musicXml`, `abcNotation`) | `UC-070`, `UC-167`, `UC-179` |
| `lib/features/media_vault/domain/timeline_project_entity.dart` | `TimelineTrackKind`, `TimelineClipEntity`, `TimelineTrackEntity`, `TimelineProjectEntity` | `defaultWorkspace`, `beatDurationMs`, `totalDurationMs`, `quantizeMs`, `resolveNonOverlappingStartMs`, `placeAssetOnTrack`, `moveClip`, `removeClip`, `toggleTrackMute`, `toggleTrackSolo`, `isTrackAudible`, `toJson`, `fromJson` | `UC-070`, `UC-140`, `UC-166`, `UC-167` |
| `lib/features/media_vault/domain/wav_pcm_codec.dart` | `DecodedWavPcm`, `WavPcmCodec` | `encodeMono16Bit`, `decode` (RIFF/WAVE 16-bit PCM a `Float64List` mono), `extractPeaks` | `UC-070`, `UC-166`, `UC-167` |

### 1.2 `lib/features/media_vault/data/` (3 archivos)

| Archivo `.dart` | Clases / Tipos Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
|---|---|---|---|
| `lib/features/media_vault/data/in_memory_media_vault_repository.dart` | Re-export de `../domain/in_memory_media_vault_repository.dart` | Compatibilidad legacy | `UC-122`, `UC-176` |
| `lib/features/media_vault/data/universal_media_io_service.dart` | `UniversalMediaIoService`, `_TrackClipPair` | `importBytes` (WAV con auto-BPM/Camelot, MIDI, MusicXML, MXL, ABC, PDF, `.tunner.json`), `exportTimeline` (mixdown WAV, CUE sheet, `.tunner.json`, MIDI, MusicXML, ABC) — **100% Pure Dart** | `UC-070`, `UC-140`, `UC-167`, `UC-179` |
| `lib/features/media_vault/data/wav_pcm_codec.dart` | Re-export de `../domain/wav_pcm_codec.dart` | Compatibilidad legacy | `UC-122`, `UC-176` |

### 1.3 `lib/features/media_vault/presentation/` (3 archivos)

| Archivo `.dart` | Clases / Tipos Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
|---|---|---|---|
| `lib/features/media_vault/presentation/media_vault_viewmodel.dart` | `MediaVaultViewModel` (`ChangeNotifier`) | `pickAndImportFile`, `exportTimelineToDisk`, `persistCatalogToDisk`, `registerAsset`, `removeAsset`, `dropAssetOnTrack`, `moveClip`, `removeClip`, `toggleTrackMute`, `toggleTrackSolo`, `importExternalBytes`, `exportTimeline`, `dispatchAssetToTool`, transporte del timeline | `UC-070`, `UC-140`, `UC-166`, `UC-167`, `UC-179` |
| `lib/features/media_vault/presentation/media_vault_workspace_modal.dart` | `MediaVaultWorkspaceModal`, `_ClipWaveformPainter` | Modal completo de gestión del Media Vault y arreglos en timeline con drag-and-drop | `UC-070`, `UC-167`, `UC-184` |
| `lib/features/media_vault/presentation/timeline_arrangement_painter.dart` | `TimelineArrangementPainter` | `CustomPainter` de cuadrícula de compases, beatgrid y cabezal de reproducción | `UC-070`, `UC-175` |

### 1.4 `lib/features/practice_recorder/domain/` (5 archivos)

| Archivo `.dart` | Clases / Tipos Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
|---|---|---|---|
| `lib/features/practice_recorder/domain/i_audio_playback_service.dart` | `IAudioPlaybackService`, `NoOpAudioPlaybackService` | Contrato DIP de reproducción de tomas (`play`, `pause`, `stop`, `seek`, `setPlaybackRate`, streams de posición/duración/completado) | `UC-012`, `UC-122`, `UC-141` |
| `lib/features/practice_recorder/domain/i_practice_recorder_service.dart` | `IPracticeRecorderService`, `NoOpPracticeRecorderService` | Contrato DIP de captura de micrófono (`startRecording`, `stopRecording`, `pauseRecording`, `resumeRecording`, `amplitudeStream`) | `UC-012`, `UC-122`, `UC-141` |
| `lib/features/practice_recorder/domain/multitrack_session_entity.dart` | `TimedPitchSample`, `TimedSpectralSample`, `PracticeTakeEntity`, `MultiTrackSessionEntity` | `averagePitchDeviationCents`, `averageSpectralCentroidHz`, gestión de tomas (mute, solo, gain, selección A/B), `toMap`, `fromMap`, `toJson`, `fromJson` | `UC-032`, `UC-060`, `UC-163` |
| `lib/features/practice_recorder/domain/practice_recording_entity.dart` | `PracticeRecordingEntity` | `formattedDuration`, `formattedDateTime`, `copyWith`, `toMap`, `fromMap`, `toJson`, `fromJson` | `UC-012`, `UC-163` |
| `lib/features/practice_recorder/domain/spectral_comparator_service.dart` | `SpectralComparisonPoint`, `SpectralComparisonResult`, `SpectralComparatorService` | `compareTakes` (alineación temporal uniforme por `timeStepMs`, desviación media en cents, % afinación `+-5 cents`, delta de centroide espectral Hz y diagnóstico pedagógico objetivo) | `UC-032`, `UC-060`, `UC-163`, `UC-178` |

### 1.5 `lib/features/practice_recorder/data/` (2 archivos)

| Archivo `.dart` | Clases / Tipos Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
|---|---|---|---|
| `lib/features/practice_recorder/data/audio_playback_service.dart` | `AudioPlaybackService` | Implementación de `IAudioPlaybackService` sobre `IStudioAudioEngine`/`AudioPlayer` | `UC-012`, `UC-099`, `UC-128` |
| `lib/features/practice_recorder/data/practice_recorder_service.dart` | `PracticeRecorderService` | Implementación de `IPracticeRecorderService` sobre `package:record` (`AudioRecorder`, WAV/AAC-LC, polling de amplitud dBFS a 10 Hz) | `UC-012`, `UC-128`, `UC-131` |

### 1.6 `lib/features/practice_recorder/presentation/` (5 archivos)

| Archivo `.dart` | Clases / Tipos Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
|---|---|---|---|
| `lib/features/practice_recorder/presentation/practice_recorder_controller.dart` | `PracticeRecorderController` | `startPracticeRecording`, `stopPracticeRecording`, `recordSampleForMultiTrack` (usa `HarmonicSeriesAnalyzer`), `addPracticeTake`, `setTakeMute/Solo/Gain`, `selectComparisonTakes`, `deletePracticeRecordingById`, `downsampleWaveformPeaks`, persistencia vía `ILocalPersistenceService` | `UC-012`, `UC-032`, `UC-142`, `UC-163`, `UC-185` |
| `lib/features/practice_recorder/presentation/practice_recorder_dock.dart` | `PracticeRecorderDock` | Barra acoplable de grabación rápida y visualización de forma de onda | `UC-012`, `UC-139` |
| `lib/features/practice_recorder/presentation/practice_recording_player_modal.dart` | `PracticeRecordingPlayerModal`, `_SpeedPill`, `_WaveformPainter` | Reproductor de tomas con control de velocidad (0.5x..1.5x) y scrubbing | `UC-012`, `UC-139` |
| `lib/features/practice_recorder/presentation/spectral_comparator_modal.dart` | `SpectralComparatorModal` | Modal de comparación espectral y de afinación entre Toma A y Toma B | `UC-032`, `UC-163` |
| `lib/features/practice_recorder/presentation/spectral_comparator_painter.dart` | `SpectralComparatorPainter` | `CustomPainter` con `dart:ui` para gráficas superpuestas de cents y centroide espectral | `UC-032`, `UC-175` |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Acoplamientos Bloqueantes para CLI Pure Dart

1. **`lib/features/media_vault/presentation/media_vault_viewmodel.dart` (Bloqueo Bajo-Medio):**
   - Importa `package:flutter/foundation.dart` únicamente por `ChangeNotifier`.
   - Toda la lógica de persistencia del catálogo a disco (`persistCatalogToDisk`, `_restoreCatalogFromDisk`), secuencia de IDs de clips y exportación a disco (`exportTimelineToDisk`) vive dentro del `ChangeNotifier`, en lugar de un servicio/orquestador de dominio puro (`MediaVaultSessionService`).
2. **`lib/features/practice_recorder/presentation/practice_recorder_controller.dart` (Bloqueo Trivial):**
   - Importa `package:flutter/foundation.dart` **exclusivamente por el typedef `VoidCallback`**. Reemplazar `VoidCallback` por `void Function()` elimina el 100% de la dependencia de Flutter en este archivo de 586 líneas.
3. **`lib/features/practice_recorder/data/audio_playback_service.dart` y `practice_recorder_service.dart` (Bloqueos Esperados de Hardware GUI):**
   - Importan `package:audioplayers/audioplayers.dart`, `package:flutter/foundation.dart` (`kIsWeb`) y `package:record/record.dart`. En entorno headless MCP deben sustituirse por `NoOpAudioPlaybackService` y `NoOpPracticeRecorderService` (ambos ya disponibles y Pure Dart en `domain/`) o por una implementación headless de ingesta de archivos WAV.

### 2.2 Brechas Funcionales para Gestión por Agentes IA

1. **Limitaciones de `WavPcmCodec` en `media_vault`:**
   - `WavPcmCodec.decode` rechaza cualquier WAV que no sea exactamente PCM 16-bit (`bitsPerSample != 16` retorna `null`), bloqueando la importación de archivos de estudio en 24-bit PCM o 32-bit float.
   - `WavPcmCodec` solo expone `encodeMono16Bit`: el mixdown WAV exportado por `UniversalMediaIoService.exportTimeline` es monoaural y no aplica paneo estéreo ni ganancia por pista si se añadiera `pan` a `TimelineTrackEntity`.
   - Existen dos códecs WAV separados en el proyecto (`WavPcmCodec` en `media_vault` sobre `Float64List` y `PcmWavDecoder`/`DjMixWavEncoder` en `dj_console` sobre `Float32List`), con capacidades asimétricas.
2. **Persistencia de `InMemoryMediaVaultRepository` acoplada al ViewModel:**
   - `IMediaVaultRepository` carece de una implementación `FileMediaVaultRepository` (Pure Dart sobre `StudioFileSystemRepository` o `dart:io`), por lo que en modo headless el catálogo no persiste automáticamente sin replicar la lógica de `MediaVaultViewModel`.
3. **Ausencia de edición de clips avanzada en `TimelineProjectEntity`:**
   - `TimelineProjectEntity` soporta `placeAssetOnTrack`, `moveClip`, `removeClip`, `toggleTrackMute` y `toggleTrackSolo`, pero carece de `trimClip(trackId, clipId, {trimStartMs, durationMs})`, `setTrackVolume(trackId, volume)`, `addTrack` y `removeTrack`.
4. **Ausencia de serialización JSON en `SpectralComparisonResult` y `SpectralComparisonPoint`:**
   - `SpectralComparatorService.compareTakes` retorna objetos sin `toMap()` / `toJson()`, impidiendo su serialización directa como salida de Tool MCP.
5. **Falta de ingesta offline de archivo WAV a `PracticeTakeEntity`:**
   - Actualmente `PracticeTakeEntity` con sus tracks `pitchTrack` y `spectralTrack` solo se construye en tiempo real durante la grabación desde micrófono (`recordSampleForMultiTrack`). Para que un agente IA en CLI headless pueda comparar dos archivos `.wav` grabados previamente en disco, falta un servicio Pure Dart `OfflinePracticeTakeAnalyzer` que decodifique un WAV, ejecute MPM (`pitchTrack`) + `HarmonicSeriesAnalyzer` (`spectralTrack`) y produzca un `PracticeTakeEntity` listo para `SpectralComparatorService.compareTakes`.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON Resumida |
|---|---|---|
| `tunner://vault/assets` | Catálogo completo de activos indexados en la Bóveda Multimedia (sin `rawBytesBase64` para mantener bajo consumo de tokens). | `{ "count": 4, "assets": [ { "id": "seed_house_groove", "title": "Midnight Groove 124", "fileName": "midnight_groove_124.wav", "kind": "audioTrack", "durationMs": 4000, "bpm": 124.0, "camelotKey": "8A", "sampleRate": 44100, "tags": ["house", "club"] } ] }` |
| `tunner://vault/timeline` | Estado completo del proyecto de timeline multipista (`TimelineProjectEntity`), incluyendo pistas, clips, mute/solo, beatgrid y duración total. | `{ "id": "timeline_default", "title": "...", "masterBpm": 124.0, "snapToBeatgrid": true, "totalDurationMs": 16000, "tracks": [ { "id": "track_1", "name": "Audio 1", "kind": "audio", "isMuted": false, "isSolo": false, "clips": [ { "id": "clip_1", "assetId": "seed_house_groove", "startMs": 0, "durationMs": 4000 } ] } ] }` |
| `tunner://recorder/history` | Historial de grabaciones de práctica (`PracticeRecordingEntity`) y metadatos de duración/BPM. | `{ "count": 2, "recordings": [ { "id": "rec_1", "songTitle": "Estudio en La Menor", "filePath": "...", "durationMs": 45000, "bpm": 100, "recordedAt": "2026-11-23T..." } ] }` |
| `tunner://recorder/session` | Sesión multipista activa (`MultiTrackSessionEntity`) con todas las tomas (`PracticeTakeEntity`), promedios de desviación en cents, centroide espectral y selección A/B. | `{ "id": "session_1", "title": "...", "bpm": 100, "selectedTakeAId": "take_1", "selectedTakeBId": "take_2", "takes": [ { "id": "take_1", "name": "Toma 1", "averagePitchDeviationCents": 8.4, "averageSpectralCentroidHz": 1120.5, "gain": 1.0, "isMuted": false, "isSolo": false } ] }` |

### 3.2 Tools (`tunner_*`)

| Tool Name | Parámetros (JSON Schema Resumido) | Salida | Mapeo Exacto en Tunner |
|---|---|---|---|
| `tunner_vault_import_file` | `{ "file_path": "string (required)" }` | `{ "success": true, "importedAssets": [...], "restoredTimeline": "bool", "message": "..." }` | `UniversalMediaIoService.importBytes` + `IMediaVaultRepository.upsertAll` |
| `tunner_vault_search_assets` | `{ "query?": "string", "kind?": "audioTrack|stem|sheetMusic|midiSequence|practiceRecording|djSessionPreset" }` | `{ "matches": [ { "id": "...", "title": "...", "bpm": 124.0, "camelotKey": "8A" } ] }` | `IMediaVaultRepository.getAll` + `MediaAssetEntity.matchesFilter` |
| `tunner_vault_remove_asset` | `{ "asset_id": "string" }` | `{ "removedAssetId": "string", "remainingCount": 3 }` | `IMediaVaultRepository.remove` |
| `tunner_vault_place_clip` | `{ "asset_id": "string", "track_id": "string", "start_ms": "int", "quantize?": "bool (default true)" }` | `{ "clipId": "string", "resolvedStartMs": 4000, "totalDurationMs": 8000 }` | `TimelineProjectEntity.placeAssetOnTrack` |
| `tunner_vault_move_clip` | `{ "from_track_id": "string", "to_track_id": "string", "clip_id": "string", "new_start_ms": "int" }` | `{ "clipId": "string", "toTrackId": "string", "resolvedStartMs": 8000 }` | `TimelineProjectEntity.moveClip` |
| `tunner_vault_remove_clip` | `{ "track_id": "string", "clip_id": "string" }` | `{ "removedClipId": "string", "totalDurationMs": 4000 }` | `TimelineProjectEntity.removeClip` |
| `tunner_vault_set_track_state` | `{ "track_id": "string", "toggle_mute?": "bool", "toggle_solo?": "bool" }` | `{ "trackId": "string", "isMuted": false, "isSolo": true, "isAudible": true }` | `TimelineProjectEntity.toggleTrackMute`, `toggleTrackSolo`, `isTrackAudible` |
| `tunner_vault_export_timeline` | `{ "format": "wavMixdown|cueSheet|tunnerBundleJson|midi|musicXml|abcNotation", "output_path": "string" }` | `{ "success": true, "outputPath": "string", "fileName": "string", "bytesWritten": 352844 }` | `UniversalMediaIoService.exportTimeline` |
| `tunner_recorder_analyze_wav_take` | `{ "file_path": "string", "take_name": "string", "add_to_session?": "bool (default true)" }` | `{ "takeId": "string", "durationMs": 12000, "averagePitchDeviationCents": 6.2, "averageSpectralCentroidHz": 1280.0, "pitchSamplesCount": 240 }` | Nuevo `OfflinePracticeTakeAnalyzer` (MPM + `HarmonicSeriesAnalyzer`) + `MultiTrackSessionEntity` |
| `tunner_recorder_compare_takes` | `{ "take_a_id": "string", "take_b_id": "string", "time_step_ms?": "int (default 50)", "include_points?": "bool (default false)" }` | `{ "meanPitchDeviationA": 11.2, "meanPitchDeviationB": 5.4, "pitchStabilityDelta": 5.8, "inTunePercentageA": 62.0, "inTunePercentageB": 88.5, "meanCentroidA": 1050.0, "meanCentroidB": 1260.0, "centroidDeltaHz": 210.0, "pedagogicalSummary": "..." }` | `SpectralComparatorService.compareTakes` |
| `tunner_recorder_manage_session_take` | `{ "take_id": "string", "gain?": "number [0,2]", "is_muted?": "bool", "is_solo?": "bool" }` | Estado actualizado de `PracticeTakeEntity` dentro de `MultiTrackSessionEntity` | `PracticeRecorderController.setTakeGain`, `setTakeMute`, `setTakeSolo` |

### 3.3 Prompts Guiados Sugeridos

1. **`vault_arrange_and_export_mix`**: Inspecciona `tunner://vault/assets`, selecciona clips armónicamente compatibles (por `camelotKey` y `bpm`), los organiza sin colisiones sobre las pistas del timeline (`tunner_vault_place_clip`), ajusta mute/solo y exporta simultáneamente el mixdown WAV y la hoja CUE (`tunner_vault_export_timeline`).
2. **`practice_take_diagnostic_coach`**: Ingresa dos tomas WAV de práctica de un estudiante (`tunner_recorder_analyze_wav_take`), ejecuta la comparación espectral y de entonación (`tunner_recorder_compare_takes`) y redacta un plan de corrección técnica basado en `pitchStabilityDelta`, `inTunePercentage` y `centroidDeltaHz`.

---

## 4. Plan de Ajustes Técnicos Previos

1. **Eliminar acoplamiento trivial de `package:flutter/foundation.dart` en `PracticeRecorderController`:**
   - Sustituir `VoidCallback` por `void Function()` en `lib/features/practice_recorder/presentation/practice_recorder_controller.dart` y mover la lógica de sesión multipista y análisis a `domain/practice_session_orchestrator.dart` (Pure Dart).
2. **Extraer `MediaVaultHeadlessService` y `FileMediaVaultRepository` en `media_vault`:**
   - Separar la coordinación de catálogo, timeline y persistencia en disco fuera de `MediaVaultViewModel` hacia `lib/features/media_vault/domain/media_vault_orchestrator.dart` (Pure Dart), dejando `MediaVaultViewModel` como adaptador `ChangeNotifier` para la GUI.
3. **Unificar y ampliar soporte WAV en `WavPcmCodec`:**
   - Soportar decodificación de WAV 8-bit, 16-bit, 24-bit PCM y 32-bit IEEE float.
   - Agregar `encodeStereo16Bit` y soporte de ganancia/paneo por pista en `UniversalMediaIoService.exportTimeline` para exportaciones `wavMixdown` de calidad de estudio.
4. **Completar serialización JSON en `SpectralComparatorService`:**
   - Implementar `toMap()` en `SpectralComparisonPoint` y `SpectralComparisonResult` (con bandera opcional `includePoints` para no saturar el contexto del LLM en sesiones largas).
5. **Implementar `OfflinePracticeTakeAnalyzer` (Pure Dart):**
   - Crear un servicio de dominio en `lib/features/practice_recorder/domain/offline_practice_take_analyzer.dart` que procese un archivo WAV en `Isolate.run` usando el motor MPM y `HarmonicSeriesAnalyzer` para construir `PracticeTakeEntity` sin depender de micrófono en vivo (`package:record`).
