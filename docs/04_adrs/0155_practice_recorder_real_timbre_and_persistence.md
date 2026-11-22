# ADR 0155: Eliminacion de Tomas Falsas, Analisis Timbrico Real FFT/DFT, Downsampling Proporcional y Persistencia MultiTrack

## Estado
Aprobado

## Contexto
La auditoria de integridad acustica y arquitectura del modulo `practice_recorder` detecto cinco defectos criticos de simulacion y perdida de datos:

1. **Tomas falsas presembradas:** `PracticeRecorderController.initDefaultMultiTrackSession` inyectaba dos tomas ficticias (`take_1` y `take_2`) con rutas vacias y metricas inventadas, mientras `seedDefaultRecordingsIfEmpty` agregaba dos grabaciones falsas (`rec_acoustic_demo_a440`, `rec_club_groove_124bpm`) cuyos archivos no existian en la ruta de documentos del usuario.
2. **Fallback acustico sintetico:** `playActiveRecording` y `playTakeAudio` invocaban `_audioSynthesizer.playNoteTone(...)` (pitido de 440 Hz o frecuencia de referencia) cuando `filePath` estaba vacio, simulando reproduccion de una grabacion inexistente.
3. **Metricas timbricas hardcodeadas:** `recordSampleForMultiTrack` asignaba `spectralCentroidHz: pitch * 2.6`, `thdPercent: 3.2` y un RMS fijo de fallback `0.25`, ignorando el espectro armonico real del instrumento.
4. **Truncamiento destructivo de forma de onda:** `addWaveformPeak` eliminaba el elemento en indice `0` al superar 60 muestras (`_currentWaveformPeaks.removeAt(0)`), descartando el inicio de toda grabacion mayor a 6 segundos y dibujando 40 barras inventadas en `_WaveformPainter` si `peaks.isEmpty`.
5. **Ausencia de persistencia multipista y playhead desvinculado:** `AppUserSettingsEntity` no serializaba `MultiTrackSessionEntity`, perdiendo todas las tomas, analisis de pitch y pistas espectrales al reiniciar la aplicacion; y `SpectralComparatorModal` no pasaba `currentPlaybackPositionNormalized` a `SpectralComparatorPainter`.

## Decision

1. **Inicializacion limpia sin datos falsos:**
   - `initDefaultMultiTrackSession` inicializa `MultiTrackSessionEntity` con una lista mutable vacia (`<PracticeTakeEntity>[]`) y selecciones A/B en `null`.
   - `seedDefaultRecordingsIfEmpty` deja de insertar grabaciones sinteticas ficticias.

2. **Eliminacion del fallback sintetico en reproduccion:**
   - Tanto `playActiveRecording` como `playTakeAudio` validan que `filePath.trim().isNotEmpty`. En caso contrario o ante fallo de `IAudioPlaybackService.play`, mantienen `_isPlayingAudio = false`, emiten una advertencia via `StudioDebugLogger` y notifican a la UI sin llamar a `IAudioSynthesizerService.playNoteTone`. Se remueve la dependencia innecesaria de `IAudioSynthesizerService` en `PracticeRecorderController`.

3. **Analisis timbrico real mediante `HarmonicSeriesAnalyzer`:**
   - `PitchDetectorService` emite `onAudioWindowCaptured` y `onClarityDetected` antes de `onPitchDetected` para garantizar que `_latestAudioSamples` este sincronizado con el ciclo actual de pitch.
   - `TunerViewModel` reenvia `_latestAudioSamples` a `PracticeRecorderController.recordSampleForMultiTrack`.
   - `recordSampleForMultiTrack` ejecuta `HarmonicSeriesAnalyzer(maxHarmonics: 8).analyze(...)` con ventana de Hann y DFT dirigida. Solo cuando `timbre.harmonics.isNotEmpty` se registra un `TimedSpectralSample` con `spectralCentroidHz`, `thdPercent` y `rmsEnergy` medidos fisicamente sobre la ventana PCM.

4. **Downsampling proporcional de forma de onda en toda la duracion:**
   - Se mantiene un acumulador de picos brutos `_rawWaveformPeaks` (con compactacion binaria por parejas al superar un tope seguro de 16384 muestras para garantizar memoria acotada en grabaciones largas) y se proyecta proporcionalmente en `_currentWaveformPeaks` mediante max-pooling por cubetas hasta `maxWaveformPeaks = 120`.
   - Si el numero de muestras brutas es menor o igual a `120`, se conservan integramente sin alteracion.
   - En `practice_recording_player_modal.dart`, `_WaveformPainter` elimina la generacion de 40 barras sinteticas cuando `peaks.isEmpty` y renderiza la linea base horizontal de amplitud cero junto al playhead.

5. **Persistencia de `MultiTrackSessionEntity` y Playhead Espectral Reactivo:**
   - `AppUserSettingsEntity` incorpora el campo opcional `MultiTrackSessionEntity? multiTrackSession` (nullable para preservar constructor `const defaultSettings` y compatibilidad hacia atras con JSON heredados), con serializacion condicional en `toMap()` y parsing resiliente en `fromMap()`.
   - `PracticeRecorderController.loadSettingsInto` restaura `settings.multiTrackSession` cuando esta presente, y `TunerViewModel._triggerAutoSave` persiste `_recorderController.multiTrackSession`.
   - `SpectralComparatorModal` envuelve su contenido en un `ListenableBuilder` suscrito a `widget.viewModel` y calcula `currentPlaybackPositionNormalized` a partir de `playbackPosition` respecto a la duracion maxima de las tomas comparadas (o `playbackDuration` como respaldo), pasandolo a `SpectralComparatorPainter`.

## Consecuencias

- **Positivas:**
  - Fidelidad acustica completa en el comparador espectral y en los visualizadores de forma de onda.
  - Cero datos falsos o enmascaramiento de archivos faltantes con pitidos de 440 Hz.
  - Las grabaciones largas conservan la envolvente dinamica desde el inicio hasta el final.
  - Las sesiones multipista sobreviven reinicios completos de la aplicacion de manera transparente y offline.
  - El usuario observa la aguja de reproduccion sincronizada sobre las curvas de entonacion y centroide espectral.

- **Negativas / Trade-offs:**
  - Incremento marginal del tamano del JSON de configuracion del usuario proporcional al numero de tomas y muestras en `multiTrackSession`. Se mitiga manteniendo la lista de tomas grabadas por el usuario y capturando muestras con umbral temporal minimo de 20 ms.
  - Las pruebas unitarias heredadas que dependian de tomas falsas presembradas deben crear explicitamente sus tomas de prueba mediante `addPracticeTake` o `startPracticeRecording`/`stopPracticeRecording`.
