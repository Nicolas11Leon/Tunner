# Plan de Implementación: Arquitectura de Enlace Nativo dart:ffi y Procesamiento DSP de Ultra-Baja Latencia

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE9-NATIVE-FFI-2026-0103`
- **Título de la Implementación:** Arquitectura de Enlace Nativo dart:ffi y Procesamiento DSP de Ultra-Baja Latencia
- **Fase del Proyecto:** Fase 9 (Motor Nativo FFI y Aceleración Bare-Metal)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0103](../04_adrs/0103_native_dsp_ffi_bridge_and_bare_metal_acceleration.md)
- **Documento Funcional Base:** [Caso de Uso 114](../02_use_cases/114_uc_native_dsp_ffi_bridge_and_bare_metal_acceleration.md)
- **Issue Asociado:** [#53](https://github.com/Nicolas11Leon/Tunner/issues/53)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Construir la infraestructura de enlace nativo en `lib/core/audio/` (`domain/ffi/` e `infrastructure/ffi/`) implementando el contrato `INativeDspBridge`, el motor de cálculo seguro `NativeDspBridgeFallback` y el cargador dinámico resiliente `NativeDspFfiBridge`, con integración de telemetría en `TunnerOsKernel`.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Contrato `INativeDspBridge` en `lib/core/audio/domain/ffi/`.
  - Implementación de respaldo determinista en Dart puro `NativeDspBridgeFallback`.
  - Implementación con carga dinámica FFI y degradación elegante `NativeDspFfiBridge` en `lib/core/audio/infrastructure/ffi/`.
  - Integración en comando `dsp status` de `TunnerOsKernel` para reportar si la aceleración nativa está activa o en modo fallback.
  - Pruebas unitarias de cálculo vectorial de ganancia, suma de mezclas y autocorrelación.
- **Excluido (Out-of-Scope):**
  - Compilación cruzada de binarios C/Rust en pipelines de CI (asignado a Fase 9.2).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Contrato de Dominio e Interfaz Abstracta
- Crear `lib/core/audio/domain/ffi/i_native_dsp_bridge.dart`.
- Crear `lib/core/audio/domain/ffi/native_dsp_bridge_fallback.dart`.

### Paso 2: Capa de Infraestructura FFI
- Crear `lib/core/audio/infrastructure/ffi/native_dsp_ffi_bridge.dart` utilizando `dart:ffi`.

### Paso 3: Integración en el Kernel de Estudio
- Integrar `INativeDspBridge` en `TunnerOsKernel` y en el comando `dsp status`.

### Paso 4: Pruebas Unitarias
- Crear `test/core/audio/native_dsp_ffi_bridge_test.dart` verificando corrección matemática, estabilidad de fallback y conmutación de interfaces.

---

## 3. Criterios de Aceptación (Definition of Done)

1. Funcionalidad transparente y determinista garantizada tanto con biblioteca nativa como en modo fallback de Dart puro.
2. Latencia de cómputo en bloque menor a $0.1\text{ ms}$ por búfer de 1024 muestras.
3. Cobertura de pruebas unitarias al 100% pasando sin errores.
4. `flutter analyze` sin incidencias.
