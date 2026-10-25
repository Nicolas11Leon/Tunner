# Implementation Plan: Multi-Instrument Transposition & Multi-Dimensional Analytics

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-MULTI-INSTRUMENT-2026-012`
- **Título de la Implementación:** `Transposición Multi-Instrumento y Analítica Multidimensional de Interpretación`
- **Fase del Proyecto:** `Fase 3 & Fase 4`
- **Estado:** `Aprobado`
- **ADR Relacionado:** `docs/04_adrs/0006_multi_instrument_transposition_and_multidimensional_analytics.md`
- **Documento Funcional Base:** `docs/02_use_cases/10_uc_multi_instrument_transposition_and_multidimensional_metrics.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Incorporar a **Tunner** el catálogo y motor de transposición para instrumentos en Do, Si♭, Mi♭, Fa y Clave de Fa/Bajo, junto a la ampliación de la evaluación interpretativa para medir afinación, tempo con tendencia *rushing/dragging* y sostenimiento rítmico (*sustain ratio*).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Módulo `lib/features/instrument/`:
    - `domain/instrument_profile_entity.dart` (perfiles de instrumentos universales: Flauta, Trompeta Bb, Clarinete Bb, Saxo Alto Eb, Saxo Tenor Bb, Corno Francés F, Violín, Guitarra, Cello/Bajo).
    - `domain/i_instrument_transposition_service.dart`.
    - `data/instrument_transposition_service.dart`.
  - Ampliación de `lib/features/practice_evaluator/`:
    - Incorporación de `sustainPercentage`, `timingDeltaMs`, `RhythmDriftTendency` en `NoteEvaluationEntity` y `PracticeReportEntity`.
    - Algoritmo de cálculo de tendencia de tempo (*rushing*, *dragging*, *estable*) y promedio de sostenimiento.
  - Integración en `TunerViewModel`:
    - Selección de instrumento activo (`activeInstrumentProfile`).
    - Transposición en tiempo real de la nota esperada al evaluar el micrófono.
  - Actualización de `TunerScreen` y `PracticeReportModal`:
    - Selector rápido de instrumento en la UI.
    - Desglose 4D en el reporte (Afinación, Tempo & Tendencia, Sostenimiento, Instrumento activo).
  - Pruebas unitarias exhaustivas en `test/features/instrument/` y `test/features/practice_evaluator/`.
- **Excluido (Out-of-Scope):**
  - Grabación multipista a disco (se aborda en el siguiente hito de loopback).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio de Instrumento (Modelos y Transposición)
- [ ] Crear `InstrumentKey` y `InstrumentProfileEntity`.
- [ ] Definir `IInstrumentTranspositionService` y su implementación matemática en `InstrumentTranspositionService`.
- [ ] Escribir tests unitarios de transposición para Bb, Eb, F y C.

### Paso 2: Ampliación Multidimensional del Evaluador de Práctica
- [ ] Agregar métricas de sostenimiento (*sustain ratio*) y tendencia rítmica (*rushing/dragging*).
- [ ] Actualizar `IPracticeEvaluatorService` y `PracticeEvaluatorService`.
- [ ] Escribir tests unitarios multidimensionales.

### Paso 3: Integración en ViewModel y UI
- [ ] Conectar `activeInstrumentProfile` en `TunerViewModel`.
- [ ] Añadir modal o selector de instrumento en `TunerScreen`.
- [ ] Enriquecer `PracticeReportModal` con los nuevos medidores y advertencias de tempo.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Ejecutar `flutter analyze` (0 lints).
- [ ] Ejecutar `flutter test` (100% pruebas pasando).
- [ ] Commit y sincronización remota en `main`.

---

## 3. Criterios de Aceptación (Definition of Done)
- [ ] Toda nota escrita para Bb, Eb o F se transporta con exactitud matemática a su frecuencia física.
- [ ] El reporte de práctica muestra desglose de Afinación, Tempo (con alerta de Rushing o Dragging) y Sostenimiento.
- [ ] 100% de la suite de pruebas unitarias pasando.
- [ ] Cero dependencias parásitas en la capa de dominio.
