# Plan de Implementación: Generador Algorítmico de Ejercicios y Escalas

Este documento define el plan estructurado para implementar el generador procedural de ejercicios en **Tunner**, cumpliendo con [AGENTS.md](AGENTS.md).

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE6-EXERCISES-2026-003`
- **Título:** Generador Procedural de Escalas, Arpegios y Rutinas Técnicas
- **Fase del Proyecto:** Fase 6 (Vanguardia Open Source)
- **Estado:** `Aprobado`
- **ADR Relacionado:** [ADR-0017](../04_adrs/0017_algorithmic_exercise_generator.md)
- **Documento Funcional Base:** [DOC-EXERCISE-GEN-2026-001](../01_product_vision/doc_algorithmic_exercise_generator.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Capacidad de generar instantáneamente partituras de escalas, arpegios e intervalos en compases $4/4$ conformes al estándar SMuFL para cualquier centro tonal.

### 1.2 Límites del Alcance
- **Incluido:**
  - `AlgorithmicExerciseGenerator` (Dart puro en `lib/features/exercise_generator/domain/`).
  - `ExerciseGeneratorModal` en `lib/features/exercise_generator/presentation/`.
  - Integración en `TunerViewModel`: `loadGeneratedExercise(...)`.
  - Pruebas unitarias de dominio y widgets.

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Dart Puro)
- [ ] Implementar enumeraciones `ExerciseType`, `ExerciseRhythm` y la clase `AlgorithmicExerciseGenerator`.
- [ ] Implementar la generación de notas diatónicas, intervalos y arpegios empaquetados en compases de 16 ticks.
- [ ] Crear suite de pruebas en `test/features/exercise_generator/algorithmic_exercise_generator_test.dart`.

### Paso 2: Integración y Capa de Presentación
- [ ] Conectar método `loadGeneratedExercise` en `TunerViewModel`.
- [ ] Crear `ExerciseGeneratorModal` con selectores de tónica, tipo y rítmica.
- [ ] Integrar botón de acceso en `TunerScreen`.
- [ ] Crear pruebas de widget en `test/features/exercise_generator/exercise_generator_ui_test.dart`.

### Paso 3: Verificación Completa
- [ ] `flutter analyze` (0 issues).
- [ ] `flutter test` (100% pasando).
