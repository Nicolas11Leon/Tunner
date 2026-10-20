# Implementation Plan: Ultra-Fast Pitch Tracking & Virtual Strobe Tuner UI

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE1-FAST-PITCH-STROBE-2026-002`
- **Título de la Implementación:** `Pipeline de Detección de Transitorios Rápidos (Sub-10ms) y UI Estroboscópica Continua`
- **Fase del Proyecto:** `Fase 1`
- **Estado:** `Completado`
- **ADR Relacionado:** `docs/04_adrs/0001_in_process_isolate_clock_and_dsp_pipeline.md`
- **Documento Funcional Base:** `docs/02_use_cases/01_uc_acoustic_pitch_detection.md` y `docs/02_use_cases/04_uc_virtual_strobe_tuner.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Atender los dos requisitos no negociables de calidad de estudio:
1. **Velocidad de Respuesta Ultrasónica (Detección de Solos Rápidos de Violín/Guitarra):** Eliminar la latencia artificial y el retraso de 250 ms existente en `_silenceTimer`, ajustando la ventana de detección y la reactividad para capturar notas de paso ultra-cortas (semicorcheas/fusas de hasta $50\text{ a }80\text{ ms}$ de duración).
2. **Precisión Quirúrgica Microtonal ($\pm 0.1\text{ cents}$):** Implementar el widget visual de Afinador Estroboscópico (`StrobeTunerWidget`) con rotación continua por integración de fase a 60/120 FPS que se congela en afinación perfecta.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - **Pipeline de Audio:** Reducción de la ventana de silencio a $\le 60\text{ ms}$ con disparo inmediato por flanco de ataque (nuevo pitch detectado sobrescribe al instante el anterior sin colas de retardo).
  - **Presentación:** Creación de `StrobeTunerWidget` y `StrobePainter` con bandas estroboscópicas físicas y display numérico en tiempo real.
  - **Sustitución en UI:** Integrar el afinador estroboscópico en `lib/presentation/tuner_screen.dart` manteniendo la partitura en la parte inferior.
- **Excluido (Out-of-Scope):**
  - Renderizado SMuFL completo de partituras (Fase 2).
  - Síntesis de ondas de audio (Fase 3).

---

## 2. Análisis de Dependencias y Tecnologías

- **Librerías:** `record: ^6.2.1`, `pitch_detector_dart: ^0.0.7`, `flutter/material.dart`, `dart:math`.
- **Rendimiento:** El cálculo trigonométrico de fase en el `CustomPainter` se optimiza con pre-cálculo de radianes para mantener el tiempo de cuadro por debajo de $1\text{ ms}$.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Pure Dart)
- [ ] Incorporar en `NoteEntity` métodos auxiliares para cálculo de frecuencia teórica de referencia $f_0$ y factor de escala estroboscópico.

### Paso 2: Capa de Infraestructura / Datos (Optimización de Flujo y Latencia)
- [ ] En `PitchDetectorService`: Optimizar la velocidad de paso del buffer sin intermediarios redundantes.
- [ ] En `TunerViewModel`: Eliminar el `Timer(Duration(milliseconds: 250))` que introducía latencia artificial de un cuarto de segundo. Reducirlo a $50\text{ ms}$ dinámico con reactividad instantánea para solos rápidos.

### Paso 3: Capa de Presentación (Widget Estroboscópico & UI)
- [ ] Crear `lib/presentation/widgets/strobe_tuner_widget.dart`:
  - `AnimationController` continuo desacoplado del stream de audio para rotación a 60/120 FPS sin parpadeos.
  - Bandas cilíndricas/radiales con efecto estroboscópico de contraste alto.
  - Lectura digital de frecuencia exacta ($Hz$), nota musical ($Do_4$, $La_4$) y cents ($\pm 50.0$).
- [ ] Integrar el nuevo widget en `lib/presentation/tuner_screen.dart`.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Ejecutar `flutter analyze` (0 errores).
- [ ] Ejecutar `flutter test` (100% pruebas pasando).
- [ ] Commit y sincronización con GitHub.

---

## 4. Estrategia de Rollback

- Si la reactividad rápida produce lecturas falsas en salas muy ruidosas, el umbral de silencio y el RMS se ajustarán de forma configurable.
- Hash de restauración: `26b9987`.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Las notas sucesivas en pasajes rápidos de violín/guitarra se actualizan sin retraso acumulado.
- [ ] El estroboscopio virtual rota según los cents y se detiene en afinación precisa.
- [ ] Cero errores de linter y tests pasando.
- [ ] Sincronizado en `main`.
