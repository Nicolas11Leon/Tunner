# ADR 0153: Descomposicion Algoritmica Real por Stems y Rango Completo 0..8 / BPM 20..300

## Estado
Aprobado (Approved)

## Contexto
La auditoria forense sobre `lib/features/song_library/` detecto cuatro limitaciones de completitud y hardcoding:
1. `SongDecomposerService.decomposeCustomScore` creaba unicamente etiquetas `AudioTrack` sin generar contenido musical independiente para los stems de armonia, bajo ni percusion ritmica.
2. `SongDecomposerService.parseMelodyText` inyectaba silenciosamente un compas hardcodeado `Do4-Mi4-Sol4-Do5` cuando recibia texto vacio.
3. `SongDecomposerModal._buildQuickNoteKeypad` limitaba los botones de octava a `[3, 4, 5]`, impidiendo componer registros graves (bajo/chelo/fagot en octavas `0..2`) o agudos (`6..8`).
4. `_StudioNewScoreDialog` restringia la seleccion de tempo a un desplegable con cuatro opciones fijas (`[80, 100, 120, 140]`).

## Decision
1. Extender `SongPackage` con el campo opcional retrocompatible `final Map<String, HierarchicalScore> stemScores` (valor por defecto `const {}`) para almacenar partituras independientes por pista sin alterar la firma existente de los consumidores actuales.
2. Implementar en `SongDecomposerService.decomposeCustomScore` generadores algoritmicos puros en Dart para:
   - `lead_stem`: partitura principal original.
   - `harmony_stem`: acompanamiento polifonico triadico (fundamental, tercera mayor y quinta justa en octava 3/4) derivado del primer evento sonoro de cada compas o pulso fuerte.
   - `bass_stem`: linea de fundamental en registro grave (octava 2, dentro de las capacidades acusticas definidas en `AGENTS.md §4.1`).
   - `rhythm_stem`: marcacion metrica por pulso segun `timeSignature.numerator` y `timeSignature.denominator`.
3. Modificar `parseMelodyText` para devolver un compas de silencio completo cuando la entrada este vacia o carezca de tokens validos.
4. Habilitar octavas `[0..8]` en `SongDecomposerModal` y control continuo de tempo `[20..300]` BPM en `_StudioNewScoreDialog`.

## Consecuencias
- **Positivas:**
  - Descomposicion multi-pista real y verificable en `SongPackage.stemScores`.
  - Cobertura integral de todo el registro orquestal y vocal (`0..8`) y de tempos musicales (`20..300` BPM).
  - Retrocompatibilidad total con constructores existentes de `SongPackage`.
- **Negativas / Compromisos:**
  - `SongPackage` aumenta ligeramente su huella en memoria cuando se puebla `stemScores` (cuatro estructuras ligeras de `HierarchicalScore`), impacto despreciable en dispositivos modernos.
