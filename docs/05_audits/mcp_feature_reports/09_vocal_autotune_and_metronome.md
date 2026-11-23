# Reporte de Auditoría Forense MCP: `vocal_autotune` y `metronome`

- **Módulos Auditados**: `lib/features/vocal_autotune/` (9 archivos `.dart`) y `lib/features/metronome/` (6 archivos `.dart`)
- **Total de Archivos Auditados**: 15 archivos `.dart`
- **Objetivo**: Evaluar la preparación para ejecución Headless Pure Dart (corrección vocal TD-PSOLA offline, conversión voz-a-partitura, cálculo de tap tempo y generación de pistas de metrónomo en CLI sin Flutter) y definir los primitivos MCP (`Resources`, `Tools`, `Prompts`) y ajustes técnicos previos.
- **Estado Global de Preparación Headless**: **MUY ALTO en Dominio y Data (100% Pure Dart en ambos módulos)**; **BRECHAS CRÍTICAS en Autotune Autónomo de WAV sin `pitchTrack` Precalculado y Generación Offline de Click-Track en `metronome`**.

---

## 1. Inventario Archivo por Archivo

### 1.1 Módulo `lib/features/vocal_autotune/` (9 archivos)

| Archivo | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
| :--- | :--- | :--- | :--- | :--- |
| `domain/autotune_config_entity.dart` | Domain | `VocalScaleType` (7 escalas), `VocalScaleTypeExtension`, `AutoTuneConfigEntity` | `intervals`, `allowedPitchClasses`, `isPitchClassAllowed`, factories `naturalStudio`, `smoothPop`, `hardTuneUrban`, `vocalDoubler`, `copyWith`, `toJson`, `fromJson` | UC-039, UC-060, UC-128 |
| `domain/i_vocal_take_file_gateway.dart` | Domain | `IVocalTakeFileGateway`, `NoOpVocalTakeFileGateway` | `readTakeBytes`, `saveAutoTunedWavBytes` | UC-060, UC-141, UC-162 |
| `domain/scale_quantizer.dart` | Domain | `ScaleQuantizationResult`, `ScaleQuantizer` | `quantize` (cuantización a escala + filtro de inercia exponencial `retuneSpeedMs` + `correctionAmount`), `reset` | UC-039, UC-060 |
| `domain/td_psola_pitch_shifter.dart` | Domain | `TdPsolaPitchShifter` | `shiftPitch` (rango 27.5..4186.0 Hz, marcas glóticas síncronas, preservación de formantes vía liftering cepstral STFT + FFT Cooley-Tukey Radix-2 in-place, mezcla Dry/Wet) | UC-039, UC-128, UC-162 |
| `domain/vocal_autotune_processor.dart` | Domain | `VocalAutoTuneProcessor` | `updateConfig`, `evaluatePitchFrame`, `processAudioBlock`, `processPracticeTake`, `processPracticeTakeAsync`, `processWavBytes`, `processWavBytesAsync` | UC-039, UC-060, UC-144, UC-162 |
| `domain/vocal_score_converter.dart` | Domain | `VocalScoreConversionResult`, `VocalScoreConverter` | `convertTrackToScore` (segmentación por onsets > 0.8 semitonos o silencio > 120 ms, cuantización de silencios y notas a `HierarchicalScore`), `snapToScale` (Melodyne 1-Tap Snap) | UC-060, UC-162 |
| `data/local_vocal_take_file_gateway.dart` | Data | `LocalVocalTakeFileGateway` | `readTakeBytes`, `saveAutoTunedWavBytes`, `buildAutoTunedPath` (100% Pure Dart `dart:io`, fallback a `Directory.systemTemp.path`) | UC-060, UC-126, UC-162 |
| `presentation/vocal_pedagogy_controller.dart` | Presentation | `VocalPedagogyController` | Orquestador de lecciones guiadas, AutoTune, conversión vocal a partitura, sesiones Minus-One y `PortPermissionBroker` | UC-060, UC-142 |
| `presentation/vocal_autotune_modal.dart` | Presentation | `VocalAutoTuneModal` | Modal Flutter para configurar presets, escala, velocidad de retune y post-procesar tomas multitrack | UC-039, UC-060 |

### 1.2 Módulo `lib/features/metronome/` (6 archivos)

| Archivo | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
| :--- | :--- | :--- | :--- | :--- |
| `domain/i_metronome_service.dart` | Domain | `IMetronomeService`, `IMeteredMetronomeService`, `NoOpMetronomeService` | `start(bpm, ticksPerMeasure)`, `startWithMeter(bpm, ticksPerMeasure, meterDenominator)`, `stop` | UC-002, UC-103, UC-159 |
| `domain/tempo_entity.dart` | Domain | `TempoMark` | `standardMarks` (8 marcas italianas de 20 a 300 BPM: Larghissimo..Prestissimo), `fromBpm` | UC-026 |
| `domain/tap_tempo_result.dart` | Domain | `TapTempoResult` | `initial`, `isCalibrated` (`bpm`, `exactBpm`, `tapCount`, `jitterMs`, `jitterPercentage`, `stabilityDescription`, `tempoMark`) | UC-026 |
| `domain/tap_tempo_engine.dart` | Domain | `TapTempoEngine` | `recordTap([timestampMs])` (promedio móvil ponderado de hasta 8 intervalos, timeout 3200 ms, cálculo de jitter muestral), `reset` | UC-026 |
| `data/metronome_service.dart` | Data | `MetronomeService` (implementa `IMeteredMetronomeService`) | `start`, `startWithMeter`, `stop`, `dispose`, `computeSubTicksPerBeat`, `_highResolutionTicksLogic` (Isolate Pure Dart con `Stopwatch` + `Timer` compensado sin busy-waiting) | UC-002, UC-015, UC-103, UC-159 |
| `presentation/tap_tempo_modal.dart` | Presentation | `TapTempoModal` | Modal Flutter animado con pulso visual acoplado a `TunerViewModel` | UC-026 |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Acoplamientos Bloqueantes para CLI Pure Dart

| Archivo | Dependencia Bloqueante | Severidad | Impacto en Headless / MCP |
| :--- | :--- | :--- | :--- |
| `vocal_autotune/presentation/vocal_pedagogy_controller.dart` | `package:flutter/foundation.dart` (únicamente por `VoidCallback`) | **BAJA** | Innecesariamente acoplado a Flutter solo por `typedef VoidCallback = void Function()`. Aun así, en MCP es preferible invocar directamente `VocalAutoTuneProcessor` y `VocalScoreConverter`. |
| `vocal_autotune/presentation/vocal_autotune_modal.dart` y `metronome/presentation/tap_tempo_modal.dart` | `package:flutter/material.dart`, `package:flutter/services.dart`, `package:provider/provider.dart`, `TunerViewModel` | **MEDIA** | Exclusivos de UI; quedan fuera del runtime Headless MCP. |

**Resultado Positivo Verificado**: El 100% de `vocal_autotune/domain/` (6 archivos), `vocal_autotune/data/local_vocal_take_file_gateway.dart`, `metronome/domain/` (4 archivos) y `metronome/data/metronome_service.dart` son **estrictamente Pure Dart**, sin ningún import de `package:flutter/` ni `dart:ui` (ni directo ni transitivo).

### 2.2 Brechas Funcionales Detectadas (Gaps)

1. **`VocalAutoTuneProcessor.processWavBytes` No Es Autónomo sobre un Archivo WAV**:
   - Exige que el invocador suministre un `List<TimedPitchSample> pitchTrack` pre-calculado. Si un agente IA entrega un archivo `voz_cruda.wav` a través de MCP, `VocalAutoTuneProcessor` no tiene un método `autoTuneWavBytes(Uint8List wavBytes, AutoTuneConfigEntity config)` que extraiga primero el contorno $f_0$ internamente con `McleodPitchMethod` y luego ejecute `processWavBytes`.
2. **Limitaciones de Formato WAV y Transiciones en `VocalAutoTuneProcessor.processWavBytes`**:
   - Rechaza silenciosamente (devuelve el buffer original sin error) cualquier archivo WAV que no sea exactamente **PCM 16-bit** (ej. 24-bit PCM o 32-bit IEEE float).
   - Hace downmix forzado a Mono 16-bit incluso cuando la entrada es Estéreo.
   - Escribe segmentos TD-PSOLA consecutivos directamente (`outSamples[startSample + i] = shifted[i]`) sin crossfade en las fronteras de segmento, lo que puede producir clics/discontinuidades de fase en cambios de nota.
3. **`VocalScoreConverter` Sin Soporte de WAV Directo ni Calibración A4 Personalizada**:
   - `convertTrackToScore` solo acepta `List<TimedPitchSample>` (no un WAV directo) y llama a `NoteEntity.fromFrequency(freq)` con `a4Ref = 440.0` fijo, ignorando calibraciones alternativas (ej. 432 Hz, 442 Hz).
   - `snapToScale` utiliza el arreglo cromático fijo con sostenidos y `NoteEntity.frequencyForNote` a 440 Hz.
4. **Ausencia de Generador Offline de Click-Track WAV en `lib/features/metronome/`**:
   - `MetronomeService` es un reloj en tiempo real basado en `Isolate` + `Stopwatch` que emite sub-ticks por `ReceivePort`.
   - No existe un generador offline `OfflineMetronomeTrackGenerator` en `metronome/domain/` que sintetice un archivo WAV de metrónomo para parámetros arbitrarios (`bpm`, `numerator`, `denominator`, `bars`, `subdivision`, `accentPattern`, `countInBars`, `sampleRate`) usando `PcmWavSynthesizer.generateMetronomeClickWav`.
   - Aunque `StemAudioSynthesizer.synthesizeMetronomeSamples` genera clics en WAV, exige construir un `HierarchicalScore` completo y solo soporta pulsos de negra según `numerator` (ignorando `denominator` para compases compuestos como 6/8 o 12/8).
5. **Ausencia de Helper Batch en `TapTempoEngine` y Serialización JSON**:
   - `TapTempoEngine` no expone `analyzeTimestamps(List<int> timestampsMs)` para análisis determinista de una lista completa de marcas temporales en una sola llamada MCP.
   - `ScaleQuantizationResult`, `VocalScoreConversionResult`, `TempoMark` y `TapTempoResult` no implementan `toJson()`.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON |
| :--- | :--- | :--- |
| `tunner://vocal-autotune/scales` | Catálogo de las 7 escalas soportadas por `VocalScaleType` y sus intervalos en semitonos. | `{ "scales": [{ "id": "major", "displayName": "Mayor Natural (Jónica)", "intervals": [0, 2, 4, 5, 7, 9, 11] }, ...] }` |
| `tunner://vocal-autotune/presets` | Presets canónicos de `AutoTuneConfigEntity` (`naturalStudio`, `smoothPop`, `hardTuneUrban`, `vocalDoubler`). | `{ "presets": [{ "id": "naturalStudio", "config": { "isEnabled": true, "retuneSpeedMs": 35.0, "correctionAmount": 0.85, "formantPreservation": true, "leadVocalMix": 1.0 } }, ...] }` |
| `tunner://metronome/tempo-marks` | Catálogo oficial de las 8 marcas italianas de tempo (`TempoMark.standardMarks`) con rangos BPM. | `{ "marks": [{ "italianName": "Allegro", "description": "Rápido, animado y brillante", "minBpm": 120, "maxBpm": 155 }, ...] }` |

### 3.2 Tools (`tunner_*`)

| Nombre del Tool | Parámetros (JSON Schema Resumido) | Salida JSON | Mapeo Exacto en Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_vocal_autotune_wav` | `{ "inputWavPath": string, "outputWavPath?": string, "scaleRoot": int (0..11), "scaleType": string, "retuneSpeedMs?": number, "correctionAmount?": number, "formantPreservation?": bool, "leadVocalMix?": number, "a4Reference?": number, "preset?": "naturalStudio" \| "smoothPop" \| "hardTuneUrban" \| "vocalDoubler" }` | `{ "outputWavPath": string, "sizeBytes": int, "voicedSegmentsProcessed": int, "averageCentsBefore": number, "averageCentsAfter": number, "config": object }` | `LocalVocalTakeFileGateway.readTakeBytes` + extracción $f_0$ (`McleodPitchMethod`) + `VocalAutoTuneProcessor.processWavBytesAsync` + `LocalVocalTakeFileGateway.saveAutoTunedWavBytes` |
| `tunner_vocal_quantize_pitch` | `{ "detectedPitchHz": number, "config": AutoTuneConfigJson, "deltaSeconds?": number }` | `{ "detectedFrequencyHz": number, "targetFrequencyHz": number, "targetNoteName": string, "pitchShiftRatio": number, "centsDeviation": number, "isVoiced": bool, "isNoteInScale": bool }` | `ScaleQuantizer.quantize` |
| `tunner_vocal_wav_to_score` | `{ "inputWavPath": string, "title?": string, "bpm": int, "timeSignatureNumerator?": int, "timeSignatureDenominator?": int, "preferCorrectedPitch?": bool, "snapToScale?": { "rootKey": int, "scaleType": string } }` | `{ "title": string, "bpm": int, "totalNotes": int, "measureCount": int, "averageCentsError": number, "autoTunedNotesCount": int, "score": HierarchicalScoreJson }` | Extracción $f_0$ + `VocalScoreConverter.convertTrackToScore` (+ `VocalScoreConverter.snapToScale` opcional) |
| `tunner_vocal_snap_score_to_scale` | `{ "scorePackageJson": object, "rootKey": int (0..11), "scaleType": string }` | `{ "updatedPackage": object, "modifiedNotesCount": int }` | `VocalScoreConverter.snapToScale` |
| `tunner_metronome_generate_click_wav` | `{ "bpm": int (20..300), "numerator?": int (default 4), "denominator?": int (default 4), "bars": int, "countInBars?": int (default 0), "subdivision?": int (1 \| 2 \| 4), "sampleRate?": int (default 44100), "outputPath": string }` | `{ "outputPath": string, "bpm": int, "tempoMark": string, "meter": "4/4", "totalBeats": int, "durationSeconds": number, "sizeBytes": int }` | Nuevo `OfflineMetronomeTrackGenerator` sobre `PcmWavSynthesizer.generateMetronomeClickWav` + `MetronomeService.computeSubTicksPerBeat` + `TempoMark.fromBpm` |
| `tunner_metronome_analyze_tap_tempo` | `{ "timestampsMs": int[], "minBpm?": int, "maxBpm?": int, "inactivityTimeoutMs?": int }` | `{ "bpm": int, "exactBpm": number, "tapCount": int, "isCalibrated": bool, "jitterMs": number, "jitterPercentage": number, "stabilityDescription": string, "tempoMark": { "italianName", "description", "minBpm", "maxBpm" } }` | `TapTempoEngine.recordTap` (iteración sobre `timestampsMs`) + `TempoMark.fromBpm` |

### 3.3 Prompts Guiados para Agentes IA

1. **`vocal_take_postproduction_pipeline`**: Guía al agente para analizar la afinación cruda de una toma vocal (`tunner_detect_pitch_wav`), seleccionar la tonalidad y preset adecuados (`tunner://vocal-autotune/presets`, `tunner://vocal-autotune/scales`), renderizar la toma corregida con preservación de formantes (`tunner_vocal_autotune_wav`) y transcribir la melodía cuantizada a partitura (`tunner_vocal_wav_to_score`).
2. **`build_rehearsal_click_track`**: Guía al agente para estimar el tempo real de un intérprete a partir de marcas de tap (`tunner_metronome_analyze_tap_tempo`), consultar la marca italiana correspondiente (`tunner://metronome/tempo-marks`) y generar un click-track WAV listo para ensayo con compás de cuenta previa (`tunner_metronome_generate_click_wav`).

---

## 4. Plan de Ajustes Técnicos Previos

1. **Autotune Offline Autónomo en `VocalAutoTuneProcessor`**:
   - Añadir método `autoTuneWavBytes({required Uint8List wavBytes, AutoTuneConfigEntity? customConfig, int windowSize = 4096, int hopSize = 512})` y su versión asíncrona `autoTuneWavBytesAsync`, que ejecute internamente `OfflinePitchContourAnalyzer` (`McleodPitchMethod`) para construir el `List<TimedPitchSample>` y luego aplique `processWavBytes`.
   - Aplicar crossfade corto (5-10 ms) en las fronteras de cada segmento TD-PSOLA en `processWavBytes` para eliminar clics de transición.
   - Reemplazar el parser WAV inline de 16-bit de `processWavBytes` por el decodificador WAV compartido de dominio (soporte 16/24/32-bit float y reporte explícito de `FormatException` en archivos inválidos en lugar de retorno silencioso).
2. **Calibración A4 y Soporte WAV en `VocalScoreConverter`**:
   - Añadir parámetro `double a4Reference = 440.0` en `convertTrackToScore` y `snapToScale` para eliminar el hardcoding de 440 Hz.
3. **Crear `OfflineMetronomeTrackGenerator` en `lib/features/metronome/domain/`**:
   - Implementar un generador Pure Dart determinista que sintetice pistas WAV de clics de metrónomo con soporte de `bpm`, compases simples y compuestos (`numerator`/`denominator` usando `MetronomeService.computeSubTicksPerBeat`), subdivisiones, compases de cuenta previa (`countInBars`) y ganancia por acento, reutilizando `PcmWavSynthesizer.generateMetronomeClickWav` y `PcmWavSynthesizer.buildWavHeader`.
4. **Completar Ergonomía MCP en `metronome/domain/` y `vocal_autotune/domain/`**:
   - Agregar `TapTempoEngine.analyzeTimestamps(List<int> timestampsMs)` en `tap_tempo_engine.dart`.
   - Implementar `toJson()` en `ScaleQuantizationResult`, `VocalScoreConversionResult`, `TempoMark` y `TapTempoResult`.
   - Opcionalmente reemplazar `VoidCallback` de `package:flutter/foundation.dart` por `void Function()` en `VocalPedagogyController` si se requiere reutilizar dicho coordinador fuera de Flutter.
