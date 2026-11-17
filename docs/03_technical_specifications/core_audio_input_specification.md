# Especificación Técnica: Motor Canónico de Entrada de Audio Core (Studio Audio Input Engine)

## Metadatos del Documento
- **ID del Documento:** `DOC-CORE-AUDIO-IN-2026-02`
- **Título Oficial:** Especificación Técnica de Ingesta, Ring Buffer y Dispositivos de Captura
- **Estado:** Aprobado
- **Fecha de Creación:** 2026-11-16
- **Última Modificación:** 2026-11-16
- **Fase Asociada:** Fase 1 / Infraestructura Core
- **Autor / Revisor Principal:** Tunner Core Architecture Team

---

## 1. Resumen Ejecutivo
Este documento formaliza la especificación técnica de la ingesta física de audio en Tunner Studio. Define los contratos e implementaciones de `lib/core/audio/` responsables de la captura de micrófono y líneas analógicas/digitales, el almacenamiento temporal en memoria circular lock-free y la transformación de flujos de bytes PCM en estructuras matemáticas normalizadas para procesamiento en tiempo real.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
La captura de audio en sistemas de escritorio y móviles sufre de variaciones en los tamaños de buffer nativo, cambios imprevistos de frecuencia de muestreo y pausas por recolección de basura (Garbage Collector) cuando se crean nuevos objetos en cada ciclo de interrupción de hardware. Esto degrada la precisión de la detección de tono y puede inducir latencias superiores al objetivo no negociable de $<10\text{ ms}$.

### 2.2 Fundamento Teórico y Matemático
1. **Normalización de Muestras PCM 16-Bit Little Endian:**
   Para cada muestra entera $s \in [-32768, 32767]$:
   $$x = \frac{s}{32768.0} \in [-1.0, 1.0)$$

2. **Cálculo de Energía RMS y dBFS:**
   Dado un bloque de $N$ muestras normalizadas $\{x_1, x_2, \dots, x_N\}$:
   $$\text{RMS} = \sqrt{\frac{1}{N}\sum_{i=1}^N x_i^2}$$
   $$\text{dBFS} = \begin{cases} 20 \log_{10}(\text{RMS}) & \text{si } \text{RMS} > 10^{-5} \\ -100.0 & \text{en otro caso} \end{cases}$$

3. **Cálculo de Pico Absoluto (Peak dBFS):**
   $$\text{Peak} = \max_{1 \le i \le N} |x_i|$$
   $$\text{Peak dBFS} = 20 \log_{10}(\text{Peak})$$

4. **Principio de Operación del Ring Buffer Lock-Free:**
   Con una capacidad de buffer $C = 2^k$, los punteros de escritura $W$ y lectura $R$ se incrementan monotónicamente. Los índices reales se obtienen mediante una operación binaria rápida de máscara:
   $$\text{index} = \text{pointer} \ \& \ (C - 1)$$
   Esto elimina divisiones enteras y previene bloqueos de exclusión mutua en hilos concurrentes.

---

## 3. Especificación Funcional Detallada

### 3.1 Contratos de Dominio (`lib/core/audio/domain/`)
- `AudioDeviceEntity`: Identificador `id`, nombre descriptivo `label`, bandera `isDefault`, número de canales de entrada `inputChannels` y lista de frecuencias de muestreo soportadas.
- `AudioPcmFrame`: Contiene `Float32List samples`, `Uint8List rawBytes`, `int sampleRate`, `int channels`, `int timestampMicros`, `double rmsDb` y `double peakDb`.
- `AudioRingBuffer`: Métodos `write(Float32List data)`, `read(int count)`, `availableRead`, `availableWrite`, `clear()`.
- `IStudioAudioInputEngine`: Métodos `listInputDevices()`, `setInputDevice(String id)`, `startCapture()`, `stopCapture()`, `dispose()`, y propiedades reactivas `Stream<AudioPcmFrame> pcmFrameStream`, `Stream<double> rmsDbStream`, `Stream<double> peakDbStream`.
