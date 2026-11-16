# Implementation Plan: Universal DJ Console Emulation File System & DAW Multi-Panel Docking Suite

Este documento define la planificación técnica formal para la arquitectura de emulación de consolas físicas mediante archivos abiertos (`.djconsole`) y el sistema de acoplamiento y arrastre de ventanas divididas tipo DAW profesional en **Tunner**, cumpliendo con la Constitución del Proyecto (`AGENTS.md`).

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-EMULATOR-DOCKING-2026-0075`
- **Título de la Implementación:** Emulador Universal de Consolas por Archivo Abierto y Sistema Docking de Ventanas Multi-Panel tipo DAW
- **Fase del Proyecto:** Fase 2 (Instrumentos Virtuales y Motores de Mezcla DSP)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0075: Formato Canónico de Archivos de Consolas Virtuales y Sistema de Docking Multi-Panel](../04_adrs/0075_console_emulator_file_system_and_daw_docking_suite.md)
- **Documento Funcional Base:** [Caso de Uso 85: Emulador de Consolas por Archivo y Sistema de Ventanas Arrastrables](../02_use_cases/85_uc_console_emulator_file_system_and_daw_docking_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
1. **Emulación Universal de Consolas Físicas:** Permitir a cualquier persona emular cualquier controlador o consola física del mercado en su computadora sin costo de hardware, mediante un formato de archivo abierto y comprimido (`.djconsole` en JSON con metadatos, controles vectoriales, mapeos de teclado y colores) y un constructor interactivo para crear nuevas consolas personalizadas o importar presets de fabricantes.
2. **Sistema Docking de Ventanas tipo DAW Profesional:** Proveer una arquitectura de gestión de ventanas y paneles desacoplables que permita arrastrar pestañas y módulos (Consola DJ, Afinador Estroboscópico, Espectrograma FFT, Bóveda Multimedia, Editor de Partituras) hacia zonas de anclaje divididas (Izquierda, Derecha, Inferior o Maximizado) dentro de cualquier espacio de trabajo.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad de especificación de consola (`DjConsoleBlueprintEntity`) con serialización JSON canónica y códec de archivo (`.djconsole`).
  - Servicio de importación, exportación y almacenamiento local de consolas de usuario (`DjConsoleBlueprintStorageService`).
  - Constructor/Editor interactivo de consolas emuladas (`DjConsoleModelBuilderModal`), permitiendo agregar jogs, faders, knobs, pads y vincularlos a teclas físicas en tiempo real.
  - Motor de Docking de Ventanas (`StudioDockLayoutEngine`, `StudioDockZone`, `StudioDockablePanelEntity`).
  - Widgets interactivos de arrastre de paneles: `StudioDockableWindowCard`, `StudioDockDropZoneTarget` y divisor redimensionable `StudioSplitterDivider`.
  - Integración en `MainAppShell` y `DjStudioWorkstationView` para arrastrar la consola y otras herramientas entre los espacios de trabajo.
  - Cobertura de pruebas unitarias y de widgets con análisis estático impecable.
- **Excluido (Out-of-Scope):**
  - Renderizado 3D poligonal OpenGL/Vulkan pesado (se mantiene el renderizado vectorial fluido de 60/120 FPS sin latencia de GPU).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK & Flutter:** Pure Dart en Dominio (`dart:convert` para serialización JSON).
- **Flutter Framework:** `Draggable`, `DragTarget`, `CustomPaint`, `FocusNode` para arrastre reactivo con feedback visual de áreas de inserción (Drop Highlights).
- **Rendimiento:** Cero busy-waiting, uso determinista de memoria y actualización inmediata de layouts.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [ ] Definir `DjConsoleBlueprintEntity` con especificación de dimensiones físicas, lista de controles normalizados, mapeos QWERTY por defecto y metadatos del fabricante.
- [ ] Definir entidades del sistema de Docking: `StudioDockZone`, `StudioDockLayoutEntity`, `StudioDockablePanelEntity`.
- [ ] Pruebas unitarias de serialización y resolución de zonas de docking.

### Paso 2: Capa de Infraestructura / Datos (Servicios de Archivo y Códec)
- [ ] Implementar `DjConsoleFileCodec` para importar y exportar archivos `.djconsole`.
- [ ] Implementar `DjConsoleBlueprintStorageService` para persistir consolas personalizadas creadas por la comunidad.

### Paso 3: Capa de Presentación (Docking DAW y Constructor de Consolas)
- [ ] Crear componentes de Docking: `StudioDockDropZoneTarget`, `StudioDockableWindowWrapper`, `StudioWorkspaceDockingContainer`.
- [ ] Crear el modal interactivo `DjConsoleModelBuilderModal` para diseñar, nombrar y mapear consolas desde cero.
- [ ] Integrar el sistema de arrastre en `MainAppShell` y `DjStudioWorkstationView`.

### Paso 4: Pruebas, Verificación y Control de Calidad
- [ ] Crear suite de pruebas exhaustivas en `test/features/dj_console/` y `test/core/docking/`.
- [ ] Validar con `flutter analyze` asegurando cero errores.
- [ ] Compilar y verificar en vivo sobre Linux Desktop.
- [ ] Commit y Push a Git.
