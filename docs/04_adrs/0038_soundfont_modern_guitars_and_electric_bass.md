# ADR 0038: Incorporación de Timbres Contemporáneos de Guitarras Modernas y Bajo Eléctrico en el Banco SoundFont SF2

---

## Estado
Aprobado (Approved)

---

## Contexto
El motor SoundFont SF2 inicial implementado en el proyecto Tunner (ADR-0036) incluyó un banco canónico acústico centrado en instrumentos orquestales clásicos (Piano de Cola, Flauta Traversa, Violín, Violonchelo y Guitarra Clásica con cuerdas de nylon).

No obstante, los estudiantes y músicos contemporáneos requieren herramientas acústicas adaptadas a géneros modernos (rock, pop, jazz, funk, música acústica moderna). La ausencia de timbres específicos de **Guitarra Acústica con Cuerdas de Acero (Steel String)**, **Guitarra Eléctrica Limpia** y **Bajo Eléctrico** obligaba a utilizar tonos genéricos o clásicos que no reproducían fielmente la resonancia de pastillas electromagnéticas ni la profundidad del registro sub-grave de un bajo.

---

## Decisión
Se decide incorporar formalmente tres nuevos presets canónicos al banco embebido `TunnerAcousticSoundFontBank`:
1. **Steel String Guitar (General MIDI #25):** Modelo con armónicos pares e impares de alta energía ($2f_0$ a $5f_0$), ataque de púa y decaimiento percusivo prolongado.
2. **Electric Guitar Clean (General MIDI #27):** Modelo de resonancia magnética con compresión analógica suave $\tanh(1.2 \cdot s)$ que emula el timbre de un amplificador valvular limpio.
3. **Electric Bass Fingerstyle (General MIDI #33):** Muestra raíz en $E_2$ ($82.41\text{ Hz}$) con alta fundamental, segundo armónico cálido y respuesta suave en graves.

La síntesis se mantiene 100% en Pure Dart mediante el oscilador con remuestreo cúbico Hermite (`Sf2WavetableOscillator`) y generadores de envolvente VolEG, preservando la regla de latencia sub-10ms y cero dependencias nativas externas.

---

## Consecuencias

### Positivas:
- **Mayor versatilidad musical:** Los guitarristas y bajistas disponen de timbres idénticos a sus instrumentos para afinar, practicar escalas y reproducir partituras.
- **Rendimiento determinista:** No se agregan archivos pesados en disco ni dependencias binarias; las muestras raíz se generan proceduralmente al inicio en $< 15\text{ ms}$.
- **Consistencia de Clean Architecture:** Todo el modelado reside en la capa de dominio (`lib/features/audio_synthesizer/domain/sf2/`).

### Neutras / Mitigaciones:
- El banco SF2 en memoria incrementa su tamaño en aproximadamente $380\text{ KB}$ de buffers PCM, lo cual es despreciable en dispositivos modernos y no afecta el recolector de basura de Dart.
