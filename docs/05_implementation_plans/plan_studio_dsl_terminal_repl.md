# Plan de Implementación: Terminal REPL y Consola de Scripting Interactiva para Tunner Studio OS

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE6-TERMINAL-REPL-2026-0098`
- **Título de la Implementación:** Terminal REPL y Consola de Scripting Interactiva para Tunner Studio OS
- **Fase del Proyecto:** Fase 6 (Ecosistema de Plataforma Autónoma y Lenguaje DSL)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0098](../04_adrs/0098_studio_dsl_terminal_repl.md)
- **Documento Funcional Base:** [Caso de Uso 109](../02_use_cases/109_uc_studio_dsl_terminal_repl.md)
- **Issue Asociado:** [#36](https://github.com/Nicolas11Leon/Tunner/issues/36)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Construir el widget de presentación `StudioDslTerminalPanelWidget` que provee una consola REPL profesional acoplable en Tunner Studio, con editor de código multilínea, evaluación reactiva, atajos de teclado (`Ctrl+Enter` / `Cmd+Enter`), plantillas de scripts (`quick_jam.tun` y `mastering_chain.tun`) y visualización de resultados en tiempo real.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Widget interactivo `StudioDslTerminalPanelWidget` en `lib/core/terminal/presentation/`.
  - Plantillas de scripts estándar en código de producción.
  - Atajos de hardware para ejecución directa (`Ctrl+Enter` / `Cmd+Enter`).
  - Historial de scripts ejecutados con navegación `ArrowUp` / `ArrowDown`.
  - Pruebas unitarias y de widgets en `test/core/terminal/studio_dsl_terminal_panel_widget_test.dart`.
  - Verificación de estática con `flutter analyze` reportando 0 advertencias.
- **Excluido (Out-of-Scope):**
  - Procesador de convolución IR y algoritmos de reverberación física (asignado a Fase 7 e Issue #37).

---

## 2. Análisis de Dependencias y Tecnologías

- **Framework:** Flutter Material / Custom Painters / Services (Hardware Keyboard Shortcuts).
- **Estilo:** Atomic Design de Tunner (Dark Slate `#1E1E22`, Hairline borders 1px, tipografía monoespaciada para código y telemetría, cero emojis).
- **Rendimiento:** 60/120 FPS sin reconstrucciones redundantes.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Implementación de `StudioDslTerminalPanelWidget`
- Diseñar la interfaz con:
  - Header técnico con título, selector de plantillas, botón de ejecución y botón de limpiar.
  - Campo de texto multilínea con callback de atajo de teclado (`HardwareKeyboard` / `FocusNode`).
  - Panel de telemetría de salida con vista monoespaciada y colores semánticos (verde mate `#4ADE80` para éxito, rojo mate `#F87171` para errores).

### Paso 2: Integración en la Interfaz de Usuario
- Ofrecer diálogo o panel acoplable accesible desde la barra superior de herramientas o la terminal CLI.

### Paso 3: Pruebas de Widgets y Funcionales
- Escribir `test/core/terminal/studio_dsl_terminal_panel_widget_test.dart`:
  - Prueba de renderizado inicial y componentes básicos.
  - Prueba de ejecución de script válido y actualización del panel de salida.
  - Prueba de selección y carga de plantilla `quick_jam.tun`.
  - Prueba de reporte de errores sintácticos.
  - Prueba de atajo `Ctrl+Enter`.

---

## 4. Criterios de Aceptación (Definition of Done)

1. `StudioDslTerminalPanelWidget` se renderiza de forma limpia y responde a la interacción sin excepciones.
2. Ejecutar un script DSL actualiza la salida con el reporte de sentencias y tiempo de evaluación.
3. Las plantillas de ejemplo se cargan correctamente en el editor al pulsar sus botones.
4. Cobertura de pruebas unitarias y de widgets al 100% pasando sin errores.
5. `flutter analyze` con 0 advertencias.
