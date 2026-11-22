# ADR 0151: Preservacion Polifonica de Acordes, Compases Arbitrarios y Rango 0..8 en Parsers y Exportadores

## Estado
Aprobado

## Contexto
Los subsistemas de importacion y exportacion canonica en `lib/features/universal_importer/` presentaban cinco limitaciones estructurales frente a partituras polifonicas reales y metricas modernas o compuestas:
1. **MusicXML (`MusicXmlScoreParser` y `CanonicalMusicXmlExporter`):** El parser omitia explicitamente cualquier etiqueta `<note>` que contuviera `<chord/>` (comportamiento heredado de la Ola C) y el exportador serializaba notas simultaneas secuencialmente sin emitir `<chord/>`. Ademas, `_parseTimeSignature` reducia toda metrica distinta de `3/4`, `2/4` y `6/8` a `TimeSignature.commonTime44`, y el exportador solo emitia `<time>` en el compas 1.
2. **MIDI (`MidiScoreParser`):** En `_quantizeToMeasures`, el algoritmo avanzaba `currentTick += duration` por cada evento individual, convirtiendo acordes simultaneos (mismo `startTick`) en arpegios monofonicos y corrompiendo las posiciones de silencios intermedios.
3. **ABC Notation (`AbcScoreParser` y `CanonicalAbcExporter`):** El parser ignoraba los delimitadores de acorde `[...]`, serializaba notas concurrentes como notas consecutivas en exportacion, restringia `M:` exclusivamente a `3/4`, `6/8` o `4/4`, limitaba `clamp(1, 16)` en duraciones y `clamp(1, 8)` en octavas (destruyendo la octava `0` de piano/bajo), y solo contemplaba 8 de las 15 armaduras estandar en `K:`.

## Decision
1. **Soporte nativo de `<chord/>` y metricas arbitrarias en MusicXML:**
   - En `MusicXmlScoreParser`, registrar `lastBaseNoteStartTick` en cada nota base no-gracia y no-acorde. Cuando aparezca `<chord/>`, asignar `startTick = lastBaseNoteStartTick` sin avanzar `currentTick` (procesando incluso acordes ubicados sobre el ultimo tiempo cuando `currentTick == maxTicks`). Mantener el descarte de `<grace/>`. Esta decision reemplaza el comportamiento previo documentado en la prueba de Ola C donde `<chord/>` era descartado.
   - Refactorizar `_parseTimeSignature` para construir `TimeSignature(beats, beatType)` ante cualquier numerador positivo (incluyendo sumas compuestas tipo `3+2`) y denominadores validos `{1, 2, 4, 8, 16}`, asi como atributos `symbol="cut"` (`2/2`) y `symbol="common"` (`4/4`).
   - En `MusicXmlScoreParser._parsePitch`, calcular el acarreo de octava en semitonos y acotar `effectiveOctave` al rango `0..8`.
   - En `CanonicalMusicXmlExporter`, ordenar las notas del compas por `startTick`, emitir `<chord/>` antes de `<pitch>` para todas las notas posteriores a la nota base en el mismo `startTick`, emitir `<attributes><time>` cuando cambie la metrica respecto al compas anterior, y acotar octavas exportadas al rango `0..8`.

2. **Agrupacion por `startTick` cuantizado en `MidiScoreParser._quantizeToMeasures`:**
   - Agrupar las notas de cada compas en un mapa ordenado por `quantizedStartTick` dentro de `[0, measureTicks - 1]`.
   - Ordenar las voces de cada grupo por `pitch` ascendente y emitir todas las notas del grupo con el mismo `startTick` y duracion acotada a `measureTicks - startTick`.
   - Mantener un cursor de cobertura `timelineCursor` (maximo `endTick` acumulado) para insertar silencios intermedios exclusivamente cuando `groupStartTick > timelineCursor` y un silencio final si `timelineCursor < measureTicks`.
   - Validar en el meta-evento `0x58` que `metaBytes[1] <= 4` para garantizar denominadores `{1, 2, 4, 8, 16}` con `totalTicks > 0`.

3. **Polifonia `[CEG]`, 15 armaduras, metricas arbitrarias y rango `0..8` en ABC:**
   - En `AbcScoreParser`, validar acordes entre corchetes `[...]` mediante expresion regular estricta (excluyendo campos inline `[M:...]`, `[K:...]`, `[L:...]` y voltas `[1`, `[2`), aplicando multiplicadores de duracion internos y posteriores al corchete, asignando el mismo `startTick` a todas las notas del acorde y avanzando `currentTick` por la duracion del acorde.
   - Implementar `_parseAbcMeter` para cualquier `M: num/den`, `M: C`, `M: C|` y numeradores aditivos, y `_parseUnitLengthTicks` para `L:` arbitrario (`16 * num / den`).
   - Implementar `_keySignatureAccidentals` sobre el circulo de quintas completo cubriendo las 15 armaduras estandar (`-7` a `+7`), incluyendo tonalidades mayores, menores relativas (`m`, `min`, `minor`) y modos eclesiasticos.
   - Cambiar el rango de octava en `_mapAbcToSolfege` de `clamp(1, 8)` a `clamp(0, 8)` y ampliar el limite de duracion por compas de `16` a `maxTicks`.
   - En `CanonicalAbcExporter`, agrupar notas por `startTick` para emitir acordes entre corchetes (`[CEG]` / `[CEG]2` o duraciones individuales si difieren), emitir `[M:num/den]` ante cambios de metrica entre compases, soportar octavas `0..8` (`C,,,,` hasta `c'''`) y calcular duraciones proporcionales arbitrarias.

## Consecuencias
- **Positivas:**
  - Fidelidad polifonica de extremo a extremo (importacion y exportacion) en MusicXML, MIDI y ABC sin degradar acordes a monofonia.
  - Soporte completo para repertorio contemporaneo, progresivo y tradicional en compases irregulares (`5/4`, `7/8`, `11/8`, etc.) y compuestos (`9/8`, `12/8`).
  - Soporte integro del registro de piano de 88 teclas y orquestal (`0..8`) y de todas las armaduras tonales estandar (`-7..+7`).
  - Preservacion garantizada del invariante `MeasureEntity.isValidMeasure`.
- **Negativas / Mitigacion:**
  - La prueba de regresion heredada en `test/features/notation/wave_c_notation_parsers_pedagogy_shell_test.dart` que verificaba explicitamente el descarte de `<chord/>` en MusicXML queda obsoleta y debe actualizarse para verificar la preservacion de `<chord/>` con el mismo `startTick` de la nota base.
