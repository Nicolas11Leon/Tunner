# ADR 0013: Motor de Reproducción Acústica Procedural de Partituras en Memoria

## Estado
Aceptado (Accepted)

---

## Contexto
El reproductor de partituras de Tunner permitía seguir métricamente el avance del cursor (*playhead*) visual a lo largo de los compases, pero carecía de una señal sonora que permitiera al estudiante escuchar la melodía de las notas escritas.
Para mantener el principio de **cero dependencias de red y 100% offline**, la síntesis no debe depender de librerías de SoundFonts pesadas ni servicios de streaming. Debe ser rápida, ligera, matemáticamente exacta y completamente desacoplada mediante Clean Architecture.

---

## Decisión
1. Extender `PcmWavSynthesizer` en la capa de dominio (`lib/features/audio_synthesizer/domain/pcm_wav_synthesizer.dart`) con el método puro `generateMusicalNoteWav({required double frequencyHz, required int durationMs, ...})`.
2. Modelar las notas musicales con una envolvente ADSR (Ataque 15 ms, Decaimiento 35 ms, Sostenimiento 0.85, Relajación 25 ms) y síntesis aditiva multifrecuencia (fundamental al 70%, 2do armónico al 20%, 3er armónico al 10%) para lograr un timbre orquestal cálido sin chasquidos digitales.
3. Extender el contrato de dominio `IAudioSynthesizerService` con:
   ```dart
   Future<void> playNoteTone({
     required double frequencyHz,
     required Duration duration,
     double volume = 0.8,
   });
   ```
4. Conectar la reproducción sonora con el evento de tick del metrónomo en `TunerViewModel`, respetando la ganancia efectiva del canal "voice" de la consola de mezcla (`_mixerConsole.getEffectiveGain("voice")`).
5. Proveer soporte completo en el test double `MemoryAudioSynthesizerService` para pruebas de regresión deterministas.

---

## Consecuencias

### Positivas
- **Didáctica Musical Superior:** Los estudiantes pueden escuchar el modelo acústico antes de tocar o durante la práctica.
- **Soporte Minus-One:** Silenciar la melodía en el mezclador permite practicar sobre el metrónomo y acompañamiento.
- **Clean Architecture Pura:** Ninguna dependencia de Flutter UI en la síntesis matemática.
- **Zero Disk Overhead:** Los buffers WAV de 16 bits se generan proceduralmente en RAM en microsegundos y se reproducen en streaming de memoria.

### Desafíos y Mitigaciones
- **Concurrencia de Audio:** Se utiliza una instancia dedicada de `AudioPlayer` para notas melódicas en la infraestructura, separada del reproductor de clics de metrónomo para evitar colisiones de buffer.
