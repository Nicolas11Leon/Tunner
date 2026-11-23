# Plan de Implementación: ARCH-4 — Isolates para DSP Offline, Ticker Perezoso DJ y Reloj Monotónico

**ID:** PLAN-ARCH-4-DSP-ISOLATES-2026-01  
**Issue:** #111  
**Rama:** `refactor/arch-4-dsp-isolates-and-lazy-timers`  
**Base:** `qa`  

---

## 1. Objetivo
Eliminar bloqueos del hilo de UI por DSP offline, erradicar timers activos en reposo en `DjConsoleViewModel`, y eliminar la deriva temporal del secuenciador en `ScorePlaybackCoordinator`.

## 2. Archivos a Modificar / Crear
1. `lib/features/song_library/domain/song_decomposer_service.dart`: agregar `decomposeCustomScoreAsync(...)` con `Isolate.run`.
2. `lib/features/song_library/presentation/song_decomposer_modal.dart`: migrar `_executeDecomposition()` a `async` usando `decomposeCustomScoreAsync`.
3. `lib/features/vocal_autotune/domain/vocal_autotune_processor.dart`: agregar `processPracticeTakeAsync(...)` con `Isolate.run`.
4. `lib/features/dj_console/domain/bpm_beat_tracker_engine.dart`: agregar `estimateBpmAsync(...)` con `Isolate.run`.
5. `lib/features/dj_console/presentation/dj_console_view_model.dart`:
   - Agregar `loadTrackWithBeatTrackingAsync(...)` con `Isolate.run` para BPM + Camelot + Spectral Summary.
   - Remover `_startTicker()` del constructor; implementar `_syncTickerLifecycle()` y getter `isTickerActive`.
6. `lib/features/sheet_music/domain/score_playback_coordinator.dart`:
   - Reemplazar deriva de `Timer.periodic` por reloj monotónico `Stopwatch` con cálculo exacto de sub-ticks acumulados.
7. `test/core/performance/arch_4_dsp_isolates_and_lazy_timers_test.dart`:
   - Verificar que `DjConsoleViewModel` inicia con `isTickerActive == false`, se activa al reproducir y se detiene al pausar.
   - Verificar `BpmBeatTrackerEngine.estimateBpmAsync`, `VocalAutoTuneProcessor.processPracticeTakeAsync`, `SongDecomposerService.decomposeCustomScoreAsync`.
   - Verificar que `ScorePlaybackCoordinator` avanza sub-ticks con reloj monotónico sin deriva y se detiene limpiamente.

## 3. Criterios de Aceptación
- `flutter analyze --no-fatal-infos`: 0 issues.
- `flutter test --no-pub`: 100% de pruebas aprobadas.
- Cero emojis en código y documentación.
