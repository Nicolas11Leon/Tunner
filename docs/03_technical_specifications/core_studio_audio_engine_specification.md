# Especificación Técnica: Motor Canónico de Audio Core (Studio Audio Engine)

## Metadatos del Documento
- **ID del Documento:** `DOC-CORE-AUDIO-2026-01`
- **Título Oficial:** Especificación Técnica de Arquitectura e Infraestructura de Salida de Audio
- **Estado:** Aprobado
- **Fecha de Creación:** 2026-11-16
- **Última Modificación:** 2026-11-16
- **Fase Asociada:** Fase 1 / Infraestructura Core
- **Autor / Revisor Principal:** Tunner Core Architecture Team

---

## 1. Resumen Ejecutivo
Este documento define la arquitectura y las reglas de implementación del motor central de reproducción y transporte de audio (`StudioAudioEngine`) en `lib/core/audio/`. El motor unifica la totalidad de los canales de salida física de la plataforma bajo un modelo de estados determinista, resolviendo los problemas de desincronización, saturación de canales y condiciones de carrera entre el transporte y los faders de ganancia.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Previamente, los componentes de software (Consola DJ, Sintetizador/Metrónomo, Grabador) creaban sus propias instancias de reproductores. Al enviar comandos de transporte como `pause()` o `play()`, la latencia de comunicación entre el isolate principal de Dart y los plugins nativos (GStreamer en Linux, WASAPI en Windows, CoreAudio en macOS) producía desfasajes temporales donde los bucles de volumen reactivos (`_syncAudioVolumes`) inspeccionaban banderas desactualizadas y enviaban órdenes de `resume()` a canales que debían estar silenciados.

### 2.2 Fundamento Teórico y de Transporte
El transporte de una estación de trabajo de audio digital (DAW) sigue un autómata de estados finito (FSM):
$$\text{TransportState} \in \{\text{stopped}, \text{playing}, \text{paused}, \text{seeking}, \text{error}\}$$

Reglas de transición:
1. $\text{play}(): \text{stopped} \to \text{playing}$ (desde $t = 0$).
2. $\text{play}(): \text{paused} \to \text{playing}$ (reanudación desde $t = t_{\text{paused}}$).
3. $\text{pause}(): \text{playing} \to \text{paused}$ (detención de flujo sin reiniciar $t$).
4. $\text{stop}(): \{\text{playing}, \text{paused}\} \to \text{stopped}$ ($t = 0$).
5. $\text{setVolume}(v): \text{state} \to \text{state}$ (invarianza de estado: el volumen nunca altera el estado del autómata).

---

## 3. Especificación Funcional Detallada

### 3.1 Contratos de Dominio (`lib/core/audio/domain/`)
- `StudioTransportStatus`: Define los 5 estados canónicos.
- `IStudioAudioChannel`: Expone:
  - `Future<void> loadSource({String? filePath, Uint8List? bytes, bool loop})`
  - `Future<void> play()`
  - `Future<void> pause()`
  - `Future<void> stop()`
  - `Future<void> seek(Duration position)`
  - `Future<void> setVolume(double volume)`
  - `Future<void> setPlaybackRate(double rate)`
  - `StudioTransportStatus get status`
  - `bool get isPlaying`
  - `bool get isPaused`
  - `Duration get currentPosition`
  - `Stream<StudioAudioTrackState> get stateStream`
- `IStudioAudioEngine`: Expone:
  - `IStudioAudioChannel getChannel(String channelId)`
  - `Future<void> pauseAll()`
  - `Future<void> stopAll()`
  - `Future<void> dispose()`

### 3.2 Reglas de Concurrencia e Infraestructura
1. **Bandera Síncrona Inmediata:** La propiedad `_status` del canal debe transicionar inmediatamente a `StudioTransportStatus.paused` de forma síncrona en el hilo principal antes de esperar el `Future` de la plataforma nativa.
2. **Guarda Incondicional en Volumen:** La rutina de aplicación de volumen verifica:
   ```dart
   if (_status == StudioTransportStatus.paused || _status == StudioTransportStatus.stopped) {
     // Aplica el volumen al backend pero NUNCA llama a resume().
   }
   ```
3. **Piso Anti-Freeze Seguro:** El volumen efectivo se calibra a $0.0001$ ($-80\text{ dBFS}$) durante reproducción activa para evitar estancamiento en Linux GStreamer, pero si el canal está en pausa o detenido, se mantiene silenciado sin activar el pipeline.
