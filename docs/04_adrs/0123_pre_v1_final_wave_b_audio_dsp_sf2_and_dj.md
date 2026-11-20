# ADR 0123: Cableado Real de Audio, Precisión DSP/Temperamentos, Metrónomo y Consola DJ (Ola Final B)

## Estado
Aceptado

## Contexto
La auditoría forense de `qa` evidenció varios motores sonoros desconectados o con defectos matemáticos S1/S2:
1. `PolyphonicVoicePool.renderBlock()`, `InstrumentSoundFontSelectorModal._previewNote()`, `UniversalMasterKeyboardWidget` y `HarmonicTutorViewModel` no emitían audio audible hacia `IAudioSynthesizerService`.
2. `VocalAutoTuneProcessor.processPracticeTake()` devolvía el `filePath` original sin procesar el WAV con `TdPsolaPitchShifter`.
3. `HarmonicSpectrogramModal`, `ChordAnalyzer` y `SmartInstrumentDetector` recibían `null` o armónicos hardcodeados en lugar de frames PCM reales del micrófono.
4. `PitchDetectorService.listInputDevices()` descartaba `id` y pasaba `label`; el timeout de silencio de 60 ms causaba parpadeo a `--` en notas sostenidas; y `PracticeRecorderService` competía con `StudioAudioInputEngine` registrando pitch a 1 Hz.
5. `TemperamentEngine` tenía valores desviados en Vallotti, Young II, Werckmeister IV y Kirnberger I, `anchorA4` desactivado por defecto y `NoteEntity` tenía error de $\pm 1$ octava en `Cb`/`B#`.
6. El Count-In tocaba 5 pulsos acentuando el 2; compases compuestos `6/8`/`9/8` se rompían; `MetronomeService` sufría carrera de Isolates y polling a 500 Hz; `TapTempo` no bajaba de 30 BPM.
7. `Sf2Parser` leía generadores con signo como `Uint16` (30 s de silencio) y `Sf2WavetableOscillator` omitía la fase Release.
8. `DjConsoleViewModel.syncBpm()` no actualizaba `setDeckPlaybackRate`, `DjTrackLoaderModal` carecía de `fileGateway`, Hot Cues mezclaban índices `0..3` y `1..4`, y `StudioPatchbayRoutingService` entregaba señales duplicadas.

## Decisión
1. Cablear la conversión de bloques `Float32List`/`Float64List` a WAV PCM mediante `PcmWavSynthesizer` / `ProceduralInstrumentSynthesizer` hacia `IAudioSynthesizerService.playPcmWav()` para escucha inmediata en SF2 Preview, Polifonía, Teclado Maestro y Tutor Armónico.
2. Implementar lectura y escritura WAV real en `VocalAutoTuneProcessor.processPracticeTake()` usando `TdPsolaPitchShifter`.
3. Alimentar un buffer circular de muestras PCM reales en `TunerViewModel` hacia el espectrograma, analizador de acordes y detector inteligente de instrumentos.
4. Corregir las tablas de temperamentos a 2 decimales exactos, activar `anchorA4: true`, corregir `Cb`/`B#`, selector por `id`, timeout de silencio (350 ms) y `Stopwatch` en grabadora.
5. Corregir la matemática de pulsos y Count-In en `TunerViewModel`/`MetronomeService`/`StudioMasterClockService`, añadir token de generación en Isolates y timers one-shot exactos.
6. Corregir `Sf2Parser` (signo `Int16`), `Sf2WavetableOscillator` (fase Release), `DjConsoleViewModel` (`syncBpm`, Hot Cues `0..3`, `fileGateway`), y `StudioPatchbayRoutingService`/`SignalBus` (entrega única, `Mute`/`Gain`, `PortDirection.input`).

## Consecuencias
- Todos los módulos de síntesis, afinación, metrónomo, DJ y análisis espectral funcionan extremo a extremo con audio y matemáticas reales.
