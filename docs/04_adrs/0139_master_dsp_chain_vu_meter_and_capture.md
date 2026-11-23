# ADR 0139: Conexión Serial de la Cadena DSP Master, Medición Balística y Captura WAV Real

## Estado
Aprobado

## Contexto
El análisis forense del subsistema de audio central reveló:
1. `StudioAudioDeviceMatrixService._startMeterLoop` simulaba los niveles estéreo mediante una fórmula estática dependiente solo de `effectiveMasterGain` (`leftRms: 0.60 * effGain`, `rightRms: 0.62 * effGain`), simulando actividad acústica falsa incluso cuando no se reproducía sonido alguno.
2. La cadena de efectos maestros (`_filterLow`, `_filterMid`, `_filterHigh`, `_dynamicsProcessor`) estaba instanciada pero desacoplada del pipeline de audio maestro, careciendo de un método formal de procesamiento de muestras estéreo en tiempo real.
3. El servicio de captura maestra (`StudioMasterCaptureService`) implementaba `appendStereoSamples`, pero ninguna parte del núcleo de la aplicación suministraba los bloques de audio procesados al iniciar la grabación maestra (`startMasterRecording`).

## Decisión
1. Declarar formalmente en el contrato `IStudioAudioDeviceMatrixPort`:
   ```dart
   void processMasterStereoSamples(List<double> left, List<double> right);
   ```
2. Implementar `processMasterStereoSamples` en `StudioAudioDeviceMatrixService` encadenando:
   - Verificación de silencio (`isMuted`).
   - Colapso monoaural promediando canales si `isMono` está activo.
   - Procesamiento en cascada de los filtros Biquad Low-Shelf, Peaking y High-Shelf (con bypass condicional).
   - Procesamiento no lineal del compresor de masterización con cálculo de reducción de ganancia en dB.
   - Multiplicación por la ganancia maestra efectiva.
   - Cálculo real de $V_{\text{RMS}}$ y $V_{\text{Peak}}$ para canal izquierdo y derecho, actualizando `_masterMeterData`.
   - Volcado de muestras procesadas a `_captureService.appendStereoSamples` si `isMasterRecording` es verdadero.
3. Reemplazar el bucle simulado de `_startMeterLoop` por un temporizador de balística acústica que atenúa suavemente los niveles RMS y de pico hacia cero con una constante de tiempo proporcional a $20\text{ dB/s}$, manteniendo el vúmetro en reposo absoluto cuando no hay audio circulando.

## Consecuencias
- **Positivas:**
  - El bus maestro y el widget `StudioMasterHardwareConsoleWidget` representan de manera fidedigna la dinámica acústica del audio de la estación de trabajo.
  - El botón `REC MASTER` produce archivos de audio que contienen la mezcla procesada real.
  - Se eliminan por completo los números fijos y simulaciones de vúmetro en producción.
- **Negativas:**
  - Carga computacional adicional en Dart al procesar bloques de muestras muestra a muestra en el hilo de la matriz si no se descarga a C99/FFI. Se mantiene optimizado para bloques estándar de 512–2048 muestras.
