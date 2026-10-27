# Documento Técnico de Visión de Producto: Motor de Síntesis PCM, Clics Acústicos y Diapasón de Concierto

- **Módulo:** Audio Synthesizer & Acoustic Metronome Clicks
- **Fase del Proyecto:** Fase 5 (Vanguardia de Audio Digital & Laboratorio Acústico)
- **Estado:** Especificación Canónica de Producto
- **Autor:** Antigravity AI & Nicolas Leon
- **Licencia:** GNU AGPLv3

---

## 1. Justificación y Propósito del Componente

Hasta la Fase 4, **Tunner** contaba con un motor visual estroboscópico de ultra alta resolución y un reloj metronómico compensado en `Isolate` a nivel de microsegundos. Sin embargo, el metrónomo no emitía pulsos sonoros por los altavoces, y el afinador no permitía al músico escuchar el tono de referencia $A_4$ generado por síntesis física.

El **Motor de Síntesis PCM en Memoria (In-Memory PCM Audio Synthesizer)** dota a Tunner de capacidades acústicas generativas de vanguardia:
1. **Clics Acústicos de Metrónomo:** Generación determinista de impulsos percusivos tipo madera (*woodblock/clave*) con diferenciación espectral entre el pulso fuerte (*downbeat*, acento orquestal) y los pulsos secundarios (*off-beats*).
2. **Diapasón Digital de Conservatorio (Acoustic Tuning Fork):** Síntesis senoidal pura de $A_4$ (calibrable dinámicamente de 415 Hz a 466 Hz) con envolvente ADSR de transición suave (*anti-pop/anti-click*).
3. **Cero Dependencia de Archivos o Red:** Generación procedural de bloques PCM RIFF WAV a 44.1 kHz / 16 bits en memoria RAM sin necesidad de almacenar assets pesados en disco ni realizar llamadas de red.

---

## 2. Modelado Matemático y DSP de Síntesis

### 2.1 Formato de Buffer Canónico RIFF/WAVE (16-bit PCM Mono a 44,100 Hz)
La cabecera WAV estándar de 44 bytes se sintetiza mediante `ByteData`:
* Frecuencia de muestreo ($F_s$): $44,100\text{ Hz}$
* Profundidad de bits: $16\text{ bits}$ little-endian (rango $[-32768, 32767]$)
* Canales: $1$ (Mono)
* Tamaño de muestra: $2\text{ bytes}$

### 2.2 Física del Clic de Metrónomo
Para evitar el sonido artificial y fatigante de una onda cuadrada, el impulso percusivo se modela como una onda senoidal amortiguada exponencialmente:
$$s_{\text{click}}(t) = A \cdot \sin(2\pi f_c t) \cdot e^{-\frac{t}{\tau}}$$

Donde:
* **Pulso 1 (Downbeat / Acento):**
  * Frecuencia portadora: $f_c = 2200.0\text{ Hz}$
  * Constante de tiempo de decaimiento: $\tau = 0.006\text{ s}$
  * Duración total: $25\text{ ms}$ ($1102$ muestras)
* **Pulsos 2, 3, 4 (Sub-beats):**
  * Frecuencia portadora: $f_c = 1400.0\text{ Hz}$
  * Constante de tiempo de decaimiento: $\tau = 0.0035\text{ s}$
  * Duración total: $18\text{ ms}$ ($793$ muestras)

### 2.3 Síntesis de Diapasón Senoidal con Envolvente ADSR Suave
Para evitar chasquidos (*clicks/pops*) causados por discontinuidades en la fase al iniciar o detener el tono:
$$s_{\text{diapason}}(t) = A \cdot \text{Env}(t) \cdot \sin(2\pi f_{\text{ref}} t)$$

Donde $\text{Env}(t)$ implementa:
* **Attack (Ataque):** Rampa lineal ascendente de $15\text{ ms}$ de $0$ a $1.0$.
* **Sustain (Sostenimiento):** Amplitud $1.0$ continua.
* **Release (Caída):** Rampa lineal descendente de $20\text{ ms}$ de $1.0$ a $0$.

---

## 3. Arquitectura e Integración Clean Architecture

```mermaid
graph TD
    classDef domain fill:#0D0D14,stroke:#00E676,stroke-width:2px,color:#fff;
    classDef data fill:#161622,stroke:#38BDF8,stroke-width:2px,color:#fff;
    classDef presentation fill:#181310,stroke:#F59E0B,stroke-width:2px,color:#fff;

    subgraph Dominio ["Dominio (Pure Dart)"]
        IAudioSynthesizerService["IAudioSynthesizerService"]:::domain
        PcmWavSynthesizer["PcmWavSynthesizer (Math / DSP)"]:::domain
    end

    subgraph Datos ["Datos / Infraestructura"]
        AudioSynthesizerService["AudioSynthesizerService (audioplayers BytesSource)"]:::data
        MemoryAudioSynthesizerService["MemoryAudioSynthesizerService (Mock / Tests)"]:::data
    end

    subgraph Presentacion ["Presentación"]
        TunerViewModel["TunerViewModel (Orquestador)"]:::presentation
        ConcertPitchSelectorModal["ConcertPitchSelectorModal"]:::presentation
        TunerScreen["TunerScreen"]:::presentation
    end

    IAudioSynthesizerService <|-- AudioSynthesizerService
    IAudioSynthesizerService <|-- MemoryAudioSynthesizerService
    AudioSynthesizerService --> PcmWavSynthesizer
    TunerViewModel --> IAudioSynthesizerService
    ConcertPitchSelectorModal --> TunerViewModel
    TunerScreen --> TunerViewModel
```

---

## 4. Requisitos No Negociables
1. **0% Busy-Waiting:** El reproductor emite el audio a través de los buffers nativos sin bloquear el hilo principal.
2. **Aislamiento en Tests:** `MemoryAudioSynthesizerService` permite testear la lógica de ViewModel sin canales de plataforma.
3. **Respeto a la Consola Mezcladora:** El volumen del clic de metrónomo respeta el fader y el botón de Mute (M) de la consola de stems.
