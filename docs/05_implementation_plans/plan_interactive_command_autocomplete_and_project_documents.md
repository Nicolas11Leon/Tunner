# Template: Implementation Plan (Plantilla Plan de Implementación)

Este documento define la estructura obligatoria previa a la implementación del sistema de autocompletado interactivo de comandos y el acceso completo a proyectos y documentos musicales en el árbol de navegación de **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-COMMAND-PROMPT-DOCUMENTS-2026-074`
- **Título de la Implementación:** `Implementación del Prompt Interactivo con Autocompletado de Comandos (/ y @), Sistema de Ayuda Universal (/help) y Gestor de Documentos/Proyectos en el Árbol Jerárquico`
- **Fase del Proyecto:** `Fase 2 (Estación de Trabajo Desktop & Consola de Control)`
- **Estado:** `En Progreso`
- **ADR Relacionado:** `docs/04_adrs/0015_interactive_command_palette_and_workspace_documents_architecture.md`
- **Documento Funcional Base:** `docs/02_use_cases/74_uc_interactive_command_autocomplete_and_project_documents.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Transformar la consola inferior de la estación de trabajo en un **motor de autocompletado interactivo de alta reactividad** (estilo Antigravity / Claude Code / VS Code Omnibox) que sugiera acciones con `/`, módulos con `@`, y provea ayuda interactiva con `/help` o un botón `?`, e integrar en la barra lateral izquierda el acceso completo a **proyectos, partituras MusicXML, sesiones de afinación y grabaciones WAV**.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación del widget molecular `StudioCommandPromptBar` con `TextField`, overlay de sugerencias autocompletables, filtrado en tiempo real, navegación con teclado (flechas arriba/abajo, Enter, Tab, Escape).
  - Diccionario de comandos de acción `/` (`/afinar`, `/metro`, `/bpm <num>`, `/calibrar <hz>`, `/grabar`, `/espectrograma`, `/dron`, `/acordes`, `/oido`, `/partituras`, `/rack`, `/instrumento`, `/help`).
  - Diccionario de módulos `@` (`@tuner`, `@rack`, `@conservatorio`, `@laboratorio`, `@partituras`).
  - Botón de ayuda interactiva `? Help` que despliega la hoja de ayuda completa con descripción y atajos de todos los comandos.
  - Expansión de `MainAppShell` para modelar documentos y proyectos musicales reales en el árbol lateral (archivos MusicXML, sesiones de afinación con diferentes temperamentos, tomas de práctica WAV, rutinas didácticas).
  - Pruebas unitarias de autocompletado, ejecución de comandos y navegación de documentos.
- **Excluido (Out-of-Scope):**
  - Conexión a servicios en la nube (la arquitectura es 100% offline y monolítica).
  - Modificación de los algoritmos de detección de tono FFI.

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.x`
- **Flutter SDK:** Canal estable de Linux Desktop.
- **Riesgo Tecnológico:**
  - Cero bibliotecas externas añadidas. Uso de primitivas de Flutter (`Overlay`, `CompositedTransformTarget`, `CompositedTransformFollower`, `FocusNode`, `TextEditingController`).
  - Zero busy-waiting loops. Filtrado síncrono ultra-rápido en memoria (<1ms para cientos de comandos).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Molécula `StudioCommandPromptBar` con Overlay de Autocompletado
- [x] Crear modelo de sugerencia de comando: `PromptSuggestion` (prefix, trigger `/` o `@`, título, descripción, atajo, callback de ejecución).
- [x] Implementar widget reactivo con input estilizado estilo IDE y popup emergente flotante anclado mediante `CompositedTransformTarget`.
- [x] Soporte para navegación con teclas de flecha arriba/abajo y selección con Enter/Tab.
- [x] Integración de botón de ayuda `? Help`.

### Paso 2: Integración de Comandos y Ayuda Universal (`/help`)
- [x] Registrar todos los comandos musicales del sistema (Afinador, BPM, Grabación, Metrónomo, Herramientas Acústicas, Partituras, Calibración).
- [x] Implementar comando `/help` y modal interactivo de documentación de comandos.

### Paso 3: Expansión de Proyectos y Documentos en `StudioTreeView`
- [x] Estructurar el árbol de proyectos en `MainAppShell` para presentar documentos musicales concretos (Sesiones de afinación, grabaciones WAV, partituras MusicXML, lecciones).
- [x] Conectar los callbacks de selección de cada documento para cargar el estado en `TunerViewModel`.

### Paso 4: Pruebas y Validación
- [x] Redactar pruebas unitarias en `test/core/design_system/studio_command_prompt_test.dart`.
- [x] Ejecutar `flutter analyze` y asegurar cero advertencias.
- [x] Compilar el binario nativo y validar en vivo en `DISPLAY=:0`.
