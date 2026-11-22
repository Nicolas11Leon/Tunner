# ADR 0141: Salida de Audio Polifónico, Carga Externa SF2, Continuidad de Diapasón y Rango Universal de Dron

## Estado
Aprobado

## Contexto
El análisis del subsistema de síntesis de audio evidenció:
1. `PolyphonicVoicePool` implementaba síntesis aditiva y saturador analógico suave, pero carecía de métodos de conversión a WAV PCM para audición inmediata o persistencia.
2. `InstrumentSoundFontSelectorModal` contenía una lista estática de presets del banco por defecto pero no ofrecía al usuario la opción de cargar librerías SoundFont `.sf2` reales desde el disco.
3. `PcmWavSynthesizer.generateSineToneWav` aplicaba una envolvente de caída a cero al final del búfer de 1.5 segundos, lo cual generaba una interrupción de amplitud y clics audibles al reproducirse en modo bucle (`_isLooping = true`).
4. `HarmonicDroneConfig` poseía una aserción restrictiva (`assert(octave >= 1 && octave <= 6)`) y `HarmonicDroneModal` limitaba la selección a las octavas 2, 3 y 4, violando el principio cardinal de cobertura universal $A_0$ a $C_8$ (`AGENTS.md §4.1`).

## Decisión
1. **Renderizado WAV en PolyphonicVoicePool:**
   - Incorporar el método `Uint8List renderWavBlock({required double durationSeconds, int sampleRate = 44100})` en `PolyphonicVoicePool` para generar un archivo WAV estéreo estándar a partir de las notas polifónicas activas.
2. **Carga Real de SoundFonts (.sf2):**
   - Incorporar en `InstrumentSoundFontSelectorModal` un botón de acción para importar archivos `.sf2` utilizando `FilePicker` (o `IPlatformFileGateway`), pasando los bytes binarios a `synthService.loadSoundFontFromBytes`.
3. **Continuidad de Bucle en Diapasón:**
   - En `PcmWavSynthesizer.generateSineToneWav`, calcular la longitud del búfer de modo que contenga un número entero exacto de ciclos completos de la onda senoidal:
     $$M = \lfloor f \cdot \text{duration} \rceil, \quad N = \lfloor M \cdot \frac{f_s}{f} \rceil$$
   - Omitir el desvanecimiento forzado a cero en los extremos cuando se sintetiza en modo de bucle continuo, garantizando $\sin(0) = \sin(2\pi M) = 0$ y pendiente idéntica sin clics.
4. **Rango Universal de Dron:**
   - Ampliar la aserción de `HarmonicDroneConfig` a `octave >= 0 && octave <= 8`.
   - Modificar `HarmonicDroneModal` para admitir la selección de octavas desde 0 hasta 8 en la interfaz gráfica.

## Consecuencias
- **Positivas:**
  - El usuario puede emplear cualquier SoundFont `.sf2` de conservatorio o estándar General MIDI en el sintetizador.
  - El diapasón suena con pureza continua sin pausas ni ruidos periódicos.
  - El estudio de dron cubre la totalidad del rango acústico humano y orquestal ($A_0 = 27.5\text{ Hz}$ a $C_8 = 4186\text{ Hz}$).
- **Negativas:**
  - Archivos SoundFont grandes (>50 MB) consumen memoria en el dispositivo al cargarse en RAM. El parser existente maneja eficientemente tablas de muestras en bloques.
