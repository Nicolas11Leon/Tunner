# ADR-0161: Evaluacion Acumulada por Sub-Ticks y Telemetria Timbral DFT en Pedagogia

- **Estado:** Aceptado
- **Fecha:** 2026-11-22
- **Historia de Usuario:** US-6.2 (EPIC-06)
- **Issue:** #165

## Contexto

La auditoria detecto cuatro fuentes de datos sinteticos en pedagogia y clasificacion:
1. `TunerViewModel._updateExpectedNoteForTick` evaluaba la nota en su primer sub-tick con `timingDeltaMs: 0` y `sustainRatio: 1.0`.
2. `ScoreEditorController.buildPedagogicalSessionData` fabricaba sesiones con `89.2%`, `120` notas, curva `math.sin`, `820.0 Hz` y `11.8%` THD.
3. `PedagogicalReportModal.initState` hardcodeaba `'Flauta Traversa / Voz'`.
4. `TunerViewModel._evaluateSmartInstrumentFromPitch` y `PolyphonicLiveVoicingWidget._buildHarmonicSeriesBreakdown` usaban un vector de armonicos fijo y alturas hardcodeadas `(12 + (8 - i) * 3)`.

## Decision

1. **Acumulador por ventana de nota en `TunerViewModel`:** Registrar `_pendingFirstAttackTick` y `_pendingInTuneTicks` mientras el cursor recorre `[startTick, endTick)`, finalizando la evaluacion al avanzar a la siguiente nota o detener la reproduccion.
2. **Unificacion sobre `HarmonicSeriesAnalyzer`:** Reutilizar `HarmonicSeriesAnalyzer.analyze(...)` sobre `_latestAudioSamples` para alimentar `evaluateSmartInstrumentAcoustics`, `buildPedagogicalSessionData` y `PolyphonicLiveVoicingWidget`.
3. **Cero datos fabricados en reportes:** Cuando no existen evaluaciones o tomas reales, devolver valores en cero y listas vacias en `PedagogicalSessionData`.

## Consecuencias

- **Positivas:**
  - Precision pedagogica autentica en ataque ritmico, sostenimiento, centroide espectral y THD.
  - Consistencia total entre el instrumento activo del usuario y el reporte PDF generado.
- **Negativas / Compensaciones:**
  - Requiere que los consumidores de `PedagogicalSessionData` toleren `timedPitchSamples` vacio y `totalEvaluatedNotes == 0` cuando aun no se ha practicado.
