# Plan de Implementación: Suite Vocal con Auto-Tune en Tiempo Real, Grabación Multitrack y Edición Microtonal en Pentagrama

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE5-VOCAL-SUITE-2026-058`
- **Título de la Implementación:** Integración Sinérgica de Auto-Tune, Grabadora Multipista, Conversor Vocal a Pentagrama y Síntesis SoundFont
- **Fase del Proyecto:** Fase 5 (Modular Studio & Hiper-Sinergia)
- **Estado:** En Progreso
- **ADR Relacionado:** [`0054_vocal_suite_autotune_multitrack_and_score_pitch_editing.md`](../04_adrs/0054_vocal_suite_autotune_multitrack_and_score_pitch_editing.md)
- **Documento Funcional Base:** [`doc_vocal_suite_autotune_multitrack_and_score_pitch_editing.md`](../01_product_vision/doc_vocal_suite_autotune_multitrack_and_score_pitch_editing.md)

---

## 1. Alcance y Objetivos

### 1.1 Objetivo Primario
Crear el motor de conversión y edición tonal vocal `VocalScoreConverter` en el dominio puro, extender `MultiTrackSample` con metadata de afinación corregida en tiempo real por el Auto-Tune, y permitir que una toma vocal grabada se convierta en una partitura editable con 1 tap, permitiendo audición y alineación a escala con SoundFont SF2.

### 1.2 Límites del Alcance
- **In-Scope:**
  - Extender `MultiTrackSample` con `correctedPitchHz`, `centsDeviation`, `isAutoTuned`.
  - Crear `VocalScoreConverter` en `lib/features/vocal_autotune/domain/vocal_score_converter.dart`.
  - Métodos en `TunerViewModel`: `convertActiveRecordingToScorePackage()`, `snapActiveScoreToScale()`.
  - Integrar botón de acción en `PracticeRecordingPlayerModal` y `VocalAutoTuneModal`: *"Editar Afinación en Pentagrama"*.
  - Pruebas unitarias de dominio para `VocalScoreConverter` y pruebas de integración en `TunerViewModel`.
- **Out-of-Scope:**
  - Plugins VST/AU de escritorio (la aplicación es offline-first y multiplataforma en Flutter/Dart).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Dominio Puro y Modelos
- [ ] Actualizar `MultiTrackSample` en `lib/features/practice_recorder/domain/multitrack_session_entity.dart`.
- [ ] Implementar `VocalScoreConverter` en `lib/features/vocal_autotune/domain/vocal_score_converter.dart`.
- [ ] Escribir pruebas unitarias exhaustivas en `test/features/vocal_autotune/vocal_score_converter_test.dart`.

### Paso 2: Integración en `TunerViewModel`
- [ ] Registrar muestras de grabación con `correctedPitchHz` y `centsDeviation` cuando Auto-Tune está activo.
- [ ] Implementar `convertActiveRecordingToScorePackage()` y `snapActiveScoreToScale()`.
- [ ] Escribir pruebas de integración en `test/features/vocal_autotune/vocal_suite_integration_test.dart`.

### Paso 3: Interfaz de Usuario y Sinergia
- [ ] Añadir botón de acción en `PracticeRecordingPlayerModal` para abrir la partitura generada.
- [ ] Enlace de acceso directo desde `VocalAutoTuneModal`.

### Paso 4: Quality Gate y Merge
- [ ] `flutter analyze` limpio (0 errores, 0 advertencias).
- [ ] `flutter test` ejecutando toda la suite de pruebas al 100%.
- [ ] PR y merge administrativo a `main`.
