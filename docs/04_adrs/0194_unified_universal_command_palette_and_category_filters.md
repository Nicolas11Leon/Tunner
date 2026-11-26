# ADR 0194: Unificacion de la Command Palette Universal con Filtros por Categoria e Indexacion Dinamica

- **Estado:** Aprobado
- **Fecha:** 2026-11-25
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-202](../02_use_cases/202_uc_unified_universal_command_palette_and_category_filters.md)

---

## 1. Contexto

El analisis comparativo con **Autodesk Fusion 360 (Command Search `S`)** y **VS Code (`Ctrl+K` / `Ctrl+P`)** revelo que en Tunner coexistian buscadores desconectados (`ProCommandPaletteModal` y `ToolSearchModal`), que herramientas como el `Tutor Armonico de Entonacion Justa` o las calibraciones rapidas de `A4` (`432/440/442 Hz`) y las partituras activas del proyecto (`workspaceScores`) no estaban indexadas en `StudioCommandCatalogBuilder`, y que `ProCommandPaletteModal` carecia de filtros rapidos por categoria semantica.

---

## 2. Decision

1. **Expansion de `StudioCommandCatalogBuilder` (`lib/features/navigation/presentation/studio_command_catalog_builder.dart`):** Incorporar al catalogo universal el comando `open_harmonic_tutor` (`Abrir Tutor Armonico`), los comandos directos de calibracion `set_a4_432`, `set_a4_440` y `set_a4_442`, y la indexacion dinamica de cada partitura cargada en `viewModel.workspaceScores` (`open_project_score_<index>`).
2. **Filtros por Categoria en `ProCommandPaletteModal` (`lib/features/navigation/presentation/pro_command_palette_modal.dart`):** Anadir la barra horizontal de pildoras de filtro `Key('command_palette_category_filter_bar')` (`cmd_filter_all`, `cmd_filter_navigation`, `cmd_filter_dsp`, `cmd_filter_scores`, `cmd_filter_pedagogy`) y el indicador de atajo universal `Key('command_palette_shortcut_hint_badge')` (`CTRL+K / CTRL+P`).
3. **Acceso Directo en `HomeDashboardScreen` (`lib/features/navigation/presentation/home_dashboard_screen.dart`):** Anadir el disparador `Key('home_universal_command_palette_trigger')` para invocar la Command Palette universal manteniendo compatibilidad con los flujos existentes.

---

## 3. Consecuencias

### 3.1 Positivas
- **Fuente Unica de Descubrimiento Universal:** Cualquier herramienta, preset de afinacion o partitura del proyecto se localiza y ejecuta desde `Ctrl+K` / `Ctrl+P` en menos de 2 segundos.
- **Reduccion de Entropia por Filtrado Semantico:** Las 5 pildoras de categoria permiten acotar los comandos en 1 clic sin necesidad de recordar el nombre exacto de la herramienta.

### 3.2 Compromisos y Mitigaciones
- **Evaluacion Perezosa del Catalogo:** El catalogo se construye al abrir el modal, garantizando cero costo de CPU mientras el modal permanece cerrado.

---

## 4. Verificacion

- Suite automatizada: `test/features/navigation/us_ux_10_universal_command_palette_test.dart`.
- Analisis estatico: `flutter analyze --no-fatal-infos` con `0 issues`.
