# ADR-0133: Isolates para DSP Offline, Ticker Perezoso DJ y Reloj Monotónico de Partitura

- **Estado:** Aceptado
- **Fecha:** 2026-11-20
- **Issue:** #111 (ARCH-4)
- **Relacionado:** UC-144

## Contexto
Se detectaron tres cuellos de botella de concurrencia y temporización:
1. Procesamiento DSP offline síncrono en el hilo principal (`SongDecomposerService.decomposeCustomScore`, `VocalAutoTuneProcessor.processPracticeTake`, `BpmBeatTrackerEngine.estimateBpm` y análisis espectral en `DjConsoleViewModel.loadTrackWithBeatTracking`).
2. `DjConsoleViewModel` iniciaba un `Timer.periodic(33ms)` permanente desde el constructor incluso sin reproducción ni grabación activa, consumiendo batería y ciclos en reposo (`AGENTS.md §4.1`).
3. `ScorePlaybackCoordinator` usaba `Timer.periodic` sin compensación de deriva temporal.

## Decisión
1. Añadir métodos asíncronos respaldados por `Isolate.run(...)` (`decomposeCustomScoreAsync`, `processPracticeTakeAsync`, `BpmBeatTrackerEngine.estimateBpmAsync`, `loadTrackWithBeatTrackingAsync`), manteniendo los métodos síncronos originales para pruebas unitarias determinísticas y compatibilidad interna dentro del Isolate.
2. Actualizar `SongDecomposerModal` para invocar `decomposeCustomScoreAsync` con estado de carga seguro ante `mounted`.
3. Hacer `_playbackTicker` en `DjConsoleViewModel` estrictamente perezoso mediante `_syncTickerLifecycle()` y exponer `isTickerActive` para verificación en pruebas.
4. Migrar `ScorePlaybackCoordinator` a un reloj monotónico basado en `Stopwatch` (`_stopwatch`) con verificación periódica de baja carga que calcula exactamente los sub-ticks acumulados según `elapsedMicroseconds`.

## Consecuencias
- **Positivas:** Cero jank en UI durante análisis de audio o descomposición de partituras; cero consumo de CPU/timers en reposo para `DjConsoleViewModel`; precisión rítmica sin deriva en `ScorePlaybackCoordinator`.
- **Negativas / Trade-offs:** Las invocaciones `Async` introducen un salto de microtarea/Isolate (~1-3 ms), despreciable para flujos offline.
