# ADR 0148: Unificacion de ScorePlaybackCoordinator Polifonico y Sintesis Multi-Stem Estereo Real

## Estado
Aprobado (Approved)

## Contexto
El motor de partituras presentaba tres inconsistencias funcionales y acusticas documentadas en la auditoria forense:
1. `TunerViewModel.selectAndPreviewScoreNote` invocaba concurrentemente a `_scorePlaybackCoordinator.previewNote(note)` y `_audioSynthesizer.playNoteTone(freq, ...)`. Esta doble llamada simultanea provocaba un molesto efecto de fase (*flanging / comb filtering*) y fugas de temporizadores si el usuario tocaba rapidamente multiples notas.
2. Durante la reproduccion compas a compas, el secuenciador procesaba unicamente `_expectedNote`, ignorando notas simultaneas en acordes polifónicos y las pistas secundarias del mezclador virtual (`tracks.skip(1)`).
3. `StemAudioSynthesizer.exportStemsAndMidi` limitaba los stems a dos pistas fijas (voz y piano), ignorando stems con indice `>= 2` (guitarra, bajo, percusion) y exportaba la mezcla maestra en formato Mono (1 canal) a pesar de que la interfaz visual anunciaba balance y paneo estéreo.

## Decision
1. Unificar la audición inmediata en `ScorePlaybackCoordinator`:
   - Gestionar temporizadores individuales en `Map<int, Timer> _activePreviewTimers` indexados por número de nota MIDI. Si una misma nota es tocada antes de concluir la envolvente previa, su temporizador se cancela y se reinicia cleanly.
   - Eliminar la llamada redundante a `_audioSynthesizer.playNoteTone` en `TunerViewModel.selectAndPreviewScoreNote`.
2. Habilitar reproduccion polifonica integral en `TunerViewModel`:
   - Sintetizar todas las notas concurrentes en `currentMeasureNotes` con `startTick == subTick` escaladas por `mixerConsole.getEffectiveGain(leadTrackId)`.
   - Delegar la sintesis multi-pista completa de `mixerConsole.stems` al motor `StemAudioSynthesizer` durante la exportacion.
3. Implementar sintesis y exportacion estéreo real de 2 canales en `StemAudioSynthesizer`:
   - Agregar `floatStereoBufferToWav` para generar audio estéreo PCM interleaved de 16 bits con encabezado WAV canónico de 2 canales (`channels: 2`).
   - Procesar la totalidad de las pistas definidas en `mixerConsole.stems` aplicando balance de volumen y distribución estereofónica (*panning*).

## Consecuencias
- **Positivas:**
  - Audición táctil transparente, clara y sin interferencias de fase.
  - Reproducción sonora coherente con partituras complejas que contienen acordes y múltiples instrumentos.
  - Archivos WAV de exportación compatibles con DAWs profesionales en estéreo real de 2 canales.
- **Negativas / Compromisos:**
  - El búfer estéreo interleaved duplica el tamaño en bytes de los datos PCM en memoria durante la exportación del master mixdown (de ~88.2 kB/s a ~176.4 kB/s a 44.1 kHz). Dado que la duración estándar es de pocos minutos, el impacto en memoria es insignificante en el hardware destino.
