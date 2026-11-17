# Plan de Implementación: Arquitectura de Navegación Jerárquica Desktop Pro-Studio (Estilo IDE / Adobe CC)

- **ID del Plan:** `PLAN-UI-DESKTOP-HIERARCHICAL-WORKSPACE-2026-072`
- **Título de la Implementación:** `Layout de Escritorio Profesional con Árbol Jerárquico Lateral (Sidebar Treeview), Menú Superior y Status Bar`
- **Fase del Proyecto:** `Fase Global - Capa de Navegación, Sistema de Diseño y Workspaces`
- **Estado:** `En Progreso`
- **ADR Relacionado:** [ADR 0065](../04_adrs/0065_atomized_studio_design_system_adobe_spectrum.md)
- **Documento Funcional Base:** [Caso de Uso 72](../02_use_cases/72_uc_desktop_hierarchical_studio_workspace_and_treeview.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Erradicar la apariencia de "aplicación móvil con tarjetas apiladas y barra inferior flotante" cuando Tunner se ejecuta en entornos de escritorio (Linux, macOS, Windows). 
Implementar una **arquitectura de navegación jerárquica de grado IDE / Workstation profesional** inspirada directamente en interfaces como Antigravity, VS Code y Adobe Creative Cloud:
1. **Barra de Menú Superior Unificada (Top Menu & Breadcrumbs):** Con menús de aplicación (`Tunner Studio`, `Archivo`, `Herramientas`, `Acústica`, `Vista`, `Ayuda`) y breadcrumb del módulo activo.
2. **Barra Lateral Jerárquica Izquierda (Hierarchical Treeview Sidebar):** Categorías colapsables/expandibles con iconos técnicos, atajos de teclado, conteo de elementos y badges de estado.
3. **Área de Trabajo Central Expansiva (Full Viewport):** Sin barras móviles intrusivas que tapen el contenido.
4. **Barra de Estado Inferior de Estudio (Bottom Status Bar):** Con lecturas acústicas continuas (DSP rate, latencia en ms, afinación de referencia A4, temperamento activo, BPM y estado de grabación).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación del componente de árbol jerárquico `StudioTreeView` (`lib/core/design_system/molecules/studio_tree_view.dart`).
  - Creación del shell de escritorio profesional `StudioDesktopAppShell` (`lib/core/design_system/organisms/studio_desktop_app_shell.dart`).
  - Adaptación transparente en `MainAppShell` para desplegar el layout jerárquico en desktop.
  - Mapeo completo de las herramientas y módulos acústicos al árbol jerárquico.
- **Excluido (Out-of-Scope):**
  - No se altera la lógica interna de los ViewModels ni el bucle de audio en Isolates.

---

## 2. Análisis de Dependencias y Tecnologías

- **Layout:** `Row` + `Expanded` con ancho de sidebar determinista (240px a 260px), bordes hairline de 1px (`#2A2D35` / `#3E3E42`).
- **Rendimiento:** Cero recreación de árboles pesados; uso de `IndexedStack` y listeners eficientes sin parpadeo de pantalla.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Documentación Formal y Caso de Uso 72
- [x] Redacción del Plan de Implementación formal (`docs/05_implementation_plans/plan_desktop_hierarchical_studio_workspace.md`).
- [ ] Redacción del Caso de Uso 72 con diagramas Mermaid de Arquitectura y Flujo (`docs/02_use_cases/72_uc_desktop_hierarchical_studio_workspace_and_treeview.md`).

### Paso 2: Creación del Átomo/Molécula `StudioTreeView`
- [ ] Implementar `StudioTreeSection`: Sección colapsable con chevron animado y título en mayúsculas pequeñas.
- [ ] Implementar `StudioTreeItem`: Fila interactiva con glifo técnico, título, badge de estado, atajo y estilo de selección activa tipo píldora (`#252528`).

### Paso 3: Creación del Organismo `StudioDesktopAppShell`
- [ ] Top Menu Bar con menús de sistema y breadcrumb.
- [ ] Sidebar izquierda con el árbol jerárquico y tarjeta técnica de instrumento activo en el pie de la barra.
- [ ] Viewport central dinámico.
- [ ] Status Bar inferior de 26px con indicadores DSP.

### Paso 4: Integración en `MainAppShell`
- [ ] Conectar la navegación del árbol jerárquico con los índices de vistas y modales.
- [ ] Asegurar retrocompatibilidad con los atajos globales de teclado existentes.

### Paso 5: Pruebas, Verificación y Lanzamiento
- [ ] Pruebas unitarias de widgets para el árbol jerárquico y shell desktop.
- [ ] Ejecución de `flutter analyze` y `flutter test`.
- [ ] Compilación y lanzamiento en vivo en Linux Desktop para validación del usuario.

---

## 4. Criterios de Aceptación (Definition of Done)

- [ ] La aplicación abre con una barra lateral izquierda jerárquica idéntica a la estructura de un IDE profesional (Antigravity/VS Code).
- [ ] Cada herramienta principal es accesible desde el árbol colapsable con selección activa evidente.
- [ ] La barra superior incluye menús y breadcrumbs limpios.
- [ ] Cero barras móviles flotantes estorbando la pantalla en desktop.
- [ ] Suite de pruebas pasando al 100%.
