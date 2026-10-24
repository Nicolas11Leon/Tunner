# Implementation Plan: Interactive Practice Evaluation & Performance Analytics

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-PRACTICE-EVALUATION-2026-011`
- **Título de la Implementación:** `Evaluador de Práctica Interactivo, Calificación y Analítica de Tendencia Histórica`
- **Fase del Proyecto:** `Fase 3 & Fase 4`
- **Estado:** `Aprobado`
- **ADR Relacionado:** `docs/04_adrs/0005_interactive_practice_evaluator_and_analytics.md`
- **Documento Funcional Base:** `docs/02_use_cases/09_uc_practice_evaluation_and_performance_analytics.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Implementar el motor pedagógico interactivo de **Tunner** que evalúa en tiempo real la ejecución del músico sobre la partitura, ofreciendo:
1. Modo "Espera Inteligente" (*Smart Wait*) para sincronizar el avance del pentagrama únicamente ante ejecuciones afinadas.
2. Generación automática de un **Informe de Desempeño (Practice Report)** con calificación de estudio (S/A/B/C/D), medidores de precisión rítmica/tonal y análisis de mejora/declive respecto al historial.
3. Actualización de la identidad de la aplicación en `lib/main.dart` con branding profesional y estilo temático a nivel de sistema.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Módulo `lib/features/practice_evaluator/`:
    - `domain/note_evaluation_entity.dart`
    - `domain/practice_report_entity.dart`
    - `domain/i_practice_evaluator_service.dart`
    - `data/practice_evaluator_service.dart`
    - `presentation/practice_report_modal.dart`
  - Pruebas unitarias de dominio completas en `test/features/practice_evaluator/`.
  - Integración en `TunerViewModel` y controles en `TunerScreen`.
  - Refinamiento de `lib/main.dart` (título formal y tema dinámico).
- **Excluido (Out-of-Scope):**
  - Almacenamiento en servidores remotos en la nube (100% offline).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Entidades e Interfaces Puras)
- [ ] Crear `NoteEvaluationEntity` con notas esperadas, detectadas, cents y timing.
- [ ] Crear `PracticeReportEntity` y `HistoricalProgressEntity` con cálculo de notas críticas y tendencias ($\Delta\%$).
- [ ] Definir `IPracticeEvaluatorService`.

### Paso 2: Capa de Datos (Servicio de Evaluación Matemática)
- [ ] Implementar `PracticeEvaluatorService` calculando notas acertadas, tolerancia de cents y ponderación rítmica.
- [ ] Pruebas unitarias exhaustivas en `test/features/practice_evaluator/practice_evaluator_test.dart`.

### Paso 3: Capa de Presentación e Integración
- [ ] Conectar `TunerViewModel` con `IPracticeEvaluatorService`:
  - Flag `isPracticeModeActive` y `isSmartWaitEnabled`.
  - Acumulador de evaluaciones y generación automática de `lastReport`.
  - Historial de reportes para cálculo de mejora/declive continuo.
- [ ] Diseñar `PracticeReportModal` con estética ultra-premium (medallas de grado, gráficas circulares, mapa de calor de notas y análisis de tendencia).
- [ ] Botones de control en `TunerScreen` para activar Modo Práctica / Smart Wait y visualizar el último informe.

### Paso 4: Pulido de `main.dart` y Verificación
- [ ] Actualizar `lib/main.dart` con el nombre de producción y tema dark dinámico.
- [ ] Ejecutar `flutter test` y `flutter analyze`.

---

## 3. Criterios de Aceptación (Definition of Done)
- [ ] 100% pruebas pasando sin errores.
- [ ] `flutter analyze` con 0 advertencias o lints.
- [ ] Arquitectura limpia estrictamente respetada en `practice_evaluator`.
