# ADR 0129: Consola DJ Interactiva, DSP en Vivo, Pedagogia y Media Vault (Ola UX-4)

## Estado
Aceptado

## Contexto
En la evaluacion de experiencia de usuario de la Consola DJ y los modales auxiliares:
1. Las perillas de ecualizacion y filtros de la consola fisica virtual (`DjHardwareConsolePainter`) dependian de toques estaticos o carecian de arrastre continuo (`onPanUpdate`), lo que impedia ajustes graduales finos esenciales para la mezcla profesional.
2. Al pulsar REC en la consola DJ, la sesion en memoria no se guardaba fisicamente a disco mediante `saveRecordingToDisk()`.
3. Al entrar a modales que requieren entrada de microfono (`GuidedLessonsModal`, `ChordAnalyzerModal`, `LiveTranscriptionModal`), si el microfono estaba inactivo, no existia un boton directo para activarlo, forzando al usuario a salir, ir al afinador, encender el microfono y regresar.
4. En `VocalAutoTuneModal`, las tomas de post-produccion no incluian un boton de reproduccion audicionable rapido para verificar el ajuste microtonal.

## Decision
1. Integrar controladores de arrastre gestual (`onPanUpdate`) en la capa de interaccion de la consola DJ para knobs y faders con normalizacion `0.0 .. 1.0` y `-1.0 .. 1.0`.
2. Invocar `saveRecordingToDisk()` automaticamente al detener la grabacion de la sesion en `DjConsoleViewModel`.
3. Anadir un boton prominente de control de microfono en `GuidedLessonsModal` y `ChordAnalyzerModal` que invoque `tunerViewModel.toggleRecording()`.
4. Incluir boton de audicion antes/despues en `VocalAutoTuneModal` conectado a `TunerViewModel.playTakeAudio(...)`.

## Consecuencias
- Operacion ergonomica de la consola DJ fiel al estandar de hardware fisico (Pioneer DJ, Allen & Heath).
- Flujo pedagogico continuo sin friccion de navegacion para activar el microfono.
- Preservacion real en disco de las sesiones de mezclas exportadas.
