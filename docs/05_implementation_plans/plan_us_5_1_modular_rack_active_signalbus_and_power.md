# Plan de Implementacion: US-5.1 SignalBus Activo en StandardRackNode, Apagado Real de Modulos, Gain y PortPermissionBroker

## Metadatos del Plan
- **ID del Plan:** `PLAN-FASE5-MODULAR-RACK-2026-051`
- **Titulo de la Implementacion:** Procesamiento Activo en StandardRackNode, Apagado Real de Modulos, Ganancia y PortPermissionBroker
- **Fase del Proyecto:** Fase 5 / EPIC-05
- **Estado:** Aprobado
- **ADR Relacionado:** [ADR 0156](docs/04_adrs/0156_modular_rack_active_signalbus_and_power.md)
- **Documento Funcional Base:** [Caso de Uso 164](docs/02_use_cases/164_uc_modular_rack_active_signalbus_and_power.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Activar el procesamiento real de eventos atomicos en `StandardRackNode.onReceiveAtomicSignal`, enlazar `audioInputEngine`, `audioEngine` y `TunerViewModel` al `SignalBus`, garantizar el apagado real de subsistemas al apagar o retirar modulos, y aplicar `ModuleConnection.gain` + `PortPermissionBroker.canAuthorizeConnection` en `SignalBus.emit`.

### 1.2 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `lib/features/modular_rack/domain/signal_bus.dart`: integracion de `PortPermissionBroker.canAuthorizeConnection` y escalado por `conn.gain` en `emit`.
  - `lib/features/modular_rack/presentation/modular_rack_viewmodel.dart`: handlers reales en `StandardRackNode.onReceiveAtomicSignal`, suscripcion a `IStudioAudioInputEngine`, enlace bidireccional seguro con `TunerViewModel` e `IStudioAudioEngine`, y apagado real de subsistemas en `toggleModulePower` y `removeModule`.
  - `lib/features/tuner/presentation/tuner_viewmodel.dart`: metodos de ingesta limpia desde el bus (`ingestBusAudioPcm`, `ingestBusPitchFrame`, `ingestBusClockTick`).
  - `lib/app/studio_composition_root.dart` y `lib/features/navigation/presentation/main_app_shell.dart`: enlace opcional de `TunerViewModel` al `ModularRackViewModel`.
  - Pruebas unitarias en `test/features/modular_rack/us_5_1_active_signalbus_and_power_test.dart`.
- **Excluido (Out-of-Scope):**
  - Rediseno visual de `RackUnitCard` o nuevos widgets en el Patchbay UI.

---

## 2. Analisis de Dependencias y Tecnologias
- **SDK:** Dart / Flutter estable configurado en el entorno.
- **Arquitectura:** `lib/features/modular_rack/domain/signal_bus.dart` se mantiene 100% Pure Dart; `ModularRackViewModel` reemplaza la importacion de infraestructura `studio_audio_input_engine.dart` por el puerto de dominio `i_studio_audio_input_engine.dart`.
- **Riesgo de Bucles:** Mitigado mediante guarda booleana `_isDispatchingFromBus` en `ModularRackViewModel` al sincronizar `TunerViewModel` <-> `SignalBus`.

---

## 3. Plan Paso a Paso de Ejecucion

### Paso 1: Capa de Dominio (`SignalBus`)
- [ ] Agregar `PortPermissionBroker` y mapa `_registeredPorts` en `SignalBus`.
- [ ] Validar en `addConnection` y `emit` (punto a punto y broadcast) mediante `canAuthorizeConnection`.
- [ ] Escalar `AudioPcmEvent`, `PitchDetectionEvent` y `List<double>` segun `conn.gain` en `emit`.

### Paso 2: Capa de Presentacion y Composicion
- [ ] Agregar metodos `ingestBusAudioPcm`, `ingestBusPitchFrame` e `ingestBusClockTick` en `TunerViewModel`.
- [ ] Conectar `IStudioAudioInputEngine`, `IStudioAudioEngine` y `TunerViewModel` en `ModularRackViewModel`.
- [ ] Implementar handlers en `StandardRackNode.onReceiveAtomicSignal` para los eventos `TransportControlEvent`, `TuningCalibrationEvent`, `ClockTickEvent`, `PitchDetectionEvent`, `AudioPcmEvent` y `SpectralDataEvent`.
- [ ] Implementar `_shutdownSubsystemForModule` e invocarlo en `toggleModulePower` (al apagar) y `removeModule`.
- [ ] Conectar `bindTunerViewModel` en `MainAppShell` y parametro opcional en `StudioCompositionRoot.createModularRackViewModel`.

### Paso 3: Pruebas y Validacion
- [ ] Crear `test/features/modular_rack/us_5_1_active_signalbus_and_power_test.dart`.
- [ ] Ejecutar `flutter analyze --no-fatal-infos` (0 issues).
- [ ] Ejecutar `flutter test test/features/modular_rack/ test/core/architecture/arch_1_clean_architecture_boundaries_test.dart` (100% pass).

---

## 4. Estrategia de Rollback
- **Punto de Restauracion Git:** Commit base de `origin/qa` (`e946b95`).
- **Mitigacion Inmediata:** Reversion de la rama `feature/us-5.1-modular-rack-active-signalbus-and-power` previo a merge.

---

## 5. Criterios de Aceptacion (Definition of Done)
- [ ] Cero emojis en codigo, comentarios, commits, PR y documentacion.
- [ ] Cumplimiento estricto de `arch_1_clean_architecture_boundaries_test.dart`.
- [ ] `flutter analyze --no-fatal-infos` con 0 issues.
- [ ] 100% de pruebas pasando en `test/features/modular_rack/` y `arch_1`.
