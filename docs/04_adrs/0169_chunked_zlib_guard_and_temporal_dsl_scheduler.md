# ADR-0169: Guarda Anti Zip-Bomb por Chunks en ZLib, Isolates DSP y Planificador Temporal Real de Tunner DSL

- **Estado:** `Accepted`
- **Fecha:** `2026-11-23`
- **Autores:** `Devs 2 (Agente 02)`
- **Issues Relacionados:** `#187 (US-10.2)`, `#188 (US-10.3)`
- **Plan Asociado:** `docs/03_plans/plan_audit_04_dsp_isolates_real_audio_and_dsl_scheduler.md`

---

## 1. Contexto

Durante la auditoría forense integral de Fase 6 en **Tunner**, se identificaron cinco puntos críticos en los subsistemas de DSP, persistencia binaria, reloj métrico y lenguaje específico de dominio (Tunner DSL):

1. `TunnerBinaryProjectCodec` invocaba `_zlib.decode(compressedPayload)` de manera monolítica antes de validar `maxDecompressedPayloadBytes` (64 MiB). Un archivo `.tunner` o `.tnt` malicioso con alta tasa de compresión (zip-bomb de gigabytes de ceros) provocaba un pico de asignación de memoria no acotado antes de llegar a la validación de longitud.
2. `HarmonicSeriesAnalyzer` recalculaba 4096 cosenos de la ventana de Hann en cada frame de análisis y carecía de una vía `Isolate.run` asíncrona, mientras que `LocalProjectStorageRepository` comprimía y descomprimía payloads en el hilo llamador y `VocalPedagogyController` ejecutaba `processPracticeTake` de forma síncrona.
3. `MetronomeService` calculaba `subTicksPerBeat` como `meterDenominator == 2 ? 8.0 : 4.0`, ignorando denominadores compuestos como `8` (`6/8`, `9/8`, `12/8`) o `16`.
4. `StemAudioSynthesizer` y `PolyphonicVoicePool` fijaban la referencia `A4 = 440.0 Hz`, y `HarmonicDroneSynthesizer` sintetizaba armónicos sin verificar el límite anti-aliasing de Nyquist ($0.48 \cdot f_s$).
5. `TunnerDslInterpreter` ejecutaba secuencias de `note`, `chord` y `rest` sin cursor temporal acumulado, haciendo que todas las notas de un script o bucle se dispararan en $t = 0\text{ ms}$ y que `rest` no tuviera efecto temporal.

---

## 2. Decisión

1. **Descompresión ZLib por Chunks con Aborto Temprano (`TunnerBinaryProjectCodec`):**
   Se reemplaza `_zlib.decode(compressedPayload)` por una conversión por fragmentos (`_zlib.decoder.startChunkedConversion(ByteConversionSink.withCallback(...))`) alimentada en bloques de tamaño fijo (16 KiB). En cada chunk emitido por el decodificador, se incrementa el contador de bytes descomprimidos y se aborta inmediatamente lanzando `FormatException` en el instante exacto en que el acumulado supera `maxDecompressedPayloadBytes`. Asimismo, se unifica el framing binario (cabecera mágica de 4 bytes + 1 byte de versión + payload ZLib) entre proyectos y presets.

2. **Caché de Ventana de Hann y Offloading a `Isolate.run`:**
   - En `HarmonicSeriesAnalyzer`, se cachean los vectores `Float64List` de pesos de Hann y sus sumas coherentes por longitud $N$ en mapas estáticos (`_hannCache` y `_hannSumCache`), y se expone `analyzeAsync` sobre `Isolate.run`.
   - En `LocalProjectStorageRepository`, las operaciones asíncronas `saveProject`, `loadProject`, `saveToolPreset` y `loadToolPreset` delegan la codificación y decodificación binaria a `Isolate.run`.
   - En `VocalPedagogyController.applyAutoTuneToRecordingTake`, se utiliza `await _autoTuneProcessor.processPracticeTakeAsync(take: originalTake)`.

3. **Fórmula General de Sub-Ticks en `MetronomeService`:**
   Se define `computeSubTicksPerBeat(int meterDenominator) => 16.0 / meterDenominator.clamp(1, 16)`, garantizando `2.0` semicorcheas por pulso de corchea en `6/8`, `9/8` y `12/8`, `4.0` en `x/4` y `8.0` en `x/2`, además de exponer `Future<void> dispose() => stop()`.

4. **Calibración de Referencia A4 y Guarda de Nyquist:**
   Se parametriza `{double referencePitchHz = 440.0}` en `StemAudioSynthesizer.midiPitchToFrequency`, `PolyphonicVoicePool.midiToFrequency` y `TunnerDslInterpreter.midiToFrequency`, y se añade la condición `harmonicFreq < sampleRate * 0.48` en `HarmonicDroneSynthesizer.synthesizeVoiceSample`.

5. **Planificador Temporal Real en `TunnerDslInterpreter` y `StudioOsAudioKernelBridge`:**
   - `TunnerDslExecutionContext` mantiene `double currentBeatOffset = 0.0` y calcula `int get currentScheduledOffsetMs => (currentBeatOffset * 60000.0 / currentBpm).round()`.
   - Cada sentencia `note`, `chord` y `rest` calcula sus `beats = parseFraction(durationFraction) * 4.0` y `durationMs = calculateDurationMs(durationFraction, currentBpm).round()`, emite su evento con `scheduledOffsetMs` y `durationMs`, y avanza `currentBeatOffset += beats`.
   - `StudioOsAudioKernelBridge` programa la activación (`noteOn`) en `scheduledOffsetMs` (ejecutándola de forma inmediata cuando `scheduledOffsetMs <= 0` para preservar determinismo en notas iniciales) y su liberación (`noteOff`) en `scheduledOffsetMs + durationMs`, registrando todos los `Timer` en `_activeNoteTimers` para cancelación limpia en `stop` o `dispose()`.

---

## 3. Consecuencias

### Positivas
- Protección determinista O(1) en memoria frente a ataques o corrupciones tipo zip-bomb en archivos `.tunner` y `.tnt`.
- Eliminación de miles de operaciones trigonométricas redundantes por frame en el laboratorio acústico y cero bloqueo del hilo UI en persistencia de proyectos y AutoTune.
- Precisión métrica exacta en compases simples, alla breve y compuestos (`6/8`, `9/8`, `12/8`).
- Ejecución musical secuencial real de scripts Tunner DSL, respetando silencios (`rest`), bucles (`loop`) y cambios de `tempo`.

### Negativas / Trade-offs
- La caché estática `_hannCache` retiene en memoria los arreglos `Float64List` para los tamaños de ventana observados (típicamente 1 a 3 tamaños como 1024, 2048 o 4096 muestras, lo que representa menos de 64 KiB en total).
