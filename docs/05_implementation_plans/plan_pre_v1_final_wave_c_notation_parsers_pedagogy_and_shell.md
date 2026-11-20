# Plan de Implementacion: Ola Final C Pre-v1.0.0 (#94)

## Objetivo
Resolver en lotes incrementales y verificados todos los hallazgos de la Ola C (S1-13 a S1-22 y S2-10 a S2-14) sobre una rama limpia desde `qa`.

## Lotes de Trabajo
1. **Lote C1 — SMuFL, ScoreEditor, ExerciseGenerator y PDF Exporters:**
   - `SmuflGlyphPathEngine`: signo de lineas adicionales sobre/debajo del pentagrama, `PathFillType.evenOdd` para redondas.
   - `ScoreEditorOperations`: preservar cola al dividir notas, marcar silencios con `isRest: true`; `AlgorithmicExerciseGenerator`: `isRest: true` en silencios.
   - `CanonicalPdfExporter`: quitar stripping destructivo de `MI` sobre `MIB4`, eliminar `re f` sobre cabezas huecas, usar compas real de la partitura.
   - `PedagogicalReportPdfGenerator`: `latin1.encode` para offsets `xref`, curvas Bezier `c` en lugar de `arc`, matriz absoluta `Tm`, `sha256` real, respetar `includeRhythmJitter`, corregir `"TUNER"` -> `"TUNNER"`.
   - `ScoreEditorModal` y `PedagogicalReportModal`: conectar exportacion real a plataforma/disco via `IPlatformFileGateway` (sin descartar bytes).
2. **Lote C2 — Pedagogia, Transcripcion y Repeticion Espaciada:**
   - `GuidedLessonsModal` & `GuidedLessonEvaluator`: mostrar pantalla de completado cuando `progress.isCompleted`, comparacion exacta/enarmonica.
   - `PracticeEvaluatorService`: comparacion enarmonica por MIDI.
   - `BlindEarTrainerEngine` & `BlindEarTrainerModal`: rechazar `0 Hz`, usar distancia en cents para `_findClosestInterval`, llamar `stopReferenceTone()` en `dispose()`, conectar SRS.
   - `EbbinghausSpacedRepetitionEngine`: `nextReview` a 90% de retencion, `retentionAt(nextReview)` real, tope de estabilidad.
   - `LiveTranscriptionEngine` & `PolyphonicTranscriptionEngine`: acumular duracion real en ms segun BPM y registrar silencios.
3. **Lote C3 — Parsers & Exporters & Edge-cases:**
   - `MusicXmlScoreParser`: `Cb`/`B#`, `<part>`, `<chord/>`, `<grace/>`, `<backup>`.
   - `MidiScoreParser`: SysEx `0xF0`/`0xF7`, VLQ tope 4 bytes, `runningStatus`, time signature real, sin tope arbitrario de 100 compases.
   - `AbcScoreParser`: `K:` key signatures, limpiar acordes `"Am7"` y decoraciones `!fermata!`.
   - `PdfScoreParser` / `VectorOmrEngine`: procesamiento por pagina, filtrar silencios planos.
   - `AudioToScoreTranscriptionEngine`: guardas contra `channels == 0`, `sampleRate == 0` y buffers cortos.
   - `CanonicalMusicXmlExporter`, `MidiExporter`, `AbcExporter`: `<sound tempo>`, `<dot/>`, `utf8.encode`, `NoteOff < NoteOn`, fracciones enteras y notacion anglosajona.
   - `RealSheetMusicPainter` y `InstrumentPedagogyAdapterEngine`: parseo correcto de `"b4"` minuscula.
   - `LocalDiskStudioFileSystemRepository` y `StudioAudioHardwarePersistenceService`: `Platform.pathSeparator`, evitar `'//'`, `.tmp` unico por escritura.
4. **Lote C4 — Shell, Modales, Docking, TunnerOsKernel y DSL:**
   - `MainAppShell` (`TaskQuickJumpModal`, `_handleOpenFile`, `onMenuSaveWorkspace`), `ToolSearchModal` (enrutar 7 acciones, quitar uso de context post-pop, `dispose()` de VMs), `ThemeEditorDialog` (preservar ID al editar), `StudioAutomationsModal` / `StudioCustomizationsModal`.
   - `StudioWorkspaceDockingContainer` y `StudioDockLayoutEntity`: acotar `left + right` y evitar altura negativa.
   - `TunnerOsKernel`: compartir instancia unica de `NativeDspFfiBridge`, leer FS real e I/O real.
   - `TunnerDslInterpreter`: temporizacion secuencial real con `rest`, parseo solfeo `Do4/Mi4/La4`, `isDryRun`, historial ring-buffer sin bloqueo tras 100 eventos, setters booleanos explicitos.
5. **Verificacion y PR:**
   - Pruebas de regresion en `test/features/notation/wave_c_notation_parsers_pedagogy_shell_test.dart`.
   - `flutter analyze --no-fatal-infos` (0 issues) y `flutter test --no-pub` (100% pass).
   - PR y squash-merge hacia `qa`, cierre de Issue #94.
