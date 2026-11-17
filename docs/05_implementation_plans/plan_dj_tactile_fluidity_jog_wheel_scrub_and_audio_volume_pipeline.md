# Template: Implementation Plan (Plantilla Plan de Implementación)

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE1-DJ-TACTILE-FLUIDITY-SCRUB-2026-98`
- **Título de la Implementación:** Fluidez Táctil de Botones, Rebobinado Físico de Jog Wheels y Estabilidad de Tubería de Volumen en la Consola DJ Pro Studio
- **Fase del Proyecto:** Fase 1
- **Estado:** Propuesto
- **ADR Relacionado:** [`docs/04_adrs/0088_dj_tactile_fluidity_jog_wheel_scrub_and_audio_volume_pipeline.md`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/04_adrs/0088_dj_tactile_fluidity_jog_wheel_scrub_and_audio_volume_pipeline.md)
- **Documento Funcional Base:** [`docs/02_use_cases/98_uc_dj_tactile_fluidity_jog_wheel_scrub_and_audio_volume_pipeline.md`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/02_use_cases/98_uc_dj_tactile_fluidity_jog_wheel_scrub_and_audio_volume_pipeline.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Resolver de forma exhaustiva los 3 problemas de interacción física y acústica reportados en la Consola DJ:
1. **Rebobinado y Búsqueda en Jog Wheel ("rebobinar el disco"):** Reemplazar el delta lineal defectuoso por un cálculo angular vectorial polar continuo $\Delta \theta = \text{atan2}(y, x) - \text{atan2}(y_{\text{prev}}, x_{\text{prev}})$. Enlazar la rotación con la búsqueda y rebobinado real de la pista en milisegundos (`seekDeckPlayback` y `seekDeck`).
2. **Estabilidad del Pipeline de Volumen ("si subes el volumen y lo bajas deja de sonar"):** Erradicar la saturación del canal asíncrono y el congelamiento del sumidero GStreamer en Linux al bajar el volumen a 0. Mantener un piso inaudible a $-80\text{ dBFS}$ ($0.0001$) para conservar la tubería activa y reanudar activamente la reproducción al subir el volumen.
3. **Control Real de Faders de Canal y Fluidez de Botones:** Conectar los faders verticales de canal en `DjVerticalChannelStrip` con el volumen del deck (`setDeckVolume`), optimizar el dimensionamiento táctil de los mandos y dotar a los botones de transporte (Play/Cue/HotCues) de respuesta instantánea y retroalimentación reactiva.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Métodos `seekDeckPlayback` y `setDeckVolume` en `DjPerformanceOrchestrator` y `DjConsoleViewModel`.
  - Transformación matemática de `VectorJogWheel` a un `StatefulWidget` con seguimiento polar verdadero.
  - Implementación de rebobinado y avance en milisegundos proporcional al giro en `scratchDeck`.
  - Protección acústica y serialización de volumen en `DjDeckAudioService` para evitar bloqueos del backend GStreamer.
  - Conexión del fader vertical de `DjVerticalChannelStrip` al volumen del canal y ampliación del área táctil.
  - Ajuste de respuesta de botones de transporte en `DjStudioWorkstationView`.
- **Excluido (Out-of-Scope):**
  - Servicios de red o plugins externos de audio.

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `>=3.0.0 <4.0.0`.
  - Flutter SDK: Canal estable Linux/Desktop.
  - Audioplayers: `6.1.1` (gestión de `seek` y `setVolume`).
- **Riesgo Tecnológico:**
  - Cero dependencias externas.
  - Matemática puramente vectorial en punto flotante (`math.atan2`) con costo despreciable ($<0.01\text{ ms}$ por evento de arrastre).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (`DjPerformanceOrchestrator`)
- [ ] Implementar `seekDeckPlayback(String deckId, int targetPositionMs)` para actualizar `currentPositionMs` y `slipPositionMs`.
- [ ] Implementar `setDeckVolume(String deckId, double volume)` para modificar `_deckA.volume` y `_deckB.volume`.
- [ ] Validar que `getEffectiveGains` pondere correctamente el volumen individual del canal con el crossfader y el volumen maestro.

### Paso 2: Capa de Infraestructura / Datos (`DjDeckAudioService`)
- [ ] Implementar protección contra congelamiento de tubería de audio en `setDeckVolume`:
  - Clamping seguro con piso inaudible a $0.0001$ si la pista está en reproducción para evitar que GStreamer pause el sink.
  - Auto-reanudación (`player.resume()`) si el volumen asciende desde cero mientras el deck está en estado `isPlaying`.
  - Serialización asíncrona de llamadas de volumen para evitar condiciones de carrera en arrastres rápidos.

### Paso 3: Capa de Presentación (Jog Wheel, Fader y Botones)
- [ ] Refactorizar `VectorJogWheel` con física de rotación polar centrada en $(c_x, c_y)$ usando `math.atan2` y normalización de discontinuidad $[-\pi, \pi]$.
- [ ] Refactorizar `scratchDeck` en `DjConsoleViewModel` para calcular el desplazamiento temporal en milisegundos y despachar `seekDeckPlayback` y `seekDeck`.
- [ ] Conectar el fader vertical de `DjVerticalChannelStrip` a `viewModel.setDeckVolume(deckId, val)` con control táctil ampliado.
- [ ] Optimizar botones de transporte en `DjStudioWorkstationView` eliminando retardos visuales.

### Paso 4: Pruebas, Verificación y Despliegue
- [ ] Crear suite de pruebas en `test/features/dj_console/dj_tactile_and_volume_scrub_test.dart`.
- [ ] Ejecutar la suite completa de pruebas de DJ.
- [ ] Recompilar el binario Linux en modo Release y relanzar la aplicación.
