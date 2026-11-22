# ADR 0138: Streaming Real de Ventana PCM, Claridad NSDF y Eliminación de Simulación Armónica

## Estado
Aprobado

## Contexto
Durante la auditoría forense integral de código de pre-v1.0.0, se identificaron tres discrepancias críticas en el subsistema de análisis tímbrico y afinación:
1. `TunerViewModel` mantenía `latestAudioSamples` en null durante la afinación normal por micrófono, impidiendo que el laboratorio acústico recibiera las muestras reales a menos que se ejecutara manualmente un método secundario.
2. `HarmonicSeriesAnalyzer.analyze` implementaba un fallback sintético que generaba armónicos artificiales mediante la fórmula $1/k^{1.2}$ cuando `samples == null`, engañando al usuario sobre el contenido espectral de su instrumento.
3. `HarmonicSpectrogramModal` forzaba una frecuencia fundamental de 440 Hz cuando `vm.frequency <= 20.0`, mostrando armónicos de un tono inexistente durante periodos de silencio.
4. El cálculo de DFT en `HarmonicSeriesAnalyzer` carecía de enventanado (windowing), provocando fugas espectrales (spectral leakage) entre sobretonos adyacentes.

## Decisión
1. Extender `IPitchDetectorService` con los callbacks de dominio:
   - `Function(List<double> audioWindow)? onAudioWindowCaptured`
   - `Function(double clarity)? onClarityDetected`
2. En `PitchDetectorService` (dentro del Isolate de procesamiento DSP), emitir hacia el hilo principal la claridad del pico NSDF calculada por McLeod Pitch Method y una ventana flotante de muestras normalizadas.
3. En `TunerViewModel`, conectar dichos callbacks para almacenar `latestAudioSamples` y `lastClarity`, asegurando que `HarmonicSpectrogramModal` y los analizadores reciban datos reales.
4. En `HarmonicSeriesAnalyzer`, eliminar por completo el bucle sintético $1/k^{1.2}$. Si no se suministran muestras o las muestras son insuficientes, retornar `TimbreAnalysisResult.empty`.
5. Aplicar una ventana de Hann simétrica ($w[i] = 0.5 \cdot (1 - \cos(2\pi i / (N - 1)))$) a las muestras antes de calcular la DFT dirigida.
6. En `HarmonicSpectrogramModal`, evaluar si `hasSignal` es verdadero antes de invocar el analizador. Si no hay señal, retornar `TimbreAnalysisResult.empty` y mostrar el estado de espera en la interfaz de usuario.

## Consecuencias
- **Positivas:**
  - Cero datos acústicos inventados o simulados en el pipeline de análisis tímbrico.
  - El espectrograma refleja con exactitud la física de la señal recibida por el micrófono.
  - La ventana de Hann reduce sustancialmente el piso de ruido y la distorsión interarmónica calculada (THD).
- **Negativas:**
  - Mayor consumo marginal de ancho de banda entre Isolates al transmitir la ventana flotante cada ciclo de análisis. Se mitiga desacoplando la emisión con un búfer de tamaño acotado.
