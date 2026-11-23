# Auditoría Forense MCP: Sheet Music y Score Editor (`04`)

- **Módulos auditados:** `lib/features/sheet_music/` (4 archivos) y `lib/features/score_editor/` (3 archivos)
- **Total de archivos inspeccionados:** 7 archivos `.dart`
- **Objetivo:** Evaluar preparación para ejecución Headless Pure Dart (`dart run`) y especificar la interfaz canónica de exposición mediante Model Context Protocol (MCP) para composición, edición, validación y reproducción de partituras asistidas por agentes IA.

---

## 1. Inventario Archivo por Archivo

| Archivo | Capa | Clases Principales | Métodos / Funciones Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- | :--- |
| `lib/features/sheet_music/domain/score_tree.dart` | Domain (Pure Dart) | `TimeSignature`, `HierarchicalNote`, `MeasureEntity`, `HierarchicalScore` | `TimeSignature.totalTicks`, `HierarchicalNote.note()`, `HierarchicalNote.rest()`, `MeasureEntity.isValidMeasure`, `HierarchicalScore.isValidScore`, `toMap()` / `fromMap()`, `getCanonicalStudies()` | `UC-006`, `UC-018`, `UC-105`, `UC-155` |
| `lib/features/sheet_music/domain/score_playback_coordinator.dart` | Domain (Pure Dart) | `ScorePlaybackCoordinator` | `noteNameToMidi()`, `previewNote()`, `startPlayback()`, `pausePlayback()`, `stopPlayback()`, `dispose()` | `UC-003`, `UC-017`, `UC-105`, `UC-156` |
| `lib/features/sheet_music/presentation/real_sheet_music_painter.dart` | Presentation (Flutter) | `PlayedRecord`, `RealSheetMusicPainter` | `getNoteStep()`, `findNoteIndexAtOffset()`, `paint()`, `shouldRepaint()` | `UC-003`, `UC-006`, `UC-139`, `UC-155` |
| `lib/features/sheet_music/presentation/smufl/smufl_glyph_path_engine.dart` | Presentation (Flutter) | `SmuflGlyphPathEngine` | `getStemUpAnchor()`, `getStemDownAnchor()`, `drawNotehead()`, `drawAugmentationDot()`, `drawStem()`, `drawFlag()`, `drawGClef()`, `drawFClef()`, `drawCClef()`, `drawRest()`, `drawAccidental()`, `drawLedgerLines()` | `UC-006`, `UC-105`, `UC-154` |
| `lib/features/score_editor/domain/score_editor_domain.dart` | Domain (Pure Dart) | `ScoreEditorOperations`, `ScoreUndoRedoHistory` | `insertOrUpdateNote()`, `insertChordNotes()`, `deleteNoteAt()`, `addMeasure()`, `removeMeasure()`, `transposeScore()`, `recordState()`, `undo()`, `redo()` | `UC-018`, `UC-060`, `UC-124`, `UC-157` |
| `lib/features/score_editor/presentation/score_editor_controller.dart` | Presentation (Flutter `foundation`) | `ScoreEditorController` | `insertOrUpdateScoreNote()`, `insertScoreChordNotes()`, `deleteScoreNote()`, `undoScoreEdit()`, `redoScoreEdit()`, `addScoreMeasure()`, `removeScoreMeasure()`, `transposeActiveScore()`, `transposeActiveScoreForInstrument()`, `exportActiveScoreToMusicXml/Midi/Abc/Pdf()`, `buildPedagogicalSessionData()`, `exportPedagogicalReportPdf()`, `transcribeAudioFileToScore()`, `toggleLiveTranscription()`, `togglePolyphonicLiveTranscription()`, `generateExercise()`, `exportStemsAndMidi()` | `UC-018`, `UC-124`, `UC-129`, `UC-157` |
| `lib/features/score_editor/presentation/score_editor_modal.dart` | Presentation (Flutter UI) | `ScoreEditorModal`, `_ScoreEditorModalState` | `show()`, `_insertCurrentNote()`, `_exportScoreToFile()`, `build()` | `UC-018`, `UC-139`, `UC-157` |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Acoplamientos con `package:flutter/` y `dart:ui`

| Archivo | Imports Bloqueantes | Impacto en CLI Pure Dart | Severidad |
| :--- | :--- | :--- | :--- |
| `score_tree.dart` | Ninguno | 100% compatible Headless Pure Dart. | Ninguna |
| `score_playback_coordinator.dart` | Ninguno (dependencias transitivas `PolyphonicVoicePool` y `NoteEntity` verificadas Pure Dart) | 100% compatible Headless Pure Dart. | Ninguna |
| `score_editor_domain.dart` | Ninguno | 100% compatible Headless Pure Dart. | Ninguna |
| `score_editor_controller.dart` | `package:flutter/foundation.dart` (usado unicamente para `VoidCallback` y `Uint8List`) | Bloquea compilación en `dart run` de forma innecesaria. Todas sus dependencias transitivas (`StemAudioSynthesizer`, `PedagogicalReportPdfGenerator`, `AlgorithmicExerciseGenerator`, exportadores y motores de transcripción) son Pure Dart. | Alta (remediación trivial) |
| `real_sheet_music_painter.dart` | `package:flutter/material.dart`, `TunnerThemePalette` | Bloqueado en CLI. Sin embargo, contiene lógica pura (`getNoteStep`, cálculo de `beamedGroups`) embebida en un `CustomPainter`. | Media (solo UI; lógica de layout debe extraerse si se requiere SVG headless) |
| `smufl_glyph_path_engine.dart` | `package:flutter/material.dart` (`Canvas`, `Path`, `Paint`, `Offset`, `Rect`, `Color`) | Bloqueado en CLI. Para renderizado headless vectorial se dispone de `CanonicalPdfExporter` (Pure Dart), pero no existe exportación SVG headless equivalente. | Baja (mitigado por PDF) |
| `score_editor_modal.dart` | `package:flutter/material.dart`, `package:flutter/services.dart`, `package:provider/provider.dart`, `TunerViewModel` | Exclusivo de interfaz gráfica; no se expone en el servidor MCP. | Ninguna |

### 2.2 Brechas Funcionales y Limitaciones Arquitectónicas

1. **Ausencia de Polifonía Independiente por Voces y Multi-Pentagrama (Grand Staff / Multi-Part):**
   - `HierarchicalScore` modela un único pentagrama lineal (`List<MeasureEntity>`). No soporta múltiples partes (`parts`) ni múltiples pentagramas por instrumento (ej. Piano: mano derecha en clave de Sol + mano izquierda en clave de Fa).
   - `HierarchicalNote` carece de campos `voice` (int) y `staff` (int).
   - **Bloqueo crítico en edición:** `ScoreEditorOperations._splitOverlappingNotes()` recorta y divide cualquier nota preexistente que se solape temporalmente con `[startTick, endTick)`. En consecuencia, es imposible insertar una blanca en el bajo (ticks 0..8) y simultáneamente negras melódicas (ticks 0..4, 4..8) en el mismo compás sin destruir la nota larga.
2. **Resolución Temporal Rígida (16 sub-ticks por redonda) sin Soporte de Tresillos (Tuplets) ni Fusas:**
   - `TimeSignature.totalTicks` usa división entera `numerator * (16 ~/ denominator)`. Para denominadores mayores a 16 (ej. `32`) retorna `0`.
   - No es posible representar tresillos (triplets), seisillos ni figuras de 1/32 porque la rejilla fija es `1/16` (4 ticks por negra).
3. **Atributos Musicales Faltantes en `HierarchicalNote` y `MeasureEntity`:**
   - Sin `velocity` ni dinámicas (`pp`, `p`, `mf`, `f`, `ff`, crescendo/diminuendo).
   - Sin articulaciones (`staccato`, `tenuto`, `accent`, `marcato`, `fermata`) ni ligaduras de expresión (`slur`).
   - Sin clave (`clef`) por compás o pentagrama dentro del modelo de dominio (la clave vive fuera del `HierarchicalScore`, en `InstrumentProfileEntity`).
   - Sin cifrado de acordes (`chordSymbol`), letra (`lyric`) ni cambios de tempo inter-compás (`tempoChange`).
   - `isTied` es un booleano sin distinción de inicio/fin ni continuidad inter-compás, y es ignorado por `ScorePlaybackCoordinator` (despacha `noteOff` y re-ataca `noteOn`).
4. **Mutaciones Faltantes en `ScoreEditorOperations`:**
   - No existen operaciones para modificar `timeSignature` de un compás, `keySignatureFifths`, `baseBpm`, `title`, ni `isTied`.
   - No existe inserción declarativa por lotes (`setMeasureNotes` o `composeMeasures`) para que un agente IA escriba múltiples compases en una sola llamada atómica sin consumir decenas de turnos RPC.
   - `deleteNoteAt` convierte todas las notas en ese `startTick` en silencios redundantes (si había un acorde de 3 notas, genera 3 silencios superpuestos en el mismo tick) y no permite eliminar una única nota específica dentro de un acorde.
   - `transposeScore` transpone convirtiendo a frecuencia (`frequencyForNote -> pow(2, n/12) -> fromFrequency`), perdiendo ortografía enarmónica y desalineándose de la armadura (`keySignatureFifths`).
5. **Agrupación de Barras (Beaming) y Tempo en Compases Compuestos:**
   - En `real_sheet_music_painter.dart` (línea 324), el cálculo de barras agrupa por `startTick ~/ 4` (pulsos de negra), lo cual es incorrecto para compases compuestos (`6/8`, `9/8`, `12/8`) donde los grupos deben ser de 6 sub-ticks (negra con puntillo).
   - En `ScorePlaybackCoordinator`, la duración de tick asume siempre `15.0 / _bpm` (BPM referenciado a negra).
6. **Cohesión de `ScoreEditorController`:**
   - `ScoreEditorController` actúa como fachada mixta acoplando edición de partituras, exportación, reportes pedagógicos PDF, transcripción en vivo, generación de ejercicios y exportación de stems. Para el servidor MCP conviene consumir los servicios de dominio puros (`ScoreEditorOperations`, `ScoreUndoRedoHistory`) y un `ScoreSessionService` headless dedicado.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON |
| :--- | :--- | :--- |
| `tunner://score/active` | Estado completo de la partitura activa en sesión (`HierarchicalScore` + metadatos de `SongPackage`). | `{ "id": "str", "title": "str", "composer": "str", "bpm": 120, "totalMeasures": 4, "isValid": true, "measures": [{ "index": 0, "timeSignature": "3/4", "keySignatureFifths": 0, "notes": [{ "startTick": 0, "durationTicks": 4, "noteName": "Do4", "isRest": false, "isTied": false, "voice": 1, "staff": 1 }] }] }` |
| `tunner://score/active/measure/{index}` | Vista enfocada de un compás específico, sus notas ordenadas y resultado de validación métrica. | `{ "index": 0, "timeSignature": "4/4", "totalTicks": 16, "keySignatureFifths": 1, "isValidMeasure": true, "occupiedTicks": 16, "notes": [...] }` |
| `tunner://score/studies/canonical` | Catálogo de estudios pedagógicos canónicos definidos en `HierarchicalScore.getCanonicalStudies()`. | `{ "studies": [{ "title": "str", "baseBpm": 75, "totalMeasures": 2, "timeSignature": "4/4" }] }` |
| `tunner://score/history/status` | Estado actual de las pilas Memento Undo/Redo de la sesión activa. | `{ "canUndo": true, "canRedo": false, "undoCount": 3, "redoCount": 0 }` |
| `tunner://score/time-signatures` | Métricas estándar soportadas y su equivalencia en sub-ticks de resolución base. | `{ "signatures": [{ "label": "4/4", "numerator": 4, "denominator": 4, "totalTicks": 16 }, { "label": "3/4", "numerator": 3, "denominator": 4, "totalTicks": 12 }, ...] }` |

### 3.2 Tools (`tunner_*`)

| Tool Name | Parámetros (JSON Schema Resumido) | Salida | Mapeo Exacto en Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_score_create` | `{ title: string, composer?: string, bpm?: int (20..300), timeSignature?: string ("4/4"), keySignatureFifths?: int (-7..7), measureCount?: int (1..128) }` | `{ scoreId, title, totalMeasures, isValid }` | `HierarchicalScore` + `MeasureEntity` + `SongPackage` (`score_tree.dart`, `song_package_entity.dart`) |
| `tunner_score_insert_note` | `{ measureIndex: int, startTick: int, durationTicks: int, noteName: string, voice?: int, staff?: int, isTied?: bool }` | `{ measureIndex, isValidMeasure, notesCount }` | `ScoreEditorOperations.insertOrUpdateNote()` (`score_editor_domain.dart`) |
| `tunner_score_insert_chord` | `{ measureIndex: int, startTick: int, durationTicks: int, noteNames: string[], voice?: int, staff?: int }` | `{ measureIndex, insertedCount, isValidMeasure }` | `ScoreEditorOperations.insertChordNotes()` (`score_editor_domain.dart`) |
| `tunner_score_compose_measures` | `{ measures: [{ index?: int, timeSignature?: string, keySignatureFifths?: int, events: [{ startTick: int, durationTicks: int, notes: string[], voice?: int, staff?: int, isTied?: bool }] }] }` | `{ totalMeasures, totalNotes, isValidScore, validationErrors[] }` | Operación por lotes a construir sobre `ScoreEditorOperations` + `MeasureEntity` |
| `tunner_score_delete_note` | `{ measureIndex: int, startTick: int, noteName?: string, voice?: int }` | `{ measureIndex, remainingNotes, isValidMeasure }` | `ScoreEditorOperations.deleteNoteAt()` (`score_editor_domain.dart`) |
| `tunner_score_add_measure` | `{ timeSignature?: string, keySignatureFifths?: int, insertAtIndex?: int }` | `{ totalMeasures, addedIndex }` | `ScoreEditorOperations.addMeasure()` (`score_editor_domain.dart`) |
| `tunner_score_remove_measure` | `{ measureIndex: int }` | `{ totalMeasures, removedIndex }` | `ScoreEditorOperations.removeMeasure()` (`score_editor_domain.dart`) |
| `tunner_score_set_metadata` | `{ title?: string, composer?: string, bpm?: int, keySignatureFifths?: int, measureIndex?: int, timeSignature?: string }` | `{ title, bpm, timeSignature, keySignatureFifths }` | Nuevo método requerido en `ScoreEditorOperations` |
| `tunner_score_transpose` | `{ semitones: int (-24..24), preferFlats?: bool }` | `{ semitones, totalNotesTransposed }` | `ScoreEditorOperations.transposeScore()` (`score_editor_domain.dart`) |
| `tunner_score_validate` | `{ measureIndex?: int }` | `{ isValidScore, invalidMeasures: [{ index, expectedTicks, occupiedTicks, reason }] }` | `HierarchicalScore.isValidScore` y `MeasureEntity.isValidMeasure` (`score_tree.dart`) |
| `tunner_score_undo` | `{}` | `{ applied: bool, undoCount, redoCount }` | `ScoreUndoRedoHistory.undo()` (`score_editor_domain.dart`) |
| `tunner_score_redo` | `{}` | `{ applied: bool, undoCount, redoCount }` | `ScoreUndoRedoHistory.redo()` (`score_editor_domain.dart`) |
| `tunner_score_preview_note` | `{ noteName: string, durationSeconds?: number, velocity?: number }` | `{ midiNumber, frequencyHz, played: bool }` | `ScorePlaybackCoordinator.previewNote()` y `noteNameToMidi()` (`score_playback_coordinator.dart`) |

### 3.3 Prompts

1. **`compose_piano_waltz_3_4`**:
   - **Propósito:** Guiar a un agente IA para componer una pieza de piano en 3/4 con melodía en mano derecha (voz 1, clave de Sol) y acompañamiento de vals en mano izquierda (voz 2, clave de Fa).
   - **Flujo guiado:**
     1. Invocar `tunner_score_create` con `timeSignature: "3/4"` (12 sub-ticks por compás), `bpm: 108`, `keySignatureFifths` acorde a la tonalidad solicitada.
     2. Construir bloques de 4 a 8 compases usando `tunner_score_compose_measures`, asignando `staff: 1, voice: 1` para la línea melódica y `staff: 2, voice: 2` para el patrón bajo-acorde-acorde (ticks 0, 4, 8).
     3. Invocar `tunner_score_validate` para confirmar cobertura métrica exacta de 12/12 ticks por voz en cada compás.
     4. Exportar el resultado a MusicXML/MIDI/PDF mediante las herramientas del módulo `universal_importer`.
2. **`harmonize_and_transpose_study`**:
   - **Propósito:** Leer `tunner://score/active`, analizar la línea melódica, añadir voces armónicas en acordes mediante `tunner_score_insert_chord` y transponer a la tesitura de un instrumento objetivo con `tunner_score_transpose`.
3. **`fix_metric_errors`**:
   - **Propósito:** Ejecutar `tunner_score_validate`, inspeccionar compases inválidos vía `tunner://score/active/measure/{index}` y corregir duraciones o rellenar silencios hasta lograr `isValidScore == true`.

---

## 4. Plan de Ajustes Técnicos Previos

1. **Desacoplar `ScoreEditorController` de Flutter (Prioridad Crítica):**
   - Eliminar `import 'package:flutter/foundation.dart';` en `lib/features/score_editor/presentation/score_editor_controller.dart`.
   - Reemplazar `Uint8List` importando `dart:typed_data` y reemplazar `VoidCallback` por `typedef StudioNotifyCallback = void Function();` en dominio puro.
2. **Extender el Modelo `score_tree.dart` para Polifonía y Multi-Pentagrama (Prioridad Crítica):**
   - Agregar `final int voice` (default `1`), `final int staff` (default `1`), `final int velocity` (default `96`) y `final String? articulation` a `HierarchicalNote`, preservando compatibilidad retroactiva en `toMap()` / `fromMap()`.
   - Agregar `final String clef` (ej. `'treble'`, `'bass'`, `'alto'`) opcional a `MeasureEntity` o introducir una estructura `StaffPartEntity` en `HierarchicalScore` para soportar Grand Staff (Piano) y ensambles.
   - Evaluar migración de resolución de `16` sub-ticks a `48` sub-ticks por redonda (12 por negra) para soportar simultáneamente semicorcheas (3 ticks) y tresillos de corchea (4 ticks) sin perder determinismo entero.
3. **Completar Operaciones de Edición en `ScoreEditorOperations` (Prioridad Alta):**
   - Hacer que `_splitOverlappingNotes()` filtre solapamientos únicamente dentro de la misma `(voice, staff)`, permitiendo escritura polifónica real sin destruir notas largas de otras voces.
   - Corregir `deleteNoteAt()` para aceptar `noteName` y `voice` opcionales y consolidar silencios sin duplicar objetos `HierarchicalNote.rest` en el mismo tick.
   - Implementar `setMeasureMetadata()` (métrica, armadura `keySignatureFifths`, clave), `setScoreMetadata()` (título, compositor, BPM), `setTie()` y `composeMeasures()` (escritura declarativa por lotes).
   - Reemplazar la transposición basada en frecuencia en `_transposeNoteName()` por aritmética diatónica/MIDI vía `CanonicalPitchNotationCodec` respetando `preferFlats` según la armadura.
4. **Respetar Ligaduras (`isTied`) y Compases Compuestos en Reproducción y Layout (Prioridad Media):**
   - Actualizar `ScorePlaybackCoordinator` para encadenar notas ligadas (`isTied == true`) sin disparar `noteOff`/`noteOn` redundantes en la frontera de sub-tick o compás.
   - Extraer `getNoteStep()` y la lógica de agrupación de barras (`beamedGroups`, corrigiendo el divisor a 6 ticks para `6/8`, `9/8`, `12/8`) fuera de `RealSheetMusicPainter` hacia un helper Pure Dart en `lib/features/sheet_music/domain/`.
