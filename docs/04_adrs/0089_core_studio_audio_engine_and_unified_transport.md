# ADR 0089: Motor Canónico de Audio Core (StudioAudioEngine) y Transporte Unificado

## Estado
Aprobado

## Contexto
En Tunner Studio, la salida de audio físico se encontraba descentralizada entre múltiples servicios aislados (`DjDeckAudioService`, `AudioSynthesizerService`, `AudioPlaybackService`). Cada uno creaba instancias independientes de `AudioPlayer` e implementaba su propia gestión de estado y volumen.

Esta dispersión provocó un fallo crítico en la Consola DJ: al pausar la reproducción de un deck, la invocación asíncrona de `pause()` no actualizaba inmediatamente las banderas del modelo antes de que se ejecutara la sincronización de faders de volumen. Como resultado, la rutina de volumen interpretaba erróneamente que el deck aún estaba en reproducción activa y ejecutaba un `resume()` no deseado en el backend de GStreamer/WASAPI, imposibilitando pausar la música. Además, al volver a reproducir tras una pausa, se ejecutaba `play()` en lugar de `resume()`, reiniciando la pista desde el inicio en vez de continuarla.

Como Tunner es un software de producción musical y acústica profesional, la salida de audio no puede ser un "feature" secundario ni tener soluciones a medias, sino que debe constituir el núcleo oficial de infraestructura de la aplicación (`lib/core/audio/`).

## Decisión
1. **Creación del Dominio de Audio en `lib/core/audio/domain/`:**
   - `IStudioAudioEngine`: Contrato central para solicitar canales de audio (`getChannel(String channelId)`), controlar el transporte global o individual y liberar recursos.
   - `IStudioAudioChannel`: Contrato atómico para cada canal individual (`play`, `pause`, `stop`, `seek`, `setVolume`, `setPlaybackRate`, `loadSource`).
   - `StudioTransportStatus`: Enumeración estricta con estados `stopped`, `playing`, `paused`, `seeking`, `error`.
   - `StudioAudioTrackState`: Entidad inmutable con la posición temporal en milisegundos, volumen calibrado, tasa de reproducción y estado actual.
2. **Implementación de Infraestructura en `lib/core/audio/infrastructure/`:**
   - `StudioAudioEngine`: Implementación concreta que administra un pool dinámico de reproductores nativos, asegurando que `pause()` marque inmediatamente el canal como pausado a nivel síncrono antes del await nativo, y garantizando que las actualizaciones de volumen nunca despierten canales en estado `paused` o `stopped`.
   - `MemoryStudioAudioEngine`: Implementación en memoria para pruebas unitarias sin dependencias de hardware.
3. **Migración Completa de Consumidores (Cero Refactorización a Medias):**
   - Refactorizar `DjDeckAudioService` para delegar sus canales `dj_deck_a` y `dj_deck_b` al `IStudioAudioEngine`.
   - Refactorizar `AudioSynthesizerService` (Metrónomo, Diapasón, Dron Armónico) para utilizar canales dedicados del motor central.
   - Refactorizar `AudioPlaybackService` (Grabador de Práctica) para utilizar el motor central.
   - Asegurar que la arquitectura quede 100% limpia sin acoplamientos circulares.

## Consecuencias

### Positivas
- Se elimina la condición de carrera: Pausar detiene la música de inmediato y de forma definitiva hasta que el usuario decida reanudarla.
- Reanudación fiel: Al reanudar tras una pausa, la pista continúa exactamente donde se quedó.
- Consistencia arquitectónica: Todos los módulos de la aplicación acceden a la salida de audio bajo las mismas garantías deterministas y sin dependencias cruzadas entre features.
- Facilidad de pruebas: La suite completa puede probarse en entornos CI sin hardware físico gracias a `MemoryStudioAudioEngine`.

### Negativas / Mitigaciones
- Requiere actualizar múltiples servicios para adaptar sus llamadas al nuevo contrato unificado.
- Mitigación: Se provee una interfaz intuitiva con compatibilidad directa hacia los flujos existentes y pruebas de regresión exhaustivas.
