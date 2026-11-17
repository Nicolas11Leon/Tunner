# ADR 0082: Expansión del Motor de Rendimiento DJ al Estándar de la Industria

- **Estado:** Aceptado
- **Fecha:** 2026-11-16
- **Contexto:** Consola DJ, Reproducción de Audio en Hardware, Síntesis y Enrutamiento de Estudio
- **Fase:** Fase 1 (Sinceramiento y Emisión Acústica Real)

---

## 1. Contexto

La Consola DJ de Tunner implementaba visualizaciones completas, emulación de hardware (controladores DDJ-FLX4, Traktor S4, CDJ-3000), mapeo de gamepad y orquestación de parámetros de mezcla. Sin embargo, para cumplir con el estándar exigido por DJs profesionales y educadores musicales (equivalente a Pioneer Rekordbox, Serato DJ o Traktor Pro), era indispensable que todas las acciones interactivas críticas (Hot Cues, Sampler de 8 pads, Scratching de Jog Wheel, Auto-Loops continuos y Beat Jumps) emitieran sonido audible real a través del motor de audio físico en lugar de limitarse a mutar variables de estado en memoria.

---

## 2. Decisión

Se adopta una integración directa y de baja latencia entre la capa de presentación/orquestación de la Consola DJ y los servicios de audio de Tunner:
1. **Audición y Búsqueda de Hot Cues:** Conectar `triggerHotCue` en `DjConsoleViewModel` para buscar la posición exacta en milisegundos mediante `_deckAudioPlayer.seekDeck(deckId, Duration(milliseconds: targetMs))` y activar la reproducción instantánea.
2. **Sampler de Rendimiento Audible:** Inyectar `IAudioSynthesizerService` en `DjConsoleViewModel` para que cada disparo de los 8 pads (`DjSamplerPadType`) convierta el buffer float sintetizado por `DjTransitionSfxSynthesizer` en formato PCM WAV y lo despache a través de `playPcmWav`, permitiendo escuchar bocinas, sirenas, caídas de bajo subgrave y percusiones al instante.
3. **Modulación Angular del Jog Wheel:** Extender `scratchDeck` para modular temporalmente el `playbackRate` de `_deckAudioPlayer` en proporción a la velocidad angular $\omega = \frac{\Delta \theta}{\Delta t}$ y permitir scrubbing de audio durante movimientos acelerados, con temporizador de restitución automática al soltar el plato.
4. **Ciclo de Auto-Loops y Salto de Compás Cuantizado:** Asegurar que `beatJump` ejecute `seekDeck` de forma síncrona en el hardware de audio, y que el bucle de actualización de 30 Hz sincronice el retorno del cabezal hacia `loopStartMs` cuando se sobrepasa `loopEndMs`.
5. **Enrutamiento Directo desde Canales de Estudio:** Extender el receptor de eventos del Patchbay en `DjStudioWorkstationView` para permitir la ingesta directa de pistas renderizadas y streams de audio hacia los Decks A y B.

---

## 3. Consecuencias

### Positivas
- Coherencia total entre la respuesta visual de la consola y la señal acústica reproducida en parlantes o auriculares.
- La consola cumple con la expectativa táctil de hardware profesional para aprendizaje auditivo y mezclas en vivo.
- Rendimiento determinista sin bloqueos del hilo de interfaz gráfica gracias a la síntesis no bloqueante en memoria.
- Totalmente compatible con las pruebas unitarias y de integración mediante implementaciones en memoria (`MemoryDjDeckAudioPlayer` y `MemoryAudioSynthesizerService`).

### Negativas / Mitigaciones
- La búsqueda de audio de alta frecuencia (scrubbing extremo) puede generar artefactos si el códec del sistema operativo no procesa seeks rápidos.
  *Mitigación:* Se implementa un estrangulamiento (throttling) temporal en la búsqueda y modulación de velocidad para asegurar fluidez acústica.
