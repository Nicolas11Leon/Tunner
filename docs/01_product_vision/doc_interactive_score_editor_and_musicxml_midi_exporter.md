# Product Vision: Interactive SMuFL Score Editor & Canonical MusicXML/MIDI Exporter

Este documento define la especificación técnica, fundamento de notación musical estándar y arquitectura del **Editor Interactivo de Partituras SMuFL y Exportador Canónico Bidireccional (MusicXML y MIDI)** en **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-NOTATION-2026-EDITOR`
- **Título Oficial:** Suite de Edición Musical SMuFL Interactiva y Serialización Canónica Bidireccional MusicXML/MIDI
- **Estado:** Approved
- **Fecha de Creación:** 2026-10-27
- **Última Modificación:** 2026-10-27
- **Fase Asociada:** Fase 5 (Vanguardia Acústica y Aprendizaje Musical)
- **Autor / Revisor Principal:** Equipo de Arquitectura de Notación y Edición Musical de Tunner

---

## 1. Resumen Ejecutivo (Executive Summary)

Hasta ahora, **Tunner** contaba con visualización de pentagramas e importación de partituras (MusicXML y MIDI). Para consolidar a Tunner como la herramienta libre y de código abierto más completa del mundo para educación y creación musical, este hito transforma el motor de partituras en un **Estudio de Edición Bidireccional Completo**:

1. **Editor Interactivo de Notación:** Navegación por compases y tiempos, inserción de notas (redonda, blanca, negra, corchea, semicorchea), inserción de silencios, alteraciones accidentales (sostenidos, bemoles, becuadros), transposición y borrado, respaldado por un historial transaccional de Deshacer / Rehacer (*Undo/Redo* Memento) en Pure Dart.
2. **Audición Inmediata:** Cada nota insertada o modificada dispara instantáneamente su síntesis acústica procedural en RAM, permitiendo al músico escuchar la armonía mientras edita.
3. **Exportador Canónico Bidireccional:** Generador nativo en Pure Dart de archivos **MusicXML 3.1/4.0** estándar de la W3C (compatibles con MuseScore, Sibelius, Dorico, Finale) y archivos binarios **Standard MIDI (SMF Tipo 0)** con eventos de tempo, compás y notas con velocidad dinámica.

---

## 2. Fundamento Técnico y Estándares Internacionales

### 2.1 Estructura Jerárquica de la Partitura (Score Tree)
El editor manipula la entidad de dominio inmutable `HierarchicalScorePackage`, compuesta por `HierarchicalScore`, `MeasureEntity` y `HierarchicalNote`. Cada compás posee una métrica (`TimeSignature`) que define el límite estricto de ticks permitidos:
$$\text{Total Ticks} = \text{Numerator} \times \left(\frac{16}{\text{Denominator}}\right)$$
*Ejemplo:* En compás de $4/4$, cada compás admite exactamente 16 sub-ticks (4 tiempos de negra = 4 ticks cada una).

### 2.2 Patrón Memento para Deshacer / Rehacer (Undo / Redo)
Toda mutación en el árbol de notas genera una instantánea inmutable en una pila de historial de edición:
- Pila de `_undoStack`: Almacena estados previos de la partitura.
- Pila de `_redoStack`: Almacena estados revertidos listos para re-aplicar.
- Límite de memoria determinista (máximo 50 estados retenidos).

### 2.3 Estándar W3C MusicXML
La serialización genera un documento XML estricto con:
- Cabecera DOCTYPE oficial `partwise.dtd`.
- Metadatos de obra (`<work>`, `<creator>`, `<rights>`).
- Atributos iniciales (`<divisions>`, `<key>`, `<time>`, `<clef>`).
- Nodos `<note>` con `<pitch>` (`<step>`, `<alter>`, `<octave>`) o `<rest/>`, `<duration>`, `<voice>`, `<type>` (whole, half, quarter, eighth, 16th).

### 2.4 Estándar Standard MIDI File (SMF Format 0)
La serialización binaria genera los bytes canónicos:
- **Chunk MThd (14 bytes):** Magic `4D 54 68 64`, longitud 6, formato 0 (pista única), 1 pista, división de tiempo (ej. 480 ticks por negra).
- **Chunk MTrk:** Magic `4D 54 72 6B`, longitud N bytes.
- **Eventos MIDI:** Delta-times en formato variable-length quantity (VLQ), meta-eventos (Tempo `FF 51 03`, Time Signature `FF 58 04`, End of Track `FF 2F 00`), y pares NoteOn (`90 note velocity`) / NoteOff (`80 note 00`).

---

## 3. Especificación Funcional

- **REQ-ED-01:** Edición atómica en la capa de dominio sin dependencias de Flutter UI.
- **REQ-ED-02:** Soporte de figuras musicales canónicas: Redonda (16 ticks en 4/4), Blanca (8 ticks), Negra (4 ticks), Corchea (2 ticks), Semicorchea (1 tick).
- **REQ-ED-03:** Alteraciones accidentales instantáneas: sostenido ($\sharp$), bemol ($\flat$) y becuadro ($\natural$).
- **REQ-ED-04:** Pila de Deshacer / Rehacer completa con notificación reactiva.
- **REQ-ED-05:** Exportador MusicXML generador de cadenas XML conformes al estándar internacional.
- **REQ-ED-06:** Exportador MIDI generador de `Uint8List` binario SMF reproducible en cualquier DAW o sistema operativo.
- **REQ-ED-07:** Audición interactiva: reproducir el tono de la nota modificada inmediatamente a través del sintetizador en RAM.
