# Implementation Plan: Corrección de Fallos Críticos de Runtime, Fugas de Recursos y Rendimiento DSP (Ola 1)

**Issue Asociado:** #68 (Pre-v1.0.0 - Ola 1)  
**Rama:** `fix/pre-v1-critical-bugs-and-resource-leaks`  
**Rama Base:** `qa`  
**Fecha:** `2026-11-19`  

---

## 1. Resumen y Objetivos

Resolver los 7 fallos críticos de tiempo de ejecución, las 9 fugas de memoria/Isolates/Timers/Controllers, las guardias `_isDisposed` faltantes, la asignación nativa por frame en FFI y el emoji residual en `tunner_os_kernel.dart`.

---

## 2. Tareas de Implementación

- [ ] **DSP y FFI:** Acotar `NativeDspBridgeFallback.vectorSum`, corregir `StudioMasterDspChain` con buffers reutilizables, acumular `tunner_autocorrelate` en `double` y reutilizar punteros nativos en `NativeDspFfiBridge` con `dispose()`.
- [ ] **Reloj Maestro:** Implementar acumulador de fase por anclaje en `StudioMasterClockService`, reducir intervalo a `<= 4 ms` y añadir guardia `_isDisposed`.
- [ ] **DJ, Transporte y DSL:** Normalizar `deckId` en `DjConsoleViewModel`, usar `playDeck`/`pauseDeck` en `MainAppShell` y `TunnerOsKernel`, y propagar `viewModel`/`synthVoicePool` en `TunnerOsKernel` hacia `kernelBridge`.
- [ ] **UI 60 FPS y Matriz Unificada:** Cambiar `context.watch` por `context.select` en `lib/main.dart`, y compartir la instancia única de `StudioAudioDeviceMatrixService`.
- [ ] **Fugas de Recursos:** Añadir `dispose()` en `IMetronomeService`/`MetronomeService`, `PitchDetectorService` (catch), `StudioOsAudioKernelBridge`, `StudioPatchbayRoutingService`, `MainAppShell` (`audioInput`, `onOpenFile = null`) y los 5 modales con `TextEditingController`; añadir `_isDisposed` en los 7 `ChangeNotifier`.
- [ ] **Reglas Cardinales y Web:** Reemplazar emoji en `tunner_os_kernel.dart:372` por `[DIR]`, y reescribir `CanonicalMidiExporter.encodeVlq` sin `while (true)` y web-safe.
- [ ] **Pruebas:** Crear suite de regresión verificando cada corrección, recompilar `libtunner_dsp.so`, ejecutar `flutter analyze` y `flutter test`.
