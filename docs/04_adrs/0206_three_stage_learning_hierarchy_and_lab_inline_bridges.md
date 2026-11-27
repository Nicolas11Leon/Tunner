# ADR 0206: Jerarquia de Aprendizaje en 3 Etapas y Puentes Inline de Laboratorio

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-214](../02_use_cases/214_uc_three_stage_learning_hierarchy_and_lab_inline_bridges.md)

---

## 1. Contexto

`LearningPracticeWorkspaceView` (`lib/features/workspaces/presentation/learning_practice_workspace_view.dart`) expone simultaneamente el banner pedagogico, la tarjeta de nota monumental, el afinador estroboscopico, el diagnostico biomecanico, el metronomo, una barra horizontal con 9 chips de herramientas heterogeneas y el dock de grabacion, saturando la carga cognitiva del estudiante. Por su parte, `ProductionAcousticLabWorkspaceView` (`lib/features/workspaces/presentation/production_acoustic_lab_workspace_view.dart`) presenta tarjetas de espectrograma, analizador de acordes y Vocal AutoTune que dependen de abrir modales completos para acciones frecuentes de laboratorio.

---

## 2. Decision

1. **Jerarquia Pedagogica en 3 Etapas en `LearningPracticeWorkspaceView`:**
   - Agrupar los controles de practica en tres bloques ordenados y colapsables/navegables:
     - **Etapa 1 — Afinar y Escuchar (`Key('learning_stage_1_tune_listen')`):** Banner de perfil, selector de instrumento, tarjeta monumental de nota, afinador estroboscopico y diagnostico biomecanico en vivo.
     - **Etapa 2 — Practicar con Guia (`Key('learning_stage_2_guided_practice')`):** Metronomo anti-bleed, modo evaluacion, Smart Wait, Dron Armonico y Lecciones Guiadas.
     - **Etapa 3 — Evaluar y Revisar (`Key('learning_stage_3_evaluate_review')`):** Dock de grabacion, Comparador Espectral, Vocal AutoTune, Generador de Ejercicios e Informe PDF.
   - Conservar las keys existentes de los chips y botones internos para preservar la compatibilidad con pruebas previas.
2. **Puentes Inline de Laboratorio en `ProductionAcousticLabWorkspaceView`:**
   - Anadir accion inline `Key('lab_inline_chord_to_drone_btn')` en la tarjeta del Analizador de Acordes para activar el Dron Armonico con la fundamental del acorde detectado sin abrir `ChordAnalyzerModal`.
   - Incorporar conmutador inline `Key('lab_inline_autotune_toggle_btn')` en la tarjeta de `VOCAL AUTOTUNE & DSP` y selector rapido de tonica `Key('lab_inline_root_key_selector')` junto a la calibracion de temperamento historico.

---

## 3. Consecuencias

### 3.1 Positivas
- **Menor Entropia Visual (Ley de Hick-Hyman):** El estudiante identifica de inmediato que bloque corresponde a afinar, practicar o revisar su progreso.
- **Laboratorio Sin Saltos Modales:** Los ingenieros y docentes pueden disparar acciones DSP frecuentes directamente sobre la vista principal.

### 3.2 Compromisos y Mitigaciones
- **Visibilidad de Controles en Pantallas Pequenas:** Las 3 etapas permiten expansion simultanea por defecto o conmutacion por etapa activa sin ocultar permanentemente controles clave en flujos automatizados.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/workspaces/us_ux_14_three_stage_learning_and_lab_inline_bridges_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
