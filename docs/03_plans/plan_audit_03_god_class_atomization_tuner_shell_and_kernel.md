# Plan de Implementación 03: Atomización Extrema de God Classes (Tuner, Shell, Master Console y Kernel)

## Metadatos del Plan

- **ID del Plan:** `PLAN-AUDIT-03-ATOMIZATION-2026`
- **Título de la Implementación:** `Descomposición Modular de God Classes >1,000 LOC en Controladores y Componentes Atómicos`
- **Fase del Proyecto:** `Fase 6 — Hardening Estructural v1.0`
- **Estado:** `Propuesto`
- **ADR Relacionado:** `Por crear (ADR-0168: Strict File & Method Atomization Ceilings)`
- **Documento Funcional Base:** [Auditoría Forense Integral](../05_audits/2026-11-23_master_tool_by_tool_forensic_audit.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Descomponer las 7 mayores God Classes del núcleo y afinador (`tuner_viewmodel.dart` 3,105 LOC, `main_app_shell.dart` 1,498 LOC, `tuner_screen.dart` 1,380 LOC, `tunner_os_kernel.dart` 1,306 LOC, `studio_master_hardware_console_widget.dart` 1,148 LOC, `studio_desktop_app_shell.dart` 1,058 LOC y `universal_instrument_definition.dart` 1,029 LOC) en unidades cohesivas de `<350 LOC` por archivo y `<60 LOC` por método.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Extracción de sub-controladores de `TunerViewModel`: `PitchCalibrationController`, `DroneAndTemperamentController`, `WorkspacePersistenceCoordinator`, `PedagogySessionCoordinator`, manteniendo a `TunerViewModel` como fachada delgada o eliminando el acoplamiento directo de otros módulos hacia él.
  - Descomposición de `tuner_screen.dart` (extraer `_showLibraryModal`, `_showMixerModal`, `_showInstrumentModal` y sub-paneles a widgets dedicados).
  - Descomposición de `main_app_shell.dart` (extraer `ShellShortcutRegistry`, `ShellFileOpenerCoordinator`, `ShellMediaSynergyRouter`, `MobileShellScaffold`).
  - Descomposición de `studio_desktop_app_shell.dart` (extraer `DesktopTopMenuBar`, `DesktopSidebarPanel`, `DesktopStatusBar` y desacoplar el registro de pestañas `0..5` en un contrato `StudioWorkspaceTabSpec`).
  - Descomposición de `studio_master_hardware_console_widget.dart` (5 sub-widgets tipados: `HardwareEndpointsPanel`, `MasterClockPanel`, `MasterStripPanel`, `MasteringChainPanel`, `MatrixRoutingPanel`).
  - Migración del `switch` gigante de `tunner_os_kernel.dart` a handlers modulares `ITerminalCommandHandler` por dominio (`audio`, `dsp`, `fs`, `dj`, `master`, `nav`, `theme`, `train`, `vocal`).
  - Unificación del catálogo duplicado de instrumentos (`instrument_profile_entity.dart` + `universal_instrument_definition.dart`) separando la entidad del catálogo por familias (`strings_catalog.dart`, `winds_catalog.dart`, `keyboards_catalog.dart`, `percussion_catalog.dart`) con frecuencias derivadas desde MIDI + A4.
- **Excluido (Out-of-Scope):**
  - Atomización específica de `dj_console`, `modular_rack` y `media_vault` (cubierta en Plan 05).

---

## 2. Análisis de Dependencias y Tecnologías

- **SDKs:** Pure Dart / Flutter estable. Sin dependencias nuevas.
- **Riesgo Tecnológico:** Medio (refactorizaciones estructurales extensas; mitigar manteniendo fachadas compatibles paso a paso y ejecutando tests tras cada archivo dividido).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Atomización de `TunnerOsKernel` y `StudioMasterHardwareConsoleWidget`
- [ ] Dividir los 21 comandos del `switch` de `tunner_os_kernel.dart` en implementaciones dedicadas de `ITerminalCommandHandler` (`<150 LOC` c/u), reduciendo `tunner_os_kernel.dart` a `<250 LOC` como despachador puro.
- [ ] Extraer los 5 paneles de `studio_master_hardware_console_widget.dart` con tipos estrictos (`StudioDesignTokens`, `IStudioAudioDeviceMatrixService`, `IStudioMasterClockService`).

### Paso 2: Atomización de `StudioDesktopAppShell` y `MainAppShell`
- [ ] Crear `StudioWorkspaceTabSpec` para eliminar la triplicación del mapeo de pestañas `0..5` entre `main_app_shell.dart`, `studio_desktop_app_shell.dart` y `tunner_os_kernel.dart`.
- [ ] Dividir `studio_desktop_app_shell.dart` en 4 organismos `<250 LOC` y `main_app_shell.dart` en coordinadores dedicados (`<300 LOC` c/u).

### Paso 3: Descomposición de `TunerViewModel`, `TunerScreen` y Catálogo de Instrumentos
- [ ] Extraer `PitchCalibrationController`, `DroneAndTemperamentController`, `PedagogySessionCoordinator` y `WorkspacePersistenceCoordinator` desde `tuner_viewmodel.dart` (meta: reducir `tuner_viewmodel.dart` de 3,105 LOC a `<600 LOC` de orquestación delgada).
- [ ] Dividir `tuner_screen.dart` (1,380 LOC) y `microphone_calibration_modal.dart` (749 LOC) en sub-widgets atómicos.
- [ ] Unificar `instrument_profile_entity.dart` y `universal_instrument_definition.dart` en un solo modelo con sub-catálogos por familia Hornbostel-Sachs y derivación de Hz desde MIDI + A4 de concierto.

### Paso 4: Verificación
- [ ] Verificar que ningún archivo intervenido supere 400 LOC ni tenga métodos >80 LOC.
- [ ] Ejecutar `flutter analyze --no-fatal-infos` y suite completa de pruebas.

---

## 4. Estrategia de Rollback
- **Punto de Restauración Git:** Branch base previa al plan.
- **Mitigación Inmediata:** Extracción incremental con tests verdes por cada archivo atomizado.

---

## 5. Criterios de Aceptación (Definition of Done)
- [ ] Reducción comprobada de las 7 God Classes por debajo de los umbrales objetivo.
- [ ] Cero duplicación del mapa de pestañas `0..5` y del catálogo de instrumentos.
- [ ] `flutter analyze` y `flutter test` al 100%.
