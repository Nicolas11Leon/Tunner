# Plan de Implementacion: UX Wave 2 - Shell Desktop, Pestanas DAW, Explorador y Automatizaciones Reales

## Metadatos
- **ID:** `PLAN-UX-WAVE-2-2026-002`
- **Titulo:** Sincronizacion de Pestanas, Carga Real de Archivos y Automatizaciones de Estudio
- **Fase:** Fase 4 - Hardening Pre-v1.0.0
- **Estado:** Aprobado
- **ADR Relacionado:** [ADR 0127](../04_adrs/0127_ux_wave_2_desktop_shell_tabs_and_automations.md)
- **Documento Funcional Base:** [Caso de Uso 138](../02_use_cases/138_uc_ux_wave_2_desktop_shell_tabs_and_automations.md)

---

## 1. Alcance y Objetivos

### 1.1 Objetivo Primario
Remediar inconsistencias de navegacion en la interfaz de escritorio, habilitar la carga y persistencia real de proyectos desde el explorador y las plantillas, permitir la eleccion de vistas secundarias en modo dividido y conectar las automatizaciones y personalizaciones con el motor de ejecucion en tiempo real.

### 1.2 Limites del Alcance
- **Incluido:**
  - `studio_workspace_tab_bar.dart`: Expansión a 6 pestañas (0 a 5) con títulos y atajos correctos.
  - `studio_desktop_app_shell.dart`: Corrección del menú Window con las 6 vistas y selector de vista secundaria en `Dual Split`.
  - `main_app_shell.dart`: Deserialización real en `_handleOpenFile`, persistencia en `onMenuSaveWorkspace` y plantillas de Home.
  - `studio_customizations_modal.dart`: Aplicación de motor DSP, precisión y FPS en `TunerViewModel`.
  - `studio_automations_modal.dart`: Rampa de metrónomo activa (+2 BPM cada 4 compases) y calentamiento guiado.
- **Excluido:**
  - Motores táctiles de instrumentos del Rack (alcance de Ola UX-3).
  - Controles DJ de arrastre físico y filtros en tiempo real (alcance de Ola UX-4).

---

## 2. Plan Paso a Paso de Ejecucion

### Paso 1: Sincronizacion de Pestanas y Menu Window
1. En `studio_workspace_tab_bar.dart`, definir la lista completa de las 6 pestañas DAW:
   - 0: Inicio (`F1` / `Alt+1`)
   - 1: Afinador (`F2` / `Alt+2`)
   - 2: Aprender (`F3` / `Alt+3`)
   - 3: Rack Modular (`F4` / `Alt+4`)
   - 4: Partituras (`F5` / `Alt+5`)
   - 5: Consola DJ (`F6` / `Alt+6`)
2. En `studio_desktop_app_shell.dart`, actualizar el menú `Window` para listar las 6 opciones ordenadas y mapeadas a `widget.onNavigateToTabIndex?.call(0..5)`.

### Paso 2: Carga Real de Archivos en `MainAppShell`
1. En `_handleOpenFile(StudioFileEntity file)`:
   - Para `.tunner`: Deserializar `TunnerProjectPackage` o cargar MusicXML/JSON en `viewModel.loadSongPackage` y navegar a la pestaña 4.
   - Para `.tnpreset`: Extraer valores de afinación/temperamento y aplicarlos en `viewModel`.
   - Para `.tnt`: Deserializar especificación de rack y cargarla en `_modularRackViewModel`.
   - Para `.tndj`: Cargar pista o preset en `_djConsoleViewModel` y navegar a la pestaña 5.
2. En `onMenuSaveWorkspace`: Invocar `viewModel.savePersistedState()`.

### Paso 3: Selector de Vista Secundaria en Dual Split View
1. Permitir conmutar la vista secundaria entre Rack Modular, Afinador Estroboscópico, Espectrograma o Metrónomo si la pestaña principal activa ya es el Rack Modular (índice 3).

### Paso 4: Automatizaciones y Personalizaciones Reales
1. En `StudioCustomizationsModal`: Conectar el botón "Aplicar Cambios" con los métodos de `viewModel` (`setPitchAlgorithm`, etc.).
2. En `StudioAutomationsModal`: Implementar la rampa de metrónomo progresiva escuchando cambios de compás o mediante temporizador de compases en vivo.

### Paso 5: Suite de Pruebas de Regresion y Verificacion
1. Crear `test/features/navigation/ux_wave_2_desktop_shell_and_tabs_test.dart` verificando:
   - Renderizado y navegación de las 6 pestañas en TabBar.
   - Navegación desde el menú Window.
   - Deserialización y carga real de archivos en `_handleOpenFile`.
   - Persistencia de sesión en almacenamiento.
2. Ejecutar `flutter analyze --no-fatal-infos` (0 advertencias).
3. Ejecutar suite de pruebas unitarias.
