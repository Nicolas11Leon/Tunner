# ADR 0147: Renderizado de Puntillos, Armaduras, Ligaduras, Beams, Octavas Negativas y Hit-Testing Vertical

## Estado
Aprobado

## Contexto
El visor y editor de partituras presentaba limitaciones graficas y de interaccion:
1. `RealSheetMusicPainter` no renderizaba puntillos para figuras de `3, 6, 12` ticks (como la negra con puntillo del canon de estudios), mostrandolas como figuras simples.
2. No existia soporte en las entidades para armaduras de clave (`keySignatureFifths`) ni ligaduras (`isTied`).
3. Las corcheas y semicorcheas consecutivas siempre tenian corchetes individuales colgantes en lugar de barras de agrupacion (beams).
4. `getNoteStep` utilizaba `replaceAll(RegExp(r'[^0-9]'), '')`, eliminando el signo menos y convirtiendo octavas subgraves `-1` en `+1`, ademas de ignorar el becuadro (`♮` / `n`) y la clave de Do (`InstrumentClef.alto`).
5. `findNoteIndexAtOffset` ignoraba la coordenada `dy`, seleccionando arbitrariamente la primera nota encontrada en la coordenada horizontal e impidiendo seleccionar notas en acordes polifonicos.

## Decision
1. Añadir `isTied` (`bool`, default `false`) a `HierarchicalNote` y `keySignatureFifths` (`int`, default `0`) a `MeasureEntity`.
2. Implementar en `RealSheetMusicPainter`:
   - Deteccion de puntillo (`durationTicks == 12 || durationTicks == 6 || durationTicks == 3`) y renderizado en espacio interlineal.
   - Renderizado de armaduras de clave (hasta 7 sostenidos o 7 bemoles) al inicio del pentagrama.
   - Renderizado de arcos de ligadura (ties) para notas con `isTied: true`.
   - Agrupacion automatica por beams para corcheas y semicorcheas adyacentes en el mismo pulso.
   - Parsing exacto de octavas con `RegExp(r'[-+]?\d+')` y soporte de `InstrumentClef.alto` en `getNoteStep`.
   - Hit-testing bidimensional ponderando la distancia vertical `(dy - noteY).abs()`.

## Consecuencias
- Cobertura completa de la notacion musical clasica y contemporanea.
- Interaccion tactil precisa en acordes polifonicos.
- Compatibilidad absoluta con obras y estudios pedagogicos avanzados.
