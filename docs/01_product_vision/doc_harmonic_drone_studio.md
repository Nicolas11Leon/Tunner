# Documentación Técnica: Estudio de Dron Armónico de Referencia Continua (Tone Drone Studio)

Este documento define la especificación técnica, fundamentos acústicos y diseño de arquitectura del generador de tonos pedal armónicos continuos de **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-DRONE-2026-001`
- **Título Oficial:** Estudio de Dron Armónico de Referencia Continua (Tone Drone Studio)
- **Estado:** Approved
- **Fecha de Creación:** 2026-10-27
- **Última Modificación:** 2026-10-27
- **Fase Asociada:** Fase 7.3 (Vanguardia Acústica y Conservatorio)
- **Autor / Revisor Principal:** Nicolas Leon / Antigravity

---

## 1. Resumen Ejecutivo (Executive Summary)

El Estudio de Dron Armónico de Referencia Continua proporciona un generador procedural de ondas armónicas sostenidas continuas ejecutado enteramente en memoria RAM en Dart puro (`HarmonicDroneSynthesizer`). Resuelve la necesidad pedagógica en conservatorios de practicar escalas, intervalos y afinación acústica contra una nota pedal fundamental pura o enriquecida armónicamente (fundamental, quinta armónica y octava).

El generador elimina cualquier discontinuidad o chasquido ("click/pop") mediante un algoritmo de bucle con fundido cruzado simétrico (equal-power crossfade de 40 ms) e integra de forma nativa la calibración de tono de concierto ($A_4$) y el temperamento musical activo (e.g. Temperamento Igual, Just Intonation, Mesotónico de 1/4 de coma, Werckmeister III, Kirnberger III, Vallotti, Pitagórico).

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
En el estudio de instrumentos de entonación libre o flexible (cuerdas frotadas como violín o cello, vientos como flauta o trompeta, y canto lírico), la afinación relativa frente a un tono de referencia continuo es fundamental para percibir batimentos acústicos (interferencias periódicas generadas por el desfase entre armónicos cercanos):
$$f_{\text{batimento}} = |f_1 - f_2|$$
Cuando la afinación del músico es perfecta, $f_{\text{batimento}} = 0\text{ Hz}$ y el sonido alcanza consonancia pura. Los reproductores convencionales o archivos WAV estáticos no permiten alterar la afinación base a 415 Hz o 442 Hz sin artefactos de remuestreo ni respetan temperamentos históricos microtonales.

### 2.2 Fundamento Teórico y Síntesis Procedural
Para cada muestra de audio en el tiempo discreto $t = \frac{n}{f_s}$ a una tasa de muestreo $f_s = 44100\text{ Hz}$, la señal compuesta $x[n]$ se obtiene sumando la frecuencia fundamental $f_0$, la quinta armónica $f_5$ (ajustada por temperamento) y la octava $f_{\text{oct}} = 2 f_0$:

$$x[n] = w_{\text{fund}} \cdot \Psi_{\text{timbre}}(2\pi f_0 t) + w_5 \cdot \Psi_{\text{timbre}}(2\pi f_5 t) + w_{\text{oct}} \cdot \Psi_{\text{timbre}}(2\pi f_{\text{oct}} t)$$

Donde $\Psi_{\text{timbre}}$ sintetiza la serie armónica según el timbre seleccionado:
- **Senoidal Pura (`pureSine`):** $\sin(\theta)$
- **Flauta Cálida (`warmFlute`):** $\sin(\theta) + 0.35\sin(2\theta) + 0.12\sin(3\theta) + 0.04\sin(4\theta)$
- **Cello Cálido (`richCello`):** $\sum_{k=1}^6 a_k \sin(k\theta)$ con caída armónica rica.
- **Órgano de Tubos (`organ`):** Síntesis aditiva emulando registros de flautas y principales.

Para asegurar un bucle circular sin clics:
- Duración del buffer: $T = 2.0\text{ s}$ ($N = 88200$ muestras).
- Longitud del fundido cruzado: $M = 1764$ muestras ($40\text{ ms}$).
- En la región $0 \le n < M$:
$$x_{\text{loop}}[n] = x[n] \cdot \sin\left(\frac{\pi n}{2M}\right) + x[N - M + n] \cdot \cos\left(\frac{\pi n}{2M}\right)$$

---

## 3. Especificación Funcional Detallada

### 3.1 Requerimientos Funcionales
- **REQ-DRONE-01:** Selección de nota fundamental (Do a Si, índices 0 a 11) y octava de registro (Octava 2 a 4).
- **REQ-DRONE-02:** Alternancia independiente de quinta armónica y octava superior.
- **REQ-DRONE-03:** Selección de cuatro perfiles tímbricos: Senoidal Pura, Flauta Cálida, Cello, Órgano.
- **REQ-DRONE-04:** Control deslizante de balance de armónicos (0.0 a 1.0) y volumen general (0.0 a 1.0).
- **REQ-DRONE-05:** Actualización en caliente sin detención manual ante cambios de nota, temperamento o afinación de concierto ($A_4$).

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (`lib/features/drone/domain/`)
- `DroneTimbre`: Enumeración con etiquetas y descripciones en español.
- `HarmonicDroneConfig`: Entidad inmutable con validación de rangos y serialización.
- `HarmonicDroneSynthesizer`: Motor puro en Dart, determinista y sin dependencias de Flutter, que produce encabezados RIFF/WAVE estándar y modulaciones PCM 16-bit Mono.

### 4.2 Capa de Infraestructura (`lib/features/audio_synthesizer/`)
- `IAudioSynthesizerService`: Expone `startDroneLoop(Uint8List wavBuffer, {double volume})`, `stopDroneLoop()` y `isDroneLoopPlaying`.
- `AudioSynthesizerService`: Utiliza `AudioPlayer` configurado con `ReleaseMode.loop` para reproducción circular continua en canal dedicado.
- `MemoryAudioSynthesizerService`: Mock en memoria para pruebas automáticas sin llamadas a APIs nativas de audio.

### 4.3 Capa de Presentación (`lib/features/drone/presentation/`)
- `HarmonicDroneModal`: Modal interactivo tipo BottomSheet con tarjetas táctiles de timbre, selectores de notas, deslizadores de volumen y botón maestro pulsante.
- Integración en `TunerScreen`: Acceso directo mediante chip animado en la barra superior tanto en Modo Esencial como en Modo Conservatorio Pro.

---

## 5. Criterios de Rendimiento

- **Generación de Buffer:** $< 4\text{ ms}$ para calcular las 88200 muestras PCM en hilo principal.
- **Memoria RAM:** $< 180\text{ KB}$ por buffer generado en memoria volátil sin fugas.
- **Concurrencia:** Coexistencia completa con el detector de pitch MPM (`McLeodPitchMethod`) en segundo plano sin alterar la latencia de análisis ($\le 10\text{ ms}$).

---

## 6. Referencias Técnicas y Bibliografía

1. *F. Richard Moore, "Elements of Computer Music", Prentice Hall (1990).*
2. *Rossing, Wheeler & Moore, "The Science of Sound", Addison-Wesley.*
3. *WAV PCM RIFF Audio File Format Specification.*
