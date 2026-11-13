# Implementation Plan: DJ Performance FX Suite, Algorithmic Beat Tracking and Live Mixdown Master Recorder

Este documento define el plan de trabajo detallado y los criterios de aceptación para la construcción e integración de la suite de efectos en vivo, detección algorítmica de BPM y grabador de mezcla maestra en **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-DJ-FX-2026-064`
- **Título de la Implementación:** Construcción de la Suite de Efectos en Vivo, Algoritmo Onset Beat Tracker y Grabador Master de Sesión para la Consola DJ Virtual
- **Fase del Proyecto:** Fase 3 (Herramientas Creativas Avanzadas) & Fase 4 (Estudio de Producción)
- **Estado:** `Aprobado`
- **ADR Relacionado:** [ADR 0060](../04_adrs/0060_dj_performance_fx_beat_tracking_and_mix_recorder.md)
- **Documento Funcional Base:** [DOC-ARCH-2026-066](../01_product_vision/doc_dj_performance_fx_beat_tracking_and_mix_recorder.md), [UC-66](../02_use_cases/66_uc_dj_performance_fx_beat_tracking_and_mix_recorder.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Incorporar procesamiento de efectos de canal (filtro bipolar sweep y retardo sincronizado), estimación algorítmica de tempo de canciones sin intervención manual y grabación de mezcla maestra con exportación canónica WAV en la Consola DJ Virtual.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades de dominio en Dart puro: `BpmBeatTrackerEngine`, `DjChannelFxEntity`, `DjLiveMixRecorderEntity`.
  - Ampliación de `DjAction` con acciones para modulación de filtro, delay y grabación.
  - Procesamiento DSP avanzado en `DjAudioProcessor`: simulación de filtro bipolar continuo $[-1.0, 1.0]$, línea de retardo con feedback acotado y summing estéreo con soft-clipping.
  - Codificador de archivo de audio `DjMixWavEncoder` (formato canónico RIFF WAV 16-bit PCM).
  - Integración en la interfaz de usuario de `DjConsoleModal`: perilla de filtro bipolar por deck, selector de división de delay, botón e indicador REC con cronómetro, y selector de carga de stems.
  - Pruebas unitarias de dominio y pruebas de widgets.
- **Excluido (Out-of-Scope):**
  - Efectos basados en convolución reverberante masiva (los cuales corresponden a una etapa posterior de mastering de sala).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.0` (o versión estable del proyecto).
- **Flutter SDK:** Canal oficial estable.
- **Dependencias Externas:** Ninguna librería externa adicional requerida; toda la manipulación matemática de matrices de audio y encabezados RIFF opera en Dart puro sin dependencias nativas bloqueantes.
- **Riesgo Tecnológico:** Cero busy-waiting loops. El búfer de análisis opera de forma acotada ($\le 5\text{ s}$ de audio) con complejidad temporal $O(N \log N)$ o $O(N)$ optimizada.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [ ] Crear `lib/features/dj_console/domain/bpm_beat_tracker_engine.dart`: Detección de energía enventanada y autocorrelación en rango $60-180\text{ BPM}$.
- [ ] Crear `lib/features/dj_console/domain/dj_channel_fx_entity.dart`: Modelo de filtro bipolar y delay cuantizado por subdivisión métrica.
- [ ] Crear `lib/features/dj_console/domain/dj_live_mix_recorder_entity.dart`: Control de sesión de grabación y metadata de tomas.
- [ ] Ampliar `lib/features/dj_console/domain/dj_action.dart`: Nuevas acciones de performance FX y grabación.
- [ ] Actualizar `lib/features/dj_console/domain/dj_performance_orchestrator.dart`: Gestión de efectos por deck y captura de búfer post-crossfader.
- [ ] Crear pruebas unitarias: `test/features/dj_console/domain/dj_fx_and_beat_tracker_test.dart`.

### Paso 2: Capa de Infraestructura / Datos
- [ ] Actualizar `lib/features/dj_console/data/dj_audio_processor.dart`: Procesamiento de filtro bipolar con frecuencia de corte dinámica y línea de retardo con feedback.
- [ ] Crear `lib/features/dj_console/data/dj_mix_wav_encoder.dart`: Serialización RIFF/WAVE estéreo de 16 bits sin pérdida.

### Paso 3: Capa de Presentación
- [ ] Actualizar `lib/features/dj_console/presentation/dj_console_view_model.dart`: Exponer controles de filtro, conmutador de delay y comandos de inicio/fin de grabación con timer en vivo.
- [ ] Actualizar `lib/features/dj_console/presentation/dj_console_modal.dart`: Controles visuales de filtro bipolar, delay, botón REC y modal de carga de stems.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Actualizar pruebas de widgets: `test/features/dj_console/presentation/dj_console_ui_test.dart`.
- [ ] Ejecutar `flutter analyze` asegurando cero advertencias.
- [ ] Ejecutar `flutter test` asegurando 100% de pruebas pasando.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Rama `main` o commit base de la rama.
- **Mitigación Inmediata:** Reversión atómica de los archivos de la suite de efectos.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md).
- [ ] Cero busy-waiting loops.
- [ ] Cero emojis en código fuente, comentarios, documentación y mensajes de commit.
- [ ] Pruebas unitarias de dominio y UI pasando al 100%.
- [ ] Documentación técnica (`DOC-ARCH-2026-066`), caso de uso (`UC-66`) y ADR (`ADR 0060`) aprobados.