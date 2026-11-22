# Plan de Implementación: US-1.3 FFI Autocorrelación, Expansión Búfer 4096 para La0 y Calibración DC

## Metadatos del Plan
- **ID del Plan:** `PLAN-US-1.3-2026-01`
- **Título de la Implementación:** FFI Autocorrelación, Búfer de 4096 Muestras, Anclaje A4 y Calibración DC Offset
- **Fase del Proyecto:** Fase 1 / Hardening Cero Hardcoding
- **Estado:** Aprobado
- **ADR Relacionado:** [ADR 0140](docs/04_adrs/0140_ffi_autocorrelation_buffer_expansion_and_dc_calibration.md)
- **Documento Funcional Base:** [Caso de Uso 148](docs/02_use_cases/148_uc_ffi_autocorrelation_buffer_expansion_and_dc_calibration.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Optimizar el rendimiento de la función NSDF con sumas acumuladas $O(N)$ y FFI C99, expandir la capacidad del estimador hasta La0 ($27.5\text{ Hz}$) mediante un búfer de 4096 muestras, calibrar el offset DC e inmutabilizar el anclaje de La4 en temperamentos.

### 1.2 Límites del Alcance
- **Incluido (In-Scope):**
  - Refactorizar `McleodPitchMethod.computeNsdf` para emplear sumas acumuladas de energía $O(N)$ y puente nativo opcional `INativeDspBridge`.
  - Configurar ventana deslizante de 4096 muestras en `PitchDetectorService`.
  - Pasar `anchorA4: true` en `TunerViewModel`.
  - Agregar `calibratedDcOffset` en `SignalConditioningFilter`.
  - Pruebas unitarias de regresión y verificación acústica.
- **Excluido (Out-of-Scope):**
  - Modificaciones en sintetizador SF2 o DSL de metrónomo (cubierto en US-1.4).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (DSP y Matemáticas)
- En `lib/features/tuner/domain/mcleod_pitch_method.dart`:
  - Implementar sumas de prefijo cuadráticas $E[k]$ para reducir el cálculo de energía a tiempo constante $O(1)$ por lag $\tau$.
  - Permitir inyección de `INativeDspBridge` para aceleración C99 de la correlación cruzada.
- En `lib/features/tuner/domain/signal_conditioning_filter.dart`:
  - Agregar campo `double calibratedDcOffset` y sustraerlo en `conditionSamples`.

### Paso 2: Capa de Infraestructura / Datos
- En `lib/features/tuner/data/pitch_detector_service.dart`:
  - Soportar tamaño de ventana completa de 4096 muestras para señales de baja frecuencia ($25\text{ Hz}$).

### Paso 3: Capa de Presentación
- En `lib/features/tuner/presentation/tuner_viewmodel.dart`:
  - Pasar `anchorA4: true` a `_temperamentEngine.getTargetFrequency`.

### Paso 4: Pruebas y Validación
- Crear `test/features/tuner/us_1_3_ffi_autocorrelation_and_buffer_4096_test.dart`.
- Ejecutar `flutter analyze --no-fatal-infos` (0 issues).
- Ejecutar suite de pruebas.
