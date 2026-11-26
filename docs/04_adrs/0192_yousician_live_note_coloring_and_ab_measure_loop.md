# ADR 0192: Coloracion Semantica de Notas SMuFL en Vivo, Live Pitch Trail y Bucle A-B de Compases

- **Estado:** Aprobado
- **Fecha:** 2026-11-25
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-200](../02_use_cases/200_uc_yousician_live_note_coloring_and_ab_measure_loop.md)

---

## 1. Contexto

Las plataformas lideres en practica musical interactiva (**Yousician, MakeMusic SmartMusic y Moises.ai**) basan su eficacia pedagogica en dos mecanismos: (1) colorear directamente cada cabeza de nota en el pentagrama en el instante en que se ejecuta (**Verde** si esta afinada, **Rojo/Ambar** si presenta error) junto con un rastro continuo de entonacion (*Live Pitch Trail*), y (2) permitir repetir un rango especifico de compases `[Compas A .. Compas B]` en bucle continuo. En Tunner, `RealSheetMusicPainter` pintaba las cabezas de nota con un color estatico y `ScorePlaybackCoordinator` carecia de limites de bucle por rango de compases.

---

## 2. Decision

1. **Bucle A-B por Rango de Compases en Dominio (`ScorePlaybackCoordinator`):** Anadir en `lib/features/sheet_music/domain/score_playback_coordinator.dart` las propiedades `loopStartMeasureIndex`, `loopEndMeasureIndex`, `isMeasureLoopActive`, `waitForNoteMode`, `loopIterationCount` y los metodos `setMeasureLoopRange(int start, int end)`, `clearMeasureLoop()` y `setWaitForNoteMode(bool enabled)`. Al concluir el ultimo pulso de `loopEndMeasureIndex`, el coordinador retorna automaticamente al primer pulso de `loopStartMeasureIndex` e incrementa `loopIterationCount`.
2. **Coloracion Semantica en Vivo y *Live Pitch Trail* en `RealSheetMusicPainter`:** En `lib/features/sheet_music/presentation/real_sheet_music_painter.dart`, implementar `RealSheetMusicPainter.resolveNoteEvaluationColor(...)` para colorear cabeza, plica, corchete y alteraciones de cada nota evaluada con `palette.correctPitchColor` o `palette.errorPitchColor`, trazar el `Path` continuo del rastro de entonacion y dibujar la insignia `'LOOP A-B [A-B]'` en la cabecera del pentagrama.

---

## 3. Consecuencias

### 3.1 Positivas
- **Foco Visual 100% en la Partitura:** El musico recibe retroalimentacion inmediata sobre el propio simbolo SMuFL de la nota sin tener que desviar la mirada hacia medidores externos.
- **Practica Deliberada de Pasajes Dificiles:** El bucle A-B en el coordinador de dominio permite aislar y repetir cualquier rango de compases sin reiniciar toda la obra.

### 3.2 Compromisos y Mitigaciones
- **Cero Sobrecarga de Renderizado:** El calculo de color por nota y el `Path` del rastro operan en `O(N)` sobre los 16 sub-ticks del compas activo, manteniendo 60/120 FPS estables.

---

## 4. Verificacion

- Suite automatizada: `test/features/sheet_music/us_ux_08_live_note_coloring_and_ab_loop_test.dart`.
- Analisis estatico: `flutter analyze --no-fatal-infos` con `0 issues`.
