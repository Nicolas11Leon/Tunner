# ADR 0188: Despeje Ergonómico Vertical del Shell de Escritorio y Barra de Comandos CLI Colapsable

- **Estado:** Aprobado
- **Fecha:** 2026-11-24
- **Autor:** Nicolás León
- **Caso de Uso Relacionado:** [UC-196](../02_use_cases/196_uc_ergonomic_desktop_shell_and_collapsible_command_bar.md)

---

## 1. Contexto

El shell principal de escritorio `StudioDesktopAppShell` (`lib/core/design_system/organisms/studio_desktop_app_shell.dart`) integra múltiples franjas horizontales fijas en el viewport:

1. Barra superior de menús, breadcrumb y controles de ventana/panel.
2. Barra de herramientas del módulo activo (`TunerScreen`, `CompositionNotationWorkspaceView` o `DjConsoleScreen`).
3. Franja inferior del `StudioCommandPromptBar` (terminal/prompt DSL acústico estilo IDE).
4. Barra de estado inferior de telemetría (`height: 24.0` con estado del motor DSP y latencia de buffer).

En pantallas portátiles estándar (p. ej., `1280x720` o `1366x768`) y en vistas divididas (`Dual Split`), mantener la barra `StudioCommandPromptBar` permanentemente expandida consumía altura vertical crítica que restaba espacio útil al lienzo tipográfico del pentagrama SMuFL (`RealSheetMusicPainter`), al estroboscopio (`StrobeTunerWidget`) y a los controles táctiles de la Consola DJ.

---

## 2. Decisión

Se establece un mecanismo de **Colapso Ergonómico en Tiempo Real de la Barra de Comandos CLI** directamente en `StudioDesktopAppShell` y su barra de estado inferior:

1. **Configuración de Visibilidad Inicial (`initialCommandPromptVisible`):**
   - `StudioDesktopAppShell` expone el parámetro `final bool initialCommandPromptVisible` (con valor predeterminado configurable para compatibilidad en tests y arranques limpios de escritorio), inicializando el estado interno `_isCommandPromptVisible` en `initState()`.
   - `StudioDesktopAppShellState` expone el getter público `bool get isCommandPromptVisible => _isCommandPromptVisible` y el método público `void toggleCommandPromptBar()`.

2. **Renderizado Condicional sin Destrucción del Viewport Central:**
   - Dentro del `Expanded` central de `StudioDesktopAppShell`, el bloque `if (_isCommandPromptVisible)` controla la inserción o retiro del `StudioCommandPromptBar` (o `_buildStudioPromptBar(tokens)`).
   - Al colapsarse (`_isCommandPromptVisible == false`), el widget `Expanded` contenedor de `widget.activeView` (y `widget.secondaryView` cuando `_isDualSplitActive` está activo) reclama automáticamente el 100% de los píxeles verticales liberados sin reconstruir ni perder el estado del módulo musical activo.

3. **Interruptor Táctil Permanente en la Barra de Estado (`btn_toggle_command_prompt_bar`):**
   - En el extremo derecho de la barra de estado inferior (`Bottom Status Bar`), se ubica un chip interactivo con `Key('btn_toggle_command_prompt_bar')`, icono `Icons.terminal` y etiqueta `CLI`, envuelto en un `Tooltip` dinámico (`'Ocultar Barra de Comandos CLI'` / `'Mostrar Barra de Comandos CLI'`).
   - El chip invoca `toggleCommandPromptBar` y refleja visualmente el estado activo/colapsado mediante tokens semánticos (`tokens.accentPrimary` vs `tokens.textMuted` / `tokens.borderHairline`).

---

## 3. Consecuencias

### 3.1 Positivas
- **Recuperación Inmediata de Espacio Vertical:** Los usuarios que trabajan con el pentagrama SMuFL, el mezclador de stems en línea o la consola DJ ganan espacio vertical útil sin renunciar a los comandos DSL cuando los necesiten.
- **Acceso Descubrible y Reversible en 1 Clic:** El indicador `CLI` en la barra de estado permanece siempre visible, permitiendo alternar el prompt DSL de manera instantánea durante una sesión.
- **Estado Determinista y Observable:** `StudioDesktopAppShellState.isCommandPromptVisible` y `Key('btn_toggle_command_prompt_bar')` permiten validación automatizada directa en pruebas de diseño y regresión.

### 3.2 Compromisos y Mitigaciones
- **Descubribilidad de Atajos de Terminal cuando está Colapsada:** Si el shell inicia con la barra colapsada en perfiles orientados a interpretación, el chip `CLI` en la barra de estado inferior y el menú superior de Vista/Paleta de Comandos (`Ctrl+K` / `onOpenSearch`) garantizan acceso inmediato a todas las acciones sin depender del prompt inferior visible.

---

## 4. Verificación

- **Caso de Uso Funcional:** [UC-196](../02_use_cases/196_uc_ergonomic_desktop_shell_and_collapsible_command_bar.md).
- **Plan de Implementación Asociado:** [Plan Maestro de Rediseño UI/UX](../05_implementation_plans/plan_ux_unified_musical_workflow_redesign.md).
- **Implementación Verificada en Código Fuente:** [studio_desktop_app_shell.dart](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/lib/core/design_system/organisms/studio_desktop_app_shell.dart).
- **Suite de Pruebas Objetivo (`US-UX-04`):** `test/core/design_system/us_ux_04_collapsible_command_bar_shell_test.dart`, validando:
  - Respeto de `initialCommandPromptVisible` (`true` y `false`) al montar `StudioDesktopAppShell`.
  - Conmutación bidireccional vía `btn_toggle_command_prompt_bar` y vía `StudioDesktopAppShellState.toggleCommandPromptBar()`.
  - Incremento medible de la altura efectiva asignada a `activeView` al colapsar la barra de comandos.
