# Especificación Canónica: Tareas Conjuntas Multi-Herramienta y Orquestación Atómica en Tunner

## Metadatos del Documento

- **ID del Documento:** `DOC-ARCH-2026-057`
- **Título Oficial:** Arquitectura Canónica de Tareas Conjuntas Multi-Herramienta, Orquestación de Topologías y Sinergia de Señales
- **Estado:** Approved
- **Fecha de Creación:** 2026-11-09
- **Última Modificación:** 2026-11-09
- **Fase Asociada:** Fase 5 (Modular Studio & Advanced Pedagogy)
- **Autor / Revisor Principal:** DeepMind Agentic Pair Programmer & Tunner Core Architecture Team

---

## 1. Resumen Ejecutivo (Executive Summary)

El presente documento define la arquitectura formal para **Tareas Conjuntas Multi-Herramienta** ($\ge 3$ herramientas orquestadas en simultáneo) en la plataforma **Tunner**. A medida que la educación musical trasciende el aislamiento univariado (practicar únicamente ritmo o únicamente afinación), Tunner habilita flujos sinérgicos donde el Metrónomo determinista en Isolate, el Pentagrama vectorial SMuFL, el Afinador Estroboscópico de ultra-precisión (MPM), el Grabador de Práctica multitrack, el Dron Armónico y el Visualizador Polifónico colaboran sinérgicamente a través del `SignalBus` maestro sin acoplamiento punto a punto ni latencia perceptible ($< 1\text{ ms}$).

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Tradicionalmente, el software de práctica musical fragmenta las herramientas: el estudiante abre un afinador en una ventana, un metrónomo en otra y un lector de partituras en un tercer programa o atril físico. Esta desconexión causa:
1. **Falta de Correlación Temporal-Acústica:** El estudiante no puede saber si sus desviaciones de pitch ocurrieron por tocar antes o después del pulso (*rushing/dragging*).
2. **Carga Cognitiva Elevada:** Obliga a manipular tres interfaces desacopladas durante la ejecución física de un instrumento.
3. **Imposibilidad de Diagnóstico Integral:** La calidad del sonido no se evalúa sólo en Hz, sino en resonancia armónica ($H_1-H_8$), estabilidad en el compás y respuesta polifónica.

### 2.2 Fundamento Teórico y Acústico

#### Sincronización Temporal y Cuantización
El metrónomo emite señales de reloj discreto $\Delta t$ derivadas del pulso musical:
$$\Delta t = \frac{60}{\text{BPM} \cdot Q}$$
Donde $Q$ es la resolución de subdivisión (quarternote ticks).

#### Interferencia y Batimento en Afinación Justa
Cuando el Dron Armónico genera una frecuencia pura de referencia $f_{\text{ref}}$ y el instrumento emite $f_{\text{inst}}$, la envolvente de la señal combinada oscila a la frecuencia de batimento $f_b$:
$$f_b = |f_{\text{inst}} - f_{\text{ref}}|$$
A medida que la desviación en cents tiende a cero, $f_b \to 0$, logrando resonancia acústica pura sin oscilaciones de amplitud.

#### Desviación Microtonal en Cents
$$\text{cents} = 1200 \cdot \log_2\left(\frac{f}{f_{\text{ref}}}\right)$$

---

## 3. Especificación Funcional de las 5 Tareas Conjuntas Canónicas

### 3.1 Tarea Conjunta 1: Lectura en Vuelo con Control Estroboscópico en Vivo
- **Herramientas:** `metronome` + `score_notation` + `strobe_tuner` + `guided_lessons`.
- **Topología `SignalBus`:**
  - `metronome.clock_out` $\to$ `score_notation.clock_in` (avance de playhead compás a compás).
  - `strobe_tuner.pitch_out` $\to$ `score_notation.pitch_in` (coloreado en vivo de notas en verde/amarillo/rojo).
  - `strobe_tuner.pitch_out` & `metronome.clock_out` $\to$ `guided_lessons.eval_in` (cálculo de rushing/dragging y cents).

### 3.2 Tarea Conjunta 2: Afinación por Batimento & Dron Armónico Justo
- **Herramientas:** `harmonic_drone` + `strobe_tuner` + `spectrogram`.
- **Topología `SignalBus`:**
  - `harmonic_drone.audio_out` $\to$ `spectrogram.audio_in` (visualización de formantes de referencia).
  - `microphone.audio_in` $\to$ `spectrogram.audio_in` & `strobe_tuner.audio_in` (detección de interferencia y batimento).

### 3.3 Tarea Conjunta 3: Dictado Musical Inverso y Auto-Transcripción
- **Herramientas:** `metronome` + `score_notation` + `practice_recorder` + `guided_lessons`.
- **Topología `SignalBus`:**
  - `metronome.clock_out` $\to$ `score_notation.clock_in` & `practice_recorder.clock_in`.
  - `microphone.audio_in` $\to$ `score_notation.audio_transcribe_in` (transcripción en vivo en pentagrama).
  - `practice_recorder.buffer_out` $\to$ `guided_lessons.eval_in` (comparación con partitura esperada).

### 3.4 Tarea Conjunta 4: Auto-Diagnóstico Tímbrico y Armónicos H1-H8
- **Herramientas:** `practice_recorder` + `chord_analyzer` + `spectrogram`.
- **Topología `SignalBus`:**
  - `practice_recorder.audio_out` $\to$ `spectrogram.audio_in` (espectrograma FFT 2048).
  - `practice_recorder.audio_out` $\to$ `chord_analyzer.audio_in` (descomposición armónica y notas de tensión).

### 3.5 Tarea Conjunta 5: Exploración Polifónica y Temperamentos Históricos
- **Herramientas:** `master_keyboard` + `chord_analyzer` + `strobe_tuner` + `modular_rack`.
- **Topología `SignalBus`:**
  - `master_keyboard.midi_out` $\to$ `chord_analyzer.midi_in`.
  - `master_keyboard.audio_out` $\to$ `strobe_tuner.audio_in` (medición de desviación respecto al temperamento igual).
