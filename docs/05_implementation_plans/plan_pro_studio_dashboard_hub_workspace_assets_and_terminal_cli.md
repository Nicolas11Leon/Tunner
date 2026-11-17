# Plan de Implementación: Pro Studio Dashboard Hub, Activos Canónicos de Workspace y Terminal Interactiva Tunner OS

## Metadatos del Plan
- **ID del Plan:** `PLAN-FASE1-STUDIO-HUB-TERMINAL-2026-101`
- **Título de la Implementación:** Hub de Dashboard Profesional, Poblado de Proyectos de Workspace y Terminal Interactiva Tunner OS
- **Fase del Proyecto:** Fase 1 / Experiencia de Estudio & Interoperabilidad
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0091: Pro Studio Dashboard Hub, Activos Canónicos de Workspace y Terminal Interactiva Tunner OS](docs/04_adrs/0091_pro_studio_dashboard_hub_workspace_assets_and_terminal_cli.md)
- **Documento Funcional Base:** [Caso de Uso 101: Pro Studio Dashboard Hub, Activos Canónicos de Workspace y Terminal Interactiva Tunner OS](docs/02_use_cases/101_uc_pro_studio_dashboard_hub_workspace_assets_and_terminal_cli.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Transformar la pantalla principal de Tunner Studio en un Dashboard Hub de alta densidad con telemetría en vivo, grid de 2 columnas para escritorio, pre-carga de proyectos funcionales en el explorador de archivos y una terminal interactiva CLI (`Ctrl + ~`) para operar el software como un sistema operativo de audio.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación del subsistema de terminal en `lib/core/terminal/`:
    - `tunner_os_command_entity.dart` (modelado de comandos y argumentos).
    - `tunner_os_kernel.dart` (intérprete lógico y router de comandos).
    - `tunner_os_terminal_drawer.dart` (widget de consola interactiva con historial y scroll).
  - Rediseño de `lib/features/navigation/presentation/home_dashboard_screen.dart`:
    - Grid responsivo de 2 columnas para pantallas $\ge 950\text{ px}$.
    - Panel superior de Telemetría Core Audio en vivo (48 kHz / 24-bit / buffer / dBFS de entrada).
    - Inclusión destacada de la tarjeta de Consola DJ Pro Workstation.
    - Barra de plantillas de creación rápida (.tunner, .tndj, presets).
  - Inyección de proyectos pre-cargados en `StudioWorkspaceFileSystemService` y repositorios.
  - Atajo global `Ctrl + ~` y botón interactivo en la barra inferior para abrir la terminal.
  - Pruebas unitarias y de widgets exhaustivas.
- **Excluido (Out-of-Scope):**
  - Servidor SSH o sockets TCP remotos (la terminal es estrictamente in-process según la regla Offline First).

---

## 2. Análisis de Dependencias y Tecnologías
- **Dart SDK:** `^3.11.x`
- **Flutter SDK:** Canal estable oficial.
- **Clean Architecture:** Capa de dominio del kernel 100% pura Dart, libre de dependencias de UI.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Núcleo de Terminal y CLI (`lib/core/terminal/`)
- [ ] Definir `TunnerOsCommandResult` y tokens de comando en `lib/core/terminal/domain/`.
- [ ] Implementar `TunnerOsKernel` con soporte para dominios `tuner`, `dj`, `io`, `fs`, `dsp`, `theme`, `help`.
- [ ] Implementar `TunnerOsTerminalDrawer` con interfaz tipográfica oscura, prompt interactivo y soporte de teclas `Up` / `Down` para historial.

### Paso 2: Activos Canónicos en el Workspace (`lib/core/file_system/`)
- [ ] Pre-cargar en `LocalDiskStudioFileSystemRepository` y `MemoryStudioFileSystemRepository` los proyectos de demostración:
  - `Suite_No1_Bach.tunner`
  - `Fur_Elise_Club_Mix.tndj`
  - `Cyberpunk_Night_Groove.wav`
  - `Guitarra_Drop_D_Standard.tnpreset`
- [ ] Conectar la apertura de estos archivos a sus respectivas herramientas.

### Paso 3: Rediseño del Dashboard Hub (`lib/features/navigation/presentation/home_dashboard_screen.dart`)
- [ ] Implementar el panel superior de Telemetría Core Audio en vivo.
- [ ] Reorganizar la lista de tarjetas en un `Wrap` / `LayoutBuilder` de 2 columnas balanceadas en pantallas anchas.
- [ ] Asegurar que la Consola DJ Pro aparezca como tarjeta de módulo principal.
- [ ] Agregar la barra de plantillas rápidas.

### Paso 4: Integración del Atajo Global y Pruebas
- [ ] Enlazar `Ctrl + ~` en `StudioDesktopAppShell` / `MainAppShell` para desplegar la terminal.
- [ ] Crear tests automatizados para el kernel de la terminal y los componentes del dashboard.
- [ ] Ejecutar compilación de producción en Linux.
