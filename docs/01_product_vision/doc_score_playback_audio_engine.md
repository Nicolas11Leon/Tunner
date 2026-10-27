# Product Vision: In-Memory Procedural Score Playback Sound Engine

Este documento define la especificación técnica, fundamento pedagógico y arquitectura de audio del **Motor de Reproducción Acústica de Partituras (Score Playback Engine)** en **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-AUDIO-2026-PLAYBACK`
- **Título Oficial:** Motor Acústico Procedural de Reproducción Polifónica y Melódica de Partituras en Memoria RAM
- **Estado:** Approved
- **Fecha de Creación:** 2026-10-27
- **Última Modificación:** 2026-10-27
- **Fase Asociada:** Fase 5 (Vanguardia Acústica y Aprendizaje Musical)
- **Autor / Revisor Principal:** Equipo de Arquitectura Acústica y Síntesis de Audio de Tunner

---

## 1. Resumen Ejecutivo (Executive Summary)

El aprendizaje musical efectivo requiere retroalimentación auditiva inmediata. Hasta ahora, el visualizador de partituras de **Tunner** permitía seguir la posición métrica del cursor (*playhead*) de forma visual sincronizada con el metrónomo, pero sin emitir el audio de las notas de la partitura. 

Este hito introduce el **Score Playback Engine**: un sintetizador acústico procedural que convierte las estructuras jerárquicas de la partitura activa (`HierarchicalMeasure`, `HierarchicalNote`) en ondas acústicas con envolvente tímbrica ADSR en tiempo real. La síntesis ocurre 100% en memoria RAM local mediante buffers canónicos RIFF/WAVE PCM de 16 bits a $44.1\text{ kHz}$, controlados por el canal melódico ("voice") de la consola de mezcla (`MixerConsoleEntity`) y conmutables por el usuario.

---

## 2. Contexto del Problema y Justificación Pedagógica

### 2.1 Planteamiento del Problema
Cuando un estudiante de instrumento (como la flauta o el violín) aborda una pieza nueva importada vía MusicXML o MIDI, leer la notación visual sin referencia sonora exige un oído interno avanzado. Si no puede escuchar previamente la melodía o el ritmo exacto con entonación perfecta, la práctica se vuelve frustrante y proclive a errores de lectura.

### 2.2 Fundamento Acústico y Temporal

#### 2.2.1 Cálculo de Duración Temporal por Sub-Tick
El metrónomo de Tunner opera a una subdivisión de 4 sub-ticks por pulso (*quarter note*):
$$t_{\text{subtick}} = \frac{60.0}{\text{BPM} \cdot 4} \text{ segundos}$$
Para una nota de duración $D_{\text{ticks}}$, su duración física en milisegundos es:
$$T_{\text{ms}} = D_{\text{ticks}} \cdot \left(\frac{60000.0}{\text{BPM} \cdot 4}\right)$$

#### 2.2.2 Envolvente Acústica Musical (ADSR)
Para dotar al sonido de un timbre cálido y orgánico (similar a una flauta/madera) y evitar chasquidos digitales (*clicks/pops*):
- **Ataque (Attack, 15 ms):** Rampa suave de $0.0$ al pico de amplitud.
- **Decaimiento (Decay, 35 ms):** Caída exponencial hacia el nivel de sostenimiento ($0.85$).
- **Sostenimiento (Sustain):** Amplitud continua con modulación armónica secundaria.
- **Relajación (Release, 25 ms):** Rampa hacia cero antes del final del buffer.

#### 2.2.3 Enriquecimiento Tímbrico por Síntesis Aditiva
En lugar de una onda senoidal pura de laboratorio, la nota incorpora armónicos suaves:
$$x(t) = 0.70 \cdot \sin(2\pi f_0 t) + 0.20 \cdot \sin(4\pi f_0 t) + 0.10 \cdot \sin(6\pi f_0 t)$$
Esto produce una resonancia acústica rica que facilita la audición melódica sobre el clic del metrónomo.

---

## 3. Especificación Funcional

- **REQ-PLAY-01:** La reproducción de notas melódicas se activa al inicio de cada evento de nota (`tick == note.startTick`) durante la reproducción del metrónomo si `isScorePlaybackEnabled == true`.
- **REQ-PLAY-02:** El volumen de la nota está gobernado estrictamente por la ganancia efectiva de la pista "voice" en la consola de mezcla (`_mixerConsole.getEffectiveGain("voice")`).
- **REQ-PLAY-03:** Si el usuario silencia la pista melódica (*Mute*) o activa el modo *Solo* en otra pista, el playback de la partitura se silencia inmediatamente.
- **REQ-PLAY-04:** Las notas de silencio (`noteName == "--"` o `"rest"`) no generan emisión de audio.
- **REQ-PLAY-05:** Cero latencia y cero dependencias externas o de conexión a internet.
