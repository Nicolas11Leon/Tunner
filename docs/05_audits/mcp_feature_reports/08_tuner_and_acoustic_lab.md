# Reporte de Auditoría Forense MCP: `tuner` y `acoustic_lab`

- **Módulos Auditados**: `lib/features/tuner/` (27 archivos `.dart`) y `lib/features/acoustic_lab/` (2 archivos `.dart`)
- **Total de Archivos Auditados**: 29 archivos `.dart`
- **Objetivo**: Evaluar la preparación para ejecución Headless Pure Dart (análisis offline de tono, temperamentos, calibración de señal y serie armónica sin Flutter ni micrófono físico) y especificar los primitivos MCP (`Resources`, `Tools`, `Prompts`) y refactorings previos.
- **Estado Global de Preparación Headless**: **ALTO en Motores DSP de Dominio (100% Pure Dart)**; **BLOQUEADO en `PitchDetectorService` y `TunerViewModel`**; **BRECHA CRÍTICA en Análisis Offline de Archivos WAV Completos (Pitch Contour + Auto-DFT Armónica)**.

---

## 1. Inventario Archivo por Archivo

### 1.1 Módulo `lib/features/tuner/` (27 archivos)

| Archivo | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
| :--- | :--- | :--- | :--- | :--- |
| `domain/mcleod_pitch_method.dart` | Domain | `PitchDetectionResult`, `McleodPitchMethod` | `convertPcm16BytesToFloats`, `calculateRms`, `computeNsdf` (O(N) prefix energy + SIMD unroll + puente FFI `INativeDspBridge`), `estimatePitch`, `estimatePitchFromPcm16` | UC-001, UC-016, UC-114, UC-148 |
| `domain/note_entity.dart` | Domain | `NoteEntity` | `fromFrequency`, `parseNoteIndex`, `toEnglishName`, `toSolfegeName`, `frequencyForNote` | UC-001, UC-013, UC-059 |
| `domain/temperament_engine.dart` | Domain | `MusicalTemperament`, `TemperamentEngine` | `allTemperaments` (11 temperamentos históricos), `getById`, `getCentsOffset`, `getTargetFrequency` (con `anchorA4`), `calculateCentsDeviation` | UC-023, UC-116 |
| `domain/signal_conditioning_filter.dart` | Domain | `SignalConditioningFilter` | `processDcBlockerSample` (IIR $f_c = 15\text{ Hz}$), `conditionSamples` (DC-offset + DC-blocker + ganancia + soft limiter), `analyzeNoiseFrames`, `reset` | UC-041, UC-148 |
| `domain/acoustic_echo_suppressor.dart` | Domain | `AcousticEchoSuppressor` | `notifyClickEmitted`, `shouldSuppressPitch` (ventana de blanking 70 ms + continuidad de nota sostenida), `reset` | UC-029 |
| `domain/acoustic_rigor_profile.dart` | Domain | `AcousticRigorPreset`, `AcousticRigorProfile` | `fromPreset` (6 perfiles), `copyWith`, `toJson`, `fromJson` | UC-044 |
| `domain/instrument_acoustic_filter.dart` | Domain | `InstrumentAcousticFilterConfig`, `ToneLockTracker` | `universal`, `forInstrument`, `isFrequencyAllowed`, `ToneLockTracker.processFrame`, `reset` | UC-043, UC-059 |
| `domain/microphone_calibration_models.dart` | Domain | `MicrophoneCalibrationProfile`, `NoiseProfileReport` | `copyWith`, `toJson`, `fromJson` | UC-041, UC-148 |
| `domain/hardware_audio_endpoint.dart` | Domain | `EndpointDirection`, `AudioEndpointType`, `HardwareAudioEndpoint` | `direction`, `isFeedbackSafe`, `isInput`, `isOutput`, `copyWith` | UC-100, UC-102 |
| `domain/tuning_preset_entity.dart` | Domain | `TuningPresetEntity` | `copyWith`, `toMap`, `fromMap` | UC-013, UC-023 |
| `domain/i_pitch_detector_service.dart` | Domain | `IPitchDetectorService`, `NoOpPitchDetectorService` | `startRecording`, `stopRecording`, `updateCalibrationProfile`, `setInstrumentAcousticFilter`, `listInputDevices`, `setInputDevice` | UC-001, UC-127, UC-141 |
| `domain/tuner_session_ports.dart` | Domain | `IGuidedLessonSessionPort`, `IChordAnalyzerSessionPort`, `IScoreEditorSessionPort` | Contratos ISP segregados para desacoplar consumidores de `TunerViewModel` | UC-141, UC-142 |
| `data/pitch_detector_service.dart` | Data | `PitchDetectorService` | Implementación de `IPitchDetectorService` con `IStudioAudioInputEngine` / `AudioRecorder` y worker `Isolate` (`_dspWorkerEntryPoint` con ventana deslizante de 4096 muestras) | UC-001, UC-016, UC-127, UC-144, UC-146 |
| `presentation/tuner_viewmodel.dart` | Presentation | `TunerViewModel` (3075 líneas, `ChangeNotifier`) | Orquestador global de afinación, metrónomo, grabador, dron, autotune, partituras, evaluador y lecciones | UC-001, UC-142, UC-185 |
| `presentation/tuner_acoustic_telemetry.dart` | Presentation | `TunerAcousticTelemetry` | Snapshot inmutable de alta frecuencia (`frequency`, `cents`, `noteName`, `micRmsLevel`, `isRecording`) | UC-142, UC-185 |
| `presentation/controllers/tuner_calibration_and_drone_helper.dart` | Presentation | `NoiseCalibrationOutcome`, `TunerCalibrationAndDroneHelper` | `computeDcOffset`, `buildNoiseCalibrationOutcome`, `calibrateAmbientNoiseFloor`, `refreshDronePlayback`, `buildWarmupStepConfig`, `mapIntervalToEbbinghausId` | UC-041, UC-142, UC-148 |
| `presentation/acoustic_rigor_profile_ui_ext.dart` | Presentation | `AcousticRigorPresetUiExt` | Mapeo de iconos y colores Flutter por preset | UC-044 |
| `presentation/strobe_tuner_widget.dart` | Presentation | `StrobeTunerWidget`, `_StrobePainter` | Afinador estroboscópico virtual 60/120 FPS | UC-004 |
| `presentation/tuner_screen.dart` | Presentation | `TunerScreen` | Pantalla principal de afinador y workbench | UC-001, UC-174, UC-185 |
| `presentation/widgets/essential_tuner_panel.dart` | Presentation | `EssentialTunerPanel` | Panel compacto de lectura de afinación y estroboscopio | UC-174, UC-185 |
| `presentation/concert_pitch_selector_modal.dart` | Presentation | `ConcertPitchSelectorModal`, `_StepButton` | Modal selector de calibración A4 | UC-013 |
| `presentation/microphone_calibration_modal.dart` | Presentation | `MicrophoneCalibrationModal` | Modal de calibración de piso de ruido, ganancia y DC-offset | UC-041, UC-044 |
| `presentation/temperament_selector_modal.dart` | Presentation | `TemperamentSelectorModal` | Modal selector de temperamentos históricos y tónica | UC-023, UC-116 |
| `presentation/stem_mixer_modal.dart` | Presentation | `StemMixerModal` | Fachada modal del mezclador de stems | UC-007 |
| `presentation/modals/tuner_instrument_modal.dart` | Presentation | `TunerInstrumentModal` | Modal selector de instrumento y transposición | UC-010, UC-059 |
| `presentation/modals/tuner_library_modal.dart` | Presentation | `TunerLibraryModal` | Modal de librería curada y descomponedor | UC-008 |
| `presentation/modals/tuner_mixer_modal.dart` | Presentation | `TunerMixerModal` | Modal de control de canales de mezcla | UC-007 |

### 1.2 Módulo `lib/features/acoustic_lab/` (2 archivos)

| Archivo | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
| :--- | :--- | :--- | :--- | :--- |
| `domain/harmonic_series_analyzer.dart` | Domain | `HarmonicBarEntity`, `TimbreAnalysisResult`, `HarmonicSeriesAnalyzer` | `getHannWindow` (caché estática), `hasCachedHannWindow`, `analyze` (DFT dirigida para armónicos $k = 1..N$, centroide espectral, THD %, clasificación timbral), `analyzeAsync` (`Isolate.run`) | UC-020, UC-144, UC-146 |
| `presentation/harmonic_spectrogram_modal.dart` | Presentation | `HarmonicSpectrogramModal` | Modal Flutter que visualiza barras armónicas, centroide y THD en vivo | UC-020, UC-146 |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Acoplamientos Bloqueantes para CLI Pure Dart

| Archivo | Dependencia Bloqueante | Severidad | Impacto en Headless / MCP |
| :--- | :--- | :--- | :--- |
| `tuner/data/pitch_detector_service.dart` | `package:flutter/foundation.dart` (`kIsWeb`), `package:record/record.dart`, `StudioAudioInputEngine` | **ALTA** | Impide compilar en Pure Dart CLI. Además, el pipeline de ventana deslizante de 4096 muestras (`SignalConditioningFilter` + `McleodPitchMethod` + `ToneLockTracker`) está encapsulado en el método privado `_dspWorkerEntryPoint`, impidiendo reutilizarlo offline. |
| `tuner/presentation/tuner_viewmodel.dart` | `package:flutter/foundation.dart` (`ChangeNotifier`, `ValueNotifier`), `RealSheetMusicPainter`, `TunnerThemePalette` | **ALTA** | Monolito de 3075 líneas acoplado al runtime Flutter. El servidor MCP no debe instanciar `TunerViewModel`; debe consumir directamente las clases de dominio. |
| `tuner/presentation/modals/*.dart`, `strobe_tuner_widget.dart`, `tuner_screen.dart`, `acoustic_lab/presentation/harmonic_spectrogram_modal.dart` | `package:flutter/material.dart`, `package:provider/provider.dart` | **MEDIA** | Exclusivos de UI. Nota: `HarmonicSpectrogramModal.build()` ejecuta `analyzer.analyze(...)` síncronamente en el hilo de UI en lugar de consumir resultados de `analyzeAsync()`. |

**Resultado Positivo Verificado**: El 100% de `tuner/domain/` (12 archivos), `acoustic_lab/domain/harmonic_series_analyzer.dart` y `tuner/presentation/controllers/tuner_calibration_and_drone_helper.dart` son **Pure Dart** sin dependencias de Flutter ni `dart:ui`.

### 2.2 Brechas Funcionales Detectadas (Gaps)

1. **Ausencia de Analizador Offline de Archivos WAV en `tuner/domain/` (Pitch Tracking / Contour)**:
   - `McleodPitchMethod.estimatePitch` y `estimatePitchFromPcm16` operan únicamente sobre un buffer/ventana única.
   - No existe un decodificador WAV canónico en `tuner/domain/` (soporte 16-bit/24-bit/32-bit float, mono/estéreo, parseo de chunks `fmt `/`data`) ni un `OfflinePitchContourAnalyzer` que barra un archivo WAV con ventana deslizante configurable (ej. 4096 muestras, hop 512/1024), aplique `SignalConditioningFilter` + `ToneLockTracker` y produzca una trayectoria temporal de pitch (`List<PitchFrame>`), estadísticas agregadas (frecuencia mediana/media, estabilidad en cents, desviación frente a un temperamento) y clasificación de nota.
2. **Acoplamiento de `HarmonicSeriesAnalyzer` a Frecuencia Fundamental Pre-Calculada y Falta de Análisis Espectral Completo**:
   - `HarmonicSeriesAnalyzer.analyze` exige que el invocador ya conozca `fundamentalHz` y pase `List<double> samples` normalizados; no existe `analyzeWavFile` / `analyzePcmWindow` con auto-detección de $f_0$ vía `McleodPitchMethod`.
   - Solo ejecuta DFT dirigida en múltiplos enteros exactos $k \cdot f_0$ (no mide inharmonicidad real de cuerdas/pianos ni genera un espectrograma STFT tiempo-frecuencia sobre un archivo WAV completo).
3. **`NoteEntity.fromFrequency` Restringido a 12-EDO**:
   - `NoteEntity.fromFrequency(freq, a4Ref: ...)` calcula `cents` exclusivamente contra Temperamento Igual 12-EDO; no ofrece sobrecarga con `MusicalTemperament` + `rootKey` para obtener desviación histórica directa en un solo paso.
4. **Falta de Serialización JSON en Modelos Clave**:
   - `PitchDetectionResult`, `NoteEntity`, `MusicalTemperament`, `NoiseProfileReport`, `HardwareAudioEndpoint`, `HarmonicBarEntity` y `TimbreAnalysisResult` carecen de métodos `toJson()`.
5. **Lógica de Dominio Ubicada en `presentation/controllers/`**:
   - `TunerCalibrationAndDroneHelper.computeDcOffset` y `buildNoiseCalibrationOutcome` viven en `presentation/controllers/tuner_calibration_and_drone_helper.dart` pese a ser matemática Pure Dart reutilizable en CLI/MCP.
6. **Sin Soporte de Temperamentos Personalizados (Scala `.scl` / Offsets Dinámicos)**:
   - `TemperamentEngine` solo expone los 11 temperamentos estáticos en `allTemperaments`; no incluye factory/parser para temperamentos definidos por usuario o archivo `.scl`.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON |
| :--- | :--- | :--- |
| `tunner://tuner/temperaments` | Catálogo completo de los 11 temperamentos históricos de `TemperamentEngine.allTemperaments`. | `{ "count": 11, "temperaments": [{ "id": "vallotti", "name": "Vallotti (1779)", "historicalEra": "...", "description": "...", "centsOffsets": [0.0, -5.87, ...] }] }` |
| `tunner://tuner/rigor-presets` | Catálogo de los 6 perfiles de rigurosidad acústica (`AcousticRigorPreset`) con sus parámetros DSP. | `{ "presets": [{ "preset": "conservatoryMastery", "displayName": "Conservatorio", "minClarity": 0.92, "minConsecutiveFrames": 2, "maxCentsDeviation": 15.0, "noiseGateThreshold": 0.006, ... }] }` |
| `tunner://tuner/note-reference/{noteName}` | Resolución teórica de una nota (notación anglosajona o solfeo) a MIDI, frecuencia en A4=440 Hz y nombres equivalentes. | `{ "input": "La4", "solfegeName": "La4", "englishName": "A4", "midiNumber": 69, "frequencyHz": 440.0 }` |
| `tunner://acoustic-lab/harmonic-intervals` | Tabla canónica de los primeros 8 parciales de la serie armónica y umbrales de clasificación THD. | `{ "harmonics": [{ "k": 1, "label": "1 (Fundamental)" }, ...], "thdThresholds": [{ "maxPercent": 8.0, "classification": "..." }, ...] }` |

### 3.2 Tools (`tunner_*`)

| Nombre del Tool | Parámetros (JSON Schema Resumido) | Salida JSON | Mapeo Exacto en Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_detect_pitch_wav` | `{ "wavFilePath": string, "windowSize?": int (default 4096), "hopSize?": int (default 1024), "a4Ref?": number, "temperamentId?": string, "rootKey?": int, "minClarity?": number, "silenceThreshold?": number, "rigorPreset?": string, "applyDcBlocker?": bool }` | `{ "sampleRate": int, "durationSeconds": number, "voicedFrameCount": int, "medianPitchHz": number, "dominantNote": { "name", "englishName", "midiNumber", "cents" }, "frames": [{ "timeMs", "pitched", "pitchHz", "clarity", "rms", "noteName", "cents" }] }` | `McleodPitchMethod.estimatePitch` + `SignalConditioningFilter` + `ToneLockTracker` + `TemperamentEngine` + `NoteEntity` (requiere wrapper offline WAV) |
| `tunner_frequency_to_note` | `{ "frequencyHz": number, "a4Ref?": number (default 440.0), "temperamentId?": string (default "equal"), "rootKey?": int (0..11), "anchorA4?": bool }` | `{ "solfegeName": string, "englishName": string, "midiNumber": int, "targetFrequencyHz": number, "centsDeviation": number, "temperamentId": string }` | `NoteEntity.fromFrequency` + `TemperamentEngine.getTargetFrequency` + `calculateCentsDeviation` |
| `tunner_temperament_table` | `{ "temperamentId": string, "rootKey?": int (0..11), "octave?": int (default 4), "a4Ref?": number, "anchorA4?": bool }` | `{ "temperamentId": string, "rootKey": int, "a4Ref": number, "notes": [{ "degree": int, "solfege", "english", "midi", "centsOffset", "frequencyHz" }] }` | `TemperamentEngine.getById` + `getCentsOffset` + `getTargetFrequency` |
| `tunner_analyze_harmonics_wav` | `{ "wavFilePath": string, "fundamentalHz?": number, "startTimeMs?": int, "windowSize?": int (default 4096), "maxHarmonics?": int (default 8) }` | `{ "fundamentalHz": number, "spectralCentroidHz": number, "totalHarmonicDistortionPercent": number, "timbreClassification": string, "harmonics": [{ "harmonicNumber", "frequencyHz", "relativeAmplitude", "dbLevel", "intervalLabel" }] }` | `HarmonicSeriesAnalyzer.analyzeAsync` (+ auto-detección opcional con `McleodPitchMethod.estimatePitch`) |
| `tunner_analyze_noise_floor_wav` | `{ "wavFilePath": string, "frameSize?": int (default 2048) }` | `{ "meanRms": number, "peakRms": number, "recommendedNoiseGate": number, "detectedDcOffset": number, "totalFramesAnalyzed": int }` | `SignalConditioningFilter.analyzeNoiseFrames` |
| `tunner_simulate_echo_suppression` | `{ "clickTimestampsMs": int[], "pitchEvents": [{ "timeMs": int, "pitchHz": number }], "blankingDurationMs?": int (default 70) }` | `{ "results": [{ "timeMs": int, "pitchHz": number, "suppressed": bool }] }` | `AcousticEchoSuppressor.notifyClickEmitted` + `shouldSuppressPitch` |

### 3.3 Prompts Guiados para Agentes IA

1. **`audit_recording_intonation_and_timbre`**: Guía al agente para medir primero el piso de ruido de un fragmento silencioso (`tunner_analyze_noise_floor_wav`), extraer la curva de afinación de una toma (`tunner_detect_pitch_wav`) bajo un temperamento histórico específico (`tunner://tuner/temperaments`), y diagnosticar la pureza espectral/THD (`tunner_analyze_harmonics_wav`) entregando un informe técnico de afinación y timbre.
2. **`compare_historical_temperaments`**: Guía al agente para generar tablas de frecuencias (`tunner_temperament_table`) comparando 12-EDO, Entonación Justa, Werckmeister III y Vallotti en una tonalidad objetivo, resaltando desviaciones críticas en terceras mayores y quintas lobo.

---

## 4. Plan de Ajustes Técnicos Previos

1. **Crear `OfflinePitchContourAnalyzer` y `SlidingWindowPitchPipeline` en `lib/features/tuner/domain/`**:
   - Extraer la lógica de ventana deslizante (4096 muestras + `SignalConditioningFilter` + `McleodPitchMethod` + `ToneLockTracker`) desde `PitchDetectorService._dspWorkerEntryPoint` hacia una clase Pure Dart reutilizable tanto por el `Isolate` en vivo como por el servidor MCP offline.
   - Incorporar un decodificador WAV Pure Dart compartido (16-bit PCM, 24-bit PCM, 32-bit IEEE float, mono y downmix estéreo) para alimentar tanto `tuner` como `acoustic_lab` y `vocal_autotune`.
2. **Extender `HarmonicSeriesAnalyzer` para Ingesta Offline Autónoma**:
   - Añadir `analyzePcmSamplesAutoF0(Float64List samples, {required int sampleRate, McleodPitchMethod? pitchDetector})` para que no dependa obligatoriamente de un `fundamentalHz` externo.
   - Añadir soporte opcional de análisis multi-frame (resumen promedio de THD, centroide y perfil armónico a lo largo de un archivo WAV).
   - Corregir `HarmonicSpectrogramModal` para consumir resultados precalculados o `analyzeAsync` fuera de `build()`.
3. **Integración de Temperamentos en `NoteEntity` y Soporte de Serialización JSON**:
   - Añadir método `NoteEntity.fromFrequencyWithTemperament(freq, {required MusicalTemperament temperament, double a4Ref, int rootKey, bool anchorA4})`.
   - Implementar `toJson()` en `PitchDetectionResult`, `NoteEntity`, `MusicalTemperament`, `NoiseProfileReport`, `HarmonicBarEntity` y `TimbreAnalysisResult`.
4. **Reubicar Utilidades Matemáticas Puras desde `presentation/` a `domain/`**:
   - Mover `computeDcOffset` y `buildNoiseCalibrationOutcome` desde `tuner/presentation/controllers/tuner_calibration_and_drone_helper.dart` hacia `tuner/domain/signal_conditioning_filter.dart` (o un servicio de calibración de dominio).
5. **Aislamiento Estricto del Runtime MCP**:
   - Excluir `tuner/data/pitch_detector_service.dart` y todo `tuner/presentation/` del entrypoint Pure Dart CLI del servidor MCP.
