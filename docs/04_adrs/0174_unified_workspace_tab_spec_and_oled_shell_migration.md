# ADR-0174: Especificación Unificada de Pestañas DAW (StudioWorkspaceTabSpec) y Migración OLED de Shell, Canales, Terminal y Workspaces

- **Estado:** Aceptado
- **Fecha:** 2026-11-23
- **Historias de Usuario:** US-7.2 (Issue #177), US-9.2 (Issue #184)
- **Caso de Uso:** [UC-182](../02_use_cases/182_uc_oled_shell_workspaces_and_unified_tab_spec.md)

---

## Contexto

Tras la introducción del sistema de diseño Pro OLED Monochrome (`StudioDesignTokens`, `StudioThemeScope`, `StudioIcon`) en ADR-0166, coexistían dos problemas estructurales:

1. **Fragmentación de metadatos de pestañas DAW:** Las 6 pestañas principales (`home`, `tuner`, `learning`, `studio`, `library`, `dj`) estaban duplicadas manualmente en cuatro ubicaciones independientes (`StudioWorkspaceTabBar.defaultTabs`, `StudioDesktopAppShell._buildWindowMenu`, `MainAppShell._buildCurrentBreadcrumb`/`_buildCurrentActiveItemId` y `MainAppShell` `NavigationBar`). Cualquier cambio de orden, etiqueta o atajo introducía riesgo de desincronización.
2. **Estilos legacy y cableado incompleto en Shell, Canales, Terminal y Workspaces:**
   - `studio_channel_modals.dart`, `tunner_os_terminal_drawer.dart` y `studio_dsl_terminal_panel_widget.dart` conservaban paletas neón o zinc hardcoded (`0xFF00E5FF`, `0xFF090D16`, `0xFF10131E`, `0xFF2563EB`) y `StudioDslTerminalPanelWidget` no integraba el catálogo canónico `TunnerDslTemplateCatalog`.
   - Las vistas de `lib/features/workspaces/presentation/` dependían exclusivamente de `TunnerThemePalette` y `Icons.*` de Material en lugar de `StudioThemeScope.of(context)` y `StudioIcon`.
   - En `MainAppShell`, el comando CLI `theme set` solo actualizaba `TunerViewModel.setPaletteById` sin sincronizar `StudioThemeController`, y `onCommandSubmitted` ejecutaba `_terminalKernel.execute(cmd)` descartando su salida antes de abrir `TunnerOsTerminalDrawer`.
   - Dos pruebas de navegación (`main_app_shell_test.dart` y `home_dashboard_hub_test.dart`) aún validaban cadenas legacy anteriores al rediseño Pro OLED Hub.

---

## Decisión

1. **Fuente Única de Verdad en Dominio (`StudioWorkspaceTabSpec`):**
   - Crear `lib/core/design_system/domain/studio_workspace_tab_spec.dart` en Dart puro (sin dependencias de Flutter), definiendo `StudioWorkspaceTabId` y `StudioWorkspaceTabSpec.canonicalTabs` con los 6 espacios de trabajo (`home`, `tuner`, `learning`, `studio`, `library`, `dj`), sus índices, claves `navKey`, etiquetas desktop/móvil, títulos del menú `Window`, atajos, breadcrumbs, `activeItemId` e iconos `StudioIconId`.
   - Exportar `StudioWorkspaceTabSpec` desde `studio_design_system.dart` e integrarlo en `StudioWorkspaceTabBar`, `StudioDesktopAppShell` y `MainAppShell`.

2. **Migración OLED Pro-DAW (`StudioThemeScope` + `StudioIcon`):**
   - Migrar `studio_channel_modals.dart`, `tunner_os_terminal_drawer.dart`, `studio_dsl_terminal_panel_widget.dart` y los cinco archivos de `lib/features/workspaces/presentation/` para leer tokens desde `StudioThemeScope.of(context)` y renderizar iconografía semántica mediante `StudioIcon`.
   - Integrar `TunnerDslTemplateCatalog.allTemplates` en `StudioDslTerminalPanelWidget` preservando los presets interactivos existentes (`Quick Jam`, `Mastering Chain`) para retrocompatibilidad.

3. **Sincronización CLI de Tema y Salida de Terminal:**
   - Ampliar `StudioThemeController.selectById` para resolver coincidencias insensibles a mayúsculas por `id` o `displayName`.
   - En `MainAppShell`, actualizar `onSetTheme` para invocar tanto `viewModel.setPaletteById(themeId)` como `StudioThemeScope.controllerOf(context)?.selectById(themeId)`.
   - Añadir soporte de `externalHistory` en `TunnerOsTerminalDrawer` y capturar el `Future<TunnerOsCommandResult>` de `onCommandSubmitted` en `MainAppShell` para mostrar tanto el comando como su salida en el drawer.

4. **Alineación de Pruebas de Regresión:**
   - Actualizar `main_app_shell_test.dart` y `home_dashboard_hub_test.dart` a las etiquetas canónicas del Pro OLED Hub (`WORKBENCH MODULES`, `CORE AUDIO DSP`, `48.0 kHz · 24-bit`).
   - Incorporar la suite dedicada `test/features/navigation/us_7_2_9_2_oled_shell_and_tab_spec_test.dart`.

---

## Consecuencias

### Positivas
- Cero duplicación de metadatos de navegación entre escritorio y móvil.
- Coherencia visual absoluta al alternar entre OLED Monochrome, Studio Light y cualquier skin del catálogo en tiempo real, incluyendo mediante CLI `theme set`.
- Trazabilidad completa de comandos despachados desde `StudioCommandPromptBar` dentro de `TunnerOsTerminalDrawer`.
- Acceso directo en el REPL a las plantillas declarativas oficiales de `TunnerDslTemplateCatalog`.

### Negativas / Compromisos
- Los constructores públicos de vistas de `workspaces` mantienen temporalmente el parámetro `palette` (`TunnerThemePalette`) para preservar retrocompatibilidad binaria con `StrobeTunerWidget`, `RealSheetMusicPainter` y tests existentes, delegando los estilos de contenedor y controles a `StudioThemeScope.of(context)`.

---

## Verificación

- `flutter analyze --no-fatal-infos` sin errores.
- `flutter test --no-pub --timeout 45s` verde sobre `test/features/navigation/`, `test/core/channels/`, `test/core/terminal/` y `test/features/workspaces/`.
