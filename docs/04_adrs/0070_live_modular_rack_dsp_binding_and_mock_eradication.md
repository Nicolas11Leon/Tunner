# ADR 0070: Enlace Real de DSP y Erradicación Total de Mocks en el Rack Modular

## Estado
Aprobado

## Fecha
2026-11-16

## Contexto
El Rack Modular de Estudio (`ModularStudioRackView`) fue concebido para albergar unidades independientes de procesamiento de señal, metrónomo, afinación, partituras y grabación. No obstante, las sub-vistas internas de las tarjetas (`RackUnitCard`) contenían valores fijos simulados (como `120 BPM`, `+0.2 ¢`, `TOMA 01 (00:45)`) y controladores vacíos (`onPressed: () {}`, `Slider(onChanged: (_) {})`).
Esta desconexión rompía la coherencia del sistema y generaba una percepción de software incompleto o decorativo.

## Decisión
1. **Consumo Reactivo de `TunerViewModel`:** Vincular `RackUnitCard` al `TunerViewModel` global mediante `context.watch<TunerViewModel>()`.
2. **Reemplazo Integral de Controles:**
   - Sustituir los sliders y botones fijos del metrónomo por mutadores reales (`setBpm`, `toggleMetronome`, `tapTempo`).
   - Sustituir las lecturas estáticas del afinador por telemetría en tiempo real (`noteName`, `cents`, `fundamentalFrequency`).
   - Conectar el grabador de estudio a las tomas reales de audio WAV (`practiceRecordings`, `isRecording`, `startPracticeRecording`, `stopPracticeRecording`).
   - Conectar el pentagrama al estado de partitura (`currentSongPackage`) e importador universal.
   - Enlazar los módulos de Autotune, Dron, Espectrograma, Acordes, Tutor y Oído a sus respectivos modales y motores DSP.
3. **Consola Multitarea Sincronizada:** El transporte maestro en `MultitaskMasterConsoleWidget` ahora orquesta simultáneamente el reloj auditivo y la grabación global.

## Consecuencias
- **Positivas:**
  - El rack modular es 100% interactivo, reactivo y operativo.
  - Cero controladores vacíos (`onPressed: () {}`) en las unidades de rack.
  - El usuario puede operar todo su flujo de práctica y producción sin salir de la vista modular.
- **Negativas / Desafíos:**
  - Requiere rediseño cuidadoso de los layouts internos para evitar desbordamientos de píxeles (`RenderFlex`) en resoluciones compactas.
