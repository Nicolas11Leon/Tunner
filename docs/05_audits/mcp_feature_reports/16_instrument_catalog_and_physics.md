# Reporte de Auditoría Forense MCP 16: Catálogo de Instrumentos, Física Acústica y Emulación

## Metadatos de Auditoría

- **ID del Reporte:** `AUDIT-MCP-2026-16`
- **Módulo Auditado:** `lib/features/instrument/`
- **Total de Archivos `.dart` Auditados:** 24 (13 en `domain/`, 2 en `data/`, 9 en `presentation/`)
- **Casos de Uso Asociados:** `UC-10`, `UC-31`, `UC-45`, `UC-48`, `UC-59`, `UC-90`, `UC-117`, `UC-171`, `UC-186`
- **Estado de Preparación Headless (Pure Dart):** `Parcialmente Listo (Dominio 100% Pure Dart; requiere unificación de catálogos, serialización JSON y corrección de defectos DSP/transposición)`

---

## 1. Inventario Archivo por Archivo

### 1.1 Capa de Dominio (`lib/features/instrument/domain/`) — 13 archivos

| Archivo | Clases / Enums Principales | Métodos / Propiedades Clave | Casos de Uso |
| :--- | :--- | :--- | :--- |
| `lib/features/instrument/domain/acoustic_range.dart` | `AcousticRange` | `minFrequencyHz`, `maxFrequencyHz`, `minMidiNote`, `maxMidiNote`, `standardTuningFrequencies`, `standardTuningNoteNames`, `containsFrequency(double)`, `containsMidiNote(int)` | `UC-48`, `UC-171` |
| `lib/features/instrument/domain/i_instrument_transposition_service.dart` | `IInstrumentTranspositionService` | `getSoundingNote(String, InstrumentProfileEntity)`, `getSoundingFrequency(String, InstrumentProfileEntity, {double a4Ref})`, `getWrittenNote(String, InstrumentProfileEntity)` | `UC-10`, `UC-31`, `UC-45` |
| `lib/features/instrument/domain/instrument_customization_profile.dart` | `InstrumentCustomizationProfile` | `defaultFor(UniversalInstrumentDefinition)`, `calculateFrequencyForMidiNote(int, {int? stringIndex})`, `copyWith(...)` | `UC-48`, `UC-171` |
| `lib/features/instrument/domain/instrument_profile_entity.dart` | `InstrumentClef`, `InstrumentKey`, `InstrumentFamily`, `InstrumentProfileEntity` | `isTransposing`, `standardInstruments` (42 perfiles estáticos), constantes de perfiles orquestales y étnicos | `UC-10`, `UC-31`, `UC-59`, `UC-117`, `UC-171` |
| `lib/features/instrument/domain/instrument_transposition_service.dart` | `InstrumentTranspositionService` | `getSoundingNote(...)`, `getSoundingFrequency(...)`, `getWrittenNote(...)`, `_noteNameToMidi(String)`, `_midiToNoteName(int)` | `UC-10`, `UC-31` |
| `lib/features/instrument/domain/musical_phrase_entity.dart` | `MusicalPhraseNote`, `MusicalPhraseEntity` | `totalTicks`, `restQuarter`, `canonicalPhrases` (5 frases: `majorConcertArpeggio`, `bachPreludeMotif`, `andeanPentatonic`, `funkBassline`, `maqamBayatiStanza`) | `UC-48`, `UC-90` |
| `lib/features/instrument/domain/per_note_detuning_profile.dart` | `PerNoteDetuningProfile` | `getCentsOffsetForNote(int)`, `getCentsOffsetForString(int)`, `calculateDetunedFrequency(double, {int?, int?})`, `withNoteOffset(int, double)`, `withStringOffset(int, double)`, `presets` (5 presets: `standard`, `honkyTonk`, `railsbackStretch`, `twelveStrings`, `quarterToneMaqam`) | `UC-48` |
| `lib/features/instrument/domain/procedural_instrument_synthesizer.dart` | `ProceduralInstrumentSynthesizer` | `sampleRate` (`44100`), `synthesizeNote(...)`, `synthesizeCustomNote(...)`, `synthesizePhrase(...)`, `floatBufferToWavBytes(Float32List, {int sampleRate})` | `UC-48`, `UC-90`, `UC-171` |
| `lib/features/instrument/domain/smart_instrument_detector.dart` | `AcousticSignature`, `SmartInstrumentMatch`, `SmartInstrumentDetector` | `oddHarmonicEnergyFraction`, `highFrequencyHarmonicRatio`, `detectCandidates(AcousticSignature, {int limit})`, `bestMatch(AcousticSignature, {double minimumConfidence})` | `UC-59` |
| `lib/features/instrument/domain/timbral_profile.dart` | `AdsrEnvelope`, `TimbralProfile` | 8 presets ADSR (`percussivePitched`, `pluckedString`, `pianoAcoustic`, etc.), 14 presets tímbricos (`pureFlute`, `clarinet`, `brassBright`, `grandPiano`, `kora`, `sitar`, `shakuhachi`, `charango`, `cuatroVenezuelan`, etc.) | `UC-48`, `UC-117`, `UC-171` |
| `lib/features/instrument/domain/universal_instrument_definition.dart` | `UniversalInstrumentDefinition` | `isTransposing`, `standardTuningFrequenciesFor({double referencePitchHz})`, `masterCatalog` (40 instrumentos), `findById(String)`, `search(String)`, `filterByCategory(HornbostelSachsCategory)`, `filterBySubfamily(InstrumentSubfamily)` | `UC-117`, `UC-171`, `UC-186` |
| `lib/features/instrument/domain/universal_instrument_taxonomy.dart` | `HornbostelSachsCategory`, `InstrumentSubfamily` | 6 categorías Hornbostel-Sachs (`idiophone`, `membranophone`, `chordophone`, `aerophone`, `electrophone`, `vocal`) y 14 subfamilias con `code` y `displayName` | `UC-117`, `UC-171` |
| `lib/features/instrument/domain/visual_interface_profile.dart` | `VisualRendererType`, `VisualInterfaceProfile` | 7 tipos de renderizador táctil y 15 presets visuales con colores ARGB32 como `int` (`primaryAccentHex`, `secondaryAccentHex`, `surfaceHex`) sin dependencia de `dart:ui` | `UC-171` |

### 1.2 Capa de Datos (`lib/features/instrument/data/`) — 2 archivos

| Archivo | Clases / Exports Principales | Propósito | Casos de Uso |
| :--- | :--- | :--- | :--- |
| `lib/features/instrument/data/instrument_transposition_service.dart` | Re-export de `../domain/instrument_transposition_service.dart` | Retrocompatibilidad tras migración a dominio puro | `UC-10`, `UC-31` |
| `lib/features/instrument/data/procedural_instrument_synthesizer.dart` | Re-export de `../domain/procedural_instrument_synthesizer.dart` | Retrocompatibilidad tras migración a dominio puro | `UC-48`, `UC-171` |

### 1.3 Capa de Presentación (`lib/features/instrument/presentation/`) — 9 archivos

| Archivo | Clases Principales | Rol en UI | Casos de Uso |
| :--- | :--- | :--- | :--- |
| `lib/features/instrument/presentation/visual_interface_profile_ui_ext.dart` | `VisualInterfaceProfileUiExt` | Convierte códigos ARGB32 `int` en `Color` de Flutter | `UC-171` |
| `lib/features/instrument/presentation/drum_pads_tactile_widget.dart` | `DrumPadsTactileWidget` | Cuadrícula de 8 pads GM Canal 10 (`36`..`51`) | `UC-171` |
| `lib/features/instrument/presentation/fretboard_tactile_widget.dart` | `FretboardTactileWidget` | Mástil interactivo con trastes para cuerdas pulsadas/frotadas | `UC-171` |
| `lib/features/instrument/presentation/keybed_tactile_widget.dart` | `KeybedTactileWidget` | Teclado de 2 octavas diatónicas con respuesta táctil | `UC-171` |
| `lib/features/instrument/presentation/instrument_emulation_surface_widget.dart` | `InstrumentEmulationSurfaceWidget` | Superficie polimórfica que despacha según `VisualRendererType` | `UC-171` |
| `lib/features/instrument/presentation/instrument_customization_modal.dart` | `InstrumentCustomizationModal` | Modal de 3 pestañas (A4/temperamento, ADSR/brillo, micro-afinación) | `UC-48` |
| `lib/features/instrument/presentation/instrument_selector_modal.dart` | `InstrumentSelectorModal` | Selector modal acoplado a `TunerViewModel` e `InstrumentProfileEntity.standardInstruments` | `UC-10`, `UC-31` |
| `lib/features/instrument/presentation/universal_master_keyboard_widget.dart` | `UniversalMasterKeyboardWidget` | Teclado polifónico maestro QWERTY y reproductor de `MusicalPhraseEntity` | `UC-48`, `UC-90` |
| `lib/features/instrument/presentation/widgets/smart_instrument_badge.dart` | `SmartInstrumentBadge` | Badge reactivo de detección inteligente y cambio automático de instrumento | `UC-59` |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Evaluación de Acoplamiento Flutter / Pure Dart

- **Capa `domain/` y `data/` (15/15 archivos):** **0 imports** de `package:flutter/`, `dart:ui`, `shared_preferences` ni `path_provider`. Son completamente compilables en `dart run bin/tunner_mcp_server.dart`.
  - Dependencias externas del dominio dentro del repositorio:
    - `instrument_customization_profile.dart` importa `../../tuner/domain/temperament_engine.dart` (Pure Dart).
    - `procedural_instrument_synthesizer.dart` importa `../../audio_synthesizer/domain/pcm_wav_synthesizer.dart` (Pure Dart).
- **Capa `presentation/` (9/9 archivos):** Aislada correctamente de `domain/` mediante `VisualInterfaceProfileUiExt`. No se importa desde el servidor MCP.

### 2.2 Brechas Funcionales y Arquitectónicas Críticas

1. **Dualidad de Modelos y Desincronización de Catálogos (Severidad Alta):**
   - Existen dos modelos de instrumento paralelos e incompatibles sin puente canónico:
     - `UniversalInstrumentDefinition.masterCatalog`: **40 instrumentos** con IDs jerárquicos Hornbostel-Sachs (`chordophone.keyboard.piano_grand_acoustic`, `aerophone.woodwind.flute_concert_c`).
     - `InstrumentProfileEntity.standardInstruments`: **42 instrumentos** con IDs planos (`grand_piano`, `flute`, `bb_clarinet`).
   - Diferencias concretas detectadas:
     - `InstrumentProfileEntity` incluye `altoFlute`, `aClarinet` y `voice` (genérico), ausentes en `UniversalInstrumentDefinition.masterCatalog`.
     - `UniversalInstrumentDefinition` incluye `voiceTenor`, ausente en `InstrumentProfileEntity.standardInstruments`.
     - `IInstrumentTranspositionService` y `SmartInstrumentDetector` operan sobre `InstrumentProfileEntity`, mientras que `InstrumentCustomizationProfile` y `ProceduralInstrumentSynthesizer` operan sobre `UniversalInstrumentDefinition`.
   - Impacto en MCP: Un agente IA que consulte `tunner://catalog/instruments` recibirá `universalId`, pero si luego llama a una herramienta de transposición o cambia el instrumento activo en `AppUserSettingsEntity.selectedInstrumentId` (que por defecto es `'flute'`, un ID plano de `InstrumentProfileEntity`), habrá colisión de identificadores.

2. **Ausencia Total de Serialización JSON (`toJson` / `fromJson`) en el Dominio (Severidad Alta):**
   - Ninguna clase de `lib/features/instrument/domain/` implementa `toJson()` ni `fromJson()`: `UniversalInstrumentDefinition`, `InstrumentProfileEntity`, `AcousticRange`, `TimbralProfile`, `AdsrEnvelope`, `VisualInterfaceProfile`, `InstrumentCustomizationProfile`, `PerNoteDetuningProfile`, `MusicalPhraseEntity`, `MusicalPhraseNote`, `AcousticSignature` y `SmartInstrumentMatch`.
   - Impacto en MCP: Impide exponer recursos estructurados y recibir perfiles de personalización o firmas acústicas por JSON-RPC sin escribir mappers duplicados en la capa MCP.

3. **Defecto de Octava y Enarmonías en `InstrumentTranspositionService._noteNameToMidi` (Severidad Alta):**
   - En `lib/features/instrument/domain/instrument_transposition_service.dart` (líneas 60-61), `dob` (`Cb4`) se normaliza a `'Si'` sin restar 1 a `octavePart`, produciendo MIDI 71 (`Si4`) en lugar de MIDI 59 (`Si3`) — un error de 12 semitonos.
   - No soporta enarmonías ascendentes `E#`/`Mi#` ni `B#`/`Si#`, ni dobles alteraciones (`##`, `bb`).
   - El método `_midiToNoteName` siempre retorna solfeo con sostenidos (`Do`, `Do#`, ...), sin opción de formato anglosajón (`C4`, `Bb3`) requerido por estándares MIDI/MusicXML y clientes MCP.

4. **Cobertura Reducida de `SmartInstrumentDetector` (Severidad Media):**
   - `_referenceProfiles` (líneas 97-170) solo define **9 perfiles** hardcoded (`flute`, `bb_clarinet`, `bb_trumpet`, `eb_alto_sax`, `violin`, `guitar`, `cello`, `trombone`, `voice`), dejando fuera 31 de los 40 instrumentos universales (incluyendo piano, bajo eléctrico, percusión afinada y los 5 instrumentos étnicos de `UC-117`).
   - Tampoco existe un extractor que construya `AcousticSignature` directamente desde un buffer PCM o archivo WAV en modo headless.

5. **Brechas en `ProceduralInstrumentSynthesizer` (Severidad Media):**
   - `customization.resonanceFactor` se almacena en `InstrumentCustomizationProfile`, pero nunca se usa en `synthesizeCustomNote()`.
   - `sampleRate` es constante (`44100`) en `synthesizeNote`, `synthesizeCustomNote` y `synthesizePhrase`; solo `floatBufferToWavBytes` acepta parámetro `sampleRate`, lo cual puede producir archivos WAV con pitch desplazado si se pasa otro `sampleRate` sin re-sintetizar.
   - No existe método `synthesizeChord(...)` para polifonía simultánea, ni parámetro `stringIndex` en `synthesizePhrase(...)` para evaluar `centsOffsetsByStringIndex`.
   - `MusicalPhraseEntity.maqamBayatiStanza` documenta `-50 cents` en E4, pero la entidad `MusicalPhraseNote` no transporta un campo opcional `microtoneOffsetCents`; depende de que el llamador aplique externamente `PerNoteDetuningProfile.quarterToneMaqam`.

6. **Inexistencia de Repositorio en Memoria/Disco para Perfiles Personalizados (Severidad Media):**
   - No hay un contrato `IInstrumentCatalogRepository` ni almacén de perfiles `InstrumentCustomizationProfile` persistidos por sesión/usuario. En modo headless MCP, las personalizaciones aplicadas a un instrumento deben poder consultarse y mutarse en estado de sesión.

### 2.3 Integración con `HeadlessCompositionRoot`

El módulo `instrument` no requiere mocks de Flutter para integrarse en `HeadlessCompositionRoot`. Debe registrarse como servicios stateless/stateful puros:
- `IInstrumentCatalogService` (unificando `UniversalInstrumentDefinition.masterCatalog` + mapa bidireccional con `InstrumentProfileEntity`).
- `IInstrumentTranspositionService` -> `const InstrumentTranspositionService()`.
- `SmartInstrumentDetector` -> instancia pura con referencias derivables del catálogo maestro.
- `InstrumentSessionRegistry` -> mantiene el `InstrumentCustomizationProfile` activo por `universalId` para la sesión MCP.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON Retornada |
| :--- | :--- | :--- |
| `tunner://catalog/instruments` | Catálogo maestro unificado de los 40 instrumentos universales con taxonomía Hornbostel-Sachs, tesitura, transposición y GM patch. | `{ "count": 40, "instruments": [ { "universalId": "string", "legacyProfileId": "string|null", "displayName": "string", "category": "chordophone", "subfamily": "keyboard", "tuningKey": "concertC", "notationClef": "treble", "transpositionSemitones": 0, "generalMidiNumber": 0, "isDrumMapPercussion": false, "acousticRange": { "minFrequencyHz": 27.5, "maxFrequencyHz": 4186.01, "minMidiNote": 21, "maxMidiNote": 108, "standardTuningFrequencies": [], "standardTuningNoteNames": [] }, "timbralProfile": { "adsr": { "attackMs": 3.0, "decayMs": 800.0, "sustainLevel": 0.35, "releaseMs": 600.0 }, "harmonicOvertoneAmplitudes": [1.0, ...], "noiseTransientRatio": 0.07, "resonanceFactor": 0.9 }, "visualRendererType": "keybed" } ] }` |
| `tunner://catalog/instruments/{universalId}` | Detalle completo de un instrumento individual, incluyendo frecuencias escaladas a A4 activo y palabras clave de búsqueda. | Objeto JSON del instrumento con `searchKeywords`, `acousticRange`, `timbralProfile`, `visualProfile` (códigos hex) y `activeCustomization`. |
| `tunner://catalog/taxonomy` | Taxonomía formal Hornbostel-Sachs (6 categorías y 14 subfamilias) con conteo de instrumentos por rama. | `{ "categories": [ { "code": "string", "displayName": "string", "instrumentCount": 0 } ], "subfamilies": [ { "code": "string", "displayName": "string", "instrumentCount": 0 } ] }` |
| `tunner://catalog/detuning-presets` | Presets canónicos de micro-afinación (`PerNoteDetuningProfile.presets`: estándar, honky-tonk, Railsback, 12 cuerdas, Maqam Bayati). | `{ "presets": [ { "id": "string", "name": "string", "description": "string", "centsOffsetsByMidiNote": { "64": -50.0 }, "centsOffsetsByStringIndex": {} } ] }` |
| `tunner://catalog/phrases` | Catálogo de estrofas canónicas (`MusicalPhraseEntity.canonicalPhrases`) para pruebas de síntesis y calibración tímbrica. | `{ "phrases": [ { "id": "string", "title": "string", "genreOrTradition": "string", "defaultBpm": 120, "timeSignature": "4/4", "totalTicks": 36, "notes": [ { "midiNote": 60, "durationTicks": 4, "velocity": 0.8, "isRest": false } ] } ] }` |

### 3.2 Tools (`tunner_*`)

| Nombre de Tool | Parámetros (JSON Schema Resumido) | Salida JSON | Mapeo Exacto en Código Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_search_instruments` | `{ "query": "string?", "category": "string?", "subfamily": "string?", "minMidiNote": "int?", "maxMidiNote": "int?", "onlyTransposing": "bool?" }` | `{ "matches": [ ...UniversalInstrumentDefinitionJSON ], "total": int }` | `UniversalInstrumentDefinition.search()`, `filterByCategory()`, `filterBySubfamily()` + filtro por `AcousticRange.containsMidiNote()` |
| `tunner_validate_instrument_range` | `{ "instrumentId": "string", "midiNotes": "int[]?", "frequenciesHz": "number[]?" }` | `{ "instrumentId": "string", "allInRange": bool, "outOfRangeItems": [ { "input": ..., "reason": "string" } ], "supportedRange": { "minMidiNote": int, "maxMidiNote": int, "minFrequencyHz": number, "maxFrequencyHz": number } }` | `UniversalInstrumentDefinition.findById()` + `AcousticRange.containsMidiNote()` / `containsFrequency()` |
| `tunner_transpose_note` | `{ "note": "string", "instrumentId": "string", "direction": "'written_to_sounding' \| 'sounding_to_written'", "a4RefHz": "number (default 440.0)", "outputFormat": "'solfege' \| 'scientific'" }` | `{ "inputNote": "string", "resultNote": "string", "soundingFrequencyHz": number, "transpositionSemitones": int, "instrumentKey": "string" }` | `InstrumentTranspositionService.getSoundingNote()`, `getSoundingFrequency()`, `getWrittenNote()` |
| `tunner_calculate_microtonal_frequency` | `{ "instrumentId": "string", "midiNote": "int (0-127)", "stringIndex": "int?", "referencePitchA4": "number (415-466)", "temperamentId": "string?", "detuningPresetId": "string?", "customNoteCents": "Record<int,number>?" }` | `{ "midiNote": int, "transposedMidiNote": int, "frequencyHz": number, "equal12EdoHz": number, "totalOffsetCents": number }` | `InstrumentCustomizationProfile.calculateFrequencyForMidiNote(midiNote, stringIndex: stringIndex)` + `PerNoteDetuningProfile` |
| `tunner_get_standard_tuning` | `{ "instrumentId": "string", "referencePitchA4": "number (default 440.0)" }` | `{ "instrumentId": "string", "referencePitchA4": number, "strings": [ { "index": int, "noteName": "string", "frequencyHz": number } ] }` | `UniversalInstrumentDefinition.standardTuningFrequenciesFor(referencePitchHz: ...)` + `AcousticRange.standardTuningNoteNames` |
| `tunner_synthesize_instrument_note` | `{ "instrumentId": "string", "midiNote": "int?", "frequencyHz": "number?", "durationSeconds": "number (0.05-15.0)", "velocity": "number (0.0-1.0)", "outputWavPath": "string", "customization": "object?" }` | `{ "outputWavPath": "string", "sampleRate": int, "numSamples": int, "durationSeconds": number, "bytesWritten": int, "frequencyHz": number }` | `ProceduralInstrumentSynthesizer.synthesizeCustomNote()` + `floatBufferToWavBytes()` |
| `tunner_synthesize_instrument_phrase` | `{ "instrumentId": "string", "phraseId": "string?", "customNotes": "MusicalPhraseNote[]?", "bpm": "int?", "outputWavPath": "string", "customization": "object?" }` | `{ "outputWavPath": "string", "bpm": int, "totalTicks": int, "durationSeconds": number, "bytesWritten": int }` | `ProceduralInstrumentSynthesizer.synthesizePhrase()` + `floatBufferToWavBytes()` |
| `tunner_detect_instrument_from_signature` | `{ "fundamentalFrequencyHz": "number", "clarity": "number (0-1)", "overtoneAmplitudes": "number[8]", "spectralCentroidHz": "number", "limit": "int (default 3)", "minimumConfidence": "number (default 0.75)" }` | `{ "bestMatch": "SmartInstrumentMatchJSON|null", "candidates": [ ...SmartInstrumentMatchJSON ] }` | `SmartInstrumentDetector.detectCandidates()` / `bestMatch()` con `AcousticSignature` |

### 3.3 Prompts Guiados para Agentes IA

1. **`tunner_orchestration_range_audit`**
   - *Objetivo:* Auditar si un arreglo multi-instrumento respeta las tesituras físicas y transposiciones de cada instrumento elegido.
   - *Flujo:* Lee `tunner://catalog/instruments`, invoca `tunner_validate_instrument_range` por cada parte y usa `tunner_transpose_note` para generar particellas escritas en clave de cada instrumento transpositor.
2. **`tunner_microtonal_ethnomusicology_lab`**
   - *Objetivo:* Configurar y sintetizar una frase tradicional (e.g., Maqam Bayati, Charango Andino, Kora o Sitar) con temperamento histórico y micro-afinación por nota.
   - *Flujo:* Lee `tunner://catalog/detuning-presets` y `tunner://catalog/phrases`, calcula frecuencias con `tunner_calculate_microtonal_frequency` y renderiza demostración WAV con `tunner_synthesize_instrument_phrase`.
3. **`tunner_timbral_identification_diagnostic`**
   - *Objetivo:* Clasificar un instrumento a partir de métricas espectrales extraídas de una toma de audio y recomendar ajustes de afinación y tesitura.
   - *Flujo:* Invoca `tunner_detect_instrument_from_signature`, consulta `tunner://catalog/instruments/{universalId}` y retorna guía de rango y transposición.

---

## 4. Plan de Ajustes Técnicos Previos (Pre-MCP Refactoring)

1. **Unificación Canónica de Identificadores y Catálogo (`P0`):**
   - Crear un mapper determinista `InstrumentCatalogMapper` en `lib/features/instrument/domain/` que vincule cada `UniversalInstrumentDefinition.universalId` con su `InstrumentProfileEntity.id` correspondiente.
   - Incorporar `altoFlute`, `aClarinet` y `voice` genérico (o documentar alias explícitos) en `UniversalInstrumentDefinition.masterCatalog`, y añadir `voiceTenor` en `InstrumentProfileEntity.standardInstruments`, eliminando la asimetría 40 vs 42.
   - Extender `IInstrumentTranspositionService` con sobrecargas o adaptador que acepte `UniversalInstrumentDefinition` directamente.

2. **Serialización JSON Completa en Dominio (`P0`):**
   - Implementar `toJson()` y `fromJson()` en `AcousticRange`, `AdsrEnvelope`, `TimbralProfile`, `VisualInterfaceProfile`, `UniversalInstrumentDefinition`, `InstrumentProfileEntity`, `PerNoteDetuningProfile`, `InstrumentCustomizationProfile`, `MusicalPhraseNote`, `MusicalPhraseEntity`, `AcousticSignature` y `SmartInstrumentMatch`.

3. **Corrección de Defectos en `InstrumentTranspositionService` (`P0`):**
   - Corregir el bug de octava en `Cb` (`dob`) restando 1 a `octavePart`, y soportar `B#`/`Si#` (+1 octava), `E#`/`Mi#` y `Fb`/`Fab`.
   - Agregar parámetro opcional `NoteNotationFormat` (`solfege` vs `scientific`) en `getSoundingNote` y `getWrittenNote` para interoperabilidad directa con agentes IA y MusicXML/MIDI.

4. **Endurecimiento DSP de `ProceduralInstrumentSynthesizer` (`P1`):**
   - Parametrizar `sampleRate` en `synthesizeNote`, `synthesizeCustomNote` y `synthesizePhrase` (eliminando el hardcode de `44100`).
   - Aplicar `customization.resonanceFactor` (e.g., filtro resonante ligero o realce de cola de release) para que el parámetro no sea muerto.
   - Añadir `synthesizeChord(...)` y campo opcional `microtoneOffsetCents` en `MusicalPhraseNote`.

5. **Expansión de `SmartInstrumentDetector` (`P2`):**
   - Derivar automáticamente perfiles de referencia desde `UniversalInstrumentDefinition.masterCatalog` (usando `timbralProfile.harmonicOvertoneAmplitudes`, `acousticRange` y `generalMidiNumber`) para cubrir los 40+ instrumentos en lugar de solo 9 perfiles estáticos.
