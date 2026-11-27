# ADR 0204: Nota Fantasma SMuFL en Hover sobre el Lienzo de Partitura

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-212](../02_use_cases/212_uc_smufl_ghost_note_hover_preview_in_score_canvas.md)

---

## 1. Contexto

En `CompositionNotationWorkspaceView` (`lib/features/workspaces/presentation/composition_notation_workspace_view.dart`), el `MouseRegion` que envuelve a `RealSheetMusicPainter` (`lib/features/sheet_music/presentation/real_sheet_music_painter.dart`) modifica el cursor visual pero no intercepta `onHover` ni `onExit`. Como resultado, el usuario no tiene referencia visual previa de que altura diatonica ni que subdivision de tick se insertaran al hacer clic sobre el pentagrama en Clave de Sol, Clave de Fa o Clave de Do.

---

## 2. Decision

1. **Mapeo Inverso Puro en `RealSheetMusicPainter`:**
   - Implementar `resolveNoteAtOffset(Offset localOffset, Size size, {int quantizeTicks = 4})` como funcion pura determinista que combina la coordenada horizontal `dx` (tick cuantizado) y la coordenada vertical `dy` (escalon diatonico relativo a `clef`: `treble = 30`, `alto = 24`, `bass = 18`) para devolver la nota proyectada y su tick.
2. **Renderizado Fantasma SMuFL y Badge de Telemetria:**
   - Anadir propiedades opcionales en `RealSheetMusicPainter` (`ghostNoteName`, `ghostTick`, `ghostDurationTicks`, `ghostIsRest`) con valor por defecto nulo para mantener retrocompatibilidad total.
   - Dibujar la cabeza de nota fantasma (y sus lineas adicionales si sale de las 5 lineas del pentagrama) mediante `SmuflGlyphPathEngine` con opacidad reducida ($\alpha \approx 0.42$).
   - Capturar `onHover` y `onExit` en `CompositionNotationWorkspaceView` actualizando estado local unicamente cuando cambia la tupla cuantizada `(tick, noteName)` y mostrando el indicador compacto `Key('score_ghost_note_badge')`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Manipulacion Directa de Precision:** El musico visualiza la nota exacta y sus lineas adicionales antes de confirmar el clic de insercion.
- **Cero Impacto en FPS:** Filtrar actualizaciones repetidas dentro de la misma celda cuantizada evita repintados redundantes a 120 Hz.

### 3.2 Compromisos y Mitigaciones
- **Puntero en Margenes de Clave o Armadura:** Si `dx` cae fuera del area util de compas (`dx < leftMargin`), `resolveNoteAtOffset` retorna `null` y limpia la nota fantasma sin interferir con el lienzo.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/workspaces/us_ux_12_smufl_ghost_note_hover_preview_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
