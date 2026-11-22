# Plan de Implementacion - US-3.2: Renderizado de Puntillos, Armaduras, Ligaduras, Beams, Octavas Negativas y Hit-Testing Vertical

## 1. Descripcion del Cambio
Extender las entidades de partitura con `isTied` y `keySignatureFifths`, e implementar en `RealSheetMusicPainter` el renderizado de puntillos, armaduras de clave, ligaduras, agrupacion por barras de corchea (beams), soporte para octavas negativas, becuadros y clave de Do, junto con un hit-testing 2D exacto para seleccion de notas.

## 2. Archivos Afectados
- `lib/features/sheet_music/domain/score_tree.dart`:
  - `HierarchicalNote`: añadir `final bool isTied;` con default `false`.
  - `MeasureEntity`: añadir `final int keySignatureFifths;` con default `0`.
- `lib/features/sheet_music/presentation/real_sheet_music_painter.dart`:
  - Añadir parametro opcional `keySignatureFifths` en `RealSheetMusicPainter`.
  - Corregir `getNoteStep`: extraer octavas con `RegExp(r'[-+]?\d+')`, soportar becuadros (`♮` / `n`) y clave de Do (`InstrumentClef.alto`).
  - Corregir `findNoteIndexAtOffset`: ponderar distancia vertical `|localOffset.dy - noteY|`.
  - Renderizar puntillo para duraciones `12, 6, 3` ticks.
  - Renderizar armaduras de clave entre la clave y la metrica.
  - Renderizar arcos de ligadura cuando `note.isTied == true`.
  - Agrupar corcheas/semicorcheas consecutivas con barras (beams).
- `test/features/sheet_music/us_3_2_sheet_music_rendering_test.dart`:
  - Pruebas unitarias de calculo de pasos, hit-testing 2D, puntillos y serializacion de entidades.

## 3. Plan Paso a Paso
1. Actualizar `score_tree.dart` con `isTied` y `keySignatureFifths`.
2. Actualizar `real_sheet_music_painter.dart` con soporte de octavas negativas, clave de Do, hit-testing 2D, puntillos, armaduras, ligaduras y beams.
3. Crear suite de pruebas unitarias y verificar analisis estatico con 0 issues.
