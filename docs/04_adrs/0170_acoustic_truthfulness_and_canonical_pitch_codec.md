# ADR-0170: Verdad Acústica en Suite Pedagógica y Códec Canónico de Notación Musical

- **Estado:** Aprobado
- **Fecha:** 2026-11-23
- **Autor:** Devs 1 (Agente 01) — Core, Editor de Partituras y Persistencia
- **Relacionado con:** `US-12.1 (#192)`, `US-12.3 (#194)`, `PLAN-AUDIT-06-TRUTHFULNESS-ZERO-MOCKS-2026`

---

## 1. Contexto

Durante la auditoría forense de la Fase 6 se identificaron discrepancias entre los parámetros configurados por el usuario, la telemetría acústica real y la representación musical en dos áreas críticas:

1. **Suite Pedagógica (`US-12.1`):**
   - `BlindEarTrainerEngine` restringía la generación de frecuencias base a una única octava fija (`C4..B4`) ignorando `minBaseFrequencyHz` y `maxBaseFrequencyHz`, y evaluaba intervalos cantados siempre en 12-EDO ignorando `config.useJustIntonation`.
   - `BlindEarTrainerModal` disparaba la evaluación ante la primera muestra $> 50\text{ Hz}$ sin validar estabilidad temporal entre muestras consecutivas.
   - `TaskCatalogIndex` no normalizaba caracteres diacríticos del español (`á, é, í, ó, ú, ü, ñ`) en `_tokenize()` y duplicaba referencias en `_byDomain` y `_byLevel` al re-registrar un mismo `task.code`.
   - `HarmonicTutorViewModel` inicializaba el estado con una frecuencia sintética (`261.63 Hz`) e `isListening = true` antes de activar captura de audio real, y truncaba la síntesis del acorde a solo 2 voces (`.take(2)`).
   - `VocalStabilityEvaluator` otorgaba `overallScore: 50.0` y `measuredMeanFrequencyHz: targetFrequencyHz` cuando recibía silencio (`< 5` muestras válidas).
   - `AdaptiveScaffoldingEngine` mostraba `'Tol: ±5c'` fijo e ignoraba `isSharp` para indicar dirección del desvío.
   - `PedagogicalReportModal` no esperaba ni verificaba el resultado de `saveExportedBytes`, y `PedagogicalReportPdfGenerator` contenía la errata `"TUNER CONSERVATORY"` además de carecer de word-wrap en líneas largas de diagnóstico.
   - `ExerciseGenerator` limitaba las octavas de UI a `2..6` y carecía de ortografía enarmónica con bemoles para tonalidades bemolizadas.

2. **Notación, Importador y Transcripción (`US-12.3`):**
   - Existían múltiples implementaciones ad-hoc de conversión entre nombres de nota y números MIDI en `score_editor_modal.dart` y `universal_importer`, algunas de las cuales confundían la nota anglosajona `B` / `b` (Si natural) con el modificador de bemol (`b`).
   - `ScoreEditorModal` podía invocar `.clamp(0, totalMeasures - 1)` cuando `totalMeasures == 0`, lanzando `ArgumentError`.
   - `RhythmicQuantizer` solo cuantizaba a potencias de dos (`[1, 2, 4, 8, 16]`), descartando figuras con puntillo (`3, 6, 12` sub-ticks).

---

## 2. Decisión

1. **Rigor Acústico y Evaluación Honesta en Pedagogía:**
   - Generar el catálogo cromático completo desde `A0` (MIDI 21, $27.5\text{ Hz}$) hasta `C8` (MIDI 108, $4186.01\text{ Hz}$) en `BlindEarTrainerEngine` y filtrar por `[config.minBaseFrequencyHz, config.maxBaseFrequencyHz]`.
   - Propagar `useJustIntonation: config.useJustIntonation` a `_findClosestInterval()`.
   - Exigir estabilidad de tono cantado en `BlindEarTrainerModal` (3 muestras consecutivas $> 20\text{ Hz}$ con variación $< 50\text{ cents}$, o confirmación mediante `btn_submit_sung_tone`, manteniendo soporte determinista en `emitTelemetryForTesting`).
   - Normalizar diacríticos en `TaskCatalogIndex._tokenize()` y limpiar entradas previas en `register()` cuando un `code` se actualiza.
   - Iniciar `HarmonicTutorViewModel` en estado pasivo (`_isListening = false`, sin frecuencia ficticia) y sintetizar todas las voces de `targetFreqs` en `_regenerateDrone()`.
   - Retornar `measuredMeanFrequencyHz: 0.0` y `overallScore: 0.0` en `VocalStabilityEvaluator` cuando `validFrequencies.length < 5`.
   - Usar `effectiveTolerance` real e `isSharp` en `AdaptiveScaffoldingEngine`.
   - Verificar `await saveExportedBytes(...)` en `PedagogicalReportModal`, corregir el encabezado a `"TUNNER CONSERVATORY"` y aplicar word-wrap a 85 caracteres en `PedagogicalReportPdfGenerator`.
   - Extender el selector de octavas a `0..8` en `ExerciseGeneratorModal` y usar escala cromática con bemoles cuando la tónica sea bemol o `Fa` en `AlgorithmicExerciseGenerator`.

2. **Unificación en `CanonicalPitchNotationCodec` y Cuantización con Puntillo:**
   - Crear `lib/features/universal_importer/domain/canonical_pitch_notation_codec.dart` en la capa de dominio pura para centralizar la conversión bidireccional nota <-> MIDI y frecuencia <-> MIDI, distinguiendo explícitamente la letra de nota `B`/`b` del accidente bemol posterior.
   - Proteger `totalMeasures <= 0` en `ScoreEditorModal` y calcular recomendaciones dinámicas según `pitchAccuracy`, `rhythmAccuracy` y `centsError` en `ScoreEditorController`.
   - Incluir `[1, 2, 3, 4, 6, 8, 12, 16]` en `RhythmicQuantizer` para representar figuras con puntillo con precisión rítmica.

---

## 3. Consecuencias

- **Positivas:**
  - Eliminación total de telemetría engañosa en reposo o silencio dentro de los módulos pedagógicos.
  - Coherencia enarmónica y soporte completo del registro instrumental y vocal `A0..C8`.
  - Unificación del parseo y formateo de notas en un único componente puro de dominio probado exhaustivamente.
- **Negativas / Trade-offs:**
  - Los tests unitarios que asumían `overallScore == 50.0` ante entrada vacía o silencio deben actualizarse para validar `overallScore == 0.0`.
