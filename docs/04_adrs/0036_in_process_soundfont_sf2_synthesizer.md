# ADR-0036: In-Process SoundFont SF2 Synthesizer and Wavetable Audio Engine

---

## Estado
**Aprobado (Approved)**

---

## Contexto

El proyecto **Tunner** tiene como objetivo fundamental ofrecer una educación musical accesible y de alta fidelidad acústica. Si bien el sistema ya cuenta con síntesis senoidal pura (`ToneGeneratorService`) y síntesis aditiva armónica (`StemAudioSynthesizer`), los estudiantes de instrumento y canto se benefician enormemente al escuchar notas de referencia y acompañamiento con timbres acústicos reales de instrumentos tradicionales (*Grand Piano*, *Flauta Travesera*, *Violín*, *Violonchelo* y *Guitarra Clásica*).

Depender de bibliotecas nativas C/C++ externas (como fluidsynth o TinySoundFont) a través de FFI para plataformas móviles (Android/iOS) y de escritorio (Linux/macOS/Windows) añade una fuerte complejidad en la cadena de compilación cruzada, incrementa el tamaño del binario y arriesga la estabilidad del proceso si un puntero falla. Por otro lado, delegar la síntesis a un servidor HTTP/gRPC está estrictamente prohibido por la Constitución de Tunner (cero microservicios, latencia $< 5\text{ ms}$, 100% offline).

---

## Decisión

Se adopta una arquitectura de **Síntesis SoundFont SF2 en Pure Dart** integrada en el monolito local:

1. **Parser Canónico RIFF/SF2 (`Sf2Parser`):**
   - Decodificación estricta de sub-chunks RIFF (`LIST/INFO`, `LIST/sdta`, `LIST/pdta`).
   - Lectura indexada de `phdr` (preset headers), `pbag` (preset zones), `inst` (instrument headers), `ibag` (instrument zones), `igen` (instrument generators) y `shdr` (sample headers).

2. **Wavetable Oscillator con Interpolación Hermite / Cúbica:**
   - Algoritmo de remuestreo de 4 puntos (Hermite 3rd-order spline) para evitar aliasing y ruido de cuantización al transponer muestras a diferentes frecuencias.

3. **Generador de Envolvente SF2 VolEG:**
   - Modelo canónico Delay $\rightarrow$ Attack $\rightarrow$ Hold $\rightarrow$ Decay $\rightarrow$ Sustain $\rightarrow$ Release conforme al estándar SoundFont 2.04.

4. **Banco Canónico Integrado "Tunner Acoustic Essentials":**
   - Un banco SF2 modular y ultraoptimizado con muestras seleccionadas de alta calidad para piano, flauta, violín y cello, asegurando funcionamiento *out-of-the-box* sin descargas adicionales.
   - Posibilidad para el usuario de cargar sus propios archivos `.sf2` locales desde el sistema de archivos.

5. **Fallback Transparente:**
   - En caso de solicitar notas fuera del rango o si un preset personalizado no está cargado, el motor conmuta instantáneamente a síntesis aditiva armónica sin interrupción de audio.

---

## Consecuencias

### Positivas
- **Fidelidad Acústica Excepcional:** Los ejercicios de entonación y ear training adquieren realismo tímbrico inmediato.
- **Portabilidad Universal:** 100% Dart puro, funciona idénticamente en Linux, macOS, Windows, Android e iOS sin necesidad de configurar toolchains de C++.
- **Determinismo y Rendimiento:** Generación directa en búferes PCM/WAV en $< 3\text{ ms}$ sin consumo de CPU residual en reposo.

### Desafíos Mitigados
- **Consumo de Memoria:** Se almacena el banco de muestras en enteros `Int16List` continuos sin conversiones redundantes, optimizando la huella de RAM.
