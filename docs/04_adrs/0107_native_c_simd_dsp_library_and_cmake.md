# ADR 0107: Implementación de Código C Nativo SIMD (libtunner_dsp) y CMake

**Estado:** Aprobado  
**Fecha:** 2026-11-18  
**Contexto Técnico:** Issue #61 (Fase 9 - Épica 9.2)  
**Autoridad:** Mantenedor Principal (@Nicolas11Leon)  

---

## 1. Contexto

La arquitectura de Tunner requiere una latencia de procesamiento de audio en tiempo real inferior a $10\text{ ms}$, con un objetivo óptimo inferior a $3\text{ ms}$ para monitoreo en vivo de afinación y síntesis acústica. En la Épica 9.1 se diseñó la interfaz de interoperabilidad `INativeDspBridge` y su puente `NativeDspFfiBridge`.

Para materializar la aceleración a nivel bare-metal, se requiere compilar una biblioteca binaria compartida en C (`libtunner_dsp`) que explote paralelismo de datos SIMD a nivel de registros de CPU (Intel/AMD AVX/SSE y ARM NEON en dispositivos móviles y Apple Silicon).

Se evaluaron tres opciones de implementación:
1. **Ensamblador manual (Inline Assembly / NASM):** Máximo control pero nula portabilidad entre x86_64, aarch64 y armv7.
2. **Rust nativo (`extern "C"` con `cbindgen`):** Alta seguridad de tipos y memoria, pero requiere toolchain de Cargo adicional y tiempos de compilación mayores.
3. **C99 Estándar con Auto-Vectorización del Compilador (`-O3 -ftree-vectorize`):** Máxima portabilidad en cualquier sistema POSIX / Windows / Android / iOS, compiladores ubicuos (GCC y Clang preinstalados) y código mantenible sin dependencias externas.

---

## 2. Decisión

Se adopta **C99 Estándar con directivas de auto-vectorización y desenrollado de bucles cuádruple**:
1. Se estructura el código fuente en `native/dsp/`:
   - `tunner_dsp.h`: Encabezado formal con visibilidad exportada (`__attribute__((visibility("default")))` en GCC/Clang y `__declspec(dllexport)` en Windows).
   - `tunner_dsp.c`: Implementación matemática de:
     - `tunner_apply_gain`: Multiplicación punto a punto vectorizada.
     - `tunner_vector_sum`: Suma lineal de señales vectorizada.
     - `tunner_autocorrelate`: Autocorrelación normalizada directa.
2. Se incorpora `native/dsp/CMakeLists.txt` configurando una biblioteca compartida (`SHARED`) con optimización `-O3 -fPIC`.
3. Se implementa el script ejecutable `scripts/build_native_dsp.sh` para compilar la biblioteca en entornos Linux y de pruebas continuas.
4. Se enlaza `NativeDspFfiBridge` en Dart mediante `DynamicLibrary.lookupFunction` resolviendo los símbolos C nativos cuando la biblioteca está presente en el sistema.

---

## 3. Consecuencias

### Positivas
- **Rendimiento Bare-Metal:** La auto-vectorización del compilador genera instrucciones vectoriales SIMD de 128 o 256 bits (`vmulps`, `vaddps`, etc.), procesando hasta 8 muestras de 32 bits por ciclo de reloj.
- **Portabilidad Total:** El código fuente C compila limpiamente en Linux, Android (NDK), macOS, iOS y Windows sin modificar una sola línea de código fuente.
- **Resiliencia Determinista:** Si la biblioteca compartida no está compilada en una máquina de desarrollo, la aplicación conmuta automáticamente al fallback de Dart puro sin fallos.

### Mitigaciones de Seguridad
- Las funciones en C validan rigurosamente que los punteros no sean nulos (`if (!buffer) return;`) y que la longitud sea positiva (`if (length <= 0) return;`) para prevenir fallos de segmentación (*segfaults*).
