# Implementation Plan: Código C/C++ Nativo SIMD (libtunner_dsp) y CMake

**Issue Asociado:** #61 (Fase 9 - Épica 9.2)  
**Rama:** `feature/native-c-simd-dsp-library`  
**Rama Base:** `qa`  
**Fecha:** 2026-11-18  

---

## 1. Resumen y Objetivos

Implementar la biblioteca en código C99 (`libtunner_dsp`) para aceleración matemática de audio en tiempo real, configurar su sistema de compilación cruzada con CMake, implementar el script de automatización de compilación y conectar la resolución dinámica de punteros FFI en `NativeDspFfiBridge`.

---

## 2. Tareas de Implementación

### Tarea 1: Código Fuente C99 Nativo
- [ ] Crear directorio `native/dsp/`.
- [ ] Crear `native/dsp/tunner_dsp.h`:
  - Macro `TUNNER_EXPORT` para portabilidad cruzada (Windows `dllexport` / POSIX `default visibility`).
  - Prototipos de función:
    - `void tunner_apply_gain(float* buffer, int length, float gain);`
    - `void tunner_vector_sum(const float* a, const float* b, float* out, int length);`
    - `void tunner_autocorrelate(const float* input, float* output, int length);`
- [ ] Crear `native/dsp/tunner_dsp.c`:
  - Validaciones de punteros nulos y longitud `<= 0`.
  - Desenrollado de bucles cuádruple (`#pragma GCC unroll 4` o desenrollado manual de 4 en 4 elementos).
  - Algoritmo de autocorrelación normalizada para estimación de tono fundamental.

### Tarea 2: Sistema de Construcción CMake y Script Automatizado
- [ ] Crear `native/dsp/CMakeLists.txt`:
  - Declaración de proyecto `tunner_dsp` en C99.
  - Creación de target de biblioteca compartida `tunner_dsp`.
  - Opciones de compilación: `-O3 -fPIC -Wall -Wextra`.
- [ ] Crear `scripts/build_native_dsp.sh`:
  - Detección de compilador (GCC o Clang).
  - Creación de directorio `build/native/` y compilación de `libtunner_dsp.so` o biblioteca de plataforma.
  - Copia de la biblioteca compartida a una ubicación accesible para pruebas y ejecución (`build/native/` y/o raíz).

### Tarea 3: Enlace FFI en Dart
- [ ] Actualizar `lib/core/audio/infrastructure/ffi/native_dsp_ffi_bridge.dart`:
  - Definir typedefs de C y Dart para las 3 funciones nativas.
  - En `_initDynamicLibrary`, resolver punteros de función mediante `lookupFunction`.
  - En `applyGain`, `vectorSum` y `autoCorrelate`, invocar la función nativa C a través de punteros de memoria cuando `_isNative == true`.
  - Mantener fallback automático si la biblioteca no se encuentra.

### Tarea 4: Batería de Pruebas Unitarias y de Paridad Numérica
- [ ] Crear `test/core/audio/native_dsp_ffi_simd_test.dart`:
  - Probar la compilación y carga de `libtunner_dsp`.
  - Comparar matemáticamente la salida de `applyGain`, `vectorSum` y `autoCorrelate` entre el código C y `NativeDspBridgeFallback` (paridad con tolerancia $< 10^{-5}$).
  - Comprobar la tolerancia a fallos con búferes vacíos o parámetros límite.

---

## 3. Criterios de Aceptación (DoD)
- Todas las pruebas unitarias pasan sin errores.
- `flutter analyze --no-fatal-infos` con 0 incidencias.
- Código C99 limpio y seguro sin fugas de memoria ni punteros colgantes.
- Cero emojis en código fuente, comentarios y commits.
- PR creado hacia `qa` y fusionado en `qa`.
