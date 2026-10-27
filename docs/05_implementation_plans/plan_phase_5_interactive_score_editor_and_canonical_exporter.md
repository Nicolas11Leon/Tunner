# Plan de Implementación: Interactive Score Editor & Canonical MusicXML/MIDI Exporter

Este documento define el plan estructurado de ingeniería para la implementación del editor de partituras interactivo y los serializadores de exportación canónica en **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE5-SCORE-EDITOR-2026-001`
- **Título de la Implementación:** Editor Interactivo de Partituras SMuFL y Exportador Canónico Bidireccional (MusicXML y MIDI)
- **Fase del Proyecto:** Fase 5 (Vanguardia Acústica y Aprendizaje Musical)
- **Estado:** Aprobado
- **ADR Relacionado:** [docs/04_adrs/0014_interactive_score_editor_and_canonical_musicxml_midi_exporter.md](../04_adrs/0014_interactive_score_editor_and_canonical_musicxml_midi_exporter.md)
- **Documento Funcional Base:** [docs/01_product_vision/doc_interactive_score_editor_and_musicxml_midi_exporter.md](../01_product_vision/doc_interactive_score_editor_and_musicxml_midi_exporter.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Proveer a Tunner de un editor de partituras interactivo con soporte de historial Memento (Undo/Redo), audición instantánea de notas editadas y exportación canónica a formatos universales MusicXML 3.1/4.0 y Standard MIDI File Format 0.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Dominio de edición `ScoreEditorOperations` y `ScoreUndoRedoHistory` en `lib/features/score_editor/domain/`.
  - Serializador `CanonicalMusicXmlExporter` en `lib/features/universal_importer/domain/canonical_musicxml_exporter.dart`.
  - Serializador `CanonicalMidiExporter` en `lib/features/universal_importer/domain/canonical_midi_exporter.dart`.
  - Integración en `TunerViewModel`: métodos de edición de partituras, audición al editar, historial Undo/Redo y funciones de exportación.
  - Componente de interfaz de usuario `ScoreEditorModal` con teclado de notas, duraciones, alteraciones y exportación.
  - Suite exhaustiva de pruebas unitarias y de widgets.
- **Excluido (Out-of-Scope):**
  - Edición polifónica de acordes de 10 voces en un solo pentagrama (se mantiene monofonía de instrumento melódico).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Pure Dart)
- [x] Documentación técnica, Caso de Uso y ADR redactados.
- [ ] Implementar `CanonicalMusicXmlExporter`:
  - Mapeo de notas a Step (A-G), Octave (0-8), Alter (-1, 0, 1).
  - Mapeo de duraciones a `<type>` (whole, half, quarter, eighth, 16th) y `<duration>`.
  - Generación de estructura partwise conforme al estándar W3C.
- [ ] Implementar `CanonicalMidiExporter`:
  - Codificación VLQ (Variable Length Quantity).
  - Generación de chunk `MThd` y chunk `MTrk`.
  - Pares NoteOn y NoteOff con cálculo de delta-times.
- [ ] Implementar `ScoreEditorOperations` e historial Undo/Redo en Pure Dart.
- [ ] Pruebas unitarias en `test/features/universal_importer/canonical_musicxml_exporter_test.dart` y `test/features/universal_importer/canonical_midi_exporter_test.dart`.

### Paso 2: Integración en TunerViewModel
- [ ] Conectar historial de edición con `activePackage`.
- [ ] Implementar `insertNoteInActiveScore(...)`, `deleteNoteInActiveScore(...)`, `undoScoreEdit()`, `redoScoreEdit()`.
- [ ] Disparar `_audioSynthesizer.playNoteTone` en cada inserción para feedback acústico.
- [ ] Exponer `exportActiveScoreToMusicXml()` y `exportActiveScoreToMidi()`.

### Paso 3: Capa de Presentación (UI)
- [ ] Crear `ScoreEditorModal` con:
  - Selector de compás activo.
  - Selector de figura rítmica (Redonda, Blanca, Negra, Corchea, Semicorchea, Silencio).
  - Selector de nota cromática con alteraciones ($\sharp$, $\flat$, $\natural$).
  - Botones de Deshacer, Rehacer y Guardar/Exportar.
- [ ] Añadir botón de acceso al editor en la barra de herramientas o vista de partitura.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Pruebas de integración del ViewModel.
- [ ] Pruebas de widgets de `ScoreEditorModal`.
- [ ] `flutter analyze` (0 errores).
- [ ] `flutter test` (100% pass).

---

## 3. Criterios de Aceptación (Definition of Done)
1. Clean Architecture estricta en las capas de Dominio.
2. MusicXML exportado legible y válido por esquemas estándar.
3. Archivos MIDI reproducibles con tempo y compás correctos.
4. Historial Undo/Redo funciona bidireccionalmente sin fugas de memoria.
5. 100% de pruebas pasando sin advertencias.
