# Implementation Plan: Integración del Acelerador Nativo FFI en la Cadena Maestra DSP y Consola de Estudio

**Issue Asociado:** #63 (Fase 9 - Épica 9.3)  
**Rama:** `feature/native-dsp-master-chain-integration`  
**Rama Base:** `qa`  
**Fecha:** 2026-11-18  

---

## 1. Resumen y Objetivos

Conectar el puente acelerador nativo `INativeDspBridge` / `NativeDspFfiBridge` con la cadena de procesamiento de audio en tiempo real de Tunner Studio creando la clase `StudioMasterDspChain`, e incorporar la funcionalidad de benchmarking de rendimiento en la terminal interactiva `TunnerOsKernel`.

---

## 2. Tareas de Implementación

### Tarea 1: Implementación de `StudioMasterDspChain`
- [ ] Crear `lib/core/audio/infrastructure/studio_master_dsp_chain.dart`:
  - Inyección de dependencias de `INativeDspBridge`.
  - Método `processMasterBlock(Float32List left, Float32List right, {double masterGain, bool isMuted, bool isDimmed, bool isMono})`.
  - Método `mixChannels(List<Float32List> channels, List<double> gains, Float32List out)` para suma lineal de stems y pistas.
  - Método `computeCorrelations(Float32List input, Float32List output)` para cálculo de autocorrelación acelerada.
  - Método `benchmark({int iterations, int blockSize})` retornando `DspBenchmarkResult` con métricas de tiempo transcurrido en microsegundos, tasa de muestras por segundo y nombre del motor activo.

### Tarea 2: Integración en `TunnerOsKernel`
- [ ] Actualizar `lib/core/terminal/domain/tunner_os_kernel.dart`:
  - Permitir inyección o inicialización de `StudioMasterDspChain`.
  - Agregar soporte para el comando `dsp bench [iteraciones] [bloque]` dentro de `_handleDsp`.
  - Formatear el reporte de benchmarking en la terminal con métricas objetivas.

### Tarea 3: Batería de Pruebas Unitarias
- [ ] Crear `test/core/audio/studio_master_dsp_chain_ffi_integration_test.dart`:
  - Pruebas de procesamiento de bloques maestros con ganancia, mute, dim y modo mono.
  - Pruebas de suma de canales múltiples (mezcla de stems).
  - Pruebas de ejecución del benchmark determinista.
  - Pruebas de integración del comando `dsp bench` en `TunnerOsKernel`.

---

## 3. Criterios de Aceptación (DoD)
- Todas las pruebas unitarias pasan sin errores.
- `flutter analyze --no-fatal-infos` con 0 incidencias.
- Código limpio, determinista y seguro sin sobrecarga en el recolector de basura.
- Cero emojis en código, documentación, comentarios y commits.
- PR creado hacia `qa` y fusionado en `qa`.
