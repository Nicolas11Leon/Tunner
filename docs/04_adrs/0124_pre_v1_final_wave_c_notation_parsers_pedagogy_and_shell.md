# ADR-0124: Endurecimiento Pre-v1.0.0 Ola C (Notacion SMuFL, Parsers/Exporters, Pedagogia, Shell y DSL)

- **Estado:** Aceptado
- **Fecha:** 2026-11-19
- **Issue Relacionado:** #94
- **Caso de Uso:** UC-135

## Contexto
La auditoria forense previa al lanzamiento `v1.0.0` identifico defectos criticos de notacion (`SmuflGlyphPathEngine`, `ScoreEditorOperations`), generacion PDF (`CanonicalPdfExporter`, `PedagogicalReportPdfGenerator`), evaluacion pedagogica (`GuidedLessonsModal`, `PracticeEvaluatorService`, `BlindEarTrainerEngine`, `EbbinghausSpacedRepetitionEngine`), transcripcion en vivo, parsers/exporters (MusicXML, MIDI, ABC, OMR, Audio-to-Score), navegacion de modales (`TaskQuickJumpModal`, `ToolSearchModal`), docking y terminal OS/DSL (`TunnerOsKernel`, `TunnerDslInterpreter`).

## Decision
1. Corregir todas las formulas geometricas y de escritura PDF (offsets `latin1`, curvas Bezier `c` en reemplazo de `arc`, matriz absoluta `Tm`, compas real y proteccion de cabezas huecas).
2. Unificar la comparacion de alturas en pedagogia y notacion por numero MIDI enarmonico y cents, eliminando coincidencias por subcadena y aprobaciones de silencio (`0 Hz`).
3. Alinear `EbbinghausSpacedRepetitionEngine.nextReview` con el umbral de retencion del 90% (`-S * ln(0.90)`) y acotar estabilidad maxima para evitar desbordamiento de `DateTime`.
4. Corregir parsers/exporters para roundtrip fiel (multi-part, `<chord/>`, `<grace/>`, SysEx/VLQ, `K:`, UTF-8 en MIDI, `NoteOff < NoteOn`, fracciones enteras ABC, normalizacion por pagina en OMR).
5. Eliminar fugas en `TunnerOsKernel` (evitar doble `NativeDspFfiBridge`), enrutar acciones de `ToolSearchModal` y `TaskQuickJumpModal`, preservar IDs al editar temas, acotar proporciones de docking (`left + right <= 0.85`) y dotar de temporizacion secuencial y `isDryRun` real al `TunnerDslInterpreter`.

## Consecuencias
- **Positivas:** PDFs validos en cualquier visor estandar, roundtrip confiable de partituras, evaluacion pedagogica justa y shell sin botones muertos ni fugas de recursos.
- **Riesgos mitigados:** Eliminacion de crashes por division por cero, overflows de layout en docking y corrupcion de bemoles en espanol.
