# ADR 0156: Enrutamiento Activo en StandardRackNode, Apagado de Subsistemas, Ganancia y PortPermissionBroker

- **Estado:** Aprobado
- **Fecha:** 2026-11-22
- **Issue Relacionado:** `#154`
- **Caso de Uso Base:** `docs/02_use_cases/164_uc_modular_rack_active_signalbus_and_power.md`

## Contexto
Durante la auditoria de la Epica EPIC-05 (US-5.1) se identificaron cuatro carencias estructurales en el subsistema del Rack Modular (`lib/features/modular_rack/`):
1. `StandardRackNode.onReceiveAtomicSignal` unicamente almacenaba `lastReceivedEvent` sin ejecutar ningun efecto sobre `TunerViewModel`, `audioEngine` o `audioInputEngine`.
2. `ModularRackViewModel.toggleModulePower` y `removeModule` modificaban la lista `_activeModules` sin detener los subsistemas activos (metronomo, dron, grabadora, autotune, analizador de acordes, captura de audio).
3. `SignalBus.emit` despachaba eventos sin aplicar `ModuleConnection.gain` sobre senales de audio o amplitud y sin invocar `PortPermissionBroker.canAuthorizeConnection` en el despacho punto a punto y broadcast.
4. `ModularRackViewModel` importaba directamente `StudioAudioInputEngine` desde `core/audio/infrastructure/` en lugar de depender de su contrato de dominio `IStudioAudioInputEngine`.

## Decision
1. **Validacion con `PortPermissionBroker` y Escalado `conn.gain` en `SignalBus`:**
   - Inyectar `PortPermissionBroker` en `SignalBus` (por defecto `const PortPermissionBroker()`) y mantener un registro `_registeredPorts` de los `PortId` declarados.
   - En `addConnection` y `emit` (tanto punto a punto como `ConnectionScope.broadcast`), autorizar cada par `(conn.sourcePort, destPort)` con `PortPermissionBroker.canAuthorizeConnection`.
   - En `emit`, escalar dinamicamente payloads de audio y amplitud (`AudioPcmEvent`, `PitchDetectionEvent` y `List<double>`) por `conn.gain` cuando `gain != 1.0`, respetando los limites fisicos normalizados (`[-1.0, 1.0]` para muestras PCM y `[0.0, 1.0]` para RMS).

2. **Handlers Reales y Enlace Desacoplado en `ModularRackViewModel` y `StandardRackNode`:**
   - Cambiar el campo `audioInputEngine` de `ModularRackViewModel` al puerto de dominio `IStudioAudioInputEngine`, eliminando la dependencia directa hacia `infrastructure/`.
   - Permitir inyeccion opcional y enlace tardio de `TunerViewModel` mediante `bindTunerViewModel(TunerViewModel vm)` (conectado automaticamente en `MainAppShell.didChangeDependencies` y `StudioCompositionRoot.createModularRackViewModel`).
   - Suscribir `audioInputEngine.pcmFrameStream` y cambios relevantes de `TunerViewModel` hacia `SignalBus` bajo una guarda anti-reentrada (`_isDispatchingFromBus`) para evitar bucles de retroalimentacion.
   - Implementar en `StandardRackNode.onReceiveAtomicSignal` el despacho exhaustivo para `TransportControlEvent`, `TuningCalibrationEvent`, `ClockTickEvent`, `PitchDetectionEvent`, `AudioPcmEvent` y `SpectralDataEvent`.

3. **Apagado Real de Subsistemas en `toggleModulePower` y `removeModule`:**
   - Extraer el helper `_shutdownSubsystemForModule(RackModuleEntity module)` que verifica si quedan otras instancias encendidas del mismo `RackModuleType` y, en caso contrario, detiene de forma determinista el subsistema en `TunerViewModel`, los canales especificos en `IStudioAudioEngine` y la captura en `IStudioAudioInputEngine`.

## Consecuencias
- **Positivas:**
  - Interoperabilidad real y verificable extremo a extremo entre captura de audio, `SignalBus`, `StandardRackNode`, `TunerViewModel` y motor de salida.
  - Seguridad acustica garantizada por `PortPermissionBroker` evitando auto-conexiones y fugas en broadcast.
  - Control real de energia sin procesos huerfanos al apagar o eliminar modulos del rack.
  - Cumplimiento estricto de Clean Architecture y reglas `ARCH-1` / `ARCH-5`.
- **Negativas / Trade-offs:**
  - El escalado por conexion en `SignalBus.emit` asigna una lista nueva por destino cuando `conn.gain != 1.0`; el sobrecosto es despreciable frente a la seguridad de inmutabilidad entre ramas con distinta ganancia.
