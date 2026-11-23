# Plan de Implementación 06: Cero Mocks y Verdad Acústica en Pedagogía, Notación, Importer y Kernel

## Metadatos del Plan

- **ID del Plan:** `PLAN-AUDIT-06-TRUTHFULNESS-ZERO-MOCKS-2026`
- **Título de la Implementación:** `Erradicación de Datos Sintéticos/Mocks en Pedagogía y Kernel OS, y Consolidación de Notación/Importer/Transcripción`
- **Fase del Proyecto:** `Fase 6 — Certificación de Rigor Acústico y Pedagógico v1.0`
- **Estado:** `Propuesto`
- **ADR Relacionado:** `Por crear (ADR-0171: Zero Synthetic Telemetry & Real Acoustic Evaluation)`
- **Documento Funcional Base:** [Auditoría Forense Integral](../05_audits/2026-11-23_master_tool_by_tool_forensic_audit.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Eliminar el 100% de los datos falsos, logros inventados, telemetría sintética y exportaciones con fallo silencioso detectados en la suite pedagógica, el `TunnerOsKernel`, el editor/importador de partituras y los motores de transcripción, asegurando rigor acústico y musical completo (`A0..C8`, enarmonía, compases arbitrarios).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - **Ear Training (`blind_ear_trainer_engine.dart` y modal):** Respetar `minBaseFrequencyHz`/`maxBaseFrequencyHz` en todo el rango cromático `A0..C8`, aplicar `useJustIntonation` en `_findClosestInterval()`, exigir ventana de estabilidad (ej. 250 ms sostenidos) antes de aceptar respuesta cantada por micrófono y descomponer el modal (744 LOC).
  - **Guided Lessons & Task Catalog:** Eliminar progreso falso (`mastered`/`S`/`A`/`B`) del seed en `task_catalog_index.dart:186-246` (todos inician en `notStarted`/`none` hasta persistencia real), normalizar diacríticos en `_tokenize()` (soportar tildes y `ñ`), evitar duplicados en `register()`, eliminar lógica de evaluación duplicada en `guided_lessons_modal.dart:201-208` y descomponer el modal (755 LOC).
  - **Harmonic Tutor:** Eliminar inicialización falsa en `261.63 Hz` + `isListening: true` (`harmonic_tutor_view_model.dart:26`), soportar 12 tónicas cromáticas, sintetizar acordes completos (tríadas/séptimas) en bucle continuo real y descomponer `harmonic_tutor_modal.dart`.
  - **Vocal Stability, Practice Evaluator, Profiles & Reports:** Devolver estado explícito `insufficientSignal` (`score: 0.0`) ante silencio en `vocal_stability_evaluator.dart:47-63`; corregir evaluación de silencios con ruido en `practice_evaluator_service.dart:28-45`; usar `effectiveTolerance` e `isSharp` reales en `adaptive_scaffolding_engine.dart:65,128`; sacar `PedagogicalSessionData.sample()` a `test/helpers/`; corregir `saveExportedBytes` con `await` + manejo real de error en `pedagogical_report_modal.dart:369-387`; corregir typo `"TUNER"` -> `"TUNNER"` y añadir word-wrap en `_drawDiagnosticBox` del generador PDF.
  - **Exercise Generator:** Ampliar rango de octavas a `0..8`, soportar compases distintos de `4/4` y ortografía enarmónica según tonalidad.
  - **TunnerOsKernel & MainAppShell:** Conectar `io list`, `dsp status`, `fs ls` y `vocal eval`/`vocal cert` exclusivamente a telemetría real (retornando error descriptivo cuando no hay dispositivo/captura en vez de inventar datos o certificados); capturar muestras reales de frecuencia/amplitud en `main_app_shell.dart:259-262` (sin `10x frequency` ni `0.85` constante); mostrar salida de `onCommandSubmitted` en la terminal; no responder `[OK]` cuando un callback es `null`; quitar `bpm: 124.0` hardcoded al abrir `.wav`.
  - **Notation, Importer, Song Library & Transcription:** Unificar los 6 conversores duplicados nota/MIDI en un único `CanonicalPitchNotationCodec`; eliminar `getMockStudies()` en `score_tree.dart`; proteger `totalMeasures == 0` en `score_editor_modal.dart:161`; unificar la base común (~85% duplicada) de `live_transcription_engine.dart` y `polyphonic_transcription_engine.dart`; añadir puntillos/tresillos en `RhythmicQuantizer`; descomponer `score_editor_modal.dart`, `song_decomposer_modal.dart`, `vocal_autotune_modal.dart` y `pdf_score_parser.dart`; sacar muestras binarias de `score_import_tab_view.dart` a un proveedor de fixtures de dominio.
- **Excluido (Out-of-Scope):**
  - Integración de fuentes `.otf/.ttf` SMuFL externas de terceros (se mantiene el motor vectorial con caché de `Paint`/`Path` optimizado en Plan 01).

---

## 2. Análisis de Dependencias y Tecnologías

- **SDKs:** Pure Dart / Flutter estable. Sin dependencias nuevas.
- **Riesgo Tecnológico:** Bajo-medio (algunos tests antiguos pueden depender de los valores sintéticos viejos como `261.63 Hz` o `50.0` en silencio; se actualizarán para validar el comportamiento acústico honesto).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Verdad Acústica en Pedagogía (`ear_training`, `guided_lessons`, `harmonic_tutor`, `pedagogy*`, `exercise_generator`)
- [ ] Corregir `blind_ear_trainer_engine.dart`, `task_catalog_index.dart`, `guided_lessons_modal.dart`, `harmonic_tutor_view_model.dart`, `vocal_stability_evaluator.dart`, `practice_evaluator_service.dart`, `adaptive_scaffolding_engine.dart`, `pedagogical_report_modal.dart`, `pedagogical_report_pdf_generator.dart` y `algorithmic_exercise_generator.dart`.

### Paso 2: Verdad Operativa en `TunnerOsKernel` y `MainAppShell`
- [ ] Eliminar respuestas ficticias en `io list`, `dsp status`, `fs ls`, `vocal eval`/`vocal cert`, `dj` y `theme set` sin callback; capturar buffers reales de frecuencia/amplitud en `main_app_shell.dart:259-262`; mostrar resultados de `onCommandSubmitted` en la terminal; detectar BPM real al abrir `.wav`.

### Paso 3: Consolidación de Notación, Importer y Transcripción
- [ ] Crear `CanonicalPitchNotationCodec` único y eliminar las 6 copias en `universal_importer` + `score_editor_modal.dart`.
- [ ] Extraer base compartida para `live_transcription_engine.dart` y `polyphonic_transcription_engine.dart` y extender `RhythmicQuantizer` con puntillos y tresillos.
- [ ] Atomizar `score_editor_modal.dart`, `song_decomposer_modal.dart`, `vocal_autotune_modal.dart`, `pdf_score_parser.dart` y limpiar `score_import_tab_view.dart`.

### Paso 4: Verificación
- [ ] Pruebas unitarias de regresión para cada corrección de verdad acústica (silencio -> `insufficientSignal`, `BlindEarTrainerEngine` respetando `min/maxHz`, `_tokenize` con tildes/`ñ`, `saveExportedBytes` propagando error real, `TunnerOsKernel` sin datos inventados).
- [ ] `flutter analyze --no-fatal-infos` y `flutter test` al 100%.

---

## 4. Estrategia de Rollback
- **Punto de Restauración Git:** Commit base de la rama `fix/audit-06-truthfulness-zero-mocks`.
- **Mitigación Inmediata:** Reversión independiente por feature pedagógico o de notación.

---

## 5. Criterios de Aceptación (Definition of Done)
- [ ] Cero datos sintéticos, logros inventados ni fallos silenciosos en producción.
- [ ] Cero duplicación de conversores nota/MIDI y motores de transcripción.
- [ ] Rango completo `A0..C8` respetado en `ear_training` y `exercise_generator`.
- [ ] `flutter analyze` y `flutter test` al 100%.
