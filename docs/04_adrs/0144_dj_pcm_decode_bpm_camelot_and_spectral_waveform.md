# Architecture Decision Record (ADR): 0144

## 1. Contexto y Problema
En la auditoría forense se evidenció:
1. `DjTrackLoaderModal._importLocalFile` y `_loadManualPath` pasaban un valor cableado `bpm: 124.0` y no decodificaban las muestras PCM de archivos locales seleccionados a través de `FilePicker`, por lo cual las pistas importadas no contaban con análisis real de tempo, detección armónica Camelot ni formas de onda espectrales reales.
2. Los vúmetros de canal en `DjVerticalChannelStrip` utilizaban una fórmula geométrica simulada basada en una envolvente exponencial `exp(-phase * 3.5)` ligada a la posición del compás, en vez de reflejar la energía RMS real de las muestras de audio.

## 2. Decisión Tomada
1. **Decodificador Canónico PCM RIFF/WAVE (`PcmWavDecoder`):**
   Implementar un decodificador puro en Dart de bajo nivel para archivos WAV (8, 16 y 32 bits PCM y float) que extrae los datos de audio a un `Float32List` normalizado mono.
2. **Pipeline de Carga con Detección en Isolate:**
   Conectar `DjTrackLoaderModal` para decodificar los bytes del archivo importado y pasar las muestras reales a `viewModel.loadTrackWithBeatTrackingAsync`, que ejecuta `BpmBeatTrackerEngine.estimateBpm`, `DjHarmonicCamelotEngine.estimateCamelotKeyFromSamples` y `DjTransitionSfxSynthesizer.computeSpectralWaveformSummary` en un Isolate secundario sin bloquear la UI a 60/120 FPS.
3. **Medición Balística VU Real en Canal:**
   Incorporar `getVuLevel(deckId)` en `DjConsoleViewModel`, calculando la raíz cuadrada del promedio cuadrático (RMS) de una ventana acústica de 33 ms alrededor de la posición actual del playhead, escalada por el fader de canal, perilla TRIM y switches de kill. Conectar este getter en `DjVerticalChannelStrip`.

## 3. Consecuencias
- **Positivas:**
  - Cero datos simulados o hardcodeados al importar pistas de audio locales en la consola DJ.
  - Los vúmetros de canal responden fielmente a los picos, silencios y dinámica real del audio.
  - Visualización espectral RGB verídica generada para cada archivo cargado.
- **Negativas / Mitigaciones:**
  - Los archivos en formatos comprimidos (.mp3/.m4a) que no sean WAV se cargan directamente en el motor de audio de plataforma sin análisis de muestras crudas, reservando la decodificación pesada para formatos descomprimidos estándar.
