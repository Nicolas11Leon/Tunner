# ADR 0205: Inspector Contextual Consciente de Pestana y Panel Lateral de Herramientas

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-213](../02_use_cases/213_uc_tab_aware_contextual_inspector_and_sidebar_tools.md)

---

## 1. Contexto

Actualmente en `MainAppShell` (`lib/features/navigation/presentation/main_app_shell.dart`), `_buildContextualRightInspectorContent` renderiza una tarjeta fija con botones globales (`A4 = 442 Hz`, `A4 = 440 Hz`, `Activar Dron`) en todas las pestanas, mientras `_buildActiveTabInspectorSection` muestra unicamente texto informativo estatico en las pestanas 1 (Afinador), 3 (Rack Modular), 4 (Partituras) y 5 (Consola DJ). Adicionalmente, en `StudioDesktopAppShell` (`lib/core/design_system/organisms/studio_desktop_app_shell.dart`), el conmutador `'Herramientas'` (`Key('sidebar_mode_tools_btn')`) vuelve a renderizar `StudioTreeView(sections: widget.navigationSections)`, que en `MainAppShell` contiene el arbol de documentos del proyecto en lugar de un catalogo operativo de herramientas de estudio.

---

## 2. Decision

1. **Inspector Derecho 100% Tab-Aware en `MainAppShell`:**
   - Sustituir las acciones fijas superiores por controles especificos por indice de pestana (`0` Hub, `1` Afinador, `2` Practica/Conservatorio, `3` Rack Modular, `4` Partituras/Notacion, `5` Consola DJ) dentro de `Key('inspector_tab_context_section_0')` .. `Key('inspector_tab_context_section_5')`, incorporando disparadores en vivo acordes a cada estacion (calibracion y rigor en Afinador; metrónomo/Ebbinghaus en Practica; agregar modulo y macros en Rack; bucle A-B/clave/exportacion en Partituras; crossfader/sync/BPM en Consola DJ).
2. **Slot Dedicado `customSidebarTools` en `StudioDesktopAppShell`:**
   - Incorporar la propiedad opcional `final Widget? customSidebarTools;` en `StudioDesktopAppShell`. Cuando `_sidebarMode == 'tools'` y `customSidebarTools != null`, el shell renderiza ese panel dedicado (`Key('sidebar_tools_panel')` construido desde `MainAppShell`) con acceso categorizado a las herramientas y modales del estudio, conservando `StudioTreeView` como fallback cuando `customSidebarTools` es nulo.

---

## 3. Consecuencias

### 3.1 Positivas
- **Separacion Clara de Espacios Mentales:** `'Explorador'` (`sidebar_mode_explorer_btn`) administra archivos/partituras del proyecto; `'Herramientas'` (`sidebar_mode_tools_btn`) lanza utilidades musicales sin mezcla.
- **Inspector de Utilidad Real:** Cada cambio de pestana actualiza el panel derecho con acciones pertinentes al flujo actual.

### 3.2 Compromisos y Mitigaciones
- **Retrocompatibilidad de Pruebas del Shell:** Al mantener `customSidebarTools` opcional con fallback a `StudioTreeView`, todas las pruebas aisladas de `StudioDesktopAppShell` siguen compilando y pasando sin cambios obligatorios.

---

## 4. Verificacion

- Suite automatizada planificada: `test/core/design_system/us_ux_13_tab_aware_inspector_and_sidebar_tools_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
