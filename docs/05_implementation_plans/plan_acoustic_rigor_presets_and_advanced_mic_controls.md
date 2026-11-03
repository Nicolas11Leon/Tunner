# Implementation Plan: Presets de Rigurosidad Acústica y Controles Avanzados de Micrófono (Noob vs. Pro)

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE1-ACOUSTIC-RIGOR-2026-045`
- **Título de la Implementación:** `Presets de Rigurosidad Acústica por Contexto y Controles de Micrófono de Doble Nivel`
- **Fase del Proyecto:** `Fase 1 / Fase 3 (DSP & Ergonomía Acústica)`
- **Estado:** `Completado`
- **ADR Relacionado:** `docs/04_adrs/0040_acoustic_rigor_presets_and_advanced_mic_controls.md`
- **Documento Funcional Base:** `docs/02_use_cases/44_uc_acoustic_rigor_presets_and_advanced_mic_controls.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Implementar un sistema configurable y adaptativo de ingesta acústica con presets de un solo toque ("Principiante", "Ensayo", "Grabación", "Escenario", "Conservatorio") y una modalidad avanzada para productores e ingenieros con control granular de parámetros DSP (claridad, cents, frames de Tone Lock, Noise Gate, ganancia digital).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad de dominio `AcousticRigorProfile` y enum `AcousticRigorPreset` en `lib/features/tuner/domain/acoustic_rigor_profile.dart`.
  - Integración en `TunerViewModel`: sincronización de presets, conmutación simple/avanzado y delegación al Isolate de audio.
  - Persistencia de `AcousticRigorProfile` en `AppUserSettingsEntity` y `LocalPersistenceService`.
  - Renovación del modal de calibración de micrófono (`MicrophoneCalibrationModal`) para incluir selector de modo (Presets vs. Avanzado) y controles dedicados.
  - Pruebas unitarias y de interfaz completas.
- **Excluido (Out-of-Scope):**
  - Servicios de procesamiento de audio en la nube (la arquitectura es 100% offline y local en el dispositivo).

---

## 2. Análisis de Dependencias y Tecnologías
- **Dart SDK:** `^3.11.5`.
- **Cero dependencias externas adicionales.** Arquitectura limpia en memoria.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Modelos Matemáticos y Presets)
- [x] Crear `lib/features/tuner/domain/acoustic_rigor_profile.dart`:
  - Enum `AcousticRigorPreset` con valores: `beginner`, `balancedRehearsal`, `studioRecording`, `noisyStage`, `conservatoryMastery`, `custom`.
  - Clase inmutable `AcousticRigorProfile` con `toJson`, `fromJson`, `copyWith`, cálculo de parámetros y factories de presets.

### Paso 2: Capa de Persistencia
- [x] Actualizar `AppUserSettingsEntity` para almacenar y restaurar `AcousticRigorProfile`.

### Paso 3: Capa de Aplicación / ViewModel
- [x] Actualizar `TunerViewModel`:
  - Campo `AcousticRigorProfile _acousticRigorProfile`.
  - Métodos `setAcousticRigorPreset(AcousticRigorPreset preset)`, `setAcousticRigorAdvancedParameters(...)`, `toggleAcousticRigorAdvancedView()`.
  - Sincronización transparente con `_pitchService.setInstrumentAcousticFilter` y `_pitchService.setMicrophoneProfile`.

### Paso 4: Capa de Presentación (UI)
- [x] Actualizar `MicrophoneCalibrationModal` en `lib/features/tuner/presentation/microphone_calibration_modal.dart`:
  - Segmented control / Tabs: `Presets Sencillos` vs. `Modo Avanzado / Productor`.
  - Vista sencilla con tarjetas informativas y reactivas para cada preset.
  - Vista avanzada con sliders para claridad armónica, desviación en cents, frames de confirmación y ganancia.

### Paso 5: Pruebas Unitarias y Verificación
- [x] Crear `test/features/tuner/acoustic_rigor_profile_test.dart`.
- [x] Ejecutar `flutter analyze` y `flutter test`.

---

## 4. Estrategia de Rollback
- Si se detecta alguna anomalía, restaurar valores nominales de fábrica con el preset `balancedRehearsal`.

---

## 5. Criterios de Aceptación (Definition of Done)
- [x] La selección de presets configura automáticamente el Noise Gate, la claridad MPM y el Tone Lock.
- [x] El modo avanzado permite ajustar independientemente cada parámetro acústico.
- [x] Las preferencias se persisten entre reinicios de la aplicación.
- [x] `flutter analyze` reporta 0 issues y 100% de los tests pasan.
