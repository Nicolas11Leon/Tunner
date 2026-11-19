# Architecture Decision Record: ADR-0108 - Integración del Acelerador Nativo FFI en la Cadena Maestra DSP y Consola de Estudio

---

## Metadatos del Documento

- **ID del ADR:** `ADR-0108`
- **Título:** Integración del Acelerador Nativo FFI en la Cadena Maestra DSP y Consola de Estudio
- **Estado:** `Accepted`
- **Fecha:** `2026-11-18`
- **Fase Asociada:** `Fase 9 (Aceleración Nativa Bare-Metal & dart:ffi) - Épica 9.3`
- **Contexto Técnico:** Issue #63
- **Autor / Revisor Principal:** `Nicolas Leon (Mantenedor Principal)`

---

## 1. Contexto

En la Épica 9.1 se establecieron los contratos abstractos `INativeDspBridge` y `NativeDspBridgeFallback`. En la Épica 9.2 se implementó la biblioteca C99 (`libtunner_dsp`) con desenrollado cuádruple SIMD y su compilación cruzada mediante CMake.

Sin embargo, para que esta capacidad reduzca de forma efectiva la latencia del motor de audio en producción y durante sesiones de estudio, era imperativo conectar el puente FFI en el flujo real de procesamiento de bloques de audio de Tunner Studio:
1. La cadena maestra de mezcla de canales (`StudioMasterDspChain`) requiere atenuación y suma vectorial en tiempo real sin bloquear el hilo principal.
2. El diagnóstico y verificación del rendimiento en tiempo de ejecución debe ser accesible desde la consola interactiva `TunnerOsKernel` mediante un comando determinista de benchmarking (`dsp bench`).

---

## 2. Decisión Arquitectónica

1. **Creación de `StudioMasterDspChain`:**
   - Se crea `lib/core/audio/infrastructure/studio_master_dsp_chain.dart`, implementando la orquestación de procesamiento de bloques maestros de audio.
   - Recibe por inyección de dependencias una instancia de `INativeDspBridge` (por defecto `NativeDspFfiBridge`).
   - Métodos principales:
     - `processMasterBlock(Float32List left, Float32List right, ...)`: Procesa atenuaciones, ganancia maestra y colapso monofónico.
     - `mixChannels(List<Float32List> channels, List<double> gains, Float32List out)`: Suma ponderada de señales multicanal vectorizada.
     - `computeCorrelations(Float32List input, Float32List output)`: Autocorrelación para pitch estimation acelerada.
     - `benchmark({int iterations, int blockSize})`: Evaluación cuantitativa de rendimiento comparando el motor activo con el fallback.

2. **Integración en `TunnerOsKernel`:**
   - Se extiende el comando `dsp` para incorporar el subcomando `dsp bench [iteraciones] [tamano_bloque]`, midiendo y mostrando el tiempo total de procesamiento en microsegundos y la tasa de transferencia en mega-muestras por segundo (MSamples/s).

3. **Inmutabilidad y Cero Asignaciones en Tiempo Real:**
   - Para evitar presión sobre el recolector de basura (GC) durante el procesamiento de bloques de audio, las operaciones de búfer reutilizan estructuras de datos preasignadas.

---

## 3. Consecuencias

### Positivas
- **Aceleración Extrema de Suma y Ganancia:** La suma de canales de mezcla y ajuste de ganancia se ejecuta de forma casi instantánea a nivel bare-metal con instrucciones vectoriales del procesador.
- **Transparencia Operativa Total:** La telemetría en tiempo real (`dsp bench`) permite verificar experimentalmente la ganancia en microsegundos tanto en entornos de escritorio como móviles.
- **Preservación de Clean Architecture:** El dominio permanece puro y desacoplado, mientras que la infraestructura implementa el pipeline físico de cómputo.

### Mitigaciones de Seguridad y Robustez
- Todo método en `StudioMasterDspChain` comprueba longitudes nulas o búferes vacíos, delegando a operaciones seguras si se detectan incongruencias de tamaño.
