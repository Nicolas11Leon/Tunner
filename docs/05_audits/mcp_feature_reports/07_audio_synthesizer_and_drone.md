# Reporte de Auditoría Forense MCP: `audio_synthesizer` y `drone`

- **Módulos Auditados**: `lib/features/audio_synthesizer/` (19 archivos `.dart`) y `lib/features/drone/` (4 archivos `.dart`)
- **Total de Archivos Auditados**: 23 archivos `.dart`
- **Objetivo**: Evaluar la preparación para ejecución Headless Pure Dart (CLI / servidor MCP sin dependencias de Flutter ni hardware de audio) y definir los primitivos MCP (`Resources`, `Tools`, `Prompts`) y ajustes técnicos previos.
- **Estado Global de Preparación Headless**: **ALTO en Dominio (100% Pure Dart)**; **BLOQUEADO en Reproducción Hardware (`AudioSynthesizerService`)**; **BRECHAS FUNCIONALES en Renderizado Offline SF2/Polifónico Multi-Evento**.

---

## 1. Inventario Archivo por Archivo

### 1.1 Módulo `lib/features/audio_synthesizer/` (19 archivos)

| Archivo | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
| :--- | :--- | :--- | :--- | :--- |
| `domain/i_audio_synthesizer_service.dart` | Domain | `IAudioSynthesizerService`, `NoOpAudioSynthesizerService` | `playMetronomeClick`, `startDiapasonTone`, `stopDiapasonTone`, `playNoteTone`, `startDroneLoop`, `playPcmWav`, `stopDroneLoop`, `dispose` | UC-005, UC-015, UC-024 |
| `domain/i_stem_export_persistence_service.dart` | Domain | `IStemExportPersistenceService`, `NoOpStemExportPersistenceService` | `saveExportBundle(bundle, customSubfolder)` | UC-036, UC-126 |
| `domain/pcm_wav_synthesizer.dart` | Domain | `PcmWavSynthesizer` | `buildWavHeader`, `generateMetronomeClickWav`, `generateSineToneWav`, `generateMusicalNoteWav` | UC-005, UC-015, UC-029 |
| `domain/stem_audio_synthesizer.dart` | Domain | `StemAudioSynthesizer` | `calculateScoreDurationSeconds`, `midiPitchToFrequency`, `synthesizeMelodySamples`, `synthesizeMetronomeSamples`, `synthesizeAccompanimentSamples`, `synthesizeTrackSamples`, `floatBufferToWav`, `floatStereoBufferToWav`, `exportStemsAndMidi` | UC-007, UC-036, UC-156 |
| `domain/stem_export_entity.dart` | Domain | `StemExportConfig`, `ExportedStemFile`, `ExportBundleResult` | `copyWith`, `sizeBytes`, `formattedSize`, `totalBytes`, `formattedTotalSize` | UC-036, UC-156 |
| `domain/polyphonic/adsr_envelope_generator.dart` | Domain | `AdsrStage`, `AdsrEnvelopeGenerator` | `noteOn`, `noteOff`, `reset`, `processSample` | UC-105, UC-149 |
| `domain/polyphonic/polyphonic_synth_voice.dart` | Domain | `SynthWaveform`, `PolyphonicSynthVoice` | `startNote`, `stopNote`, `kill`, `renderNextSample` | UC-105, UC-149 |
| `domain/polyphonic/polyphonic_voice_pool.dart` | Domain | `PolyphonicVoicePool` (implementa `ISynthVoicePoolPort`) | `noteOn`, `noteOff`, `allNotesOff`, `panic`, `setDslWaveform`, `midiToFrequency`, `renderMonoBlock`, `renderBlock`, `renderWavBlock` | UC-105, UC-108, UC-149 |
| `domain/sf2/i_soundfont_synthesizer_service.dart` | Domain | `ISoundFontSynthesizerService`, `NoOpSoundFontSynthesizerService` | `loadSoundFontFromBytes`, `resetToEssentialsBank`, `selectPatch`, `synthesizeNoteWav` | UC-040, UC-042, UC-149 |
| `domain/sf2/sf2_models.dart` | Domain | `Sf2GeneratorType`, `Sf2Range`, `Sf2SampleHeader`, `Sf2Zone`, `Sf2Instrument`, `Sf2Preset`, `Sf2SoundFont` | `Sf2Range.contains`, `Sf2SampleHeader.hasLoop`, `Sf2SoundFont.findPreset` | UC-040, UC-042 |
| `domain/sf2/sf2_parser.dart` | Domain | `Sf2Parser` | `parse(Uint8List bytes)` (chunks `RIFF`/`sfbk`, `INFO`, `sdta`/`smpl`, `pdta`/`phdr`/`pbag`/`pgen`/`inst`/`ibag`/`igen`/`shdr`, herencia de zonas globales) | UC-040, UC-128, UC-149 |
| `domain/sf2/sf2_wavetable_oscillator.dart` | Domain | `Sf2EnvelopeParams`, `Sf2WavetableOscillator` | `timecentsToSeconds`, `centibelsToGain`, `interpolateHermite4`, `evaluateVolEg`, `renderNoteSamples` | UC-040, UC-042, UC-134 |
| `domain/sf2/tunner_acoustic_soundfont_bank.dart` | Domain | `TunnerAcousticSoundFontBank` | `buildAcousticEssentialsBank` (8 instrumentos GM: #0 Piano, #73 Flute, #40 Violin, #42 Cello, #24 Classical Guitar, #25 Steel Guitar, #27 Electric Guitar Clean, #33 Electric Bass Finger) | UC-040, UC-042, UC-149 |
| `data/audio_synthesizer_service.dart` | Data | `AudioSynthesizerService` | Implementación de `IAudioSynthesizerService` sobre `IStudioAudioEngine` / `AudioPlayer` | UC-005, UC-015, UC-024, UC-127 |
| `data/memory_audio_synthesizer_service.dart` | Data | `MemoryAudioSynthesizerService` | Implementación Pure Dart en memoria con historial de clics, notas, WAVs y estado de dron/diapasón | UC-127, UC-145 |
| `data/soundfont_synthesizer_service.dart` | Data | `SoundFontSynthesizerService` | Implementación Pure Dart de `ISoundFontSynthesizerService` (`loadSoundFontFromBytes`, `selectPatch`, `synthesizeNoteWav`) | UC-040, UC-042, UC-149 |
| `data/stem_export_persistence_service.dart` | Data | `StemExportPersistenceService` | `getExportsDirectory`, `saveExportBundle` (escritura `dart:io` con sanitización de rutas) | UC-036, UC-126 |
| `presentation/audio_midi_export_modal.dart` | Presentation | `AudioMidiExportModal` | Modal Flutter para configurar y lanzar `TunerViewModel.exportStemsAndMidi` | UC-036, UC-156 |
| `presentation/instrument_soundfont_selector_modal.dart` | Presentation | `InstrumentSoundFontSelectorModal` | Modal Flutter para listar presets SF2, cargar `.sf2` vía `IPlatformFileGateway` y previsualizar notas | UC-040, UC-042, UC-149 |

### 1.2 Módulo `lib/features/drone/` (4 archivos)

| Archivo | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
| :--- | :--- | :--- | :--- | :--- |
| `domain/drone_timbre.dart` | Domain | `DroneTimbre` (`pureSine`, `warmFlute`, `richCello`, `organ`), `DroneTimbreExtension` | `displayName`, `description` | UC-024, UC-149 |
| `domain/harmonic_drone_config.dart` | Domain | `HarmonicDroneConfig` | `rootDisplayName`, `fifthDisplayName`, `octaveDisplayName`, `rootMidiNumber`, `calculateFundamentalFrequency`, `copyWith` | UC-024, UC-149 |
| `domain/harmonic_drone_synthesizer.dart` | Domain | `HarmonicDroneSynthesizer` | `calculateFrequencies` (integrado con `TemperamentEngine`), `synthesizeVoiceSample` (con guarda Nyquist `< 0.48 * fs`), `generateDroneWavBuffer` (bucle continuo con crossfade de 40 ms) | UC-023, UC-024, UC-149, UC-168 |
| `presentation/harmonic_drone_modal.dart` | Presentation | `HarmonicDroneModal` | Modal Flutter acoplado a `TunerViewModel` y `StudioThemeScope` | UC-024, UC-149 |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Acoplamientos Bloqueantes para CLI Pure Dart

| Archivo | Dependencia Bloqueante | Severidad | Impacto en Headless / MCP |
| :--- | :--- | :--- | :--- |
| `audio_synthesizer/data/audio_synthesizer_service.dart` | `package:audioplayers/audioplayers.dart`, `package:flutter/foundation.dart` (`kIsWeb`), `StudioAudioEngine` | **ALTA** | No compilable en `dart run` Pure Dart. En MCP debe excluirse del grafo de imports y reemplazarse por renderizado offline a buffers WAV/archivos o `MemoryAudioSynthesizerService`. |
| `audio_synthesizer/presentation/*.dart` y `drone/presentation/harmonic_drone_modal.dart` | `package:flutter/material.dart`, `package:provider/provider.dart`, `TunerViewModel` | **MEDIA** | Exclusivos de UI; no deben importarse desde el servidor MCP. Toda la matemática de síntesis ya está aislada en `domain/`. |

**Resultado Positivo Verificado**: El 100% de `audio_synthesizer/domain/`, `audio_synthesizer/data/soundfont_synthesizer_service.dart`, `audio_synthesizer/data/stem_export_persistence_service.dart`, `audio_synthesizer/data/memory_audio_synthesizer_service.dart` y `drone/domain/` son **estrictamente Pure Dart** sin imports transitivos de `package:flutter/` ni `dart:ui`.

### 2.2 Brechas Funcionales Detectadas (Gaps)

1. **Ausencia de Renderizado Offline SF2 Multi-Nota / Partitura / Acorde (`SoundFontSynthesizerService`)**:
   - `ISoundFontSynthesizerService` únicamente expone `synthesizeNoteWav(midiPitch, durationSeconds, velocity, sampleRate)` para una nota monofónica aislada.
   - No existe un método para renderizar secuencias de eventos MIDI (`List<NoteEvent>`), acordes polifónicos ni `HierarchicalScore` a WAV usando muestras SF2.
2. **Desconexión entre `StemAudioSynthesizer` y el Motor SF2 / `PolyphonicVoicePool`**:
   - `StemAudioSynthesizer` (`synthesizeMelodySamples`, `synthesizeAccompanimentSamples`, `synthesizeTrackSamples`) usa osciladores aditivos senoidales fijos en lugar de delegar en `ISoundFontSynthesizerService` o `PolyphonicVoicePool`.
   - `synthesizeMelodySamples` y `synthesizeAccompanimentSamples` fijan `referencePitchHz = 440.0` sin admitir `a4Ref` ni `MusicalTemperament`.
   - `StemAudioSynthesizer.exportStemsAndMidi` ignora los flags `StemExportConfig.includeMelodyTrack` y `StemExportConfig.includeAccompanimentTrack` (mapea rígidamente `stems[0]` a melodía y `stems[1]` a acompañamiento).
   - `synthesizeAccompanimentSamples` genera siempre una tríada mayor fija (`root`, `root+4`, `root+7`) sin respetar tonalidad ni modo de la partitura.
3. **Generadores SF2 Parcialmente Ignorados en `Sf2WavetableOscillator` y `SoundFontSynthesizerService`**:
   - `Sf2GeneratorType` define `initialFilterFc`, `initialFilterQ`, `pan`, `initialAttenuation`, `sampleModes`, `overridingRootKey` y offsets de muestra (`0..3`), pero `Sf2WavetableOscillator` solo evalúa la envolvente `VolEG` (`33..38`) y el loop básico de `Sf2SampleHeader.hasLoop`.
   - `SoundFontSynthesizerService.synthesizeNoteWav` toma solo la primera zona coincidente (sin layering ni muestras estéreo enlazadas por `sampleLink`) y `Sf2SoundFont.findPreset` hace fallback silencioso a `presets.first` si el patch no existe (ocultando errores de invocación en MCP).
4. **Limitaciones de Renderizado Offline en `PolyphonicVoicePool`**:
   - `renderWavBlock(durationSeconds)` renderiza el estado actual de voces ya activadas, pero carece de un secuenciador offline por lista de eventos temporales (`startSec`, `durationSec`, `midiNote`, `velocity`) que invoque `noteOn`/`noteOff` en muestras exactas.
   - Las formas de onda `sawtooth` y `pulse` en `PolyphonicSynthVoice` no aplican anti-aliasing (PolyBLEP), generando aliasing en frecuencias agudas.
   - `renderBlock` duplica la mezcla mono en `leftOut` y `rightOut` (sin panoramización por voz).
5. **Limitaciones de `HarmonicDroneSynthesizer` y `HarmonicDroneConfig`**:
   - `HarmonicDroneConfig` carece de serialización `toJson()` / `fromJson()` y limita las voces a fundamental + quinta + octava (sin soporte para intervalos configurables como tercera justa, cuarta o patrón de tanpura).
   - `generateDroneWavBuffer` genera siempre WAV Mono 16-bit e ignora el campo `config.volume` (el volumen solo se aplica en el reproductor de hardware `AudioSynthesizerService.startDroneLoop`).
6. **Falta de Serialización JSON en Entidades de Exportación y Presets SF2**:
   - `StemExportConfig`, `ExportedStemFile`, `ExportBundleResult`, `Sf2Preset` y `HarmonicDroneConfig` no implementan `toJson()` / `fromJson()`.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON |
| :--- | :--- | :--- |
| `tunner://synth/soundfonts/active` | Metadatos del banco SoundFont SF2 actualmente cargado y catálogo de presets GM disponibles. | `{ "soundFontName": "Tunner Acoustic Essentials", "activePatch": 0, "sampleCount": 8, "presets": [{ "name": "Grand Piano", "patch": 0, "bank": 0, "zoneCount": 1 }] }` |
| `tunner://synth/polyphonic/state` | Estado actual del motor `PolyphonicVoicePool` (polifonía máxima, voces activas, forma de onda, ADSR, ganancia). | `{ "maxPolyphony": 16, "activeVoiceCount": 0, "waveform": "triangle", "pulseWidth": 0.5, "masterGain": 0.75, "sampleRate": 44100, "adsr": { "attackSeconds": 0.015, "decaySeconds": 0.08, "sustainLevel": 0.65, "releaseSeconds": 0.18 } }` |
| `tunner://drone/timbres` | Catálogo de timbres de dron armónico disponibles en `DroneTimbre`. | `{ "timbres": [{ "id": "pureSine", "displayName": "Senoidal Pura", "description": "..." }, ...] }` |
| `tunner://drone/config/default` | Configuración canónica por defecto de `HarmonicDroneConfig` y frecuencias calculadas en A4=440 Hz. | `{ "rootNoteIndex": 0, "octave": 3, "includeFifth": true, "includeOctave": false, "timbre": "warmFlute", "volume": 0.7, "harmonicBalance": 0.35, "frequenciesHz": { "fundamental": 130.81, "fifth": 196.0, "octave": 0.0 } }` |

### 3.2 Tools (`tunner_*`)

| Nombre del Tool | Parámetros (JSON Schema Resumido) | Salida JSON | Mapeo Exacto en Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_synth_tone_wav` | `{ "type": "sine" \| "musical_note" \| "metronome_click", "frequencyHz?": number, "durationSeconds?": number, "isDownbeat?": boolean, "seamlessLoop?": boolean, "sampleRate?": int, "outputPath?": string }` | `{ "outputPath": string, "sizeBytes": int, "durationSeconds": number, "sampleRate": int, "channels": 1, "bitsPerSample": 16 }` | `PcmWavSynthesizer.generateSineToneWav` / `generateMusicalNoteWav` / `generateMetronomeClickWav` |
| `tunner_sf2_load_bank` | `{ "sf2FilePath": string }` | `{ "soundFontName": string, "presetCount": int, "instrumentCount": int, "sampleCount": int, "presets": [...] }` | `Sf2Parser.parse` + `SoundFontSynthesizerService.loadSoundFontFromBytes` |
| `tunner_sf2_render_note` | `{ "midiPitch": int (0..127), "patch?": int, "durationSeconds?": number, "velocity?": int (1..127), "sampleRate?": int, "outputPath": string }` | `{ "outputPath": string, "patch": int, "presetName": string, "midiPitch": int, "sizeBytes": int }` | `SoundFontSynthesizerService.selectPatch` + `synthesizeNoteWav` |
| `tunner_polyphonic_render_chord` | `{ "midiNotes": int[], "waveform?": "sine" \| "sawtooth" \| "pulse" \| "triangle", "durationSeconds": number, "velocity?": number, "adsr?": { "attack", "decay", "sustain", "release" }, "sampleRate?": int, "outputPath": string }` | `{ "outputPath": string, "renderedNotes": int[], "channels": 2, "sampleRate": int, "sizeBytes": int }` | `PolyphonicVoicePool.noteOn` + `renderWavBlock` |
| `tunner_export_stems_and_midi` | `{ "scoreJson": object, "bpm": int, "trackTitle": string, "sampleRate?": int, "includeMasterMixdown?": bool, "includeIndividualStems?": bool, "includeMidiFile?": bool, "includeMetronomeTrack?": bool, "outputSubfolder?": string }` | `{ "savedPaths": string[], "totalBytes": int, "files": [{ "fileName", "mimeType", "sizeBytes", "durationMs" }] }` | `StemAudioSynthesizer.exportStemsAndMidi` + `StemExportPersistenceService.saveExportBundle` |
| `tunner_drone_generate_wav` | `{ "rootNoteIndex": int (0..11), "octave": int (0..8), "includeFifth?": bool, "includeOctave?": bool, "timbre?": "pureSine" \| "warmFlute" \| "richCello" \| "organ", "harmonicBalance?": number, "volume?": number, "a4Ref?": number, "temperamentId?": string, "temperamentRootKey?": int, "durationSeconds?": number, "sampleRate?": int, "outputPath": string }` | `{ "outputPath": string, "rootDisplayName": string, "frequenciesHz": { "fundamental", "fifth", "octave" }, "sizeBytes": int, "durationSeconds": number }` | `HarmonicDroneSynthesizer.calculateFrequencies` + `generateDroneWavBuffer` |

### 3.3 Prompts Guiados para Agentes IA

1. **`compose_and_render_practice_backing`**: Guía al agente para construir o cargar un `HierarchicalScore`, seleccionar un temperamento y `a4Ref`, generar un dron armónico de referencia (`tunner_drone_generate_wav`) y exportar el paquete de stems + master estéreo + archivo MIDI (`tunner_export_stems_and_midi`) en un directorio de trabajo.
2. **`audition_soundfont_instrument_range`**: Guía al agente para cargar un banco `.sf2` externo (`tunner_sf2_load_bank`), inspeccionar sus presets (`tunner://synth/soundfonts/active`) y renderizar una escala o tríada de prueba en múltiples octavas (`tunner_sf2_render_note`) para verificar el mapeo de zonas y loops.

---

## 4. Plan de Ajustes Técnicos Previos

Antes de conectar `audio_synthesizer` y `drone` al servidor MCP Headless, se deben ejecutar los siguientes refactorings en `domain/` y `data/`:

1. **Renderizado Offline SF2 Polifónico y Secuencial (`ISoundFontSynthesizerService` / `SoundFontSynthesizerService`)**:
   - Agregar `synthesizeChordWav(List<int> midiPitches, ...)` y `synthesizeScoreWav(HierarchicalScore score, {required int bpm, int patch, double a4Ref, MusicalTemperament? temperament})` aplicando mezcla `Float64List` con limitador suave `tanh`.
   - Cambiar `Sf2SoundFont.findPreset` para añadir parámetro `bool strict = false` que devuelva `null` cuando el patch/bank solicitado no exista, evitando fallbacks silenciosos en invocaciones MCP.
   - Soportar `overridingRootKey`, `initialAttenuation`, `sampleModes` y `pan` en `Sf2WavetableOscillator`.
2. **Secuenciador Offline de Eventos en `PolyphonicVoicePool`**:
   - Añadir `renderEventsToWav(List<SynthNoteEvent> events, {required double totalDurationSeconds, int sampleRate})` para renderizar melodías y progresiones con tiempos exactos de `noteOn` y `noteOff` sin reloj en tiempo real.
   - Implementar PolyBLEP en `PolyphonicSynthVoice` para `sawtooth` y `pulse`.
3. **Corrección de Brechas en `StemAudioSynthesizer`**:
   - Respetar `config.includeMelodyTrack` y `config.includeAccompanimentTrack` dentro de `exportStemsAndMidi`.
   - Inyectar opcionalmente `ISoundFontSynthesizerService?` y parámetros `a4Ref` / `MusicalTemperament` para que los stems puedan renderizarse con timbres SF2 y afinación histórica en lugar de senoidales fijas a 440 Hz.
4. **Aplicación de Ganancia y Serialización en `drone/domain/`**:
   - Aplicar `config.volume` dentro de `HarmonicDroneSynthesizer.generateDroneWavBuffer` (o parámetro explícito `applyConfigVolume = true`) para que el WAV exportado refleje la ganancia configurada.
   - Implementar `toJson()` / `fromJson()` en `HarmonicDroneConfig`, `StemExportConfig` y `ExportedStemFile` (metadatos sin bytes binarios).
5. **Aislamiento de Dependencias de Hardware en el Paquete Headless**:
   - Mantener `data/audio_synthesizer_service.dart` fuera del barrel/entrypoint del servidor MCP; exportar exclusivamente los servicios Pure Dart (`PcmWavSynthesizer`, `StemAudioSynthesizer`, `PolyphonicVoicePool`, `SoundFontSynthesizerService`, `StemExportPersistenceService`, `HarmonicDroneSynthesizer`).
