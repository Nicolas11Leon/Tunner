# Plan de Implementación: US-2.1

## 1. Alcance y Objetivos
Implementar la cadena DSP completa en tiempo real de los Decks DJ:
- Aislamiento de 4 Stems (Voz, Batería, Bajo, Melodía).
- Ecualización de 3 bandas con cortes isolator (-infinito dB) ante activación de kill switches.
- Filtro bipolar continuo LPF/HPF con barrido exponencial.
- Línea de retardo circular de estado persistente (`StatefulDelayLine`) para Deck A y Deck B con retroalimentación acotada y sincronización por divisiones de beat.
- Conexión de audio en el grabador de mezcla en vivo de `DjConsoleViewModel`.

---

## 2. Archivos Afectados
1. `lib/features/dj_console/domain/dj_audio_processor.dart`
   - Incorporar clase `StatefulDelayLine`.
   - Agregar instancias `_delayA` y `_delayB` en `DjAudioProcessor`.
   - Extender `mixBuffers` con parámetros `stemsA` y `stemsB`.
   - Refinar `apply3BandEq` para soportar cortes totales sin fugas cuando la ganancia de una banda es 0.0.
2. `lib/features/dj_console/presentation/dj_console_view_model.dart`
   - Enviar `deckA.stems` y `deckB.stems` a `mixBuffers`.
   - Aplicar `deckA.isKillLow ? 0.0 : deckA.gainLow` (y mid/high) al alimentar `mixBuffers`.
3. `test/features/dj_console/us_2_1_dj_deck_dsp_chain_test.dart`
   - Pruebas unitarias de aislamiento de stems, cortes kill, filtro bipolar y persistencia del delay en bloques sucesivos.

---

## 3. Plan de Pruebas y Validación
- `flutter analyze --no-fatal-infos`: Cero warnings ni errores.
- `flutter test`: 100% de pruebas pasando.
