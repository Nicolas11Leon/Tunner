# ADR 0014: Editor de Partituras SMuFL Interactivo y Exportador Canónico Bidireccional (MusicXML & MIDI)

## Estado
Aceptado (Accepted)

---

## Contexto
Tunner poseía capacidades de lectura e importación de partituras (Universal MusicXML/MIDI Importer) y reproducción sonora procedural en memoria. No obstante, para los compositores, docentes y estudiantes, la falta de una herramienta para corregir, componer o modificar notas directamente en la aplicación obligaba a recurrir a software de escritorio externo comercial o privativo.
Asimismo, el ciclo estaba incompleto sin la exportación estándar: cualquier partitura adaptada o creada dentro de Tunner debe poder ser compartida con el ecosistema global de notación y producción de audio (MuseScore, Sibelius, Dorico, DAWs).

---

## Decisión
1. **Dominio de Edición en Pure Dart (`lib/features/score_editor/domain/`):**
   - Implementar `ScoreEditorDomain` con operaciones atómicas: `insertNote`, `deleteNoteAtTick`, `setAccidental`, `transposeMeasure`, `addMeasure`, `removeMeasure`.
   - Incorporar un gestor de transacciones con patrón Memento (`ScoreUndoRedoHistory`) que soporte hasta 50 niveles de Deshacer / Rehacer.
2. **Exportador Canónico MusicXML (`CanonicalMusicXmlExporter`):**
   - Generar documentos XML válidos bajo el esquema W3C MusicXML 3.1/4.0 partwise con tags jerárquicos `<score-partwise>`, `<part>`, `<measure>`, `<attributes>`, `<note>`, `<pitch>`, `<duration>`, `<type>`, `<time>`, `<clef>`.
3. **Exportador Canónico MIDI (`CanonicalMidiExporter`):**
   - Generar flujos binarios `Uint8List` conformes a Standard MIDI File Format 0 con chunks `MThd` y `MTrk`, codificación de cantidades de longitud variable (VLQ) para delta-times y meta-eventos canónicos.
4. **Feedback Acústico Inmediato:**
   - Cada inserción o cambio de altura tonal ejecuta `playNoteTone` en el `IAudioSynthesizerService` para confirmar auditivamente la entonación.
5. **Capa de Presentación:**
   - Crear el componente `ScoreEditorModal` con paleta interactiva de duraciones, teclado tonal cromático, selector de compás y botones de exportación directa.

---

## Consecuencias

### Positivas
- **Independencia Total:** Tunner se convierte en una suite de composición y notación 100% autónoma y offline.
- **Interoperabilidad Universal:** Los archivos generados son compatibles con todo el software de notación y DAWs del mundo.
- **Clean Architecture Pura:** Lógica de manipulación del árbol de notas y serializadores aislados en la capa de dominio sin dependencias de Flutter UI.
- **Pedagogía Activa:** El estudiante escucha lo que escribe en tiempo real.

### Desafíos y Mitigaciones
- **Validación de Compás:** Para evitar que las notas sumen más ticks de los que admite el compás, el dominio calcula la capacidad restante antes de insertar y rellena con silencios automáticamente cuando se elimina una nota.
