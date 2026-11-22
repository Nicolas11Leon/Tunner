# ADR 0152: Reloj Musical Real en Transcripcion, Silencios, Division de Compas y Soporte A0 / WAV Multi-Bit

## Estado
Aprobado

## Contexto
El subsistema de transcripcion presentaba cuatro limitaciones estructurales detectadas durante la validacion funcional:
1. **Desacoplamiento temporal en transcripcion en vivo:** `LiveTranscriptionEngine` y `PolyphonicTranscriptionEngine` incrementaban `durationTicks++` por cada invocacion de frame sin medir milisegundos reales, haciendo imposible reflejar el tempo real (`bpm`) ni insertar silencios (`!isVoiced`) en pausas entre notas.
2. **Truncamiento en barra de compas y hardcoding 4/4:** Al iniciar la transcripcion se ejecutaba `math.min(startTick, 15)` (asumiendo 16 ticks de 4/4), y al cerrar una nota se truncaba su duracion con `math.min(quantizedDuration, maxTicksInMeasure - _currentTickInMeasure)` descartando los ticks excedentes en lugar de dividir la figura hacia el compas siguiente.
3. **Corte prematuro de graves y ventana insuficiente en transcripcion offline:** `AudioToScoreTranscriptionEngine` usaba `windowSize = 2048` por defecto y filtraba `result.pitchHz >= 50.0`, impidiendo detectar el registro sub-grave hasta $A_0 = 27.5\text{ Hz}$ (cuyo periodo a 44.1 kHz es ~1,603.6 muestras y requiere al menos 4,096 muestras para dos ciclos completos en NSDF).
4. **Decodificador WAV limitado a PCM 16-bit y metrica 4/4 fija:** `_decodeAudioToMonoFloats` asumia `getInt16` sin validar `audioFormat` ni `bitsPerSample`, fallando en WAVs de 8, 24, 32 bits e IEEE Float (`audioFormat == 3`); ademas `_quantizeSegmentsToMeasures` hardcodeaba 16 ticks y `TimeSignature.commonTime44`.

## Decision
1. **Reloj musical unificado (`TranscriptionMusicalClock` / acumulado en ms) en vivo:**
   - Agregar parametros opcionales `double? frameDurationMs`, `int? timestampMs` e `int? bpm` en `processPitchFrame` y `processPolyphonicFrame` (ademas de `int? bpm` en `start()` y `int? timestampMs` en `stop()`, junto con un `int Function()? clockMsProvider` opcional en constructor).
   - Convertir duraciones acumuladas tanto sonoras como de silencio (`!isVoiced`) mediante la formula exacta `subTicks = (durationMs / (15000.0 / bpm)).round()`.
   - Cuando no se proveen `frameDurationMs`, `timestampMs` ni `clockMsProvider`, conservar el paso por frame sonoro (`1` sub-tick por frame) para retrocompatibilidad con flujos sin reloj externo.
2. **Insercion de silencios y division automatica en barra de compas:**
   - Acumular la duracion de pausas no sonoras y emitir `HierarchicalNote.rest` (via `ScoreEditorOperations` con `noteName: ''` / `isRest: true`) al consolidarse una nueva nota valida o finalizar la sesion cuando los `subTicks` de silencio sean `>= 1`.
   - Reemplazar el truncamiento `math.min(..., maxTicks - currentTick)` por un lazo de particion entre compases consecutivos que respete `targetMeasure.timeSignature.totalTicks`, agregando compases nuevos con la misma metrica cuando haga falta.
   - Eliminar `math.min(startTick, 15)` en `start()`, utilizando `startTick.clamp(0, math.max(0, measure.timeSignature.totalTicks - 1))`.
3. **Soporte A0 (27.5 Hz), WAV Multi-Bit e IEEE Float, y `TimeSignature` dinamico en transcripcion offline:**
   - Establecer `windowSize = 4096` por defecto en `AudioToScoreTranscriptionEngine` y reducir el umbral minimo a `25.0 Hz` (`minPitchHz = 25.0`).
   - Decodificar `audioFormat == 1` (PCM de 8 bits sin signo, 16 bits signed LE, 24 bits signed LE, 32 bits signed LE), `audioFormat == 3` (IEEE Float 32/64 bits) y `audioFormat == 0xFFFE` (Extensible con subformato PCM/Float), promediando multiples canales a mono en `[-1.0, 1.0]`.
   - Parametrizar `TimeSignature timeSignature = TimeSignature.commonTime44` en `transcribeAudioFile` y `UniversalScoreImporterService.transcribeAudioToScoreResult`, utilizando `timeSignature.totalTicks` en todo el empaquetado de compases.

## Consecuencias
- **Positivas:**
  - Fidelidad ritmica real independiente de la tasa de muestreo o frecuencia de callbacks del microfono.
  - Compases completos sin huecos ni desbordamientos, preservando notas sostenidas y silencios a traves de barras de compas y metricas compuestas/irregulares (`3/4`, `6/8`, `12/8`, `5/4`).
  - Compatibilidad completa con archivos WAV de estudio (24-bit, 32-bit float, 8-bit retro) y rango completo de piano de 88 teclas hasta $A_0 = 27.5\text{ Hz}$.
- **Negativas / Compensaciones:**
  - La ventana por defecto de `4096` muestras en `AudioToScoreTranscriptionEngine` incrementa el tamano minimo requerido de audio (~93 ms a 44.1 kHz) y el costo computacional de NSDF respecto a `2048`. Se mantiene parametrizable en el constructor para casos de baja latencia que no requieran sub-graves.
