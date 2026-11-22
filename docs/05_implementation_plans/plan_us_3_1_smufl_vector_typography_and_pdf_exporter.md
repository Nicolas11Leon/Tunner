# Plan de Implementacion - US-3.1: Tipografia Musical Vectorial Estandar W3C SMuFL y Exportacion PDF Canónica

- **Estado:** Completado
- **Rama:** `feature/us-3.1-smufl-vector-typography-and-pdf-exporter`
- **ADR:** `docs/04_adrs/0146_smufl_vector_typography_and_pdf_exporter.md`
- **Caso de Uso:** `docs/02_use_cases/154_uc_smufl_vector_typography_and_pdf_exporter.md`

## 1. Descripcion del Cambio
Incorporar el catalogo de glifos vectoriales canónicos W3C SMuFL 1.4 en `SmuflGlyphPathEngine` (añadiendo `drawCClef`, `drawAugmentationDot`, anclajes `stemUpSE = (0.58 * sp, -0.16 * sp)` / `stemDownNW = (-0.58 * sp, 0.16 * sp)` integrados en `drawStem`) y mejorar sustancialmente `CanonicalPdfExporter` (curvas Bezier en PostScript para claves de Sol y Fa con mapeo diatónico desde `Sol2`/`G2`, soporte completo de alteraciones `#`, `b`, `n`/`N` y silencios de corchea y semicorchea).

## 2. Archivos Afectados
- `lib/features/sheet_music/presentation/smufl/smufl_glyph_path_engine.dart`:
  - Definir constantes de anclaje optico de plica SMuFL `stemUpSE` y `stemDownNW`.
  - Añadir `drawCClef` (Clave de Do `U+E05C`).
  - Añadir `drawAugmentationDot` (Puntillo de aumentacion `U+E1E7`).
  - Perfeccionar contornos de claves, cabezas y silencios.
- `lib/features/universal_importer/domain/canonical_pdf_exporter.dart`:
  - Reemplazar el dibujo elemental de clave de Sol por curvas Bezier PostScript estilizadas.
  - Añadir `_renderBassClef` para clave de Fa.
  - Añadir `_renderAccidental` (sostenido, bemol y becuadro) antes de la cabeza de nota.
  - Soportar silencios de corchea y semicorchea en `_renderRest`.
- `test/features/sheet_music/us_3_1_smufl_vector_typography_test.dart`:
  - Pruebas unitarias de generacion de glifos en Canvas y exportacion binaria PDF con los nuevos elementos vectoriales.

## 3. Plan Paso a Paso
1. Enriquecer `SmuflGlyphPathEngine` con codepoints y metodos `drawCClef` y `drawAugmentationDot`, mas anclajes formales.
2. Actualizar `CanonicalPdfExporter` con curvas PostScript para clave de Sol, clave de Fa, alteraciones y silencios.
3. Verificar que los PDFs generados contienen los operadores PostScript correspondientes (`c`, `m`, `l`, `re`, `f`, `s`).
4. Ejecutar pruebas unitarias y analisis estatico sin errores.
