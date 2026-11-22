# ADR-0163: Sincronizacion de 40 Instrumentos y Fisica Temperada en Superficies Tactiles

- **Estado:** Aceptado
- **Fecha:** 2026-11-22
- **Historia de Usuario:** US-6.4 (EPIC-06)
- **Issue:** #169

## Contexto

`InstrumentSelectorModal` solo mostraba 21 instrumentos de `InstrumentProfileEntity.standardInstruments` dejando fuera 19 de `UniversalInstrumentDefinition.masterCatalog` (como Kora, Sitar, Shakuhachi, Charango y Cuatro). Ademas, `FretboardTactileWidget` solo hacia interactiva la cuerda al aire (`fret 0`), y `_buildGenericAcousticSurface` enviaba siempre `(min + max) / 2.0` en todos los botones.

## Decision

1. **Extension retrocompatible de `InstrumentProfileEntity.standardInstruments`:** Incorporar los 19 instrumentos restantes de `UniversalInstrumentDefinition.masterCatalog` manteniendo intactos los 21 existentes.
2. **Trastes temperados 1..totalFrets:** Renderizar `InkWell` por cada celda `(cuerda, traste)` usando $f = f_{\text{open}} \cdot 2^{\text{fret}/12}$.
3. **Grados diatonicos/armonicos reales en vientos y percusion:** Mapear el indice `i` de cada llave/piston en `_buildGenericAcousticSurface` a intervalos diatonicos (`[0, 2, 4, 5, 7, 9, 11, 12]`) sobre `minFrequencyHz`, acotado a `[minFrequencyHz, maxFrequencyHz]`.

## Consecuencias

- **Positivas:**
  - Acceso completo a los 40 instrumentos Hornbostel-Sachs desde el selector principal.
  - Emulacion tactil acusticamente fiel tanto en diapasones como en llaves/pistones.
- **Negativas / Compensaciones:**
  - Ninguna regresion en IDs previos; el listado en `InstrumentSelectorModal` crece a 40 entradas.
