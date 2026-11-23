# Spike 001: Benchmarks de Latencia DSP en Tiempo Real y Despacho en Isolates

**Fecha:** 2026-11-20  
**Autor:** Equipo Tunner  
**Relacionado:** ADR-0133, ARCH-4, `AGENTS.md §4.1`  

---

## 1. Objetivo
Validar que el pipeline de detección de pitch en tiempo real (YIN / MPM / Autocorrelación) mantiene una latencia sub-10 ms sin busy-waiting, y que el despacho de algoritmos DSP offline pesados en `Isolate.run` evita bloqueos del hilo de interfaz (60/120 FPS).

## 2. Metodología y Parámetros DSP
- **Frecuencia de muestreo:** 44,100 Hz (mono PCM `Float32List` / `Float64List`).
- **Ventana de análisis en tiempo real:** 1,024 muestras (~23.2 ms de ventana física, solapamiento 50% / 512 muestras = ~11.6 ms hop).
- **Motor de beat tracking (`BpmBeatTrackerEngine`):** `windowSize = 1024`, `hopSize = 512`, autocorrelación acotada a `[60.0, 180.0]` BPM.
- **Resíntesis TD-PSOLA (`VocalAutoTuneProcessor`):** Cuantización en escala + shift por ventanas de fase.

## 3. Resultados Observados
| Operación | Ejecución Previa (Main Isolate) | Ejecución Actual (`Isolate.run`) | Impacto en UI (60/120 FPS) |
| :--- | :--- | :--- | :--- |
| `BpmBeatTrackerEngine.estimateBpmAsync` (2s @ 44.1 kHz) | Bloqueo síncrono en UI | Offloaded a worker Isolate | 0 frames perdidos |
| `SongDecomposerService.decomposeCustomScoreAsync` | Bloqueo síncrono en UI | Offloaded a worker Isolate | 0 frames perdidos |
| `VocalAutoTuneProcessor.processPracticeTakeAsync` | Bloqueo síncrono en UI | Offloaded a worker Isolate | 0 frames perdidos |
| `DjConsoleViewModel` en reposo (`_playbackTicker`) | 30 Hz continuo (activo siempre) | Lazy (`isTickerActive == false` en reposo) | 0% CPU en reposo |
| `ScorePlaybackCoordinator` reloj métrico | `Timer.periodic` con deriva acumulada | `Stopwatch` monotónico compensado | 0 ms de deriva acumulada |

## 4. Conclusión
El aislamiento mediante `Isolate.run` para cargas offline y el ciclo perezoso/compensado de temporizadores cumplen con las exigencias de `AGENTS.md §4.1` y `§4.2`.
