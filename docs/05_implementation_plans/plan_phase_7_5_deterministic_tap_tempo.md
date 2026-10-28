# Plan de Implementación: Fase 7.5 - Tap Tempo Determinista & Sincronización Rítmica con Filtrado de Jitter

Este plan formaliza la descomposición técnica y pasos de ejecución para construir el motor de medición de pulso por pulsación táctil (Tap Tempo) y evaluación de precisión métrica en **Tunner**.

---

## 1. Objetivos

1. Implementar en el dominio puro (`lib/features/metronome/domain/`) el motor `TapTempoEngine` con cálculo de BPM mediante promedio ponderado de intervalos entre pulsaciones (Inter-Onset Intervals, IOI).
2. Integrar filtro de rechazo de valores atípicos y reinicio automático por inactividad ($> 2.5\text{ s}$).
3. Calcular la métrica de varianza temporal / jitter ($\sigma\text{ en ms}$) para retroalimentación pedagógica sobre la estabilidad métrica del instrumentista.
4. Conectar el motor con `TunerViewModel` y `IMetronomeService`, permitiendo calibrar el tempo del metrónomo en tiempo real mediante pulsaciones consecutivas.
5. Desarrollar el componente visual interactivo `TapTempoWidget` con animación de onda expansiva y modal de calibración rítmica.

---

## 2. Tareas por Capa Arquitectónica

### Capa 1: Dominio Puro (Pure Dart)
- [x] Crear `lib/features/metronome/domain/tap_tempo_result.dart`:
  - Entidad inmutable `TapTempoResult`:
    - `bpm` (int, entre 30 y 300).
    - `exactBpm` (double).
    - `tapCount` (int).
    - `jitterMs` (double, desviación estándar de intervalos).
    - `jitterPercentage` (double).
    - `stabilityDescription` (String: Metronómico, Excelente, Regular, Ajustando).
    - `tempoMark` (TempoMark italiana correspondiente).
- [x] Crear `lib/features/metronome/domain/tap_tempo_engine.dart`:
  - Ventana deslizante de hasta 8 pulsaciones recientes.
  - Ponderación lineal temporal para mayor influencia de los toques recientes.
  - Detección de inactividad ($> 2500\text{ ms}$) con reinicio atómico.
  - Cálculo determinista de desviación estándar muestral.
- [x] Crear suite de pruebas de dominio: `test/features/metronome/tap_tempo_engine_test.dart`:
  - Precisión exacta a 60 BPM, 120 BPM, 180 BPM y 240 BPM.
  - Manejo de tiempos de inactividad y reinicio de búfer.
  - Cálculo preciso de métricas de jitter y estabilidad.

### Capa 2: Infraestructura y Aplicación
- [x] Actualizar `TunerViewModel`:
  - Instancia de `TapTempoEngine`.
  - Getter `TapTempoResult? lastTapResult`.
  - Método `void recordTapTempo()`:
    - Registra la pulsación.
    - Si se han registrado al menos 2 pulsaciones válidas, actualiza automáticamente el BPM del metrónomo (`setBpm`).
    - Notifica a los observadores reactivos.
  - Método `void resetTapTempo()`.

### Capa 3: Presentación (Flutter UI)
- [x] Crear `TapTempoModal` en `lib/features/metronome/presentation/tap_tempo_modal.dart`:
  - Botón táctil ergonómico con efecto de feedback háptico/visual (pulse animado).
  - Indicador monumental numérico de BPM en tiempo real, marca italiana (e.g. "Allegro") y chip de estabilidad rítmica ($\pm \sigma\text{ ms}$).
  - Panel de calibración rítmica dedicado con diagnóstico de jitter métrico.
- [x] Integrar botón de Tap Tempo (`tap_tempo_modal_btn`) en el control de metrónomo de `TunerScreen`.
- [x] Crear suite de pruebas de interfaz: `test/features/metronome/tap_tempo_ui_test.dart`.

---

## 3. Criterios de Aceptación (DoD)
- 100% de pruebas unitarias y de widgets pasando.
- Cero issues en `flutter analyze`.
- Cero emojis en código, comentarios y commits.
