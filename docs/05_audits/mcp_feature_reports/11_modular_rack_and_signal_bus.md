# Auditoría Forense MCP-Readiness: Rack Modular y Bus de Señales (`modular_rack`)

## Metadatos del Reporte

- **ID del Reporte:** `AUDIT-MCP-2026-011`
- **Módulo Auditado:** `lib/features/modular_rack/` (15 archivos `.dart`: 9 en `domain/`, 6 en `presentation/`)
- **Total de Archivos Inspeccionados:** 15 archivos `.dart`
- **Referencia MCP:** `UC-186` (`docs/02_use_cases/186_uc_tunner_mcp_server_orchestration.md`)
- **Estado de Preparación Headless:** Capa `domain/` 100% Pure Dart y limpia; sin embargo, toda la gestión de topología del rack, instanciación de nodos (`StandardRackNode`), presets y serialización a `.tunner` vive acoplada en `ModularRackViewModel` (`ChangeNotifier` + `TunerViewModel`), bloqueando su uso directo desde CLI Pure Dart.

---

## 1. Inventario Archivo por Archivo

### 1.1 `lib/features/modular_rack/domain/` (9 archivos)

| Archivo `.dart` | Clases / Tipos Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
|---|---|---|---|
| `lib/features/modular_rack/domain/atomic_signal_event.dart` | `AtomicSignalEvent` (sealed/abstract), `ClockTickEvent`, `AudioPcmEvent`, `PitchDetectionEvent`, `TransportCommand` (enum), `TransportControlEvent`, `TuningCalibrationEvent`, `SpectralDataEvent` | Jerarquía tipada inmutable de eventos atómicos del bus (timestamp en microsegundos, puerto origen y payload por tipo de señal) | `UC-049`, `UC-058`, `UC-103`, `UC-164` |
| `lib/features/modular_rack/domain/interoperable_module_node.dart` | `InteroperableModuleNode` (`abstract interface class`) | `nodeId`, `moduleType`, `isProcessingActive`, `declaredInputPorts`, `declaredOutputPorts`, `onReceiveAtomicSignal`, `acceptedSignalTypes` | `UC-049`, `UC-058`, `UC-164` |
| `lib/features/modular_rack/domain/module_connection.dart` | `ConnectionScope` (enum), `ModuleConnection` | `ModuleConnection.pointToPoint`, `ModuleConnection.broadcast`, `signalType`, `copyWith` (`isEnabled`, `gain` `[0.0, 2.0]`, `isMuted`) | `UC-047`, `UC-062`, `UC-082`, `UC-164` |
| `lib/features/modular_rack/domain/port_id.dart` | `PortDirection` (enum), `PortId` | `canConnectTo` (valida dirección opuesta, distinto `ownerModuleId`, mismo `SignalType`) | `UC-047`, `UC-062` |
| `lib/features/modular_rack/domain/port_permission_broker.dart` | `PortPermissionBroker` | `canAuthorizeConnection`, `canAuthorizeLiveMonitoring`, `canAuthorizeAudioEmission`, `getSafetyWarningReason`, `sanitizeConnections` | `UC-062`, `UC-122`, `UC-164` |
| `lib/features/modular_rack/domain/rack_module_entity.dart` | `RackModuleType` (enum, 10 tipos), `ModuleViewMode` (enum), `RackModuleEntity` | `RackModuleEntity.standard` (genera puertos canónicos de entrada/salida por tipo de módulo), `copyWith` | `UC-047`, `UC-049`, `UC-080`, `UC-164` |
| `lib/features/modular_rack/domain/signal_bus.dart` | `SignalBus` | `registerNode`, `unregisterNode`, `registerPort`, `unregisterPort`, `addConnection` (valida con `PortPermissionBroker` y `SynergyPolicyEngine`), `removeConnection`, `emit` (con escalado de ganancia `_applyConnectionGain`), `emitAtomicEvent`, `broadcastGlobalSignal`, `subscribe<T>`, `clearRoutes`, `reset`, `dispose` | `UC-049`, `UC-058`, `UC-080`, `UC-164`, `UC-179` |
| `lib/features/modular_rack/domain/signal_type.dart` | `SignalType` (enum) | 7 tipos de señal: `audioPcm`, `pitchEvents`, `musicalNotes`, `temporalClock`, `transportControl`, `tuningCalibration`, `spectralData` | `UC-049`, `UC-062` |
| `lib/features/modular_rack/domain/synergy_policy_engine.dart` | `SynergyValidationResult`, `SynergyPolicyEngine` | `validateConnection` (valida tipado, bloquea 3 conflictos pedagógicos/acústicos y clasifica las 6 Grandes Hiper-Sinergias) | `UC-058`, `UC-082`, `UC-164` |

### 1.2 `lib/features/modular_rack/presentation/` (6 archivos)

| Archivo `.dart` | Clases / Tipos Principales | Métodos / Funciones Clave | Casos de Uso (`UC-XXX`) |
|---|---|---|---|
| `lib/features/modular_rack/presentation/modular_rack_viewmodel.dart` | `StandardRackNode`, `ModularRackViewModel` (`ChangeNotifier`) | Gestión de `_activeModules`, `addModule`, `removeModule`, `reorderModules`, `toggleModulePower`, `renameModule`, `connectPorts`, `disconnect`, `toggleMasterSession`, `toggleMasterRecording`, `stopMasterSession`, `loadPreset`, `createProjectPackage`, `loadProjectPackage`, `exportToolPreset`, `importToolPreset`, `saveProjectToFile`, `loadProjectFromFile`, `bindTunerViewModel`, `updateCustomization` | `UC-047`, `UC-049`, `UC-080`, `UC-082`, `UC-102`, `UC-164`, `UC-165`, `UC-179` |
| `lib/features/modular_rack/presentation/modular_studio_rack_view.dart` | `ModularStudioRackView`, `_ModularStudioRackBody` | Vista principal reordenable del rack modular | `UC-047`, `UC-184` |
| `lib/features/modular_rack/presentation/multitask_master_console_widget.dart` | `MultitaskMasterConsoleWidget` | Barra superior de transporte maestro, instrumento activo y presets del rack | `UC-047`, `UC-102`, `UC-180` |
| `lib/features/modular_rack/presentation/rack_unit_card.dart` | `RackUnitCard` | Tarjeta visual de cada unidad montada en el rack (encendido/apagado, modo compacto/expandido, controles embebidos) | `UC-047`, `UC-164`, `UC-184` |
| `lib/features/modular_rack/presentation/studio_patchbay_modal.dart` | `StudioPatchbayModal` | Modal visual interactivo de parcheo de cables entre puertos y diagnóstico de sinergias | `UC-049`, `UC-082`, `UC-165` |
| `lib/features/modular_rack/presentation/universal_instrument_search_modal.dart` | `UniversalInstrumentSearchModal` | Selector y buscador de instrumentos para la sesión del rack | `UC-046`, `UC-048`, `UC-171` |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Acoplamientos Bloqueantes para CLI Pure Dart

1. **`ModularRackViewModel` concentra toda la lógica de dominio del rack en `presentation/` (Bloqueo Crítico):**
   - Importa `package:flutter/foundation.dart` (`ChangeNotifier`) y `../../tuner/presentation/tuner_viewmodel.dart` (dependencia transitiva hacia Flutter UI).
   - `StandardRackNode` (implementación canónica de `InteroperableModuleNode`) está definida dentro de `modular_rack_viewmodel.dart` y mantiene una referencia directa a `ModularRackViewModel _parentVm`, impidiendo instanciar nodos del rack en modo headless sin arrastrar Flutter.
   - Todas las operaciones esenciales que la IA necesita invocar (`addModule`, `removeModule`, `toggleModulePower`, `connectPorts`, `disconnect`, `loadPreset`, `createProjectPackage`, `loadProjectPackage`, `exportToolPreset`, `importToolPreset`) residen exclusivamente en `ModularRackViewModel` y no en un controlador/orquestador de dominio puro (`ModularRackOrchestrator`).

### 2.2 Brechas Funcionales y Arquitectónicas para Parcheo por IA

1. **Ausencia de detección de ciclos multi-salto (DAG) en `SignalBus` y `PortPermissionBroker`:**
   - `PortPermissionBroker.canAuthorizeConnection` solo previene auto-conexiones directas (`source.ownerModuleId == destination.ownerModuleId`). No ejecuta validación de grafo acíclico dirigido (BFS/DFS) al agregar una conexión en `SignalBus.addConnection`. Un agente IA que parchee `A -> B -> C -> A` podría provocar recursión o retroalimentación infinita de eventos en el bus.
2. **Falta de mutación de ganancia/silencio por cable en `SignalBus`:**
   - `ModuleConnection` soporta `gain` (`[0.0, 2.0]`) e `isMuted`, y `SignalBus._applyConnectionGain` ya aplica el escalado de ganancia sobre `AudioPcmEvent`, `PitchDetectionEvent` y `List<double>`. Sin embargo, `SignalBus` solo ofrece `addConnection` y `removeConnection`: carece de `updateConnection(String connectionId, {double? gain, bool? isMuted, bool? isEnabled})`.
   - Igualmente, `ModularRackViewModel.connectPorts` no expone los parámetros `gain` ni `isMuted`.
3. **Ausencia de serialización JSON en las entidades de dominio del rack:**
   - `PortId`, `ModuleConnection`, `RackModuleEntity`, `SynergyValidationResult` y `AtomicSignalEvent` no implementan `toMap()` / `fromMap()`. El servidor MCP requiere serializar el grafo completo de módulos, puertos y conexiones para `resources/read`.
4. **Brecha de unificación con Consola DJ y Mezclador (`RackModuleType` vs `StudioPatchbayRoutingService`):**
   - `RackModuleType` declara 10 módulos (`strobeTuner`, `metronome`, `scoreNotation`, `practiceRecorder`, `vocalAutoTune`, `harmonicDrone`, `spectrogram`, `chordAnalyzer`, `guidedLessons`, `earTrainer`), pero **no incluye `djConsole` ni `stemMixer`**.
   - Actualmente la Consola DJ usa un sistema de ruteo paralelo (`StudioPatchbayRoutingService` en `lib/core/channels/`). Para que un agente IA pueda parchear un flujo unificado (ej. `dj_console -> spectrogram` o `practice_recorder -> mixer`), es necesario exponer ambos buses o crear un adaptador unificado de dominio.
5. **Falta de resolución de puertos por ID textual en `SignalBus`:**
   - `SignalBus.addConnection` y `emit` exigen instancias completas de `PortId`. Para invocación MCP (donde la IA envía strings como `source_module_id`, `source_port_id`, `dest_module_id`, `dest_port_id`), se requiere un método de búsqueda determinista `findPort(String moduleId, String portId)`.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON Resumida |
|---|---|---|
| `tunner://rack/topology` | Topología completa del rack modular: módulos montados, estado de encendido, puertos declarados y lista de conexiones activas en `SignalBus`. | `{ "isSessionRunning": false, "activeInstrument": "classical_guitar", "modules": [ { "moduleId": "mod_strobe_tuner_0", "moduleType": "strobe_tuner", "title": "Afinador Estroboscópico Pro", "orderIndex": 0, "isPoweredOn": true, "inputPorts": [...], "outputPorts": [...] } ], "connections": [ { "connectionId": "mod_metronome_1.clock_out->mod_score_notation_2.clock_in", "scope": "pointToPoint", "signalType": "temporal_clock", "gain": 1.0, "isMuted": false, "isEnabled": true } ] }` |
| `tunner://rack/catalog` | Catálogo de los 10 `RackModuleType` disponibles con sus puertos estándar de entrada/salida y los 7 `SignalType` soportados. | `{ "moduleTypes": [ { "code": "strobe_tuner", "displayName": "...", "defaultInputs": ["audio_in:audio_pcm"], "defaultOutputs": ["pitch_out:pitch_events"] } ], "signalTypes": ["audio_pcm", "pitch_events", "musical_notes", "temporal_clock", "transport_control", "tuning_calibration", "spectral_data"] }` |
| `tunner://rack/telemetry` | Telemetría en tiempo real/último estado procesado en el `SignalBus` por nodo (`processedEventsCount`, `lastProcessedBpm`, `lastDetectedPitchHz`, `lastPcmRms`). | `{ "lastProcessedBpm": 120.0, "lastReferenceA4Hz": 440.0, "lastTemperamentName": "equal", "lastDetectedNoteName": "A4", "lastPcmRms": 0.14, "nodes": { "mod_strobe_tuner_0": { "processedEventsCount": 42, "lastPitchHz": 440.0 } } }` |

### 3.2 Tools (`tunner_*`)

| Tool Name | Parámetros (JSON Schema Resumido) | Salida | Mapeo Exacto en Tunner |
|---|---|---|---|
| `tunner_rack_add_module` | `{ "module_type": "strobe_tuner|metronome|score_notation|practice_recorder|vocal_autotune|harmonic_drone|spectrogram|chord_analyzer|guided_lessons|ear_trainer", "custom_id?": "string", "title?": "string" }` | Objeto JSON del `RackModuleEntity` creado con sus `inputPorts` y `outputPorts` | `RackModuleEntity.standard` + `SignalBus.registerNode` (vía futuro `ModularRackOrchestrator.addModule`) |
| `tunner_rack_remove_module` | `{ "module_id": "string" }` | `{ "removedModuleId": "string", "remainingModulesCount": 3, "activeConnectionsCount": 2 }` | `SignalBus.unregisterNode` (vía `ModularRackOrchestrator.removeModule`) |
| `tunner_rack_set_module_power` | `{ "module_id": "string", "is_powered_on": "bool" }` | `{ "moduleId": "string", "isPoweredOn": true }` | `ModularRackOrchestrator.setModulePower` |
| `tunner_rack_validate_patch` | `{ "source_module_id": "string", "source_port_id": "string", "dest_module_id": "string", "dest_port_id": "string" }` | `{ "isApproved": true, "isHyperSynergy": true, "pedagogicalNote": "...", "rejectionReason": null }` | `PortPermissionBroker.canAuthorizeConnection` + `SynergyPolicyEngine.validateConnection` |
| `tunner_rack_patch_ports` | `{ "source_module_id": "string", "source_port_id": "string", "dest_module_id?": "string", "dest_port_id?": "string", "broadcast?": "bool (default false)", "gain?": "number [0,2]", "is_muted?": "bool" }` | `{ "connectionId": "string", "isHyperSynergy": true, "pedagogicalNote": "..." }` | `ModuleConnection.pointToPoint` / `broadcast` + `SignalBus.addConnection` |
| `tunner_rack_update_connection` | `{ "connection_id": "string", "gain?": "number [0,2]", "is_muted?": "bool", "is_enabled?": "bool" }` | Estado actualizado del `ModuleConnection` | Nuevo `SignalBus.updateConnection` |
| `tunner_rack_unpatch` | `{ "connection_id": "string" }` | `{ "removedConnectionId": "string", "activeConnectionsCount": 1 }` | `SignalBus.removeConnection` |
| `tunner_rack_load_preset` | `{ "preset_name": "string" }` | Topología completa del rack tras aplicar el preset y limpiar rutas previas (`SignalBus.reset`) | `ModularRackOrchestrator.loadPreset` |
| `tunner_rack_inject_signal` | `{ "source_module_id": "string", "source_port_id": "string", "signal_type": "temporal_clock|pitch_events|tuning_calibration|transport_control", "payload": "object" }` | `{ "dispatched": true, "affectedNodes": ["mod_score_notation_2"] }` | `SignalBus.emitAtomicEvent` / `SignalBus.broadcastGlobalSignal` |
| `tunner_rack_export_package` | `{ "project_name": "string", "output_path": "string" }` | `{ "outputPath": "string", "modulesCount": 4, "connectionsCount": 3 }` | `ModularRackOrchestrator.createProjectPackage` + `ProjectStorageRepository` |

### 3.3 Prompts Guiados Sugeridos

1. **`rack_build_hyper_synergy`**: Dada una meta pedagógica o de estudio del usuario (ej. "práctica vocal con autotune y grabación" o "afinación justa con dron y espectrograma"), consulta `tunner://rack/catalog`, monta los módulos necesarios (`tunner_rack_add_module`), valida cada enlace (`tunner_rack_validate_patch`) y cablea la Hiper-Sinergia correspondiente (`tunner_rack_patch_ports`) explicando las reglas del `SynergyPolicyEngine`.
2. **`rack_audit_routing_safety`**: Lee `tunner://rack/topology`, verifica cumplimiento de seguridad acústica (`PortPermissionBroker`), detecta módulos huérfanos o apagados y sugiere correcciones de ruteo o ganancia por conexión.

---

## 4. Plan de Ajustes Técnicos Previos

1. **Extraer `ModularRackOrchestrator` y `StandardRackNode` a `lib/features/modular_rack/domain/`:**
   - Crear `lib/features/modular_rack/domain/modular_rack_orchestrator.dart` (100% Pure Dart, sin `ChangeNotifier` ni `TunerViewModel`) que posea `SignalBus`, `_activeModules`, `_activeInstrument`, `_activeCustomization`, gestión de presets, ruteo y serialización a `TunnerProjectPackage` / `TunnerToolPreset`.
   - Mover `StandardRackNode` a `domain/` desacoplándola de `ModularRackViewModel` mediante un callback `void Function(StandardRackNode, AtomicSignalEvent)`.
   - Hacer que `ModularRackViewModel` en `presentation/` sea un wrapper delgado (`ChangeNotifier`) sobre `ModularRackOrchestrator` + puente opcional a `TunerViewModel`.
2. **Fortalecer `SignalBus` y `PortPermissionBroker`:**
   - Agregar validación de ciclos multi-salto (detección de ciclos en grafo dirigido) en `SignalBus.addConnection` para impedir bucles de retroalimentación `A -> B -> ... -> A`.
   - Agregar `SignalBus.updateConnection(String connectionId, {double? gain, bool? isMuted, bool? isEnabled})` y `SignalBus.findPort(String ownerModuleId, String portId)`.
3. **Añadir serialización JSON canónica en `domain/`:**
   - Implementar `toMap()` / `fromMap()` en `PortId`, `ModuleConnection`, `RackModuleEntity`, `SynergyValidationResult` y `toMap()` en las subclases de `AtomicSignalEvent`.
4. **Evaluar puente con `StudioPatchbayRoutingService` (Fase 2 de integración):**
   - Definir si `djConsole` y `stemMixer` se registrarán como nuevos `RackModuleType` o mediante un adaptador `PatchbayToSignalBusBridge` Pure Dart para que la IA pueda orquestar señales entre la Consola DJ y el Rack Modular desde una misma superficie MCP.
