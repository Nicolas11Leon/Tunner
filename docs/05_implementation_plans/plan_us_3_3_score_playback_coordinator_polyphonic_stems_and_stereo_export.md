# Plan de Implementacion: US-3.3 Unificacion de ScorePlaybackCoordinator Polifonico y Sintesis Multi-Stem Estereo Real

## Metadatos
- **ID:** PLAN-US-3.3
- **Historia de Usuario Asociada:** US-3.3 (#139)
- **Estado:** Approved
- **Fecha:** 2026-11-22
- **Autor:** Nicolas Leon (SM/PO/Devs) & Agentes 01/02
- **Rama:** `feature/us-3.3-score-playback-coordinator-polyphonic-stems-and-stereo-export`

---

## 1. Objetivos Tecnicos
1. Refactorizar `ScorePlaybackCoordinator` para almacenar los timers de pre-escucha en `Map<int, Timer> _activePreviewTimers` y cancelarlos en `previewNote`, `stopPlayback`, `pausePlayback` y `dispose`.
2. Modificar `TunerViewModel.selectAndPreviewScoreNote` para suprimir la llamada redundante a `_audioSynthesizer.playNoteTone`.
3. Extender el callback de tick del metrónomo en `TunerViewModel` para sintetizar todas las notas concurrentes en `subTick` y las pistas de acompañamiento de `_activePackage.tracks.skip(1)` según `_mixerConsole.getEffectiveGain`.
4. Extender `StemAudioSynthesizer` agregando `floatStereoBufferToWav` e integrando el 100 % de los stems en `mixerConsole.stems` en la exportación de la mezcla maestra estéreo de 2 canales.

---

## 2. Plan Paso a Paso

### Paso 1: `ScorePlaybackCoordinator`
- Agregar campo `final Map<int, Timer> _activePreviewTimers = {};`.
- En `previewNote`:
  - Cancelar timer activo si `_activePreviewTimers.containsKey(midi)`.
  - Registrar el nuevo `Timer` en el mapa.
  - Al expirar, ejecutar `voicePool.noteOff(midi)` y remover la entrada del mapa.
- En `pausePlayback`, `stopPlayback` y `dispose`: cancelar todos los timers de `_activePreviewTimers` y limpiar el mapa.

### Paso 2: `TunerViewModel`
- En `selectAndPreviewScoreNote`: remover la invocación a `_audioSynthesizer.playNoteTone`.
- En `_initListeners`: dentro del callback del metrónomo:
  - Iterar sobre todas las notas activas en el compás actual que inicien en `subTick` (`notes.where((n) => !n.isRest && n.startTick == subTick)`).
  - Reproducir cada una escalada por la ganancia efectiva de la pista principal.
  - Iterar sobre `_activePackage.tracks.skip(1)` para reproducir pistas de acompañamiento si tienen notas asociadas.

### Paso 3: `StemAudioSynthesizer`
- Añadir método `Uint8List floatStereoBufferToWav({required Float64List leftBuffer, required Float64List rightBuffer, int sampleRate = defaultSampleRate})` que construya el encabezado WAV con `channels: 2` e intercale las muestras $L_i, R_i$ en formato PCM de 16 bits little-endian con limitador suave $\tanh$.
- En `exportStemsAndMidi`:
  - Crear `masterLeftBuffer` y `masterRightBuffer`.
  - Procesar dinamicamente todos los stems en `mixerConsole.stems` con sus ganancias y asignación de paneo estéreo.
  - Exportar `master_mixdown.wav` como estéreo de 2 canales.

### Paso 4: Pruebas Unitarias y Validacion
- Crear `test/features/sheet_music/us_3_3_score_playback_and_stereo_export_test.dart`.
- Verificar con `flutter analyze --no-fatal-infos` (0 issues).
- Ejecutar pruebas con `flutter test` (100 % pass).
