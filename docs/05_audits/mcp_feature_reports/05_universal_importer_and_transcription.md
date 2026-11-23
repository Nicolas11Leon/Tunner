# Auditoría Forense MCP: Universal Importer y Transcription (`05`)

- **Módulos auditados:** `lib/features/universal_importer/` (15 archivos) y `lib/features/transcription/` (3 archivos)
- **Total de archivos inspeccionados:** 18 archivos `.dart`
- **Objetivo:** Evaluar preparación para ejecución Headless Pure Dart (`dart run`) y especificar la interfaz MCP para ingesta multi-formato (MusicXML, MXL, MIDI, ABC, PDF Vector OMR, WAV), exportación canónica (MusicXML, MIDI, ABC, PDF) y transcripción de audio a partitura.

---

## 1. Inventario Archivo por Archivo

### 1.1 `lib/features/universal_importer/` (15 archivos)

| Archivo | Capa | Clases Principales | Métodos / Funciones Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- | :--- |
| `lib/features/universal_importer/domain/i_score_parser_service.dart` | Domain (Pure Dart) | `IScoreParserService`, `NoOpScoreParserService` | `canParse()`, `parseScoreData()` | `UC-014`, `UC-027` |
| `lib/features/universal_importer/domain/parsed_score_result_entity.dart` | Domain (Pure Dart) | `ParsedScoreResult` | Propiedades `package`, `format`, `totalMeasures`, `totalNotes`, `warnings`, `hasWarnings` | `UC-014`, `UC-027` |
| `lib/features/universal_importer/domain/canonical_pitch_notation_codec.dart` | Domain (Pure Dart) | `ParsedPitchNotation`, `CanonicalPitchNotationCodec` | `parse()`, `parseOrDefault()`, `noteNameToMidi()`, `midiToSolfege()`, `midiToEnglish()`, `midiToFrequency()`, `frequencyToMidi()` | `UC-129`, `UC-135`, `UC-157` |
| `lib/features/universal_importer/domain/canonical_musicxml_exporter.dart` | Domain (Pure Dart) | `CanonicalMusicXmlExporter` | `exportToMusicXml()`, `exportScore()` | `UC-018`, `UC-129`, `UC-135` |
| `lib/features/universal_importer/domain/canonical_midi_exporter.dart` | Domain (Pure Dart) | `CanonicalMidiExporter` | `exportToMidi()`, `exportScore()`, `encodeVlq()`, `noteNameToMidiPitch()` | `UC-018`, `UC-129`, `UC-135` |
| `lib/features/universal_importer/domain/canonical_abc_exporter.dart` | Domain (Pure Dart) | `CanonicalAbcExporter` | `exportToAbc()`, `exportScore()` | `UC-018`, `UC-129`, `UC-135` |
| `lib/features/universal_importer/domain/canonical_pdf_exporter.dart` | Domain (Pure Dart) | `CanonicalPdfExporter` | `exportToPdf()`, `exportScore()` (generador PDF ISO 32000-1 Pure Dart) | `UC-030`, `UC-154` |
| `lib/features/universal_importer/domain/vector_omr_engine.dart` | Domain (Pure Dart) | `OmrLine`, `OmrRect`, `StaffSystem`, `VectorOmrEngine` | `processGeometricElements()`, detección de pentagramas de 5 líneas, barras de compás, plicas y corchetes/barras | `UC-028`, `UC-158` |
| `lib/features/universal_importer/data/musicxml_score_parser.dart` | Data (Pure Dart + `xml`) | `MusicXmlScoreParser` | `canParse()`, `parseScoreData()` | `UC-014`, `UC-129`, `UC-135` |
| `lib/features/universal_importer/data/compressed_musicxml_parser.dart` | Data (Pure Dart + `archive`, `xml`) | `CompressedMusicXmlParser` | `canParse()`, `parseScoreData()`, protección anti Zip-Slip y cuota de 64 MB | `UC-027`, `UC-126`, `UC-129` |
| `lib/features/universal_importer/data/midi_score_parser.dart` | Data (Pure Dart) | `MidiScoreParser` | `canParse()`, `parseScoreData()`, decodificación binaria SMF `MThd`/`MTrk` y VLQ | `UC-014`, `UC-129`, `UC-135` |
| `lib/features/universal_importer/data/abc_score_parser.dart` | Data (Pure Dart) | `AbcScoreParser` | `canParse()`, `parseScoreData()`, soporte de 15 armaduras, cambios inline `[M:]`/`[L:]`/`[K:]` y acordes `[CEG]` | `UC-027`, `UC-129`, `UC-135` |
| `lib/features/universal_importer/data/pdf_score_parser.dart` | Data (Pure Dart + `archive`) | `PdfScoreParser` | `canParse()`, `parseScoreData()`, descompresión `FlateDecode`, intérprete de pila gráfica PDF (`q`, `Q`, `cm`, `m`, `l`, `c`, `re`, `S`, `f`, `B`) | `UC-028`, `UC-158` |
| `lib/features/universal_importer/data/universal_score_importer_service.dart` | Data (Acoplamiento transitivo Flutter) | `UniversalScoreImporterService` | `canParse()`, `parseScoreData()`, `transcribeAudioToScoreResult()` | `UC-014`, `UC-027`, `UC-028` |
| `lib/features/universal_importer/presentation/score_import_tab_view.dart` | Presentation (Flutter UI) | `ScoreImportTabView`, `_ScoreImportTabViewState` | `defaultNativeFilePicker()`, muestras embebidas MusicXML/MIDI/ABC/PDF, `build()` | `UC-014`, `UC-027`, `UC-028` |

### 1.2 `lib/features/transcription/` (3 archivos)

| Archivo | Capa | Clases Principales | Métodos / Funciones Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- | :--- |
| `lib/features/transcription/domain/audio_to_score_transcription_engine.dart` | Domain (Pure Dart) | `AudioToScoreTranscriptionEngine` | `transcribeAudioFile()`, decodificación RIFF/WAVE PCM 8/16/24/32/64-bit e IEEE Float + MPM | `UC-027`, `UC-160` |
| `lib/features/transcription/domain/live_transcription_engine.dart` | Domain (Pure Dart) | `RhythmicQuantizer`, `TranscriptionCandidate`, `LiveTranscriptionEngine` | `RhythmicQuantizer.quantizeDuration()`, `start()`, `processPitchFrame()`, `stop()` | `UC-019`, `UC-160` |
| `lib/features/transcription/domain/polyphonic_transcription_engine.dart` | Domain (Pure Dart) | `PolyphonicChordCandidate`, `PolyphonicTranscriptionEngine` | `start()`, `processPolyphonicFrame()`, `stop()` | `UC-063`, `UC-160` |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Acoplamientos con `package:flutter/` y `dart:ui`

| Archivo | Imports Bloqueantes | Impacto en CLI Pure Dart | Severidad |
| :--- | :--- | :--- | :--- |
| `universal_score_importer_service.dart` | **Transitivo crítico:** importa `../../../core/logging/infrastructure/studio_debug_logger.dart`, el cual importa `package:flutter/foundation.dart` (línea 1). | **Bloquea compilación en `dart run`** para el servicio orquestador principal de importación. | Crítica (bloqueador directo de CLI) |
| `score_import_tab_view.dart` | `package:flutter/material.dart`, `StudioDebugLogger`, `TunerViewModel` | Exclusivo de UI; no requerido en MCP. | Ninguna |
| Resto de 16 archivos (parsers, exportadores, Vector OMR, codec, motores de transcripción) | Ninguno (solo `dart:*`, `package:xml`, `package:archive`) | **100% compatibles con ejecución Headless Pure Dart**, incluyendo exportación PDF vectorial y Vector OMR sin UI. | Ninguna |

### 2.2 Brechas Funcionales Detectadas

1. **Exportadores Canónicos con Pérdida de Metadatos Musicales:**
   - **`CanonicalMusicXmlExporter`:**
     - Emite `<fifths>0</fifths>` fijo (ignora `MeasureEntity.keySignatureFifths`).
     - Emite `<clef><sign>G</sign><line>2</line></clef>` y `<voice>1</voice>` fijos en una sola `<part id="P1">` (no soporta Grand Staff ni múltiples partes).
     - No serializa `<tie type="start/stop"/>` aunque `HierarchicalNote.isTied` existe.
   - **`CanonicalMidiExporter`:**
     - Solo genera SMF Format 0 (una sola pista, canal 0) con `programNumber = 73` (Flauta) fijo al usar `exportToMidi(SongPackage)`.
     - Solo escribe el meta-evento `Time Signature` en el tick 0 (ignora cambios de compás en compases intermedios).
     - Velocidad fija en `96` e ignora `isTied` (genera `NoteOff` + `NoteOn` en vez de fusionar duración).
   - **`CanonicalAbcExporter`:**
     - Escribe `K: C` fijo (ignora `keySignatureFifths`), no emite ligaduras `-` ni voces `V:1`/`V:2`.
   - **`CanonicalPdfExporter`:**
     - **Defecto visual crítico en acordes:** `_renderMeasureNotes()` calcula la posición X por índice de lista (`i * slotWidth`) en lugar de por `note.startTick`. Las notas simultáneas de un acorde se dibujan desplazadas horizontalmente una al lado de la otra en vez de apiladas verticalmente.
     - No dibuja armaduras de clave (`keySignatureFifths`), puntillos de aumentación (ticks 12, 6, 3), barras de unión (`beams`), ligaduras (`ties`), cambios de métrica tras el primer sistema ni Grand Staff.
     - `_sanitizePdfText()` elimina silenciosamente todo carácter fuera de ASCII `0x20..0x7E` (tildes y eñes en títulos en español desaparecen).
2. **Parsers de Ingesta con Pérdida de Información Estructural:**
   - **`MusicXmlScoreParser`:** Solo procesa `parts.first`. Ignora múltiples partes, elementos `<backup>`/`<forward>`, `<voice>`, `<staff>`, `<key><fifths>`, `<clef>` y `<tie>`. Normaliza todas las alteraciones a sostenidos en `_parsePitch()`.
   - **`MidiScoreParser`:** Colapsa todas las pistas `MTrk` en una lista plana `rawNotes` sin conservar separación de voces/stems en el `HierarchicalScore`. El mapa `activeNotesStart` está indexado únicamente por `pitch` (sin canal MIDI), provocando colisiones si dos canales tocan el mismo pitch simultáneamente. Solo retiene el último tempo y última métrica leídos (sin cambios por compás) e ignora el meta-evento de armadura (`0xFF 0x59`).
   - **`AbcScoreParser`:** No almacena `keySignatureFifths` en `MeasureEntity` (absorbe las alteraciones directamente en cada nota) y descarta directivas multi-voz `V:`.
   - **`PdfScoreParser` + `VectorOmrEngine`:**
     - Ejecuta 100% headless sin UI, pero solo sobre PDFs vectoriales (no soporta PDFs escaneados/rasterizados).
     - Asume siempre Clave de Sol (`e4AbsStep = 30`), ignora alteraciones accidentales, armaduras, métricas impresas, puntillos y agrupa cabezas en el mismo eje X secuencialmente en lugar de detectar acordes simultáneos.
3. **Motor de Transcripción de Audio (`transcription/`):**
   - **`AudioToScoreTranscriptionEngine`:**
     - Solo soporta transcripción monofónica (MPM); no existe pipeline offline polifónico para archivos WAV de piano o guitarra.
     - No realiza estimación automática de BPM/tempo ni detección de compás; si se invoca desde `UniversalScoreImporterService.parseScoreData()`, fija `bpm = 120` y `4/4` sin permitir parámetros opcionales en la interfaz `IScoreParserService`.
     - No soporta MP3/OGG/FLAC en Pure Dart (solo RIFF/WAVE y PCM crudo).
     - Cuando una nota se divide al cruzar una barra de compás, no marca `isTied: true`.
   - **`LiveTranscriptionEngine` y `PolyphonicTranscriptionEngine`:**
     - Son máquinas de estado Pure Dart orientadas a frames. Para MCP headless pueden ejecutarse sobre arreglos de frames o sesiones de streaming, pero `RhythmicQuantizer.quantizeDuration()` está acotado a `16` ticks y diseñado para compases simples `4/4`.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON |
| :--- | :--- | :--- |
| `tunner://importer/formats` | Lista de formatos de importación y exportación soportados por Tunner en modo headless y sus capacidades reales. | `{ "import": ["musicxml", "xml", "mxl", "mid", "midi", "abc", "pdf_vector_omr", "wav_monophonic"], "export": ["musicxml", "midi_smf0", "abc", "pdf_vector"] }` |
| `tunner://importer/last-result` | Metadatos y advertencias (`warnings`) de la última importación o transcripción ejecutada en la sesión. | `{ "format": "MusicXML", "title": "str", "totalMeasures": 16, "totalNotes": 64, "warnings": [] }` |
| `tunner://pitch/codec/{noteOrMidi}` | Conversión canónica de una nota (`Sib4`, `Bb4`), número MIDI (`70`) o frecuencia (`466.16`) mediante `CanonicalPitchNotationCodec`. | `{ "step": "B", "solfegeBase": "Si", "alter": -1, "octave": 4, "midiNumber": 70, "solfegeName": "Sib4", "englishName": "Bb4", "frequencyHzA440": 466.16376 }` |

### 3.2 Tools (`tunner_*`)

| Tool Name | Parámetros (JSON Schema Resumido) | Salida | Mapeo Exacto en Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_import_score` | `{ filePath?: string, contentBase64?: string, textContent?: string, fileName: string, bpm?: int, timeSignature?: string, loadAsActive?: bool }` | `{ format, title, composer, totalMeasures, totalNotes, warnings[], score }` | `UniversalScoreImporterService.parseScoreData()` (`universal_score_importer_service.dart`) |
| `tunner_import_pdf_omr` | `{ filePath?: string, contentBase64?: string, fileName?: string, bpm?: int, timeSignature?: string }` | `{ format: "PDF (Vector OMR)", totalMeasures, totalNotes, warnings[], score }` | `PdfScoreParser.parseScoreData()` + `VectorOmrEngine.processGeometricElements()` |
| `tunner_export_musicxml` | `{ outputPath?: string, title?: string, composer?: string }` | `{ xml: string, outputPath?, bytesLength }` | `CanonicalMusicXmlExporter.exportToMusicXml()` (`canonical_musicxml_exporter.dart`) |
| `tunner_export_midi` | `{ outputPath?: string, programNumber?: int (0..127), bpm?: int }` | `{ base64?: string, outputPath?, bytesLength }` | `CanonicalMidiExporter.exportScore()` (`canonical_midi_exporter.dart`) |
| `tunner_export_abc` | `{ outputPath?: string, title?: string, composer?: string }` | `{ abc: string, outputPath?, bytesLength }` | `CanonicalAbcExporter.exportToAbc()` (`canonical_abc_exporter.dart`) |
| `tunner_export_pdf` | `{ outputPath?: string, title?: string, composer?: string }` | `{ base64?: string, outputPath?, bytesLength, pagesEstimate }` | `CanonicalPdfExporter.exportToPdf()` (`canonical_pdf_exporter.dart`) |
| `tunner_transcribe_wav` | `{ filePath?: string, audioBase64?: string, title?: string, bpm?: int, timeSignature?: string, minClarity?: number, silenceRms?: number }` | `{ totalMeasures, totalNotes, bpm, score, warnings[] }` | `AudioToScoreTranscriptionEngine.transcribeAudioFile()` (`audio_to_score_transcription_engine.dart`) |
| `tunner_transcribe_frames` | `{ mode: "monophonic" \| "polyphonic", bpm: int, timeSignature?: string, frames: [{ noteName?: string, noteNames?: string[], frequencyHz?: number, clarity?: number, energyRms?: number, frameDurationMs: number }] }` | `{ totalMeasures, totalNotes, score }` | `LiveTranscriptionEngine` / `PolyphonicTranscriptionEngine` (`live_transcription_engine.dart`, `polyphonic_transcription_engine.dart`) |
| `tunner_pitch_convert` | `{ noteName?: string, midiNumber?: int, frequencyHz?: number, a4Ref?: number, preferFlats?: bool }` | `{ solfegeName, englishName, midiNumber, frequencyHz, step, alter, octave }` | `CanonicalPitchNotationCodec` (`canonical_pitch_notation_codec.dart`) |

### 3.3 Prompts

1. **`convert_score_pipeline`**:
   - **Propósito:** Convertir cualquier partitura local (`.mxl`, `.musicxml`, `.mid`, `.abc`, `.pdf` vectorial o `.wav`) a otro formato de salida (ej. `PDF -> MusicXML + MIDI`) verificando integridad métrica en medio.
   - **Flujo guiado:** `tunner_import_score` -> revisar `warnings` -> `tunner_score_validate` -> corregir si aplica -> `tunner_export_musicxml` / `tunner_export_midi` / `tunner_export_pdf`.
2. **`transcribe_recording_and_publish`**:
   - **Propósito:** Transcribir una grabación `.wav` a partitura, limpiar transitorios o notas erróneas, transponer a la tonalidad deseada y generar una hoja imprimible en PDF y un archivo MIDI de referencia.
   - **Flujo guiado:** `tunner_transcribe_wav` -> inspeccionar `tunner://score/active` -> editar con `tunner_score_insert_note` / `tunner_score_delete_note` -> `tunner_export_pdf` y `tunner_export_midi`.

---

## 4. Plan de Ajustes Técnicos Previos

1. **Inyectar `IStudioLogger` en `UniversalScoreImporterService` (Prioridad Crítica):**
   - Eliminar el import directo de `lib/core/logging/infrastructure/studio_debug_logger.dart` en `universal_score_importer_service.dart`.
   - Aceptar `final IStudioLogger _logger;` en el constructor con valor por defecto `const NoOpStudioLogger()` (Pure Dart), desbloqueando la compilación CLI de todo el subsistema de importación.
2. **Corregir Renderizado de Acordes, Armaduras y Puntillos en `CanonicalPdfExporter` (Prioridad Alta):**
   - Agrupar notas por `startTick` en `_renderMeasureNotes()` para posicionar acordes simultáneos sobre la misma coordenada X y espaciar proporcionalmente al tiempo métrico.
   - Añadir renderizado de armaduras (`keySignatureFifths`), puntillos de aumentación (ticks 12, 6, 3), cambios de compás inter-sistema y soporte WinAnsiEncoding/transliteración segura en `_sanitizePdfText()` para no perder tildes ni eñes.
3. **Preservar Armaduras, Claves, Ligaduras y Múltiples Pistas en Parsers y Exportadores (Prioridad Alta):**
   - **`CanonicalMusicXmlExporter` y `CanonicalAbcExporter`:** Emitir `measure.keySignatureFifths` (`<fifths>` y cabecera `K:`), clave real, ligaduras (`<tie>` / `-`) y voces múltiples.
   - **`CanonicalMidiExporter`:** Soportar SMF Format 1 (multi-pista/multi-canal), propagar `programNumber` desde el instrumento, emitir cambios de compás inter-medida y fusionar notas ligadas (`isTied`).
   - **`MusicXmlScoreParser` y `MidiScoreParser`:** Capturar `<key><fifths>`, meta-evento MIDI `0xFF 0x59`, cambios de compás por medida, desambiguación por `(channel, pitch)` en MIDI y preservación de múltiples partes/voces.
4. **Mejorar `VectorOmrEngine` y `AudioToScoreTranscriptionEngine` (Prioridad Media):**
   - En `VectorOmrEngine`: agrupar cabezas de nota con proximidad horizontal (`dx <= staffSpace * 0.6`) en el mismo `startTick` para reconocer acordes polifónicos en PDFs vectoriales.
   - En `AudioToScoreTranscriptionEngine`: marcar `isTied: true` al dividir notas a través de barras de compás y añadir opción de estimación automática de BPM cuando el cliente MCP no especifique tempo.
   - Extender `IScoreParserService` o añadir un parámetro opcional `ScoreImportOptions` (BPM, métrica, pista objetivo) para evitar valores fijos `120 BPM` / `4/4` en transcripción WAV.
