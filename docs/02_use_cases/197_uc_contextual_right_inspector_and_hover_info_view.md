# Caso de Uso 197: Inspector Contextual Derecho y Panel Info View por Hover (US-UX-05)

## Metadatos del Documento

- **ID del Documento:** `DOC-UI-2026-197`
- **ID del Caso de Uso:** `UC-197`
- **Historia de Usuario Asociada:** `US-UX-05`
- **Titulo Oficial:** Inspector Contextual Derecho de Revelacion Progresiva y Panel de Ayuda Ambiental Info View por Hover
- **Estado:** `Approved`
- **Fecha de Creacion:** `2026-11-25`
- **Ultima Modificacion:** `2026-11-25`
- **Fase Asociada:** `Fase 2 / Global UX Wave 5`
- **Autor / Revisor Principal:** `Nicolas Leon`
- **ADR Relacionado:** [ADR 0189](../04_adrs/0189_contextual_right_inspector_and_hover_info_view.md)

---

## 1. Resumen Ejecutivo (Executive Summary)

Este caso de uso formaliza la interaccion del musico con el Inspector Contextual Derecho (`Ctrl+I`) y el panel acoplado `StudioHoverInfoViewPanel` (inspirado en *Essential Sound* de Adobe Audition e *Info View* de Ableton Live 12), permitiendo consultar propiedades esenciales de la sesion (Nivel 1), parametros tecnicos del motor DSP (Nivel 2) y explicaciones acusticas instantaneas al pasar el cursor sobre cualquier control sin abrir modales bloqueantes.

---

## 2. Diagramas Canonicos (Mermaid)

### 2.1 Diagrama de Casos de Uso

```mermaid
flowchart LR
    Musico(["Musico / Productor"])
    UC197_1["Alternar Inspector Contextual Derecho (Ctrl+I)"]
    UC197_2["Consultar Propiedades Esenciales (Nivel 1)"]
    UC197_3["Expandir Parametros DSP Avanzados (Nivel 2)"]
    UC197_4["Ver Formula Acustica y Atajo en Info View al pasar el cursor"]

    Musico --> UC197_1
    UC197_1 --> UC197_2
    UC197_2 --> UC197_3
    Musico --> UC197_4
```

### 2.2 Diagrama de Secuencia Detallado

```mermaid
sequenceDiagram
    actor U as Musico
    participant Shell as StudioDesktopAppShell
    participant Insp as RightContextualInspectorPanel
    participant Target as StudioHoverInfoTarget
    participant Ctrl as StudioHoverInfoController
    participant Info as StudioHoverInfoViewPanel

    U->>Shell: Tap en btn_toggle_right_inspector (INSPECTOR)
    Shell->>Shell: toggleInspector() -> _isInspectorVisible = true
    Shell->>Insp: Renderiza Nivel 1 (A4Hz, Tempo, Instrumento) y StudioHoverInfoViewPanel
    U->>Insp: Tap en inspector_level_2_advanced_toggle
    Insp->>Insp: Despliega inspector_level_2_advanced_content (Buffer, Latencia, Estado DSP)
    U->>Target: Pasa el cursor (onEnter) sobre un control del Shell
    Target->>Ctrl: setHoverInfo(StudioHoverInfoItem)
    Ctrl-->>Info: notifyListeners()
    Info-->>U: Muestra titulo, descripcion pedagogica, formula acustica y atajo
```

---

## 3. Precondiciones, Postcondiciones y Flujos

### 3.1 Precondiciones
- `StudioDesktopAppShell` se encuentra montado en modo escritorio (`width >= 900 px`).

### 3.2 Postcondiciones
- El panel `studio_right_contextual_inspector_panel` se despliega o colapsa sin alterar el estado del motor de audio ni reiniciar la vista central activa.
- `StudioHoverInfoViewPanel` refleja en tiempo real la metainformacion del ultimo control inspeccionado.

### 3.3 Flujo Principal
1. El usuario pulsa el chip `INSPECTOR` (`Key('btn_toggle_right_inspector')`) en la barra de estado inferior.
2. El sistema despliega el panel derecho de `280 px` mostrando la seccion `NIVEL 1 · PROPIEDADES ESENCIALES`.
3. El usuario pulsa el encabezado `PARAMETROS DSP & MOTOR AVANZADO` (`Key('inspector_level_2_advanced_toggle')`) para revelar los detalles tecnicos de buffer y latencia.
4. El usuario desplaza el puntero sobre cualquier accion de la barra superior o inferior; el panel `INFO VIEW` actualiza instantaneamente el titulo, la formula matematica y el atajo de teclado.

### 3.4 Flujos Alternativos y Condiciones de Error
- **Colapso para Maximizar el Lienzo:** Si el usuario pulsa el icono de cierre (`Key('btn_close_right_inspector')`) o vuelve a pulsar `INSPECTOR`, el panel se desmonta y devuelve los `280 px` horizontales al lienzo primario.

---

## 4. Trazabilidad Arquitectonica y Pruebas Automatizadas

- **Componentes:** `lib/core/design_system/molecules/studio_hover_info_view.dart`, `lib/core/design_system/organisms/studio_desktop_app_shell.dart`.
- **Suite de Verificacion:** `test/core/design_system/us_ux_05_right_inspector_and_hover_info_test.dart` (`3/3 PASS`).
