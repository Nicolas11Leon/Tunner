# ADR-0011: Generación Procedural PCM en Memoria para Clics del Metrónomo y Diapasón Senoidal

- **Fecha:** 2026-10-27
- **Estado:** Aceptado
- **Autores:** Antigravity AI & Nicolas Leon
- **Revisores:** Arquitectura de Audio Digital Tunner

---

## 1. Contexto y Problema

El metrónomo de Tunner ejecutaba su temporización en microsegundos en un `Isolate` independiente, pero la emisión era puramente visual a través del `Playhead` en la partitura. Además, la calibración de tono de concierto $A_4$ (415 Hz a 466 Hz) operaba exclusivamente como parámetro matemático en la detección estroboscópica, sin ofrecer al estudiante una referencia auditiva física (diapasón).

Para solucionar esto, se evaluaron dos alternativas:
1. **Empaquetar archivos de audio pre-grabados (`.wav` o `.mp3` en assets):** Requiere archivos estáticos para cada pulso, no permite sintetizar frecuencias arbitrarias de $A_4$ de forma continua (ej. 432 Hz, 442 Hz, 415 Hz) e infla el tamaño del binario.
2. **Síntesis procedural de buffers PCM WAV en memoria RAM:** Generar arrays de bytes sin comprimir (`RIFF/WAVE`) al vuelo utilizando fórmulas trigonométricas puras en Dart.

---

## 2. Decisión Arquitectónica

Se decide adoptar la **Síntesis Procedural PCM en Memoria RAM**:
1. Implementar la clase matemática de dominio `PcmWavSynthesizer` en Dart puro (cero dependencias de UI).
2. Generar bloques de audio WAV Mono a 44,100 Hz / 16 bits little-endian con cabecera estándar de 44 bytes.
3. Para los clics de metrónomo, modelar pulsos amortiguados tipo madera ($2200\text{ Hz}$ con $\tau = 6\text{ ms}$ para acento, $1400\text{ Hz}$ con $\tau = 3.5\text{ ms}$ para pulsos débiles).
4. Para el diapasón, sintetizar ondas senoidales puras $\sin(2\pi f t)$ parametrizadas por el `referencePitch` activo, aplicando envolventes lineales de ataque (15 ms) y decaimiento (20 ms) para erradicar cualquier chasquido acústico (*anti-pop*).
5. Desacoplar la infraestructura mediante la interfaz `IAudioSynthesizerService` e inyectar `MemoryAudioSynthesizerService` en pruebas para asegurar un aislamiento absoluto sin canales de plataforma.

---

## 3. Consecuencias

### Positivas:
* **Cero Assets de Audio:** Binario ligero y limpio sin archivos de sonido incrustados.
* **Calibración Auditiva Infinita:** El diapasón puede emitir cualquier frecuencia continua en hercios (415 Hz, 432 Hz, 440 Hz, 442 Hz, etc.).
* **100% Offline y Conforme a Clean Architecture:** El dominio matemático no depende de Flutter ni de plugins.
* **Alta Fidelidad:** Sin artefactos de compresión con pérdida (WAV sin comprimir directo al DAC del dispositivo).

### Negativas / Mitigaciones:
* **Consumo de CPU en síntesis:** La generación de un buffer de 25 ms toma menos de $0.2\text{ ms}$ en Dart. Los buffers de clics se calculan una sola vez y se reutilizan en memoria (*caching*).
