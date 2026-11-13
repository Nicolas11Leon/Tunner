# Implementation Plan: Dynamic Just Intonation & Adaptive Harmonic Tuning Tutor

Este documento define el plan de trabajo detallado y los criterios de aceptación para la construcción del Tutor de Afinación Justa Dinámica y Cancelación de Batimientos en **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-HARMONIC-TUTOR-2026-065`
- **Título de la Implementación:** Construcción del Tutor de Afinación Justa Dinámica, Detección de Rol Armónico y Cancelación de Batimientos Acústicos
- **Fase del Proyecto:** Fase 2 (Suites Sinergéticas y Multitarea Profesional)
- **Estado:** `Aprobado`
- **ADR Relacionado:** [ADR 0061](../04_adrs/0061_dynamic_just_intonation_and_harmonic_tuning_tutor.md)
- **Documento Funcional Base:** [DOC-ARCH-2026-067](../01_product_vision/doc_dynamic_just_intonation_tutor.md), [UC-67](../02_use_cases/67_uc_dynamic_just_intonation_tutor.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Desarrollar un sistema completo de entrenamiento y afinación armónica adaptativa capaz de determinar el rol funcional de la nota interpretada respecto a un acorde o fundamental guía, calcular la diana acústica en entonación justa (Just Intonation de límite 5 y 7), medir la velocidad del batimiento físico ($f_{\text{beat}}$) y ofrecer una guía visual reactiva a 60 FPS con síntesis opcional de acordes de referencia pura.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Modelos matemáticos de dominio en Dart puro: `HarmonicRoleEntity`, `JustIntonationCalculator`, `HarmonicTutorSessionEntity`.
  - Matriz completa de los 12 intervalos armónicos cromáticos con ratios enteros irreducibles $(p/q)$ y fórmula de batimiento.
  - Sintetizador de drones armónicos puros en memoria (`HarmonicReferenceSynth`) sin aliasing para tríadas mayores, menores, suspendidas y dominantes.
  - Orquestador reactivo `HarmonicTutorViewModel` con integración al flujo de pitch continuo.
  - Interfaz de usuario `HarmonicTutorModal` con aguja reactiva de batimiento (`HarmonicBeatGauge`), selectores de acorde y panel pedagógico de consonancia.
  - Pruebas unitarias de dominio y pruebas de widgets.
- **Excluido (Out-of-Scope):**
  - Modificación del motor central 12-TET del afinador estroboscópico principal (el cual mantiene su función de calibración estándar).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** Canal estable oficial.
- **Flutter SDK:** Canal estable oficial.
- **Dependencias Externas:** Cero librerías externas adicionales. Todo el cálculo trigonométrico y logarítmico se realiza con `dart:math` y tipos nativos tipados.
- **Riesgo Tecnológico:** Cero busy-waiting loops. El medidor visual opera con temporizador reactivo desacoplado del hilo de audio.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [ ] Crear `lib/features/harmonic_tutor/domain/harmonic_role_entity.dart`: Tipificación de roles armónicos (Fundamental, 2da m/M, 3ra m/M, 4ta J, Tritono, 5ta J, 6ta m/M, 7ma m armónica / 5-limit, 7ma M) con sus ratios racionales $(p/q)$, desviaciones respecto a 12-TET y fórmulas de batimiento.
- [ ] Crear `lib/features/harmonic_tutor/domain/just_intonation_calculator.dart`: Algoritmo de deducción de rol $\Delta s$, cálculo de frecuencia diana pura $f_{\text{target\_JI}}$, desviación $\Delta c_{\text{JI}}$ y tasa de batimiento $f_{\text{beat}} = |p \cdot f_0 - q \cdot f|$.
- [ ] Crear `lib/features/harmonic_tutor/domain/harmonic_tutor_session_entity.dart`: Estado inmutable de la sesión de afinación armónica.
- [ ] Pruebas unitarias de dominio: `test/features/harmonic_tutor/domain/just_intonation_calculator_test.dart`.

### Paso 2: Capa de Infraestructura / Datos (Síntesis de Referencia)
- [ ] Crear `lib/features/harmonic_tutor/data/harmonic_reference_synth.dart`: Síntesis procedural pura de tríadas guía con rampa suave anti-pop para evitar clics acústicos.

### Paso 3: Capa de Presentación (ViewModels y Widgets Reactivos)
- [ ] Crear `lib/features/harmonic_tutor/presentation/harmonic_tutor_view_model.dart`: Conexión de la sesión con eventos del micrófono y estado del drone.
- [ ] Crear `lib/features/harmonic_tutor/presentation/harmonic_beat_gauge.dart`: CustomPainter con indicador analógico de aguja cuya oscilación física y color representan el batimiento y la consonancia armónica.
- [ ] Crear `lib/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart`: Modal de grado conservatorio con selectores de fundamental, tipo de acorde y botón de drone guía.
- [ ] Pruebas de widgets: `test/features/harmonic_tutor/presentation/harmonic_tutor_ui_test.dart`.

### Paso 4: Integración en Navigation y Quick Actions Dock
- [ ] Agregar acceso directo al Tutor de Afinación Justa en `QuickActionDock` y en el menú de herramientas de `MainAppShell`.

### Paso 5: Verificación, Quality Gate y Pull Request
- [ ] Ejecutar `flutter analyze` asegurando cero advertencias.
- [ ] Ejecutar la suite completa de pruebas unitarias y de widgets (`flutter test`).
- [ ] Realizar commit respetando la política de cero emojis y conventional commits.
- [ ] Enviar rama y abrir Pull Request con `gh pr create`.
- [ ] Verificar que GitHub Actions y SonarCloud pasen 100% en verde.

---

## 4. Criterios de Aceptación (Definition of Done)

- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md).
- [ ] Cero busy-waiting loops.
- [ ] Cero emojis en código fuente, comentarios, documentación y mensajes de commit.
- [ ] Todas las pruebas unitarias y de widgets pasando al 100%.
- [ ] Documentación técnica (`DOC-ARCH-2026-067`), caso de uso (`UC-67`) y ADR (`ADR 0061`) aprobados.
