# Plan de Implementación: Calibración de Afinación de Concierto A4 y Motor de Persistencia Local Offline

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE4-PITCH-PERSIST-2026-001`
- **Título de la Implementación:** Calibración de Afinación de Concierto A4 y Motor de Persistencia Local Offline Atómica
- **Fase del Proyecto:** Fase 4 (Estudio de Práctica & Integración Universal)
- **Estado:** En Progreso
- **ADR Relacionado:** [0009_reference_pitch_calibration_and_local_persistence.md](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/04_adrs/0009_reference_pitch_calibration_and_local_persistence.md)
- **Documento Funcional Base:** [doc_reference_pitch_and_local_persistence.md](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/01_product_vision/doc_reference_pitch_and_local_persistence.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Implementar la calibración continua de tono de concierto $A_4 \in [415.0, 466.0]\text{ Hz}$ en la capa de afinación y dotar al proyecto de un motor de persistencia local offline atómica para preservar configuraciones, temas personalizados, historial pedagógico y grabaciones entre ejecuciones.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Refactorizar `NoteEntity.fromFrequency` para aceptar parámetro opcional `a4Ref`.
  - Crear `AppUserSettingsEntity` e `ILocalPersistenceService` en `lib/features/persistence/domain/`.
  - Crear `JsonLocalPersistenceService` en `lib/features/persistence/data/` con escritura atómica.
  - Integrar calibración y persistencia en `TunerViewModel`.
  - Crear componente `ConcertPitchSelectorModal` y chip indicador en `TunerScreen`.
  - Escribir suite exhaustiva de tests unitarios y de widgets.
- **Excluido (Out-of-Scope):**
  - Sincronización en la nube (la arquitectura es 100% offline-first).
  - Parser universal de MusicXML/MIDI (se aborda en el siguiente hito).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.5`
- **Flutter SDK:** Estable
- **Persistencia:** Basada en `dart:io` y `path_provider`, con inyección de proveedor de ruta para pruebas unitarias sin plugins.
- **Riesgo Tecnológico:** Cero. No introduce nuevos plugins nativos ni llamadas de plataforma no lazy.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Modelos y Contratos)
- [ ] Refactorizar [note_entity.dart](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/lib/features/tuner/domain/note_entity.dart) para que `NoteEntity.fromFrequency(double freq, {double a4Ref = 440.0})` utilice $a_4$ en la fórmula de afinación MIDI.
- [ ] Crear `AppUserSettingsEntity` con soporte JSON (`toJson` / `fromJson`).
- [ ] Crear interfaz de contrato `ILocalPersistenceService`.

### Paso 2: Capa de Infraestructura (Persistencia Atómica)
- [ ] Implementar `JsonLocalPersistenceService` con soporte de escritura atómica temporal (`.tmp` + rename).
- [ ] Permitir inyección de directorio para pruebas deterministas sin `path_provider`.

### Paso 3: Capa de Integración & ViewModel
- [ ] Actualizar `TunerViewModel` para gestionar `referencePitch` ($415 - 466$ Hz).
- [ ] Incorporar `loadPersistedState()` y `savePersistedState()` automáticos.
- [ ] Asegurar que `_validatePerformance()` y `_pitchService.onPitchDetected` utilicen `referencePitch`.

### Paso 4: Capa de Presentación (UI)
- [ ] Crear `ConcertPitchSelectorModal` con presets (432, 440, 442, 444 Hz) y slider fino.
- [ ] Integrar chip de afinación de concierto en `TunerScreen`.

### Paso 5: Suite de Pruebas y Validación Final
- [ ] Tests de `NoteEntity` con diferentes frecuencias de referencia ($A_4 = 432$, $440$, $442$, $415$).
- [ ] Tests unitarios de persistencia local (`save` / `load` / corrupción de archivo / fallback).
- [ ] Tests de integración en `TunerViewModel`.
- [ ] `flutter analyze` (0 issues) y `flutter test` (100% passing).
