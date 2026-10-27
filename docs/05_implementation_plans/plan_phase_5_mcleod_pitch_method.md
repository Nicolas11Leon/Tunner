# Plan de Implementación: McLeod Pitch Method (MPM) Pitch Detection Engine

Este documento define el plan estructurado de ingeniería para la implementación e integración del algoritmo de detección de tono acústico **McLeod Pitch Method (MPM)** en el núcleo de **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE5-MPM-2026-001`
- **Título de la Implementación:** Motor Matemático McLeod Pitch Method (MPM) con NSDF e Interpolación Parabólica en Pure Dart
- **Fase del Proyecto:** Fase 5 (Vanguardia Acústica y Aprendizaje Musical)
- **Estado:** Aprobado
- **ADR Relacionado:** [docs/04_adrs/0012_mcleod_pitch_method_pitch_detection.md](../04_adrs/0012_mcleod_pitch_method_pitch_detection.md)
- **Documento Funcional Base:** [docs/01_product_vision/doc_mcleod_pitch_method_pitch_detection.md](../01_product_vision/doc_mcleod_pitch_method_pitch_detection.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Reemplazar la dependencia de librerías externas de detección de tono por una implementación nativa en Pure Dart del **McLeod Pitch Method (MPM)**, logrando precisión sub-cent, cero saltos de octava en sobretonos armónicos y aislamiento estricto dentro de la capa de Dominio en Clean Architecture.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación de `lib/features/tuner/domain/mcleod_pitch_method.dart` con la clase `McleodPitchMethod` y entidad inmutable `PitchDetectionResult`.
  - Conversión rigurosa de PCM little-endian de 16 bits a muestras flotantes normalizadas $[-1.0, 1.0]$.
  - Cálculo de RMS para Noise Gate.
  - Implementación de la función NSDF, selección de picos con umbral relativo $k = 0.90$ e interpolación cuadrática.
  - Actualización de `PitchDetectorService` en `lib/features/tuner/data/pitch_detector_service.dart` para utilizar el motor MPM dentro del Isolate secundario.
  - Suite de pruebas unitarias con señales senoidales matemáticas ($440\text{ Hz}$, $261.63\text{ Hz}$, $880\text{ Hz}$ con segundo armónico).
- **Excluido (Out-of-Scope):**
  - Modificación de los contratos de UI o del `TunerViewModel` (la API de emisión en Hz se preserva intacta).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Pure Dart MPM)
- [x] Redacción de documentación técnica, caso de uso y ADR.
- [ ] Creación de `lib/features/tuner/domain/mcleod_pitch_method.dart`.
- [ ] Implementación de:
  - `convertPcm16BytesToFloats(Uint8List bytes)`
  - `calculateRms(Float64List samples)`
  - `computeNsdf(Float64List samples, int maxLag)`
  - `findKeyPeak(Float64List nsdf, double kThreshold)`
  - `parabolicInterpolation(Float64List nsdf, int peakIndex)`
  - `estimatePitch(Float64List samples, {int sampleRate = 44100})`
- [ ] Creación de suite de pruebas unitarias `test/features/tuner/mcleod_pitch_method_test.dart`.

### Paso 2: Capa de Infraestructura / Datos (Integración en Isolate Worker)
- [ ] Actualización de `PitchDetectorService` en `lib/features/tuner/data/pitch_detector_service.dart`.
- [ ] Sustitución del wrapper previo por `McleodPitchMethod` en `_dspWorkerEntryPoint`.
- [ ] Verificación de buffering y umbrales acústicos.

### Paso 3: Verificación y Análisis Estático
- [ ] Ejecución de `flutter analyze` (0 issues).
- [ ] Ejecución de toda la suite de pruebas unitarias de Flutter (100% de éxito).

---

## 3. Criterios de Aceptación (Definition of Done)
1. El archivo `mcleod_pitch_method.dart` pertenece exclusivamente a la capa de dominio en Pure Dart.
2. Detección comprobada de señales senoidales de $440.0\text{ Hz}$ con error $\le \pm 0.2\text{ cents}$.
3. Tolerancia frente a sobretonos armónicos sin saltos de octava.
4. Todo el conjunto de pruebas pasa al 100%.
