# ADR-0172: Manejadores Modulares de Terminal y Consola Maestra Tipada por Paneles

## Estado
Aceptado (2026-11-23)

## Contexto
Dos nucleos de infraestructura y presentacion habian crecido hasta superar las 1,100 lineas por archivo y presentaban deuda arquitectonica critica:

1. **`TunnerOsKernel` (`lib/core/terminal/application/tunner_os_kernel.dart`, 1,306 LOC):**
   - Concentraba 21 dominios de comando dentro de un unico bloque `switch`, pese a que el contrato `ITerminalCommandHandler` ya existia para despacho modular en $O(1)$.
   - Emitia datos sinteticos y falsos positivos cuando sus dependencias eran `null`: dispositivos USB inventados en `io list`, telemetria fija en `dsp status`, archivos ficticios en `fs ls`, muestras vocales fabricadas en `vocal eval`/`vocal cert`, y respuestas `[OK]` cuando callbacks de `dj` o `theme set` no estaban conectados.
2. **`StudioMasterHardwareConsoleWidget` (`lib/core/audio/presentation/studio_master_hardware_console_widget.dart`, 1,148 LOC):**
   - Construia cinco paneles complejos dentro de un solo widget.
   - Empleaba `dynamic tokens` y `dynamic matrix` en sus metodos constructores internos, perdiendo seguridad de tipos en tiempo de compilacion.
   - Mezclaba colores `Colors.*` incrustados e iconos crudos `Icon(Icons.*)` en lugar de `StudioDesignTokens` y `StudioIcon`.

## Decision

1. **Descomposicion modular de `TunnerOsKernel` mediante `ITerminalCommandHandler`:**
   - Se extraen los grupos de comandos a cuatro manejadores dedicados bajo `lib/core/terminal/application/handlers/`:
     - `AudioDspCommandHandler` (`io`, `dsp`, `master`, `eq`, `comp`, `route`, `clock`, `reverb`, `spatial`).
     - `FsWorkspaceCommandHandler` (`fs`, `project`, `train`, `vocal`, `dsl`, `eval`).
     - `DjMediaCommandHandler` (`dj`, `synth`, `score`).
     - `NavThemeCommandHandler` (`help`, `tuner`, `theme`, `clear`).
   - El kernel registra los cuatro manejadores integrados en su mapa `Map<String, ITerminalCommandHandler>` antes de registrar cualquier `customHandlers`, preservando el despacho en $O(1)$ y la extensibilidad.
   - Cada manejador lee dependencias mediante getters dinamicos del kernel (para respetar setters mutables como `synthVoicePool` y `projectPort`) y aplica **veracidad estricta**: toda dependencia ausente o captura vacia retorna `TunnerOsCommandResult.error('[ERROR] ...')` y `dsp status` deriva su telemetria exclusivamente de `matrixService`, `outputEngine` y `nativeDspBridge`.

2. **Atomizacion tipada de `StudioMasterHardwareConsoleWidget`:**
   - Se extraen cinco widgets `StatelessWidget` dedicados bajo `lib/core/audio/presentation/panels/`:
     - `HardwareEndpointsPanel` (`hardware_endpoints_panel.dart`)
     - `MasterClockPanel` (`master_clock_panel.dart`)
     - `MasterStripPanel` (`master_strip_panel.dart`)
     - `MasteringChainPanel` (`mastering_chain_panel.dart`)
     - `MatrixRoutingPanel` (`matrix_routing_panel.dart`)
   - Todos los paneles reciben tipos estrictos (`StudioDesignTokens`, `AudioDeviceMatrixEntity`, `StudioAudioDeviceMatrixService`, `StudioMasterClockService`), sin `dynamic`, sin referencias a `Colors.*` y usando exclusivamente `StudioIcon` para iconografia.

## Consecuencias

### Positivas
- **Veracidad diagnostica:** Los usuarios y herramientas de diagnostico obtienen un reflejo exacto del estado real del hardware, archivos y captura vocal, eliminando falsos positivos.
- **Mantenibilidad y testabilidad:** Cada manejador de comandos y cada panel de consola puede probarse y evolucionarse de forma aislada con responsabilidades claras.
- **Seguridad de tipos y coherencia visual:** El compilador verifica cada acceso a `StudioDesignTokens` y `AudioDeviceMatrixEntity`, y todos los temas visuales (incluyendo OLED Monochrome y temas claros/oscuros) se aplican consistentemente sin colores hardcoded.

### Negativas y Mitigaciones
- **Ajuste de pruebas antiguas basadas en fallbacks sinteticos:** Pruebas previas que asumian archivos ficticios en `fs ls` o muestras fabricadas en `vocal eval` requieren inyectar repositorios/muestras reales en su `setUp`. Se actualizan dichas pruebas para validar comportamiento real y se anade una suite dedicada para los casos negativos veraces.

## Cumplimiento con AGENTS.md
- Arquitectura limpia y monolito modular en proceso sin microservicios.
- Cero bucles bloqueantes o sobrecarga en el hilo principal.
- Documentacion de caso de uso (`docs/02_use_cases/180_uc_kernel_truthfulness_and_master_console_atomization.md`) y ADR redactados junto con la implementacion.
