# Auditoría Forense MCP-Readiness: Consola DJ y Mezclador Multipista (`dj_console` + `mixer`)

## Metadatos del Reporte

- **ID del Reporte:** `AUDIT-MCP-2026-010`
- **Módulos Auditados:** `lib/features/dj_console/` (53 archivos `.dart`) y `lib/features/mixer/` (1 archivo `.dart`)
- **Total de Archivos Inspeccionados:** 54 archivos `.dart`
- **Referencia MCP:** `UC-186` (`docs/02_use_cases/186_uc_tunner_mcp_server_orchestration.md`)
- **Estado de Preparación Headless:** Parcialmente listo (Capa `domain/` 100% Pure Dart; capa `data/` y `presentation/` con acoplamientos a `package:flutter/`, `path_provider` y `audioplayers` que bloquean ejecución CLI directa sin refactor de bordes).

---

## 1. Inventario Archivo por Archivo

### 1.1 `lib/features/mixer/` (1 archivo)

| Archivo `.dart` | Clases / Tipos Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
|---|---|---|---|
| `lib/features/mixer/domain/mixer_track_entity.dart` | `AudioTrack`, `MixerConsoleEntity` | `AudioTrack.getEffectiveGain`, `copyWith`, `toMap`, `fromMap`; `MixerConsoleEntity.defaultSetup`, `hasAnySolo`, `copyWithTrackVolume`, `toggleMute`, `setTrackMute`, `toggleSolo`, `getEffectiveGain`, `toMap`, `fromMap` | `UC-007`, `UC-036`, `UC-061`, `UC-087`, `UC-161` |

### 1.2 `lib/features/dj_console/domain/` (28 archivos)

| Archivo `.dart` | Clases / Tipos Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
|---|---|---|---|
| `lib/features/dj_console/domain/bpm_beat_tracker_engine.dart` | `BpmBeatTrackerEngine` | `estimateBpm`, `estimateBpmAsync` (`Isolate.run`), `estimate` (Onset Energy Flux + autocorrelación `[60, 180]` BPM) | `UC-066`, `UC-144`, `UC-152` |
| `lib/features/dj_console/domain/dj_action.dart` | `DjAction` (enum), `DjActionExtension` | Catálogo canónico de acciones DJ (play/pause, cue, sync, EQ kill, hot cues, loops, stems, sampler, automix, scratch, split-cue) | `UC-065`, `UC-084`, `UC-096` |
| `lib/features/dj_console/domain/dj_audio_processor.dart` | `StatefulDelayLine`, `DjAudioProcessor` | `StatefulDelayLine.process`, `reset`; `DjAudioProcessor.mixBuffers`, `apply3BandEq`, `applyBipolarFilter`, `applyDelay`, `generateDemoGroove`, `synthesizeSongPackageTrack`, `synthesizePresetTrack`, `applyStemIsolation`, `encodeSplitCueStereo` | `UC-066`, `UC-092`, `UC-097`, `UC-150`, `UC-151` |
| `lib/features/dj_console/domain/dj_channel_fx_entity.dart` | `DjDelayDivision` (enum), `DjChannelFxEntity` | Estado inmutable de filtro bipolar, delay sincronizado por subdivisión, feedback y dry/wet | `UC-066`, `UC-150` |
| `lib/features/dj_console/domain/dj_console_blueprint_entity.dart` | `DjConsoleBlueprintEntity` | `toHardwareSkin`, serialización de planos personalizados de consolas DJ | `UC-085`, `UC-153` |
| `lib/features/dj_console/domain/dj_controller_profile_entity.dart` | `DjControllerDeviceType`, `DjControllerProfileEntity` | `defaultUnified`, mapeo de tokens de controlador/gamepad a `DjAction` | `UC-068`, `UC-084` |
| `lib/features/dj_console/domain/dj_crossfader_entity.dart` | `CrossfaderCurve` (enum), `DjCrossfaderEntity` | `calculateGains` (curvas lineal, constant-power, scratch/sharp cut), `copyWith` | `UC-065`, `UC-083` |
| `lib/features/dj_console/domain/dj_cue_monitor_entity.dart` | `DjCueMonitorEntity` | Estado PFL (`cueDeckA`, `cueDeckB`), `isSplitCueEnabled`, `cueMasterMix` | `UC-069`, `UC-151` |
| `lib/features/dj_console/domain/dj_deck_entity.dart` | `DjDeckEntity` | `effectiveCamelotKey`, `effectiveBpm`, `trimDb`, `effectivePlaybackRate`, `centsOffset`, `pitchPercentage`, `effectiveGainLow/Mid/High`, `progressFraction`, `copyWith` | `UC-065`, `UC-069`, `UC-092`, `UC-151` |
| `lib/features/dj_console/domain/dj_gamepad_input_service.dart` | `DjActionTriggerCallback`, `DjInputCapturedCallback`, `DjGamepadInputService` | Despacho de tokens de entrada externa y modo Learn | `UC-068`, `UC-084` |
| `lib/features/dj_console/domain/dj_hardware_catalog.dart` | `DjHardwareCatalog` | Catálogo de skins de hardware (`ddjFlx4`, etc.), `registerCustomSkin`, `unregisterCustomSkin` | `UC-068`, `UC-079`, `UC-084`, `UC-153` |
| `lib/features/dj_console/domain/dj_hardware_skin_entity.dart` | `DjHardwareSkinEntity` | Modelo de layout geométrico y zonas interactivas de hardware DJ | `UC-068`, `UC-084` |
| `lib/features/dj_console/domain/dj_harmonic_camelot_engine.dart` | `CamelotCompatibility`, `CamelotKey`, `DjHarmonicCamelotEngine` | `wheel` (24 tonalidades 1A-12B), `findByCode`, `transpose`, `analyzeCompatibility`, `calculateOptimalSemitoneShift`, `estimateCamelotKeyFromSamples` (Goertzel + Krumhansl-Kessler) | `UC-069`, `UC-092`, `UC-151`, `UC-152` |
| `lib/features/dj_console/domain/dj_keymap_profile_entity.dart` | `DjKeymapProfileEntity` | `defaultErgonomic`, `toJson`, `fromJson`, mapeo de teclas a `DjAction` | `UC-065`, `UC-096` |
| `lib/features/dj_console/domain/dj_live_mix_recorder_entity.dart` | `DjLiveMixRecorderEntity` | Acumulación de chunks `Float32List`, `consolidateBuffer`, control de inicio/fin de sesión | `UC-066`, `UC-128` |
| `lib/features/dj_console/domain/dj_loop_and_slip_engine.dart` | `DjLoopAndSlipEngine` | Cálculo determinista de loops cuantizados por beats, halve/double loop, beat jump y puntero fantasma Slip Mode | `UC-069`, `UC-092` |
| `lib/features/dj_console/domain/dj_mix_wav_encoder.dart` | `DjMixWavEncoder` | `encode` (codificador RIFF/WAVE PCM 16-bit mono/estéreo sin dependencias) | `UC-066`, `UC-128` |
| `lib/features/dj_console/domain/dj_performance_orchestrator.dart` | `DjPerformanceOrchestrator` | Orquestador Pure Dart de ambos decks, crossfader, EQ, FX, 4-Stems, Camelot (`syncKey`, `harmonicCompatibility`), loops/slip, sampler, Smart Automix, Split-Cue, grabación y `executeAction` | `UC-065`, `UC-066`, `UC-069`, `UC-092`, `UC-143`, `UC-150`, `UC-151` |
| `lib/features/dj_console/domain/dj_sampler_bank_entity.dart` | `DjSamplerPadType`, `DjSamplerBankEntity` | Banco de pads de sampler club y ganancia maestra del sampler | `UC-069`, `UC-092` |
| `lib/features/dj_console/domain/dj_skin_zone_entity.dart` | `DjControlType`, `DjSkinZoneEntity` | Definición de zonas normalizadas (knobs, faders, jogs, pads) para skins | `UC-068`, `UC-153` |
| `lib/features/dj_console/domain/dj_smart_automix_engine.dart` | `AutomixDirection`, `DjSmartAutomixEngine` | `start`, `cancel`, `advance`, `crossfaderPosition`, `bassSwapGainLowA`, `bassSwapGainLowB` | `UC-069`, `UC-092` |
| `lib/features/dj_console/domain/dj_stem_isolation_entity.dart` | `DjStemType`, `DjStemIsolationEntity` | `effectiveVocalGain/Drums/Bass/Melody`, `isBypass`, `toggleMute`, `isolateAcapella`, `isolateInstrumental`, `isolateRhythm`, `resetAll` | `UC-069`, `UC-092`, `UC-150` |
| `lib/features/dj_console/domain/dj_transition_sfx_synthesizer.dart` | `SpectralWaveformBucket`, `DjTransitionSfxSynthesizer` | `generateSyntheticTrackWaveform`, `computeSpectralWaveformSummary` (bandas Low/Mid/High RGB), síntesis de SFX de transición | `UC-069`, `UC-152` |
| `lib/features/dj_console/domain/i_dj_console_blueprint_storage_service.dart` | `IDjConsoleBlueprintStorageService`, `NoOpDjConsoleBlueprintStorageService` | Contrato de persistencia de planos de consolas (`loadAllBlueprints`, `loadBlueprintById`, `saveBlueprint`, `deleteBlueprint`) | `UC-122`, `UC-141`, `UC-153` |
| `lib/features/dj_console/domain/i_dj_deck_audio_player.dart` | `IDjDeckAudioPlayer` | Contrato de reproducción de audio de decks (`loadDeckTrack`, `playDeck`, `pauseDeck`, `seekDeck`, `setDeckVolume`, `setDeckPlaybackRate`, `dispose`) | `UC-090`, `UC-122`, `UC-141` |
| `lib/features/dj_console/domain/i_dj_keymap_persistence_service.dart` | `IDjKeymapPersistenceService`, `NoOpDjKeymapPersistenceService` | Contrato de persistencia de perfiles de teclado (`loadActiveProfile`, `saveActiveProfile`, `resetToDefaultProfile`) | `UC-122`, `UC-141` |
| `lib/features/dj_console/domain/memory_dj_deck_audio_player.dart` | `MemoryDjDeckAudioPlayer` | Implementación headless en memoria de `IDjDeckAudioPlayer` para pruebas y CLI | `UC-090`, `UC-145` |
| `lib/features/dj_console/domain/pcm_wav_decoder.dart` | `PcmWavDecoder` | `decodeWavToFloat32` (RIFF/WAVE 8-bit, 16-bit, 32-bit IEEE float a `Float32List` mono) | `UC-152`, `UC-160` |

### 1.3 `lib/features/dj_console/data/` (10 archivos)

| Archivo `.dart` | Clases / Tipos Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
|---|---|---|---|
| `lib/features/dj_console/data/dj_audio_processor.dart` | Re-export de `../domain/dj_audio_processor.dart` | Compatibilidad legacy de imports | `UC-122`, `UC-176` |
| `lib/features/dj_console/data/dj_console_blueprint_storage_service.dart` | `DjConsoleBlueprintStorageService` | `loadCustomBlueprints`, `loadAllBlueprints`, `loadBlueprintById`, `saveBlueprint`, `deleteBlueprint` (persistencia JSON en disco) | `UC-085`, `UC-091`, `UC-153` |
| `lib/features/dj_console/data/dj_console_file_codec.dart` | `DjConsoleFileCodec` | `encodeToJsonString`, `decodeFromJsonString` | `UC-085`, `UC-153` |
| `lib/features/dj_console/data/dj_deck_audio_service.dart` | `DjDeckAudioService` | Implementación de `IDjDeckAudioPlayer` sobre `IStudioAudioEngine`/`AudioPlayer` + síntesis procedural de grooves demo | `UC-090`, `UC-098`, `UC-099`, `UC-134` |
| `lib/features/dj_console/data/dj_gamepad_input_service.dart` | Re-export de `../domain/dj_gamepad_input_service.dart` | Compatibilidad legacy | `UC-122`, `UC-176` |
| `lib/features/dj_console/data/dj_hardware_catalog.dart` | Re-export de `../domain/dj_hardware_catalog.dart` | Compatibilidad legacy | `UC-122`, `UC-176` |
| `lib/features/dj_console/data/dj_keymap_persistence_service.dart` | `DjKeymapPersistenceService` | `loadActiveProfile`, `saveProfile`, `resetToDefault` | `UC-065`, `UC-091` |
| `lib/features/dj_console/data/dj_mix_wav_encoder.dart` | Re-export de `../domain/dj_mix_wav_encoder.dart` | Compatibilidad legacy | `UC-122`, `UC-176` |
| `lib/features/dj_console/data/dj_transition_sfx_synthesizer.dart` | Re-export de `../domain/dj_transition_sfx_synthesizer.dart` | Compatibilidad legacy | `UC-122`, `UC-176` |
| `lib/features/dj_console/data/memory_dj_deck_audio_player.dart` | Re-export de `../domain/memory_dj_deck_audio_player.dart` | Compatibilidad legacy | `UC-122`, `UC-176` |

### 1.4 `lib/features/dj_console/presentation/` (15 archivos)

| Archivo `.dart` | Clases / Tipos Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
|---|---|---|---|
| `lib/features/dj_console/presentation/dj_console_view_model.dart` | `DjConsoleViewModel` (`ChangeNotifier`) | Ticker 30 Hz, `loadTrackWithBeatTracking`, `loadTrackWithBeatTrackingAsync`, `saveRecordingToDisk`, `generateSplitCueChunk`, `loadCuratedSong`, `loadPresetTrack`, `loadDeckTrack`, `scratchDeck`, `handleKeyEvent`, control completo de decks/FX/stems/automix | `UC-065`, `UC-069`, `UC-098`, `UC-143`, `UC-144`, `UC-150`, `UC-151`, `UC-152` |
| `lib/features/dj_console/presentation/dj_deck_patchbay_bridge.dart` | `DjDeckPatchbayBridge` | `nextScopePrefix`, `publishMixerChannelAsset`, `dispose`; puente aislado por instancia con `IStudioPatchbayRoutingService` | `UC-087`, `UC-181` |
| `lib/features/dj_console/presentation/dj_console_modal.dart` | `DjConsoleModal` | Modal de consola DJ estándar | `UC-065`, `UC-143` |
| `lib/features/dj_console/presentation/dj_console_model_builder_modal.dart` | `DjConsoleModelBuilderModal` | Editor visual de blueprints de consolas DJ | `UC-085`, `UC-153` |
| `lib/features/dj_console/presentation/dj_hardware_console_painter.dart` | `DjHardwareConsolePainter` | `CustomPainter` vectorial de skins de hardware | `UC-068`, `UC-084`, `UC-175` |
| `lib/features/dj_console/presentation/dj_interactive_keymap_visualizer_modal.dart` | `DjInteractiveKeymapVisualizerModal` | Visualizador interactivo de teclado QWERTY mapeado | `UC-084`, `UC-096` |
| `lib/features/dj_console/presentation/dj_keymap_editor_modal.dart` | `DjKeymapEditorModal`, `_KeyCaptureDialog` | Editor y captura de bindings de teclado | `UC-065`, `UC-084` |
| `lib/features/dj_console/presentation/dj_parallel_waveform_painter.dart` | `DjParallelWaveformPainter` | `CustomPainter` de formas de onda paralelas RGB espectrales | `UC-069`, `UC-152`, `UC-175` |
| `lib/features/dj_console/presentation/dj_pro_workstation_panel.dart` | `DjProWorkstationPanel` | Panel de Stems, Camelot, Automix, Slip y Sampler | `UC-069`, `UC-092` |
| `lib/features/dj_console/presentation/dj_studio_workstation_view.dart` | `DjStudioWorkstationView` | Vista completa de estación de trabajo DJ | `UC-069`, `UC-083`, `UC-143`, `UC-184` |
| `lib/features/dj_console/presentation/dj_track_loader_modal.dart` | `DjStudioPresetTrack`, `DjTrackLoaderModal` | Selector de pistas curadas, presets y archivos WAV locales | `UC-096`, `UC-140` |
| `lib/features/dj_console/presentation/dj_vertical_channel_strip.dart` | `DjVerticalChannelStrip`, `StudioTactileVerticalFader` | Tira de canal vertical táctil con TRIM, EQ y VU | `UC-083`, `UC-086`, `UC-151` |
| `lib/features/dj_console/presentation/dj_visual_mapping_overlay.dart` | `DjVisualMappingOverlay` | Superposición visual de modo Learn y badges | `UC-084`, `UC-153` |
| `lib/features/dj_console/presentation/vector_jog_wheel.dart` | `VectorJogWheel`, `_JogWheelPainter` | Jog wheel vectorial táctil con detección angular | `UC-098`, `UC-175` |
| `lib/features/dj_console/presentation/widgets/dj_hot_cue_pad_grid.dart` | `DjHotCuePadGrid` | Matriz de 4 pads de Hot Cues por deck | `UC-065`, `UC-092` |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Acoplamientos Bloqueantes para CLI Pure Dart

1. **`lib/features/dj_console/presentation/dj_console_view_model.dart` (Bloqueo Alto):**
   - Importa `package:flutter/foundation.dart`, `package:flutter/services.dart` y `package:flutter/widgets.dart` (`ChangeNotifier`, `ValueNotifier`, `KeyEvent`, `HardwareKeyboard`).
   - Lógica de negocio crítica para MCP está encapsulada en el ViewModel en lugar de un servicio de dominio puro: `loadTrackWithBeatTrackingAsync`, almacenamiento de buffers PCM (`_deckSamplesA`, `_deckSamplesB`), waveforms espectrales (`_waveformA`, `_waveformB`), `saveRecordingToDisk`, `generateSplitCueChunk`, `loadCuratedSong` y `loadPresetTrack`.
2. **`lib/features/dj_console/presentation/dj_deck_patchbay_bridge.dart` (Bloqueo Transitivo):**
   - No importa `package:flutter/` directamente, pero depende de `DjConsoleViewModel` (`import 'dj_console_view_model.dart'`), heredando todo el árbol de dependencias de Flutter.
3. **`lib/features/dj_console/data/dj_console_blueprint_storage_service.dart` y `dj_keymap_persistence_service.dart` (Bloqueo Medio):**
   - Importan `package:flutter/foundation.dart` (solo por `kIsWeb`) y `package:path_provider/path_provider.dart` (`getApplicationDocumentsDirectory()`). En Pure Dart CLI (`dart run bin/tunner_mcp_server.dart`), importar `package:flutter/foundation.dart` o `path_provider` rompe la compilación inmediatamente. Aunque ambos aceptan `documentsPathProvider` inyectado, el `import` estático impide cargar la clase en un binario Dart puro.
4. **`lib/features/dj_console/data/dj_deck_audio_service.dart` (Bloqueo Esperado de Infraestructura GUI):**
   - Importa `package:audioplayers/audioplayers.dart`. Para headless MCP se debe inyectar `MemoryDjDeckAudioPlayer` (que ya es 100% Pure Dart en `domain/`).

### 2.2 Brechas Funcionales y DSP para Orquestación IA

1. **Sin motor de renderizado offline de mezcla/transición DJ (Gap Crítico):**
   - `DjAudioProcessor.mixBuffers(...)` procesa buffers PCM en memoria con 4-Stems, filtro bipolar, delay, EQ 3 bandas y limitador suave, pero **no existe un caso de uso o servicio de dominio** que tome dos archivos WAV (Deck A y Deck B), aplique una curva `DjSmartAutomixEngine` (con Bass-Swap y time-stretch/pitch-match de BPM) y renderice el resultado completo a un archivo `.wav` en disco mediante `DjMixWavEncoder`.
2. **Limitaciones de `PcmWavDecoder` (`lib/features/dj_console/domain/pcm_wav_decoder.dart`):**
   - No soporta PCM de 24-bit (silenciosamente devuelve un `Float32List` lleno de ceros si `bitsPerSample == 24`).
   - Descarta `sampleRate` y `channels` al retornar solo `Float32List` (en lugar de un DTO con metadatos como `DecodedWavPcm`), obligando a asumir `44100 Hz` en análisis BPM/Camelot si el archivo es `48000 Hz`.
3. **Precisión de `DjHarmonicCamelotEngine.estimateCamelotKeyFromSamples`:**
   - Solo analiza el primer segundo del audio (`math.min(samples.length, sampleRate)`). En pistas electrónicas o de estudio con intros percusivos de 8-32 compases sin contenido armónico, analizar solo el segundo 0..1 produce detecciones de tonalidad erróneas. Debe muestrear múltiples ventanas a lo largo del track (ej. 25%, 50%, 75% de la duración) y promediar el cromagrama.
4. **Ausencia de serialización JSON en entidades DJ:**
   - `DjDeckEntity`, `DjCrossfaderEntity`, `DjChannelFxEntity`, `DjStemIsolationEntity`, `DjCueMonitorEntity`, `DjSmartAutomixEngine` y `DjPerformanceOrchestrator` carecen de métodos `toMap()` / `toJson()` para exponerse limpiamente como Resources MCP.
5. **Brechas en `lib/features/mixer/domain/mixer_track_entity.dart`:**
   - `AudioTrack` posee el campo `pan` (`[-1.0, 1.0]`), pero `MixerConsoleEntity` carece de `copyWithTrackPan(String trackId, double pan)`, `addStem(AudioTrack)`, `removeStem(String trackId)` y `resetAll()`.
   - `lib/features/mixer/` no contiene un motor de mezcla PCM multipista (`MixerAudioRenderer`) que combine N stems aplicando `getEffectiveGain`, ley de paneo de potencia constante (`cos/sin`) y limitador maestro para exportar el mixdown a WAV.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON Resumida |
|---|---|---|
| `tunner://dj/state` | Estado completo en vivo/headless de la consola DJ (`DjPerformanceOrchestrator`). | `{ "masterVolume": 0.9, "crossfader": { "position": 0.0, "curve": "constantPower" }, "harmonicCompatibility": "HARMONIC STEP", "deckA": { "title": "...", "bpm": 124.0, "effectiveBpm": 124.0, "camelotKey": "8A", "effectiveCamelotKey": "8A", "volume": 1.0, "trim": 1.0, "eq": { "low": 1.0, "mid": 1.0, "high": 1.0, "kills": [false,false,false] }, "stems": { "vocals": 1.0, "drums": 1.0, "bass": 1.0, "melody": 1.0 }, "fx": { "filter": 0.0, "delayActive": false }, "hotCues": {"1": 16000}, "loop": { "active": false, "beats": 4.0 } }, "deckB": {...}, "automix": { "active": false, "progress": 0.0 } }` |
| `tunner://dj/camelot-wheel` | Tabla canónica de las 24 tonalidades de la Rueda Camelot (`1A`..`12B`) y matriz de compatibilidad armónica. | `{ "keys": [ { "code": "8A", "musicalName": "Am", "rootPitchClass": 9, "isMinor": true }, ... ], "compatibilityRules": ["perfectUnison", "harmonicStep", "relativeSwitch", "energyBoost", "harmonicClash"] }` |
| `tunner://dj/hardware-skins` | Catálogo de skins y blueprints disponibles en `DjHardwareCatalog`. | `{ "skins": [ { "id": "ddj_flx4", "name": "...", "zonesCount": 42, "isCustom": false } ] }` |
| `tunner://mixer/state` | Estado actual del mezclador de stems (`MixerConsoleEntity`). | `{ "hasAnySolo": false, "metronomeTrack": { "id": "metronome", "volume": 0.75, "pan": 0.0, "isMuted": false, "isSolo": false, "effectiveGain": 0.75 }, "stems": [ { "id": "voice", "title": "Voz Principal", "volume": 0.85, "pan": 0.0, "isMuted": false, "isSolo": false, "effectiveGain": 0.85 } ] }` |

### 3.2 Tools (`tunner_*`)

| Tool Name | Parámetros (JSON Schema Resumido) | Salida | Mapeo Exacto en Tunner |
|---|---|---|---|
| `tunner_dj_analyze_track` | `{ "file_path": "string (required)", "deck_id?": "A|B" }` | `{ "bpm": 124.2, "camelotKey": "8A", "musicalKey": "Am", "durationMs": 182400, "sampleRate": 44100, "spectralSummaryBuckets": 64 }` | `PcmWavDecoder.decodeWavToFloat32` + `BpmBeatTrackerEngine.estimateBpmAsync` + `DjHarmonicCamelotEngine.estimateCamelotKeyFromSamples` + `DjTransitionSfxSynthesizer.computeSpectralWaveformSummary` |
| `tunner_dj_check_harmonic_compatibility` | `{ "source_key": "string (1A..12B)", "target_key": "string (1A..12B)" }` | `{ "compatibility": "HARMONIC STEP", "optimalSemitoneShift": 0, "transposedKey": "8A" }` | `DjHarmonicCamelotEngine.analyzeCompatibility`, `calculateOptimalSemitoneShift`, `transpose` |
| `tunner_dj_load_deck` | `{ "deck_id": "A|B", "file_path": "string", "title?": "string", "artist?": "string", "auto_analyze?": "bool (default true)" }` | `{ "deckId": "A", "bpm": 124.0, "camelotKey": "8A", "durationMs": 180000 }` | `DjPerformanceOrchestrator.loadTrack` (vía futuro `DjHeadlessSessionService`) |
| `tunner_dj_configure_deck_dsp` | `{ "deck_id": "A|B", "volume?": "number [0,1]", "trim?": "number [0,2]", "eq_low?": "number [0,1.5]", "eq_mid?": "number", "eq_high?": "number", "filter?": "number [-1,1]", "delay_active?": "bool", "delay_division?": "string", "stem_preset?": "acapella|instrumental|rhythm|reset" }` | Estado actualizado del deck y ganancias efectivas | `DjPerformanceOrchestrator.setDeckVolume`, `setTrim`, `setEqGains`, `setChannelFilter`, `toggleChannelDelay`, `setChannelDelayDivision`, `applyStemPreset` |
| `tunner_dj_sync_decks` | `{ "target_deck_id": "A|B", "sync_bpm": "bool", "sync_key": "bool" }` | `{ "effectiveBpm": 124.0, "effectiveCamelotKey": "8A", "pitchSemitonesShift": -1, "harmonicCompatibility": "PERFECT MATCH" }` | `DjPerformanceOrchestrator.syncBpm`, `syncKey`, `harmonicCompatibility` |
| `tunner_dj_render_transition_wav` | `{ "deck_a_path": "string", "deck_b_path": "string", "output_path": "string", "direction": "deckAToDeckB|deckBToDeckA", "duration_bars": "4|8|16", "enable_bass_swap": "bool", "crossfader_curve?": "linear|constantPower|sharpCut" }` | `{ "outputPath": "string", "durationMs": 15480, "bytesWritten": 2730680, "referenceBpm": 124.0 }` | `DjSmartAutomixEngine` + `DjAudioProcessor.mixBuffers` + `DjMixWavEncoder.encode` |
| `tunner_dj_extract_stem_wav` | `{ "input_path": "string", "output_path": "string", "preset": "acapella|instrumental|rhythm|custom", "gains?": "{ vocals, drums, bass, melody }" }` | `{ "outputPath": "string", "durationMs": 180000, "bytesWritten": 15876044 }` | `DjAudioProcessor.applyStemIsolation` + `DjMixWavEncoder.encode` |
| `tunner_mixer_configure_track` | `{ "track_id": "string", "volume?": "number [0,1]", "pan?": "number [-1,1]", "is_muted?": "bool", "is_solo?": "bool" }` | Estado actualizado de `MixerConsoleEntity` y `effectiveGain` por pista | `MixerConsoleEntity.copyWithTrackVolume`, `setTrackMute`, `toggleSolo`, (y nuevo `copyWithTrackPan`) |
| `tunner_mixer_render_stems_wav` | `{ "stems": "[{ track_id, file_path, volume, pan, is_muted, is_solo }]", "output_path": "string", "sample_rate?": 44100 }` | `{ "outputPath": "string", "peakDbfs": -0.8, "durationMs": 120000, "bytesWritten": 21168044 }` | `MixerConsoleEntity.getEffectiveGain` + nuevo `MixerAudioRenderer` + `DjMixWavEncoder.encode` |

### 3.3 Prompts Guiados Sugeridos

1. **`dj_harmonic_setlist_planner`**: Dada una lista de archivos WAV locales, invoca `tunner_dj_analyze_track` en lote, ordena los tracks por progresión armónica óptima en la Rueda Camelot (`perfectUnison` / `harmonicStep` / `relativeSwitch` / `energyBoost`) y minimiza saltos de BPM (`<= +-6%`).
2. **`dj_auto_mashup_builder`**: Carga una pista instrumental en Deck A y una pista vocal en Deck B, sincroniza BPM y tonalidad (`tunner_dj_sync_decks`), aísla `acapella` en Deck B (`tunner_dj_configure_deck_dsp`) y renderiza un mashup WAV con Bass-Swap limpio (`tunner_dj_render_transition_wav`).
3. **`stem_mixdown_engineer`**: Lee `tunner://mixer/state`, ajusta ganancias, paneo estéreo y solo/mute por stem (`tunner_mixer_configure_track`) para generar versiones *Minus-One* o mezclas balanceadas y renderizarlas a disco (`tunner_mixer_render_stems_wav`).

---

## 4. Plan de Ajustes Técnicos Previos

1. **Desacoplar persistencia de `package:flutter/foundation.dart` y `path_provider`:**
   - Extraer implementaciones Pure Dart basadas en `dart:io` (`FileDjBlueprintStorageService`, `FileDjKeymapPersistenceService`) que reciban un `Directory` o `String basePath` obligatorio, dejando los adaptadores con `path_provider` exclusivamente en el composition root de la GUI.
2. **Extraer `DjHeadlessSessionService` desde `DjConsoleViewModel`:**
   - Mover de `DjConsoleViewModel` a `lib/features/dj_console/domain/dj_headless_session_service.dart` (Pure Dart) el manejo de buffers PCM por deck (`_deckSamplesA/B`), análisis asíncrono BPM/Camelot/espectral (`analyzeTrackAsync`), gestión de grabación WAV y renderizado offline de transiciones Automix (`renderAutomixTransition`).
   - Hacer que `DjConsoleViewModel` delegue estas operaciones a `DjHeadlessSessionService` y que `DjDeckPatchbayBridge` dependa de una interfaz pura (`IDjDeckStateSource`) en lugar de `DjConsoleViewModel`.
3. **Endurecer `PcmWavDecoder` y `DjHarmonicCamelotEngine`:**
   - Añadir soporte de decodificación PCM 24-bit en `PcmWavDecoder` y retornar un objeto `DecodedPcmResult(samples, sampleRate, channels, bitsPerSample)`.
   - Actualizar `DjHarmonicCamelotEngine.estimateCamelotKeyFromSamples` para muestrear múltiples ventanas distribuidas (ej. 3 ventanas de 1s al 20%, 50% y 80% del buffer) cuando la duración supere 4 segundos.
4. **Completar serialización JSON en entidades DJ:**
   - Implementar `toMap()` / `fromMap()` en `DjDeckEntity`, `DjCrossfaderEntity`, `DjChannelFxEntity`, `DjStemIsolationEntity`, `DjCueMonitorEntity`, `DjSmartAutomixEngine` y `DjPerformanceOrchestrator.toSnapshotMap()`.
5. **Completar `lib/features/mixer/domain/`:**
   - Agregar `copyWithTrackPan`, `addStem`, `removeStem` a `MixerConsoleEntity`.
   - Crear `MixerAudioRenderer` (Pure Dart) en `lib/features/mixer/domain/mixer_audio_renderer.dart` para renderizar mezclas multipista estéreo con paneo de potencia constante y soft-limiting.
