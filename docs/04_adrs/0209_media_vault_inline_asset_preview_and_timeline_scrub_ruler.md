# ADR 0209: Pre-escucha Inline de Activos y Regla de Scrubbing en Boveda Multimedia

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-217](../02_use_cases/217_uc_media_vault_inline_asset_preview_and_timeline_scrub_ruler.md)

---

## 1. Contexto

`MediaVaultViewModel` (`lib/features/media_vault/presentation/media_vault_viewmodel.dart`) ya dispone de `togglePreviewAsset(String assetId)`, `previewingAssetId` y `seekPlayheadMs(int targetMs)`. Sin embargo, `MediaVaultWorkspaceModal` (`lib/features/media_vault/presentation/media_vault_workspace_modal.dart`) no expone ningun boton inline de pre-escucha dentro de `_buildDraggableAssetRow`, ni ofrece una regla temporal interactiva en la cabecera del secuenciador para posicionar el cabezal de lectura (`playheadMs`) mediante clic o arrastre horizontal sobre `TimelineArrangementPainter` (`lib/features/media_vault/presentation/timeline_arrangement_painter.dart`).

---

## 2. Decision

1. **Boton Inline de Pre-escucha en Cada Fila de Activo:**
   - Incorporar en `_buildDraggableAssetRow` un `IconButton` compacto `Key('vault_asset_preview_btn_${asset.id}')` conectado a `vm.togglePreviewAsset(asset.id)`, alternando icono (`Icons.play_arrow` / `Icons.stop`) y resaltado semantico cuando `vm.previewingAssetId == asset.id`.
2. **Regla Temporal Interactiva de Scrubbing (`timeline_scrub_ruler`):**
   - Dibujar marcas de tiempo (segundos y compases) en una franja superior dedicada de `TimelineArrangementPainter` e insertar un `GestureDetector` `Key('timeline_scrub_ruler')` sobre el secuenciador.
   - Traducir la coordenada `localPosition.dx` descontando la cabecera izquierda del carril (`trackHeaderWidth = 155.0`) mediante $t_{\text{ms}} = \text{round}((x / \text{pixelsPerSecond}) \cdot 1000)$, con cuantizacion opcional al beatgrid cuando `timeline.snapToBeatgrid` esta activo, invocando `vm.seekPlayheadMs(targetMs)` en `onTapDown` y `onHorizontalDragUpdate`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Audicion Instantanea Antes de Arrastrar:** El musico pre-escucha cualquier muestra, stem o toma directamente en la lista lateral antes de colocarla en una pista.
- **Navegacion DAW Real en Linea de Tiempo:** El cabezal `playheadMs` responde al clic y arrastre directo sobre la regla superior, al estilo Reaper/Ableton/Logic.

### 3.2 Compromisos y Mitigaciones
- **Desfase de Margen de Carril:** Descontar consistentemente el ancho fijo de la columna de controles de pista (`155.0 px`) garantiza alineacion exacta entre la posicion visual del cursor en la regla y los clips en los carriles inferiores.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/media_vault/us_ux_17_vault_inline_preview_and_timeline_scrub_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
