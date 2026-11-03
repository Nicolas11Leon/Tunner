# Implementation Plan: Structural Refactoring to Modular Monolith Feature-First Clean Architecture

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-ARCH-REFACTOR-FEATURE-FIRST-2026-011`
- **Título de la Implementación:** `Saneamiento Estructural a Monolito Modular Feature-First con Clean Architecture Estricta`
- **Fase del Proyecto:** `Fase 2 / Fase 3 / Fase 4 (Consolidación Arquitectónica)`
- **Estado:** `Completado`
- **ADR Relacionado:** `docs/04_adrs/0004_modular_monolith_feature_first_clean_architecture.md`
- **Documento Funcional Base:** `AGENTS.md` (Reglas Cardinales de Clean Architecture)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Reestructurar la base de código de **Tunner** desde la disposición plana anterior (`lib/data`, `lib/domain`, `lib/presentation`) hacia un **Monolito Modular Feature-First** organizado por contextos funcionales (`features/tuner`, `features/metronome`, `features/sheet_music`, `features/mixer`, `features/song_library` y `core/`), introduciendo **interfaces abstractas en el dominio** e **inyección de dependencias** en el ViewModel.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación de interfaces abstractas de dominio: `IPitchDetectorService`, `IMetronomeService`.
  - Reubicación de código y pruebas hacia carpetas de features independientes.
  - Extracción de componentes gigantes: mover `RealSheetMusicPainter` a `features/sheet_music/presentation/`.
  - Eliminación de la entidad plana duplicada `lib/domain/score_entity.dart` para unificar el dominio musical en `HierarchicalScore`.
  - Inyección de dependencias en `TunerViewModel`.
  - Actualización de todos los imports en `lib/` y `test/`.
  - Validación con 100% de tests verdes y 0 advertencias de linter.
- **Excluido (Out-of-Scope):**
  - Modificación de las matemáticas de DSP o de la UI funcional visible (la funcionalidad del usuario debe preservarse intacta al 100%).

---

## 2. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Módulo Core (`lib/core/`)
- [x] Mover el sistema de temas y paletas a `lib/core/theme/tunner_theme.dart`.

### Paso 2: Feature Tuner (`lib/features/tuner/`)
- [x] `domain/`: `note_entity.dart` e interfaz abstracta `i_pitch_detector_service.dart`.
- [x] `data/`: `pitch_detector_service.dart` implementando `IPitchDetectorService`.
- [x] `presentation/`: `strobe_tuner_widget.dart`.
- [x] Tests en `test/features/tuner/`.

### Paso 3: Feature Metronome (`lib/features/metronome/`)
- [x] `domain/`: `tempo_entity.dart` e interfaz abstracta `i_metronome_service.dart`.
- [x] `data/`: `metronome_service.dart` implementando `IMetronomeService`.
- [x] Tests en `test/features/metronome/`.

### Paso 4: Feature Sheet Music (`lib/features/sheet_music/`)
- [x] `domain/`: `score_tree.dart` (`HierarchicalScore`, `MeasureEntity`, `HierarchicalNote`, `TimeSignature`).
- [x] `presentation/`: extracción limpia de `real_sheet_music_painter.dart`.
- [x] Tests en `test/features/sheet_music/`.

### Paso 5: Feature Mixer & Tone Synthesis (`lib/features/mixer/`)
- [x] `domain/`: `mixer_track_entity.dart` (`AudioTrack`, `MixerConsoleEntity`).
- [x] `data/`: `tone_generator_service.dart` (síntesis senoidal pura y clics PCM).
- [x] Tests en `test/features/mixer/`.

### Paso 6: Feature Song Library & Decomposer (`lib/features/song_library/`)
- [x] `domain/`: `song_package_entity.dart`.
- [x] `data/`: `song_decomposer_service.dart` (biblioteca curada y descompositor de canciones).
- [x] Tests en `test/features/song_library/`.

### Paso 7: Orquestación, Inyección de Dependencias y UI Principal
- [x] Actualizar `TunerViewModel` para recibir `IPitchDetectorService` e `IMetronomeService` por inyector de dependencias (constructor con valores por defecto o factories).
- [x] Limpiar `tuner_screen.dart` para consumir los componentes modulares.
- [x] Eliminar archivos obsoletos en las carpetas raíz (`lib/data`, `lib/domain`, `lib/presentation/widgets/`).
- [x] Ejecutar `flutter analyze` y `flutter test`.

---

## 3. Criterios de Aceptación (Definition of Done)

- [x] Cero dependencias directas entre capas sin interfaces de dominio.
- [x] Cada feature vive en su Bounded Context autónomo.
- [x] `HierarchicalScore` es la única fuente de verdad para partituras.
- [x] 0 advertencias de `flutter analyze`.
- [x] 100% de tests unitarios pasando.
