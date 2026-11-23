# Registro de Decisión de Arquitectura (ADR) 0103: Arquitectura de Enlace Nativo `dart:ffi` con Fallback Transparente

---

## Metadatos

- **ID del ADR:** `ADR-0103`
- **Título:** Pasarela de Cómputo DSP Nativo Bare-Metal Mediante `dart:ffi` con Conmutación Transparente a Fallback Dart Puro
- **Estado:** `Approved`
- **Fecha:** `2026-11-18`
- **Fase Asociada:** `Fase 9`
- **Autor Principal:** `Nicolas Leon (Mantenedor Principal) / Antigravity Engine`
- **Caso de Uso Relacionado:** [Caso de Uso 114](../02_use_cases/114_uc_native_dsp_ffi_bridge_and_bare_metal_acceleration.md)
- **Plan Relacionado:** [Plan Épica 9.1](../05_implementation_plans/plan_native_dsp_ffi_bridge.md)
- **Issue Asociado:** [#53](https://github.com/Nicolas11Leon/Tunner/issues/53)

---

## 1. Contexto

La arquitectura no-negociable de Tunner prohíbe el uso de microservicios sobre la red o procesos externos pesados para tareas de procesamiento de audio en tiempo real. Cuando los límites de rendimiento de Dart se alcanzan en operaciones vectoriales masivas (ej. convolución FFT de 4096 muestras o análisis de fase polifónico), la estrategia canónica del proyecto dicta el uso de **enlaces nativos in-process (`dart:ffi`) con C, C++ o Rust**.

Restricciones:
1. **Portabilidad Universal:** La aplicación no debe fallar si se ejecuta en una plataforma o arquitectura donde el binario nativo compilado no está presente.
2. **Clean Architecture:** El contrato abstracto debe residir en la capa de dominio puro sin atarse a las llamadas FFI directas.

---

## 2. Decisión

Se adopta un **Patrón Bridge / Estrategia Dual de Dos Niveles**:

1. **`INativeDspBridge` (`lib/core/audio/domain/ffi/i_native_dsp_bridge.dart`):**
   - Interfaz de dominio que declara las operaciones de procesamiento por bloques:
     - `processGainBlock(Float32List buffer, double gain)`
     - `processVectorSum(Float32List a, Float32List b, Float32List out)`
     - `processAutoCorrelation(Float32List input, Float32List output)`
     - `isNativeAvailable`: Booleano que reporta si la aceleración C/Rust está activa.

2. **`NativeDspBridgeFallback` (`lib/core/audio/domain/ffi/native_dsp_bridge_fallback.dart`):**
   - Implementación pura en Dart con optimizaciones SIMD (`Float32x4`) cuando estén soportadas, garantizando funcionalidad total sin bibliotecas externas.

3. **`NativeDspFfiBridge` (`lib/core/audio/infrastructure/ffi/native_dsp_ffi_bridge.dart`):**
   - Implementación de infraestructura que intenta cargar dinámicamente la biblioteca del sistema (`libtunner_dsp.so`, `libtunner_dsp.dylib` o `tunner_dsp.dll`). Si la carga falla, delega silenciosamente todas las operaciones al fallback de Dart puro.

---

## 3. Consecuencias

### Positivas
- **Cero Riesgo de Caída:** Tunner puede compilarse y ejecutarse en cualquier dispositivo Android, iOS, Linux, Windows, macOS o Web sin requerir de forma mandatoria la compilación de C/Rust.
- **Rendimiento Máximo:** En sistemas con la biblioteca nativa presente, el cálculo se ejecuta a nivel de bare-metal con instrucciones vectoriales del procesador.
