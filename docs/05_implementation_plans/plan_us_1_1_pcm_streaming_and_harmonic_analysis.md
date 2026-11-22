# Plan de Implementación: US-1.1 Streaming Real de Ventana PCM y Claridad NSDF en TunerViewModel & HarmonicSeriesAnalyzer

## Metadatos del Plan
- **ID del Plan:** `PLAN-US-1.1-2026-01`
- **Título de la Implementación:** Streaming Real de Ventana PCM, Claridad NSDF y Análisis Espectral sin Simulaciones
- **Fase del Proyecto:** Fase 1 / Hardening Cero Hardcoding
- **Estado:** Aprobado
- **ADR Relacionado:** [ADR 0138](docs/04_adrs/0138_real_pcm_streaming_clarity_and_harmonic_analysis.md)
- **Documento Funcional Base:** [Caso de Uso 146](docs/02_use_cases/146_uc_real_pcm_streaming_clarity_and_harmonic_analysis.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Conectar el flujo de audio de micrófono físico a la capa de análisis armónico y presentación en vivo, eliminando los fallbacks sintéticos $1/k^{1.2}$ y el 440 Hz hardcodeado en la interfaz.

### 1.2 Límites del Alcance
- **Incluido (In-Scope):**
  - Modificación de `lib/features/tuner/domain/i_pitch_detector_service.dart` para exponer callbacks de ventana y claridad.
  - Actualización de `lib/features/tuner/data/pitch_detector_service.dart` para emitir ventana PCM y claridad desde el Isolate.
  - Conexión de callbacks en `lib/features/tuner/presentation/tuner_viewmodel.dart`.
  - Eliminación de simulación $1/k^{1.2}$ y aplicación de ventana de Hann en `lib/features/acoustic_lab/domain/harmonic_series_analyzer.dart`.
  - Corrección de fallback 440 Hz en `lib/features/acoustic_lab/presentation/harmonic_spectrogram_modal.dart`.
  - Pruebas unitarias de regresión y verificación.
- **Excluido (Out-of-Scope):**
  - Cambios en el motor de masterización o consola DJ (cubiertos en US-1.2 y EPIC-02).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio
- Actualizar `IPitchDetectorService` con `onAudioWindowCaptured` y `onClarityDetected`.
- Refactorizar `HarmonicSeriesAnalyzer` para aplicar ventana de Hann y devolver `TimbreAnalysisResult.empty` si no hay muestras.

### Paso 2: Capa de Infraestructura / Datos
- En `PitchDetectorService._dspWorkerEntryPoint`, enviar en el mensaje de tono la claridad y una copia de la ventana flotante activa cada vez que se detecta tono o periódicamente.
- Conectar los despachos en el listener de `ReceivePort`.

### Paso 3: Capa de Presentación
- En `TunerViewModel`, asignar los callbacks para actualizar `_latestAudioSamples` y `_lastClarity`.
- En `HarmonicSpectrogramModal`, pasar `hasSignal ? vm.frequency : 0.0` y solo invocar análisis si `hasSignal` es verdadero.

### Paso 4: Pruebas y Validación
- Ejecutar `flutter analyze --no-fatal-infos`.
- Ejecutar pruebas unitarias correspondientes.
