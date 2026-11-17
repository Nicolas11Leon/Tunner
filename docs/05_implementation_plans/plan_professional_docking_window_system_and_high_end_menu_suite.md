# Plan de Implementación: Sistema de Ventanas Acoplables/Ajustables (Docking & Split Viewports), Selector de Espacios DAW y Menú de Alta Gama

Este documento define la planificación técnica obligatoria para implementar el sistema ergonómico de ventanas ajustables, división de vista (split view), selectores de espacios de trabajo estilo DAW y barra de menú de alta gama en **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-UI-2026-81`
- **Título de la Implementación:** Sistema de Ventanas Acoplables/Ajustables, Selector de Espacios DAW y Menú de Alta Gama
- **Fase del Proyecto:** Fase 3 (Estación de Trabajo Desktop & Arquitectura Modular)
- **Estado:** Propuesto
- **ADR Relacionado:** [`docs/04_adrs/0071_professional_docking_window_system_and_high_end_menu_suite.md`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/04_adrs/0071_professional_docking_window_system_and_high_end_menu_suite.md)
- **Documento Funcional Base:** [`docs/02_use_cases/81_uc_professional_docking_window_system_and_high_end_menu_suite.md`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/02_use_cases/81_uc_professional_docking_window_system_and_high_end_menu_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Transformar la interfaz de escritorio de Tunner en un entorno de trabajo con estética y ergonomía equivalente a estaciones de audio digital (DAWs) comerciales de alta gama (Pro Tools, Logic Pro X, Ableton Live, Antigravity IDE):
1. Proporcionar un sistema de división de pantalla interactivo (`StudioSplitter` / `StudioDockingPanel`) que permita arrastrar con el cursor para redimensionar los paneles (panel lateral, rack modular y viewport principal) de forma fluida.
2. Incorporar una barra de pestañas de espacios de trabajo fijada en la cabecera (`Aprender & Afinar`, `Rack Modular Pro`, `Notación & Partitura`, `Consola DJ & Mezcla`) con indicador de pestaña activa y atajos rápidos.
3. Proveer controles de maximizado/minimizado de paneles (`Toggle Sidebar [ ◨ ]`, `Maximize Viewport [ ⤢ ]`, `Split Dual View [ ◫ ]`).
4. Elevar la barra de menú superior con menús desplegables de alta definición tipográfica, atajos de teclado alineados a la derecha y telemetría de audio en vivo.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Componente atómico y molecular de división interactiva con cursor de redimensionamiento (`SystemMouseCursors.resizeColumn`) y persistencia de proporciones.
  - Pestañas de espacios DAW en la barra superior de `StudioDesktopAppShell`.
  - Botones de control de layout en la barra de herramientas (colapsar barra lateral, vista dividida, maximizar).
  - Menús desplegables enriquecidos con diseño de software de licencia profesional (atajos alineados a la derecha, hover sutil, divisores hairline).
  - Soporte de modo de vista dual (Split View: Rack Modular + Viewport activo en simultáneo).
- **Excluido (Out-of-Scope):**
  - Mover ventanas fuera del proceso hacia ventanas secundarias independientes del SO (se mantiene dentro de la misma ventana de escritorio para garantizar latencia cero y offline-first sin sobrecarga de X11/Wayland).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.x`
- **Flutter SDK:** Canal oficial estable para Linux Desktop, macOS y Windows.
- **Riesgo Tecnológico:** Cero dependencias externas nuevas. Utiliza primitivas puras de Flutter (`GestureDetector`, `MouseRegion`, `LayoutBuilder`, `AnimatedContainer`, `Row`, `Expanded`, `Flex`). Cero busy-waiting.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Componentes de UI de División y Redimensionamiento (Átomos / Moléculas)
- [ ] Crear `StudioSplitter`: divisor visual de 1px a 4px de zona de arrastre con cursor de cambio de tamaño (`SystemMouseCursors.resizeColumn`), feedback hover y arrastre continuo con clamps de ancho mínimo (180px) y máximo (500px para sidebar; 25% a 75% para split view).
- [ ] Crear `StudioWorkspaceTabBar`: barra de pestañas compacta (28px) integrada en la cabecera superior con estados visuales activos/inactivos, tipografía profesional y selector de espacios (`Aprender`, `Rack Modular`, `Partitura`, `DJ & Mezcla`).

### Paso 2: Integración en `StudioDesktopAppShell`
- [ ] Incorporar el estado de redimensionamiento interactivo en la barra lateral izquierda (arrastrar para ensanchar o estrechar la barra lateral).
- [ ] Incorporar botón de colapso rápido de la barra lateral `[ ◨ ]` para modo "Full Screen Studio".
- [ ] Incorporar soporte para modo de visualización dual (`isDualSplitViewActive`): permite ver el Rack Modular a la izquierda/derecha y el Viewport activo en simultáneo con divisor ajustable.
- [ ] Estilizar menús desplegables con fondo profundo, micro-sombras, tipografía monoespaciada para atajos y hover states suaves.

### Paso 3: Conexión con `MainAppShell` y `TunerViewModel`
- [ ] Conectar las pestañas de espacios de trabajo directamente a los tabs del estudio y al modelo `WorkspaceType`.
- [ ] Preservar las proporciones ajustadas por el usuario durante la sesión.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Crear suite de pruebas de widgets para el splitter interactivo, conmutación de espacios y botones de colapso.
- [ ] Verificar análisis estático `flutter analyze` con cero errores.
- [ ] Compilar y verificar fluidez visual a 60/120 FPS en Linux Desktop.
