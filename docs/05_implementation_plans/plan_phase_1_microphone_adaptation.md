# Implementation Plan: Real-Time Microphone Adaptation, DC-Blocking Filter, and Noise Floor Profiling

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE1-MIC-ADAPTATION-2026-041`
- **Título de la Implementación:** `Sistema de Calibración de Micrófono, Perfilado de Ruido Ambiental y Filtro DC-Blocker`
- **Fase del Proyecto:** `Fase 1 / Fase 3`
- **Estado:** `Completado`
- **ADR Relacionado:** `docs/04_adrs/0037_microphone_adaptation_and_noise_profiling.md`
- **Documento Funcional Base:** `docs/02_use_cases/41_uc_microphone_calibration_and_adaptation.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Optimizar la captura acústica en cualquier micrófono y dispositivo mediante:
1. **Filtro DC-Blocker IIR** ($15\text{ Hz}$) y **multiplicador de ganancia de entrada digital** ($0.2\times$ a $5.0\times$) procesados en tiempo real dentro del DSP Isolate.
2. **Perfilador de Piso de Ruido (`NoiseFloorProfiler`)** en Pure Dart para calibrar automáticamente el Noise Gate según el ruido de sala.
3. **Soporte de selección de dispositivos de entrada de micrófono** (`AudioDevice` en `PitchDetectorService`).
4. **Modal interactivo `MicrophoneCalibrationModal`** con medidor de nivel VU en tiempo real (dBFS), asistente de calibración de ruido de 2 segundos y control manual de ganancia y umbral de silencio.
5. **Persistencia local** de la calibración de micrófono para que se mantenga entre sesiones.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Modelos matemáticos de calibración en `lib/features/tuner/domain/microphone_calibration_models.dart`.
  - Filtro DC-Blocker y acondicionador de señal en `lib/features/tuner/domain/signal_conditioning_filter.dart`.
  - Integración en `PitchDetectorService` y su worker Isolate.
  - Integración en `TunerViewModel` y persistencia en `JsonLocalPersistenceService`.
  - Interfaz gráfica en `lib/features/tuner/presentation/microphone_calibration_modal.dart`.
  - Pruebas unitarias completas de filtros, matemáticas y asistente de ruido.
- **Excluido (Out-of-Scope):**
  - Drivers propietarios de tarjetas ASIO en Windows (fuera del alcance de Flutter).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.5`.
- **Flutter Framework:** Sin nuevas dependencias de paquetes (aprovecha `record: ^6.2.1` ya instalado para enumeración de dispositivos y stream PCM).
- **Riesgo Tecnológico:** **Bajo**. Algoritmos matemáticos y procesamiento en streaming en Isolate existente.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos y Filtros Matemáticos)
- [x] Crear `lib/features/tuner/domain/microphone_calibration_models.dart`:
  - `MicrophoneCalibrationProfile`, `NoiseProfileReport`.
- [x] Crear `lib/features/tuner/domain/signal_conditioning_filter.dart`:
  - Filtro IIR de un polo DC-Blocker ($15\text{ Hz}$).
  - Acondicionador de ganancia y pre-énfasis opcional.
  - Perfilador de piso de ruido estadístico.

### Paso 2: Capa de Infraestructura / Datos
- [x] Actualizar `PitchDetectorService`:
  - Permitir pasar configuración de ganancia, umbral de silencio y filtro DC al worker Isolate.
  - Agregar soporte para seleccionar `AudioDevice` de entrada.
  - Exponer método de calibración rápida de ruido ambiental.

### Paso 3: Capa de Aplicación y Persistencia
- [x] Actualizar `AppUserSettingsEntity` y `JsonLocalPersistenceService` para guardar la calibración del micrófono.
- [x] Actualizar `TunerViewModel`:
  - Métodos `calibrateNoiseFloor()`, `setInputGain()`, `setSilenceThreshold()`, `selectInputDevice()`.
  - Exponer stream de nivel RMS actual para el medidor VU en la UI.

### Paso 4: Capa de Presentación (UI Modal & Widgets)
- [x] Crear `lib/features/tuner/presentation/microphone_calibration_modal.dart`:
  - Medidor de nivel VU interactivo con indicador de umbral de corte.
  - Botón de auto-calibración de ruido ambiental con barra de progreso.
  - Sliders para ganancia manual y umbral de silencio.
  - Selector desplegable de dispositivos físicos de micrófono.
- [x] Integrar botón de acceso en `TunerScreen`.

### Paso 5: Pruebas Unitarias y Verificación
- [x] Crear `test/features/tuner/microphone_calibration_test.dart`:
  - Pruebas del filtro DC-Blocker, eliminación de bias, cálculo de ganancia y perfilado de ruido.
- [x] Ejecutar `flutter test` garantizando 100% de tests pasando.
- [x] Commit y push a `main`.

---

## 4. Estrategia de Rollback
- Revertir al commit `2e07e2c` si se detecta alguna anomalía.

---

## 5. Criterios de Aceptación (Definition of Done)
- [x] El filtro DC-Blocker reduce a 0.0 cualquier desplazamiento constante de señal.
- [x] El Noise Gate se adapta automáticamente al ruido ambiental medido.
- [x] Medidor VU y calibrador interactivo funcionan de forma fluida.
- [x] Todos los tests de Flutter pasando al 100%.
- [x] Sincronizado en `main`.
