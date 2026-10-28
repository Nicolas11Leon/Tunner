# Plan de Implementación: Perfiles Pedagógicos Adaptativos y Andamiaje Instruccional Dinámico

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-PEDAGOGY-2026-034`
- **Título de la Implementación:** Motor de Perfiles Pedagógicos Adaptativos y Andamiaje Instruccional Dinámico
- **Fase del Proyecto:** Fase 13 (Analítica Pedagógica y Adaptación al Usuario)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0030](../04_adrs/0030_adaptive_pedagogical_profiles_and_scaffolding.md)
- **Documento Funcional Base:** [doc_pedagogical_foundations_andragogy_pedagogy_adaptation.md](../01_product_vision/doc_pedagogical_foundations_andragogy_pedagogy_adaptation.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Implementar un sistema integral de personalización pedagógica y andamiaje dinámico en Pure Dart que adapte las tolerancias de afinación ($\Delta c$), el estilo de retroalimentación (lúdico infantil, constructivo andragógico o analítico de conservatorio) y la densidad visual de Tunner en tiempo real, garantizando una curva de aprendizaje óptima para cada franja de edad y objetivo musical.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades de dominio puras: `LearnerProfileType`, `LearnerProfileEntity`, `FeedbackStyle`, `VisualDensityLevel`.
  - Motor de dominio: `AdaptiveScaffoldingEngine` con algoritmos de andamiaje progresivo y diagnóstico biomecánico/lúdico.
  - Persistencia offline en `AppUserSettingsEntity` y `JsonLocalPersistenceService`.
  - Orquestación en `TunerViewModel`: Umbrales de afinación dinámicos consumidos por el afinador y evaluador de notas.
  - Interfaz de usuario: `LearnerProfileSelectorModal` y chip de acceso rápido en `TunerScreen`.
  - Pruebas unitarias de dominio y pruebas de widgets/UI.
- **Excluido (Out-of-Scope):**
  - Modelos de telemetría remota o seguimiento en la nube (el sistema se mantiene 100% offline, local y privado).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`.
  - Flutter SDK: Canal estable oficial.
- **Riesgo Tecnológico:**
  - Cero dependencias externas adicionales; algoritmos en memoria en Pure Dart con tiempo de ejecución sub-milisegundo.
  - Cero bucles de espera activa (no busy-waiting).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Motor de Andamiaje)
- [x] Crear `lib/features/pedagogy_profiles/domain/learner_profile_entity.dart`:
  - `LearnerProfileType` (`childPlayful`, `adultDeliberate`, `conservatoryMastery`, `custom`).
  - `FeedbackStyle` (`playfulEncouraging`, `constructiveBiomechanical`, `strictMicrotonal`).
  - `VisualDensityLevel` (`minimalPlayful`, `focusedAndragogic`, `fullObservatory`).
  - `LearnerProfileEntity` con serialización JSON, presets de fábrica e inmutabilidad.
- [x] Crear `lib/features/pedagogy_profiles/domain/adaptive_scaffolding_engine.dart`:
  - Algoritmo de evaluación adaptativa con ventana de tolerancia dinámica.
  - Generación de pautas formativas contextualizadas para niños y adultos.
  - Desvanecimiento progresivo del andamiaje (*scaffolding fade-out*).
- [x] Pruebas unitarias de dominio en `test/features/pedagogy_profiles/adaptive_scaffolding_engine_test.dart`.

### Paso 2: Persistencia Offline y Orquestación en ViewModel
- [x] Integrar `learnerProfile` en `AppUserSettingsEntity`:
  - Serialización y deserialización determinista en `JsonLocalPersistenceService`.
  - Pruebas unitarias de persistencia actualizadas.
- [x] Extender `TunerViewModel`:
  - Getter `currentLearnerProfile`.
  - Método `setLearnerProfile(LearnerProfileType type)` y `updateCustomLearnerProfile(LearnerProfileEntity profile)`.
  - Actualización de tolerancias de afinación reactivas en `_cents` evaluation y evaluador de notas.

### Paso 3: Capa de Presentación (Modal y Acceso Rápido)
- [x] Crear `lib/features/pedagogy_profiles/presentation/learner_profile_selector_modal.dart`:
  - Tarjetas interactivas para cada perfil con estética de conservatorio y distintivos visuales.
  - Explicación clara de la justificación pedagógica de cada modo.
- [x] Integrar botón / chip selector en `TunerScreen` (`open_learner_profile_chip`).

### Paso 4: Pruebas, Verificación y Aprobación
- [x] Pruebas de integración UI en `test/features/pedagogy_profiles/learner_profile_ui_test.dart`.
- [x] Verificar 100% de la suite de pruebas pasando (`flutter test`).
- [x] Verificar `flutter analyze` limpio sin advertencias ni errores.
- [x] Merge a `main` con `--no-ff`.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- Si surge alguna regresión, se revierte al commit base de `main` mediante Git sin alterar el núcleo acústico ni el reloj de audio.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md) (cero emojis, nombres rigurosos, Clean Architecture).
- [x] Adaptación dinámica inmediata de la tolerancia en cents y de las pautas diagnósticas.
- [x] Cobertura de pruebas unitarias y de interfaz superando el 90%.
- [x] Documentación canónica completa en `docs/`.
