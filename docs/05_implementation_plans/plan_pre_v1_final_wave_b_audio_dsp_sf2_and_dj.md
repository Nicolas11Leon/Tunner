# Plan de Implementación: Ola Final B — Motores de Audio Reales, DSP, Temperamentos, Metrónomo, SF2 y DJ

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-PRE-V1-FINAL-WAVE-B-2026-093`
- **Título de la Implementación:** `Cableado de Audio Real, Precisión DSP/Temperamentos, Reloj/Metrónomo, SF2, Auto-Tune y Consola DJ`
- **Fase del Proyecto:** `Pre-Release Gate v1.0.0 — Ola Final B`
- **Estado:** `En Progreso`
- **Issue Relacionado:** `#93`
- **ADR Relacionado:** [ADR-0123](../04_adrs/0123_pre_v1_final_wave_b_audio_dsp_sf2_and_dj.md)
- **Documento Funcional Base:** [UC-134](../02_use_cases/134_uc_pre_v1_final_wave_b_audio_dsp_sf2_and_dj.md)

---

## 1. Plan Paso a Paso de Ejecución

- [ ] **Paso 1 (Temperamentos, NoteEntity y MPM/Mic/Grabadora):**
  - Calibrar tablas exactas de Vallotti, Young II, Werckmeister IV, Kirnberger I, Meantone/Werckmeister III/Kirnberger III; activar `anchorA4: true` en `TunerViewModel` y `HarmonicDroneSynthesizer`; corregir preset `'werckmeister_iii'`.
  - Corregir acarreo de octava `Cb`/`B#` y soporte `♭`/`♯` en `NoteEntity.frequencyForNote`.
  - Corregir `PitchDetectorService.listInputDevices` (usar `id` y `label`), aumentar timeout de silencio a `350 ms`, y usar `Stopwatch` real en `_recordSampleForMultiTrack`.
- [ ] **Paso 2 (Metrónomo, Reloj Maestro y Tap Tempo):**
  - Corregir Count-In (`_countInBeat` 1..beatsPerMeasure, acento en 1, sin saltarse compás 1 tick 0) y soporte de compases compuestos (`6/8`, `9/8`, `12/8`) en `TunerViewModel`, `MetronomeService` y `StudioMasterClockService`.
  - Añadir token de generación en `MetronomeService.start`/`stop` y timers one-shot exactos sin polling 500 Hz.
  - Ampliar `TapTempoEngine` y `StudioMasterClockService` a 20–300 BPM (`3200 ms` timeout).
- [ ] **Paso 3 (Síntesis Audible, SF2, Auto-Tune WAV y PCM en Lab Acústico):**
  - Conectar `InstrumentSoundFontSelectorModal._previewNote` y `TunerViewModel.synthesizeSoundFontNote` a `playPcmWav`.
  - Pasar `audioSynthesizer` a `UniversalMasterKeyboardWidget` desde `MultitaskMasterConsoleWidget`.
  - Conectar `PolyphonicVoicePool` / `PolyphonicSynthModal` y `HarmonicTutorViewModel` a reproducción audible y micrófono real.
  - Corregir `Sf2Parser` (`Int16` con signo) y `Sf2WavetableOscillator` (fase Release completa).
  - Implementar procesamiento WAV real con `TdPsolaPitchShifter` en `VocalAutoTuneProcessor.processPracticeTake`.
  - Alimentar PCM real desde `IStudioAudioInputEngine` hacia `_latestAudioSamples`, `processChordSamples()` y `SmartInstrumentDetector`.
- [ ] **Paso 4 (Consola DJ, Patchbay, SignalBus y DSP Math):**
  - Conectar `syncBpm()` a `setDeckPlaybackRate`, pasar `PlatformFileGateway` a `DjTrackLoaderModal`, y unificar índices Hot Cue (`0..3`).
  - Corregir doble entrega y Mute/Gain en `StudioPatchbayRoutingService` y `PortDirection.input` + `conn.gain` en `SignalBus`.
  - Corregir discontinuidad `|x|=0.95` en `StudioMasterAudioMixer` y `updateParameters()` in-place en `StudioAudioDeviceMatrixService`.
- [ ] **Paso 5 (Verificación):**
  - Añadir pruebas de regresión de Ola B, ejecutar `flutter analyze --no-fatal-infos` y `flutter test` al 100%, y fusionar PR hacia `qa`.
