# Plan de Implementación: US-1.2 Cadena DSP Master, Vúmetro Real y Grabación Master

## Metadatos del Plan
- **ID del Plan:** `PLAN-US-1.2-2026-01`
- **Título de la Implementación:** Cadena DSP Master, Vúmetro Balístico Real y Grabación Master
- **Fase del Proyecto:** Fase 1 / Hardening Cero Hardcoding
- **Estado:** Aprobado
- **ADR Relacionado:** [ADR 0139](docs/04_adrs/0139_master_dsp_chain_vu_meter_and_capture.md)
- **Documento Funcional Base:** [Caso de Uso 147](docs/02_use_cases/147_uc_master_dsp_chain_vu_meter_and_capture.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Integrar la cadena DSP de masterización y cálculo estricto de vúmetro en `StudioAudioDeviceMatrixService`, alimentando el servicio de grabación maestra con las muestras reales procesadas.

### 1.2 Límites del Alcance
- **Incluido (In-Scope):**
  - Adición de `processMasterStereoSamples` en `IStudioAudioDeviceMatrixPort` y `StudioAudioDeviceMatrixService`.
  - Conexión serial de filtros Biquad, compresor y ganancia maestra en `processMasterStereoSamples`.
  - Eliminación de niveles simulados en `_startMeterLoop`, implementando balística de decaimiento natural hacia cero.
  - Inyección de muestras procesadas en `_captureService.appendStereoSamples` cuando `isMasterRecording` es true.
  - Adición de pruebas unitarias exhaustivas en `test/core/audio/us_1_2_master_dsp_chain_and_rec_master_test.dart`.
- **Excluido (Out-of-Scope):**
  - Implementación de FFI C99 para autocorrelación o buffer de 4096 para $A_0$ (cubierto en US-1.3).
  - Voice pool y SF2 (cubierto en US-1.4).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Contrato de Dominio
- Actualizar `IStudioAudioDeviceMatrixPort` en `lib/core/audio/domain/i_studio_audio_device_matrix_port.dart`.

### Paso 2: Infraestructura DSP y Balística
- En `lib/core/audio/infrastructure/studio_audio_device_matrix_service.dart`:
  - Implementar `processMasterStereoSamples`.
  - Implementar cálculo de RMS y Peak reales.
  - Modificar `_startMeterLoop` para aplicar decaimiento exponencial balístico en reposo.
  - Canalizar muestras procesadas hacia `_captureService.appendStereoSamples`.

### Paso 3: Pruebas y Validación
- Crear `test/core/audio/us_1_2_master_dsp_chain_and_rec_master_test.dart`.
- Ejecutar `flutter analyze --no-fatal-infos` (0 issues).
- Ejecutar suite de pruebas completa.
