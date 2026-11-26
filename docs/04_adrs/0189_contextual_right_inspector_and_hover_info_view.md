# ADR 0189: Inspector Contextual Derecho de Revelacion Progresiva y Panel Info View por Hover

- **Estado:** Aprobado
- **Fecha:** 2026-11-25
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-197](../02_use_cases/197_uc_contextual_right_inspector_and_hover_info_view.md)

---

## 1. Contexto

El estudio comparativo de suites creativas profesionales (Adobe Audition Essential Sound, Figma, Logic Pro) y estaciones de trabajo de audio (Ableton Live 12 Info View) demostro que abrir hojas modales bloqueantes para consultar propiedades del contexto activo o leer ayuda pedagogica interrumpe el flujo visual sobre el lienzo primario (*Split-Attention Effect* de Sweller). En `StudioDesktopAppShell` no existia un panel Inspector Contextual Derecho acoplado ni un sistema reactivo a eventos de cursor (`onHover`) que mostrara la descripcion acustica, formula DSP y atajo de teclado sin bloquear la pantalla.

---

## 2. Decision

1. **Panel Inspector Contextual Derecho (`studio_right_contextual_inspector_panel`):** Integrar en `StudioDesktopAppShell` (`lib/core/design_system/organisms/studio_desktop_app_shell.dart`) un panel lateral derecho acoplado y colapsable (`width: 280.0`, conmutable mediante `Key('btn_toggle_right_inspector')` o `toggleInspector()`), estructurado bajo la **Regla de Revelacion Progresiva de 2 Niveles** (Nielsen Norman Group):
   - **Nivel 1 (`inspector_level_1_essential_section`):** Propiedades cardinales visibles de inmediato (Espacio Activo, Referencia `A4 Hz`, `Tempo Maestro BPM`, `Instrumento Activo` y contenido contextual inyectable `rightInspectorContent`).
   - **Nivel 2 (`inspector_level_2_advanced_toggle` / `inspector_level_2_advanced_content`):** Acordeon colapsable bajo demanda que expone parametros tecnicos del motor DSP (`engineName`, tamano de buffer, latencia en milisegundos, estado en linea y modo Dual Split).
2. **Sistema `StudioHoverInfoView` al estilo Ableton Live 12 (`lib/core/design_system/molecules/studio_hover_info_view.dart`):** Implementar el modelo inmutable `StudioHoverInfoItem`, el controlador reactivo `StudioHoverInfoController`, el wrapper `StudioHoverInfoTarget` y el panel acoplado `StudioHoverInfoViewPanel` (`Key('studio_hover_info_view_panel')`) en el pie del Inspector Derecho.

---

## 3. Consecuencias

### 3.1 Positivas
- **Cero Modales para Ayuda y Telemetria Contextual:** El musico consulta propiedades de sesion, formulas acusticas y atajos de teclado en tiempo real al pasar el cursor sin perder de vista el pentagrama ni el afinador.
- **Presupuesto Espacial Canvas-First:** Al estar colapsado por defecto (`initialInspectorVisible = false`), el lienzo central conserva mas del 82% del viewport y, al abrirse, mantiene un ratio superior al 75%.

### 3.2 Compromisos y Mitigaciones
- **Mitigacion en Dispositivos sin Cursor:** Ademas de `MouseRegion.onEnter`, `StudioHoverInfoController.instance.setHoverInfo(...)` puede invocarse programaticamente al enfocar o seleccionar controles mediante teclado o toque tactil.

---

## 4. Verificacion

- Suite automatizada: `test/core/design_system/us_ux_05_right_inspector_and_hover_info_test.dart`.
- Analisis estatico: `flutter analyze --no-fatal-infos` con `0 issues`.
