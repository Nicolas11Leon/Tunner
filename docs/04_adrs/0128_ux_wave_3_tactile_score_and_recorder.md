# ADR 0128: Interaccion Tactil, Editor de Partituras, Superficies Rack y Grabadora (Ola UX-3)

## Estado
Aceptado

## Contexto
Durante la auditoria forense integral de experiencia de usuario (UX) se detectaron varias inconsistencias criticas en la manipulacion directa por clic y tactil:
1. El boton de grabacion maestro en la consola y dock consultaba `isRecording` (micrófono del afinador) en lugar de `isAudioRecording` (grabadora de tomas WAV), impidiendo pausar o iniciar correctamente la grabacion si el afinador estaba apagado.
2. Tocar notas en el lienzo SMuFL seleccionaba la nota visualmente pero no producia sonido audible inmediato en tiempo real.
3. El modal `ScoreEditorModal` ocupaba el 88% de la pantalla tapando el pentagrama, sin auto-avance del cursor temporal al insertar notas.
4. Las superficies tactiles de instrumentos en las tarjetas del Rack Modular (`InstrumentEmulationSurfaceWidget`) no conectaban con el sintetizador de audio para emitir sonido al pulsar teclas, trastes o pads.
5. El tono continuo de referencia La4 carecia de toggle limpio e invalidaba los calculos de cents del afinador si el microfono estaba activo.

## Decision
1. Homologar el flag de grabacion de audio de practica a `isAudioRecording` en `MultitaskMasterConsoleWidget` y `QuickActionDockWidget`.
2. Implementar sintesis audible inmediata en `TunerViewModel.selectAndPreviewScoreNote(...)` invocando `playNoteTone(...)` en el sintetizador de audio procedural o SoundFont.
3. Redimensionar `ScoreEditorModal` con altura ergonomica (60% max), preview grafico de la nota seleccionada y auto-avance del tick (`_selectedStartTick = (_selectedStartTick + _selectedDurationTicks).clamp(0, 16)`).
4. Conectar callbacks de audio en las superficies tactiles del Rack Modular para sintetizar notas al recibir eventos de tap.
5. Convertir `playReferenceTone("La4")` en un toggle estricto con estado `isReferenceTonePlaying`, garantizando que pulsar de nuevo silencia el tono sin corromper el estado de deteccion de pitch.

## Consecuencias
- Experiencia tactil fluida e interactiva en dispositivos tactiles y con raton en escritorio.
- Coherencia total entre los estados de grabacion WAV y la retroalimentacion visual en la consola de transporte.
- Mayor velocidad de composicion y edicion de partituras gracias al auto-avance temporal.
