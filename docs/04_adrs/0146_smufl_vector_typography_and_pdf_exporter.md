# ADR 0146: Tipografia Musical Vectorial Estandar W3C SMuFL y Exportacion PDF Canónica

## Estado
Aprobado

## Contexto
El proyecto estipula en `AGENTS.md §4.2` que la notacion en partitura debe ceñirse a las reglas tipograficas estandarizadas (SMuFL standards) en lugar de bocetos geometricos arbitrarios ad-hoc.
Sin embargo:
1. `SmuflGlyphPathEngine` dibujaba la clave de Sol con aproximaciones esquematicas, carecia de clave de Do (`cClef`), y las plicas no utilizaban cajas de anclaje formales (`stemUpSE`, `stemDownNW`).
2. `CanonicalPdfExporter` dibujaba la clave de Sol con 3 segmentos rectos y un rectangulo, omitia totalmente las alteraciones en las notas, no soportaba silencios de corchea ni semicorchea y no contemplaba la clave de Fa.

## Decision
1. Implementar en `SmuflGlyphPathEngine` el repertorio canonico SMuFL 1.4:
   - `gClef` (`U+E050`), `fClef` (`U+E062`), `cClef` (`U+E05C`).
   - Cabezas de notas `noteheadWhole` (`U+E0A2`), `noteheadHalf` (`U+E0A3`), `noteheadBlack` (`U+E0A4`) con anclajes estandar `stemUpSE = (0.58 * sp, -0.16 * sp)` y `stemDownNW = (-0.58 * sp, 0.16 * sp)` conectados en `drawStem`.
   - Banderas `flag8thUp` (`U+E240`), `flag8thDown` (`U+E241`), `flag16thUp` (`U+E242`), `flag16thDown` (`U+E243`).
   - Alteraciones `accidentalSharp` (`U+E262`), `accidentalFlat` (`U+E260`), `accidentalNatural` (`U+E261`).
   - Silencios `restWhole` (`U+E4E3`), `restHalf` (`U+E4E4`), `restQuarter` (`U+E4E5`), `rest8th` (`U+E4E6`), `rest16th` (`U+E4E7`).
   - Puntillo de aumentacion `augmentationDot` (`U+E1E7`).
2. Actualizar `CanonicalPdfExporter` para proyectar curvas cubicas Bezier PostScript de alta fidelidad para:
   - Clave de Sol (`_renderTrebleClef`) y Clave de Fa (`_renderBassClef`).
   - Alteraciones en notas (`_renderAccidental`: sostenido `#`, bemol `b`, becuadro `n`).
   - Silencios completos para todas las duraciones (redonda, blanca, negra, corchea y semicorchea).

## Consecuencias
- Cumplimiento total de la constitucion arquitectonica del proyecto (`AGENTS.md §4.2`).
- Fidelidad visual y estetica identica a programas de notacion profesional (Dorico, Sibelius, MuseScore).
- Los archivos PDF exportados son de calidad editorial lista para imprenta, 100% vectoriales y ligeros.
