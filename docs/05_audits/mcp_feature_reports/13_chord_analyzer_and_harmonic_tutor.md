# Auditoría Forense MCP: Analizador de Acordes Polifónico y Tutor Armónico de Afinación Justa

**Módulos Auditados:** `lib/features/chord_analyzer/` (9 archivos) y `lib/features/harmonic_tutor/` (9 archivos)  
**Total de Archivos `.dart` Inspeccionados:** 18  
**Casos de Uso Canónicos Asociados:** `UC-025`, `UC-037`, `UC-053`, `UC-067`, `UC-146`, `UC-168`, `UC-169`  
**Alcance:** Preparación para ejecución Headless Pure Dart y exposición de capacidades mediante Model Context Protocol (MCP).

---

## 1. Inventario Archivo por Archivo

### 1.1 Módulo `lib/features/chord_analyzer/`

| Archivo `.dart` | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso |
| :--- | :--- | :--- | :--- | :--- |
| `domain/chord_entity.dart` | Domain (Pure Dart) | `ChordQuality`, `ChordQualityExtension`, `ChordEntity` | `intervalsInSemitones`, `symbolSuffix`, `formulaLabel`, `ChordEntity.none`, `isRecognized`, `symbol`, `displayName` | `UC-025`, `UC-169` |
| `domain/chroma_vector_calculator.dart` | Domain (Pure Dart) | `ChromaVectorCalculator` | `calculateFromSamples()`, `calculateFromFrequencies()`, `normalizeChroma()` | `UC-025`, `UC-146` |
| `domain/polyphonic_chord_recognizer.dart` | Domain (Pure Dart) | `PolyphonicChordRecognizer`, `_ChordTemplate` | `identifyFromSamples()`, `identifyFromChroma()`, `reset()` | `UC-025`, `UC-169` |
| `domain/polyphonic_multitone_detector.dart` | Domain (Pure Dart) | `PolyphonicMultiToneDetector` | `detectFromSamples()`, `_deriveHarmonicRole()` | `UC-037`, `UC-053`, `UC-146` |
| `domain/polyphonic_pitch_entity.dart` | Domain (Pure Dart) | `DetectedPolyphonicVoice`, `PolyphonicMultiToneAnalysisResult` | `formattedCents`, `formattedFrequency`, `fullNoteName`, `bassVoice`, `sopranoVoice`, `polyphonyCount` | `UC-037`, `UC-053` |
| `presentation/chord_analyzer_modal.dart` | Presentation (Flutter) | `ChordAnalyzerModal` | `show()`, `build()`, `_buildActiveChordCard()`, `_buildChordHistorySection()` | `UC-025`, `UC-037` |
| `presentation/chord_radar_widget.dart` | Presentation (Flutter) | `ChordRadarWidget`, `_ChordRadarPainter` | `paint()` (renderizado vectorial circular de 12 pitch classes) | `UC-025` |
| `presentation/multi_tone_voicing_widget.dart` | Presentation (Flutter) | `MultiToneVoicingWidget` | `build()` (tarjetas de voces simultáneas, octavas, cents y roles armónicos) | `UC-037` |
| `presentation/polyphonic_live_voicing_widget.dart` | Presentation (Flutter) | `PolyphonicLiveVoicingWidget`, `PolyphonicLiveVoicingModal` | `build()` (desglose polifónico en vivo con armónicos H1-H8) | `UC-053` |

### 1.2 Módulo `lib/features/harmonic_tutor/`

| Archivo `.dart` | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso |
| :--- | :--- | :--- | :--- | :--- |
| `domain/harmonic_role_entity.dart` | Domain (Pure Dart) | `HarmonicRole`, `HarmonicChordType` | `ratio`, `fromSemitones()`, 12 roles con razones enteras `p/q`, `justCents`, `tetOffsetCents` | `UC-067`, `UC-168` |
| `domain/just_intonation_calculator.dart` | Domain (Pure Dart) | `HarmonicLockStatus`, `HarmonicAnalysisResult`, `JustIntonationCalculator` | `analyze()`, `targetFrequency()`, cálculo de batimiento físico `f_beat = |p*f_root - q*f_user|` | `UC-067`, `UC-168` |
| `domain/harmonic_tutor_session_entity.dart` | Domain (Pure Dart) | `HarmonicTutorSessionEntity` | `copyWith()` (estado inmutable de raíz, calidad, análisis activo, dron y escucha) | `UC-067`, `UC-168` |
| `domain/i_harmonic_reference_synth.dart` | Domain (Pure Dart) | `IHarmonicReferenceSynth` | `sampleRate`, `generateChordBuffer()` | `UC-067`, `UC-168` |
| `domain/harmonic_reference_synth.dart` | Domain (Pure Dart) | `HarmonicReferenceSynth` | `generateChordBuffer()` (síntesis aditiva JI en `Float32List` con rampa anti-pop de 20 ms y limitador tanh `_softLimit`) | `UC-067`, `UC-168` |
| `data/harmonic_reference_synth.dart` | Data (Re-export) | Re-export de `../domain/harmonic_reference_synth.dart` | Compatibilidad hacia atrás | `UC-067` |
| `presentation/harmonic_tutor_view_model.dart` | Presentation (Flutter) | `HarmonicTutorViewModel` | `setRootNote()`, `setChordType()`, `setForcedRole()`, `onPitchDetected()`, `toggleDrone()`, `_regenerateDrone()` | `UC-067`, `UC-168` |
| `presentation/harmonic_beat_gauge.dart` | Presentation (Flutter) | `HarmonicBeatGauge`, `_HarmonicBeatPainter` | `paint()` (indicador vectorial animado de batimiento y cents) | `UC-067` |
| `presentation/harmonic_tutor_modal.dart` | Presentation (Flutter) | `HarmonicTutorModal` | `show()`, `build()`, tabla estática `_standardRoots` | `UC-067`, `UC-168` |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Acoplamientos con `package:flutter/` y `dart:ui`

| Archivo | Import Bloqueante | Impacto en CLI Pure Dart | Severidad |
| :--- | :--- | :--- | :--- |
| `chord_analyzer/domain/*` (5 archivos) | Ninguno (0 imports Flutter/UI) | 100% ejecutable en CLI Pure Dart | Baja (Listo) |
| `harmonic_tutor/domain/*` y `data/*` (6 archivos) | Ninguno (0 imports Flutter/UI) | 100% ejecutable en CLI Pure Dart | Baja (Listo) |
| `harmonic_tutor/presentation/harmonic_tutor_view_model.dart` | `package:flutter/foundation.dart` (`ChangeNotifier`, `VoidCallback`) | Bloquea uso directo como gestor de sesión en servidor MCP Pure Dart | Media |
| `chord_analyzer/presentation/*` (4 archivos) | `package:flutter/material.dart`, `provider`, `TunerViewModel` | Exclusivo de UI; no debe importarse en MCP | Informativa |
| `harmonic_tutor/presentation/harmonic_beat_gauge.dart`, `harmonic_tutor_modal.dart` | `package:flutter/material.dart` | Exclusivo de UI; contiene `_standardRoots` hardcodeado en modal | Baja |

**Diagnóstico de Dependencias Transitivas:** Todos los archivos de dominio de ambos módulos son estrictamente Pure Dart (`dart:math`, `dart:typed_data`). No existen importaciones transitivas hacia `flutter` ni `dart:ui`.

### 2.2 Brechas Funcionales, Acústicas y de Integración IA / Conservatorio

1. **Doble Cómputo DFT Redundante y Complejidad O(N * M) en `chord_analyzer`:**
   - `ChromaVectorCalculator.calculateFromSamples()` ejecuta una DFT directa por cada semitono MIDI (`44` notas x `4096` muestras = ~180,224 evaluaciones trigonométricas `cos`/`sin`).
   - `PolyphonicMultiToneDetector.detectFromSamples()` recalcula la misma DFT directa para `45` notas (`minMidiNote = 40` a `maxMidiNote = 84`) y acto seguido invoca `_chordRecognizer.identifyFromSamples()`, el cual vuelve a ejecutar la DFT completa sobre el mismo buffer PCM.
   - **Impacto MCP:** En análisis de archivos WAV/PCM largos o streaming de alta tasa, duplica la latencia y carga de CPU; además viola el rango orquestal de `AGENTS.md` 4.1 (`A0 = 27.5 Hz` MIDI 21 a `C8 = 4186 Hz` MIDI 108), pues los defaults están acotados a `A2..E6` (chroma) y `E2..C6` (multitone).

2. **Ausencia de Serialización JSON (`toJson`/`fromJson`) en Entidades de Dominio:**
   - Ninguna de las entidades clave (`ChordEntity`, `DetectedPolyphonicVoice`, `PolyphonicMultiToneAnalysisResult`, `HarmonicAnalysisResult`, `HarmonicTutorSessionEntity`) implementa `toJson()` ni `fromJson()`. El servidor MCP necesita serialización determinista y estricta.

3. **Histéresis Stateful en `PolyphonicChordRecognizer` Incompatible con Llamadas Stateless MCP:**
   - `PolyphonicChordRecognizer.identifyFromChroma()` mantiene estado interno (`_lastStableChord`, `_provisionalChord`, `_consecutiveDetections`) que exige 2 fotogramas consecutivos si la confianza está entre `0.58` y `0.82`. Si un agente IA analiza un acorde único (one-shot), un reconocedor compartido contaminará la siguiente llamada con el acorde anterior salvo que exista un modo `stateless` o un reinicio explícito.

4. **Vocabulario Armónico Limitado y Ausencia de Inversiones / Bajo (Slash Chords):**
   - `ChordQuality` solo cubre 9 especies (`major`, `minor`, `diminished`, `augmented`, `dominant7`, `major7`, `minor7`, `sus4`, `sus2`). Faltan especies esenciales de conservatorio y jazz: `m7b5` (semidisminuido), `dim7`, `6`, `m6`, `add9`, `9`, `maj9`, `m9`, `5` (power chord).
   - No se combina `bassVoice` de `PolyphonicMultiToneDetector` con `ChordEntity` para reportar inversiones (`C/E`, `C/G`) ni análisis de conducción de voces (*voice leading*).

5. **Limitaciones del Tutor Armónico (`harmonic_tutor`) para Orquestación IA:**
   - `HarmonicTutorSessionEntity` y `HarmonicTutorViewModel` no registran métricas agregadas de sesión (tiempo total en `pureConsonance`, porcentaje de lock, batimiento promedio en Hz, historial de progresiones practicadas).
   - No existe puente entre `HarmonicAnalysisResult` y `EbbinghausSpacedRepetitionEngine` para programar repasos de intervalos en Afinación Justa cuando el estudiante falla sistemáticamente una tercera mayor (`-13.69 c`) o una séptima armónica (`-31.17 c`).
   - `HarmonicReferenceSynth` solo devuelve `Float32List` en memoria; carece de codificador WAV/Base64 o guardado directo a ruta temporal para que un agente MCP entregue el dron armónico sintetizado o lo enrute al motor de audio del estudio.
   - `HarmonicChordType` no incluye tríada disminuida, aumentada ni séptima menor (`m7`), ni soporte para inversión de voces u octavación configurable por rol.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON |
| :--- | :--- | :--- |
| `tunner://harmony/chord-qualities` | Catálogo canónico de especies armónicas soportadas, fórmulas interválicas y semitonos. | `{ "qualities": [{ "id": "major", "symbolSuffix": "", "nameSpanish": "Mayor", "intervalsSemitones": [0, 4, 7], "formula": "1 - 3 - 5" }] }` |
| `tunner://harmony/just-intonation/roles` | Tabla de referencia de los 12 `HarmonicRole` con razones puras `p/q`, cents JI y offset respecto a 12-TET. | `{ "roles": [{ "id": "majorThird", "semitones": 4, "ratio": "5/4", "justCents": 386.31, "tetOffsetCents": -13.69, "labelEs": "Tercera Mayor", "description": "..." }] }` |
| `tunner://harmony/just-intonation/chord-types` | Catálogo de tipos de acordes soportados por el Tutor Armónico (`HarmonicChordType`). | `{ "chordTypes": [{ "id": "dominantSeventh", "label": "Séptima Dominante (1 - 3 - 5 - b7)", "roles": ["root", "majorThird", "perfectFifth", "harmonicSeventh"] }] }` |
| `tunner://harmony/tutor/session/current` | Estado en vivo de la sesión activa del Tutor de Afinación Justa (raíz, acorde, último análisis y telemetría de lock). | `{ "rootNoteName": "C4", "rootFrequency": 261.63, "chordType": "majorTriad", "forcedRole": null, "isDroneActive": true, "activeAnalysis": { "role": "majorThird", "centsOffsetFromJi": -1.4, "beatFrequencyHz": 0.42, "status": "pureConsonance" } }` |

### 3.2 Tools (`tunner_*`)

| Tool MCP | Parámetros (JSON Schema Resumido) | Salida JSON | Mapeo Exacto a Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_analyze_chord_from_pcm` | `{ "samples": number[], "sampleRate"?: number (44100), "a4Ref"?: number (440.0), "noiseGateRms"?: number (0.008), "minMidi"?: int (21), "maxMidi"?: int (108), "stateless"?: bool (true) }` | `{ "isRecognized": bool, "symbol": string, "displayName": string, "rootNoteIndex": int, "quality": string, "confidence": number, "notes": string[], "formula": string, "chromaVector": number[12] }` | `ChromaVectorCalculator.calculateFromSamples()` -> `PolyphonicChordRecognizer.identifyFromChroma()` |
| `tunner_analyze_chord_from_frequencies` | `{ "frequencyAmplitudes": { "<freqHz>": number }, "a4Ref"?: number (440.0) }` | Misma estructura `ChordEntity` JSON + `chromaVector`. | `ChromaVectorCalculator.calculateFromFrequencies()` -> `PolyphonicChordRecognizer.identifyFromChroma()` |
| `tunner_detect_polyphonic_voicing` | `{ "samples": number[], "sampleRate"?: number (44100), "a4Ref"?: number (440.0), "maxVoices"?: int (6), "minMidi"?: int (21), "maxMidi"?: int (108) }` | `{ "isSilence": bool, "voicingName": string, "polyphonyCount": int, "chord": ChordJson, "bassVoice": VoiceJson?, "sopranoVoice": VoiceJson?, "voices": [{ "fullNoteName": string, "frequencyHz": number, "midiNumber": int, "centsDeviation": number, "salience": number, "harmonicRole": string }] }` | `PolyphonicMultiToneDetector.detectFromSamples()` |
| `tunner_analyze_just_intonation` | `{ "userFrequencyHz": number, "rootFrequencyHz": number, "forcedRole"?: string }` | `{ "role": string, "ratio": string, "targetFrequencyJi": number, "centsOffsetFromJi": number, "centsOffsetFrom12Tet": number, "beatFrequencyHz": number, "status": "pureConsonance"|"adjusting"|"roughness", "isLocked": bool, "tuningAdvice": string }` | `JustIntonationCalculator.analyze()` |
| `tunner_calculate_ji_target_frequency` | `{ "rootFrequencyHz": number, "role": string, "octaveOffset"?: int (0) }` | `{ "targetFrequencyHz": number, "ratio": string, "justCents": number, "tetOffsetCents": number }` | `JustIntonationCalculator.targetFrequency()` |
| `tunner_synthesize_ji_reference_chord` | `{ "rootFrequencyHz": number, "chordType"?: string, "roles"?: string[], "durationMs"?: int (2000), "volume"?: number (0.4), "sampleRate"?: int (44100), "outputPath"?: string }` | `{ "sampleRate": int, "totalSamples": int, "durationMs": int, "voicesHz": number[], "wavFilePath"?: string, "peakAmplitude": number }` | `HarmonicReferenceSynth.generateChordBuffer()` (+ exportación WAV en capa headless) |

### 3.3 Prompts (Flujos Guiados para Agentes IA)

1. **`conservatory_just_intonation_drill`**:
   - **Objetivo:** Guiar a un instrumentista de cuerda, viento o cantante a cancelar el batimiento acústico en una tríada o acorde dominante.
   - **Flujo:** Consulta `tunner://harmony/just-intonation/roles` -> genera dron de referencia con `tunner_synthesize_ji_reference_chord` (tónica + quinta) -> solicita al estudiante entonar la tercera mayor (`5/4`, `-13.69 c`) o séptima armónica (`7/4`, `-31.17 c`) -> evalúa iterativamente con `tunner_analyze_just_intonation` hasta lograr `status == "pureConsonance"` (`<= 3.0 cents`).
2. **`polyphonic_voicing_audit`**:
   - **Objetivo:** Auditar un acorde tocado en piano o guitarra para diagnosticar afinación por cuerda/voz, balance de salience y función armónica.
   - **Flujo:** Ejecuta `tunner_detect_polyphonic_voicing` -> identifica voces con `|centsDeviation| > 8.0` -> reporta inversión real contrastando `bassVoice` contra `chord.rootNoteIndex` -> recomienda ajuste específico por cuerda o digitación.

---

## 4. Plan de Ajustes Técnicos Previos (Pre-MCP)

1. **Unificar Extracción Espectral y Eliminar Doble DFT (`chord_analyzer`):**
   - Inyectar el espectro ya calculado (o vector de magnitudes MIDI) desde `PolyphonicMultiToneDetector` hacia `ChromaVectorCalculator` / `PolyphonicChordRecognizer` para eliminar el recálculo duplicado.
   - Reemplazar la DFT directa O(N * M) por una FFT / CQT (o delegar al motor FFT nativo/FFI existente en Tunner) y habilitar el rango orquestal completo `MIDI 21..108` (`27.5 Hz` - `4186 Hz`) configurable sin penalización de rendimiento.
2. **Agregar Serialización JSON Canónica y Modo Stateless:**
   - Implementar `toJson()` / `fromJson()` en `ChordEntity`, `DetectedPolyphonicVoice`, `PolyphonicMultiToneAnalysisResult`, `HarmonicAnalysisResult` y `HarmonicTutorSessionEntity`.
   - Agregar el método `identifyFromChromaStateless()` (o flag `useHysteresis: false`) en `PolyphonicChordRecognizer` para llamadas MCP atómicas sin contaminación de estado entre invocaciones.
3. **Expandir Vocabulario de Acordes e Inversiones:**
   - Añadir especies `m7b5`, `dim7`, `6`, `m6`, `add9`, `9`, `maj9`, `m9`, `power5` en `ChordQuality` y `HarmonicChordType`.
   - Calcular e incluir el campo `inversion` / `slashBassNote` en `PolyphonicMultiToneAnalysisResult`.
4. **Desacoplar Controlador de Sesión de `HarmonicTutorViewModel`:**
   - Extraer la máquina de estados de sesión (`HarmonicTutorController` en `domain/` sin `ChangeNotifier`) que acumule estadísticas de lock (`lockedDurationSec`, `meanBeatHz`, `lockPercentage`) y emita eventos en `Stream`, dejando a `HarmonicTutorViewModel` como un adaptador ligero para Flutter.
5. **Puente con Ebbinghaus y Exportación WAV Headless:**
   - Conectar fallos persistentes de roles en Afinación Justa con ítems de categoría `microtone` / `interval` en `EbbinghausSpacedRepetitionEngine`.
   - Añadir un adaptador Pure Dart que serialice el `Float32List` de `HarmonicReferenceSynth.generateChordBuffer()` a bytes WAV PCM-16/32 para entrega directa vía MCP.
