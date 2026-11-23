# Architecture Decision Record: ADR-0110 - Corrección de Fallos Críticos de Runtime, Fugas de Recursos y Reloj Sin Deriva Pre-v1.0.0

---

## Metadatos del Documento

- **ID del ADR:** `ADR-0110`
- **Título:** Corrección de Fallos Críticos de Runtime, Fugas de Recursos y Reloj Maestro Sin Deriva Pre-v1.0.0
- **Estado:** `Accepted`
- **Fecha:** `2026-11-19`
- **Fase Asociada:** `Pre-Release Gate v1.0.0 - Ola 1`
- **Contexto Técnico:** Issue #68
- **Autor / Revisor Principal:** `Nicolas Leon (Mantenedor Principal)`

---

## 1. Contexto

La auditoría técnica integral previa al lanzamiento `v1.0.0` identificó 7 fallos funcionales de tiempo de ejecución y 9 fugas de recursos activas en producción:
- `RangeError` en mezcla DSP con búferes asimétricos.
- Congelamiento de `StudioMasterClockService` al reducir el BPM durante reproducción activa.
- Desajuste de identificadores de deck (`'deck_a'` vs `'A'`) entre `MainAppShell` y `DjConsoleViewModel`.
- Desconexión de `kernelBridge` respecto a `viewModel` y `synthVoicePool` asignados tardíamente en `TunnerOsKernel`.
- Reconstrucción completa de `MaterialApp` a 60 FPS en `lib/main.dart`.
- Instancias desconectadas de `StudioAudioDeviceMatrixService` impidiendo la persistencia de matriz en `.tunner`.
- Fugas de `ReceivePort`, `Isolate`, `Timer` y `TextEditingController`, además de asignaciones `calloc` por frame en FFI.

---

## 2. Decisión Arquitectónica

1. **Anclaje de Fase en `StudioMasterClockService`:**
   - Reemplazar el cálculo absoluto desde `t = 0` por un acumulador incremental (`_accumulatedBeats` consolidado en `_anchorElapsedMs` antes de cambiar `_bpm`) y temporización compensada de alta resolución (`<= 4 ms`).
2. **Pool Scratch Determinista en FFI y Seguridad de Límites:**
   - Reutilizar punteros nativos en `NativeDspFfiBridge` protegidos por `dispose()` y `Finalizer`, acumular `tunner_autocorrelate` en `double` dentro de `tunner_dsp.c` y acotar longitudes en `NativeDspBridgeFallback.vectorSum` y `StudioMasterDspChain`.
3. **Normalización de Contratos de Transporte y Enlace DSL:**
   - Normalizar `deckId` en `DjConsoleViewModel`, exponer `playDeck`/`pauseDeck` explícitos en `MainAppShell` y `TunnerOsKernel`, y propagar `viewModel`/`synthVoicePool` en `TunnerOsKernel` hacia `kernelBridge`.
4. **Selectores Granulares y Ciclo de Vida Estricto:**
   - Utilizar `context.select` en `TunnerApp`, inyectar la matriz única en `TunerViewModel`, añadir `dispose()` en `IMetronomeService`, `PitchDetectorService`, `StudioOsAudioKernelBridge`, `StudioPatchbayRoutingService` y todos los `TextEditingController`, y agregar guardia `_isDisposed` en los `ChangeNotifier`.

---

## 3. Consecuencias

### Positivas
- Estabilidad determinista en sesiones prolongadas sin degradación de memoria ni congelamientos de reloj.
- Ahorro drástico de CPU en UI al eliminar rebuilds globales de `MaterialApp`.
- Cero regresiones en pruebas existentes y cobertura directa de los escenarios de fallo.
