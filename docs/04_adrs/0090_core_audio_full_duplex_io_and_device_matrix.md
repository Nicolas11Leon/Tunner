# ADR 0090: Arquitectura Unificada de Entradas y Salidas de Audio en Core con Ring Buffer y Gestión de Dispositivos

## Estado
Aprobado

## Contexto
Tras consolidar el subsistema de salidas (`IStudioAudioEngine`) en `lib/core/audio/`, la captura de audio de entrada permanecía aislada dentro de `features/tuner/`. Esta asimetría limitaba la interoperabilidad de la plataforma: otros módulos (Grabador de Práctica, Espectrograma FFT, Transcripción y la Consola DJ) no podían acceder a un puerto canónico de entrada de micrófono ni seleccionar interfaces de audio de nivel profesional (e.g., Focusrite Scarlett, Universal Audio, interfaces USB multicanal).

Para alcanzar el estado del arte de una estación de trabajo de audio digital (DAW), el subsistema de Entrada debe formalizarse en `lib/core/audio/` con las mismas garantías de Arquitectura Limpia, determinismo y rendimiento que el subsistema de Salida, completando la matriz Full-Duplex del software.

## Decisión
1. **Creación del Dominio de Entrada en `lib/core/audio/domain/`:**
   - `AudioDeviceEntity`: Modelo inmutable que representa una interfaz de captura de audio del host (ID, etiqueta, canales soportados, estado predeterminado).
   - `AudioPcmFrame`: Contenedor inmutable de cuadros de audio con muestras en coma flotante normalizadas ($\in [-1.0, 1.0]$), bytes crudos PCM 16-bit, metadatos temporales de microsegundo y mediciones acústicas (RMS dBFS y Peak dBFS).
   - `AudioRingBuffer`: Buffer circular lock-free de tamaño fijo ($2^N$) en Dart puro para flujo continuo sin recolección de basura ni contención de hilos.
   - `IStudioAudioInputEngine`: Contrato central para listar dispositivos, seleccionar interfaces de captura, iniciar/detener el stream de audio y exponer flujos reactivos de cuadros y energía acústica.
2. **Implementación de Infraestructura en `lib/core/audio/infrastructure/`:**
   - `StudioAudioInputEngine`: Implementación concreta utilizando el plugin nativo `record` para captura en streaming, desacoplado de cualquier vista o feature.
   - `MemoryStudioAudioInputEngine`: Implementación en memoria que simula la captura con ondas senoidales sintéticas para pruebas unitarias e integración en CI sin requerir permisos ni hardware de micrófono.
3. **Integración con la Capa de Aplicación:**
   - `PitchDetectorService` y `TunerViewModel` se adaptan para delegar la enumeración de dispositivos y la captura física al nuevo `IStudioAudioInputEngine`.
   - Se mantiene la compatibilidad con el isolate de análisis DSP existente (McLeod Pitch Method y filtros acústicos).

## Consecuencias

### Positivas
- **Full-Duplex Simétrico:** El núcleo `lib/core/audio/` ahora administra tanto la entrada como la salida física del software bajo un estándar industrial unificado.
- **Soporte Profesional de Hardware:** Selección transparente de interfaces de audio USB externas, micrófonos dedicados y entradas de línea.
- **Rendimiento Máximo:** El Ring Buffer circular elimina la sobrecarga de asignación dinámica de memoria en cada callback de audio.
- **Reutilización Universal:** Cualquier herramienta presente o futura puede suscribirse al `pcmFrameStream` del core sin duplicar la lógica de captura.

### Negativas / Mitigaciones
- Requiere coordinar el ciclo de vida de la captura entre el motor de entrada y los consumidores que requieren aislamiento (Isolates).
- Mitigación: El motor emite cuadros atómicos `AudioPcmFrame` que pueden transferirse eficientemente mediante `SendPort` o buffers compartidos.
