# ADR 0080: Motor de Emisión de Audio Real para Consola DJ y Teclado Maestro

## Estado
Aprobado

## Contexto
Durante el análisis forense de la preparación de la versión Beta, se detectó que la Consola de DJ Virtual (`lib/features/dj_console`) y el Teclado Maestro Universal (`lib/features/instrument`) poseían una arquitectura puramente visual o matemática en memoria volátil:
1. Al activar `PLAY` en un deck, no existía un pipeline de audio físico enlazado a los parlantes del sistema operativo; únicamente se modificaba un booleano en memoria y se ejecutaba un temporizador visual para girar el jog wheel.
2. Al pulsar una tecla en el teclado maestro, `ProceduralInstrumentSynthesizer` calculaba los flotantes PCM en memoria RAM pero nunca enviaba dichos bytes a un reproductor o dispositivo de salida.
3. El usuario percibía la plataforma como "incompleta o mokeada" debido a la falta de retroalimentación sonora en componentes diseñados para producción musical e interpretación en vivo.

## Decisión
1. **Adopción de Arquitectura de Audio Multi-Deck (`DjDeckAudioService`):**
   - Implementar un servicio de infraestructura dedicado que encapsule dos instancias independientes de `AudioPlayer` (para Deck A y Deck B).
   - Generar sintéticamente bucles rítmicos audibles (Kick, Snare, Hi-hat y Bassline de 4 compases en WAV PCM) como pistas iniciales de demostración para que el usuario experimente salida de audio física inmediata.
   - Sincronizar reactivamente el fader de canal, el fader maestro y el crossfader aplicando curvas de ganancia continua a `AudioPlayer.setVolume`.
   - Mapear el fader de pitch continuo con `AudioPlayer.setPlaybackRate` para permitir aceleración/frenado de tempo y transposición de tono en tiempo real.
2. **Síntesis Audible para el Teclado Maestro:**
   - Crear un canal de reproducción de baja latencia en `AudioSynthesizerService` capaz de convertir los buffers PCM generados por `ProceduralInstrumentSynthesizer` en bloques WAV y ejecutarlos inmediatamente mediante `BytesSource`.
3. **Carga de Archivos de Audio Reales:**
   - Permitir a los decks de DJ recibir rutas de archivos físicos (`DeviceFileSource`) para reproducir canciones completas de la biblioteca del usuario.

## Consecuencias

### Positivas
- **Emisión Sonora 100% Real:** Tanto la Consola DJ como el Teclado Maestro emiten sonido físico por los altavoces y auriculares del dispositivo.
- **Transición Funcional a Beta:** Se eliminan los mocks y simulaciones mudas en los componentes centrales de interpretación.
- **Fidelidad Acústica:** El crossfader, el pitch fader y los controles de transporte operan con retroalimentación auditiva inmediata.

### Negativas / Mitigaciones
- **Consumo de Recursos:** Dos reproductores simultáneos de audio aumentan el uso de descriptores de audio del sistema operativo. Esto se mitiga destruyendo y liberando las instancias de `AudioPlayer` cuando se cierra la consola (`dispose`).
- **Latencia de Plataforma:** En sistemas Linux con servidores PulseAudio/ALSA antiguos, la latencia de inicialización del stream puede oscilar entre 15 y 30 ms. Se mitiga manteniendo los reproductores precargados en memoria.
