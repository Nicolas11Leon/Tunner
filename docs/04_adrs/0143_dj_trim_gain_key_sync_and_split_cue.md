# Architecture Decision Record (ADR): 0143

## 1. Contexto y Problema
En la auditoría de la cabina de DJ:
1. La perilla `TRIM` en `DjVerticalChannelStrip` estaba renderizada como un componente visual estático con valor `1.0`, callback vacío `onChanged: (val) {}` y texto fijo `'0.0 dB'`, sin ninguna conexión con `DjDeckEntity`, `DjPerformanceOrchestrator` o el motor de audio.
2. La acción `KEY SYNC` calculaba la clave en Camelot pero no sincronizaba la tasa de reproducción en `IDjDeckAudioPlayer`.
3. `SPLIT-CUE` no estaba conectado para generar la matriz estéreo en tiempo real entre master y PFL.
4. Múltiples acciones de hardware y teclado en `executeAction` (pitch bend, key sync, loop engagement) no invocaban `_deckAudioPlayer.setDeckPlaybackRate`, generando un desfase entre la UI y el reproductor de audio subyacente.

## 2. Decisión Tomada
1. **Control de Preamplificación TRIM:**
   - Incorporar la propiedad `trim` (por defecto `1.0`, rango `[0.0, 2.0]`) y el getter computado `trimDb` en `DjDeckEntity`.
   - Conectar la perilla TRIM en `DjVerticalChannelStrip` para invocar `viewModel.setTrim(deckId, val)` y formatear el texto en decibelios en tiempo real (e.g. `+3.5 dB`, `0.0 dB`, `-inf dB`).
   - Aplicar `trim` en `DjPerformanceOrchestrator.getEffectiveGains()` y en las ganancias de canal de grabación.
2. **Sincronización Armónica Key Sync / Key Lock:**
   - Integrar `_syncDeckPlaybackRate(deckId)` en `DjConsoleViewModel` para actualizar `_deckAudioPlayer.setDeckPlaybackRate` teniendo en cuenta `effectivePlaybackRate` según el estado de `isKeyLockEnabled`.
3. **Matriz Split-Cue en Tiempo Real:**
   - Implementar `generateSplitCueChunk` en `DjConsoleViewModel` utilizando `DjAudioProcessor.encodeSplitCueStereo` para separar master y monitor PFL en canales estéreo izquierdo y derecho respectivamente.
4. **Sincronización Total de Acciones de Transporte:**
   - Extender `executeAction` en `DjConsoleViewModel` para sincronizar `_deckAudioPlayer` en todas las acciones de pitch, sincronización, bucles y hot cues.

## 3. Consecuencias
- **Positivas:**
  - La perilla TRIM responde de forma fluida con calibración precisa en dB y afecta tanto la salida audible como la grabación master.
  - La sincronización tonal y de tempo opera sin desfases entre el orquestador y el motor de audio nativo.
  - El monitoreo Split-Cue permite preescucha profesional en hardware portátil con salida única estéreo.
- **Negativas / Mitigaciones:**
  - En plataformas donde el plugin de audio no soporte cambio dinámico de tono con algoritmos time-stretching de grado estudio, Key Lock mantiene la tasa de reproducción desacoplada de la transposición interna.
