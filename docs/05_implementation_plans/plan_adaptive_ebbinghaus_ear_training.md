# Plan de Implementación: Generador de Rutinas Adaptativas de Entrenamiento Auditivo con Curva Ebbinghaus

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE8-EBBINGHAUS-2026-0101`
- **Título de la Implementación:** Generador de Rutinas Adaptativas de Entrenamiento Auditivo con Curva de Retención Ebbinghaus
- **Fase del Proyecto:** Fase 8 (Suite Pedagógica y Analítica Cognitiva)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0101](../04_adrs/0101_adaptive_ebbinghaus_ear_training_engine.md)
- **Documento Funcional Base:** [Caso de Uso 112](../02_use_cases/112_uc_adaptive_ebbinghaus_ear_training_engine.md)
- **Issue Asociado:** [#39](https://github.com/Nicolas11Leon/Tunner/issues/39)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Construir en Dart puro dentro de `lib/features/pedagogy/domain/` el motor adaptativo de entrenamiento auditivo `EbbinghausSpacedRepetitionEngine` y la entidad inmutable `EarTrainingItemEntity`, proveyendo calendarización matemática de intervalos de repaso óptimos basada en la retención cognitiva de Ebbinghaus, y vincularlo con el kernel CLI de Tunner OS.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad `EarTrainingItemEntity` y categorización de intervalos / microtonos.
  - Motor `EbbinghausSpacedRepetitionEngine` con curva de olvido exponencial $R(t) = e^{-t/S}$.
  - Algoritmo de adaptación SM-2 calibrado para cents y latencia de respuesta.
  - Banco de ejercicios canónicos precargados (intervalos menores, mayores, justos, tríadas y microtonos).
  - Comando `train` en `TunnerOsKernel` para revisión, estado y calificación interactiva.
  - Suite de pruebas unitarias exhaustivas con inyección determinista de reloj temporal.
- **Excluido (Out-of-Scope):**
  - Asistente de evaluación vocal y generador de certificados PDF (asignado a Épica 8.2 e Issue #40).

---

## 2. Análisis de Dependencias y Tecnologías

- **Lenguaje:** Dart puro (Domain Layer).
- **Dependencias Externas:** Ninguna (`0 dependencies`).
- **Complejidad Algorítmica:** $O(N \log N)$ para ordenamiento de cola de repaso vencida, $O(1)$ para cálculo de retención por ítem.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Entidades y Modelos de Dominio (`lib/features/pedagogy/domain/`)
- Crear `ear_training_item_entity.dart`:
  - Propiedades: `id`, `name`, `category` (intervalo, acorde, microtono), `semitones`, `centsDeviation`, `stabilityDays`, `easeFactor`, `repetitions`, `lastReviewDate`, `nextReviewDate`.
  - Métodos inmutables `copyWith`, `retentionAt(DateTime now)`.

### Paso 2: Motor de Repetición Espaciada Ebbinghaus (`ebbinghaus_spaced_repetition_engine.dart`)
- Implementar la curva exponencial de retención $R(t)$.
- Implementar el cálculo de calificación de calidad $q \in [0, 5]$.
- Implementar el cálculo del próximo intervalo de repaso y actualización de estabilidad.
- Proveer catálogo canónico de intervalos (`getInitialCanonicalExerciseBank()`).
- Filtro `getDueItems(DateTime now)` ordenado por urgencia de retención.

### Paso 3: Integración en `TunnerOsKernel` CLI
- Registrar comando `train`:
  - `train review`: Muestra los ítems con retención crítica ($R \le 0.90$).
  - `train list`: Muestra todos los ítems del catálogo y su estabilidad.
  - `train answer <id> <cents_error> [tiempo_seg]`: Simula la respuesta de un ejercicio y calcula el nuevo agendamiento.
  - `train status`: Muestra métricas pedagógicas globales (retención promedio, ítems dominados).

### Paso 4: Pruebas Unitarias de Dominio e Integración (`test/features/pedagogy/`)
- Crear `test/features/pedagogy/ebbinghaus_spaced_repetition_test.dart`:
  - Pruebas matemáticas de la curva de Ebbinghaus y decaimiento temporal.
  - Pruebas de ajuste adaptativo del factor de facilidad (recompensas por rapidez y exactitud en microcents).
  - Pruebas de penalización y reseteo por fallos graves.
  - Pruebas de comandos CLI en `TunnerOsKernel`.

---

## 4. Criterios de Aceptación (Definition of Done)

1. Cálculo determinista de retención $R(t) = e^{-t/S}$ sin divergencias numéricas ni desbordamientos.
2. Adaptabilidad pedagógica demostrada: ítems difíciles se programan con mayor frecuencia que ítems dominados.
3. Cobertura de pruebas unitarias al 100% pasando sin fallos.
4. `flutter analyze` sin advertencias.
