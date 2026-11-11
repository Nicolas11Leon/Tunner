# Plan de Implementacion: Puertos de Hardware, Permisos y Arbitraje de Senales

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-HARDWARE-IO-2026-060`
- **Título de la Implementación:** Implementación del Árbitro de Permisos de Puertos (PortPermissionBroker) y Gestión de Transductores de Audio/MIDI
- **Fase del Proyecto:** Fase 2 (Infraestructura de Audio y Hardware)
- **Estado:** Aprobado
- **ADR Relacionado:** [ADR 0056: Arquitectura de Puertos de Hardware, Permisos y Arbitraje de Señales](../04_adrs/0056_hardware_io_ports_and_permission_broker.md)
- **Documento Funcional Base:** [DOC-ARCH-2026-062](../01_product_vision/doc_device_ports_permissions_and_hardware_io_broker.md) y [UC-62](../02_use_cases/62_uc_hardware_io_ports_and_permission_broker.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Crear la infraestructura de dominio y orquestación para gobernar con seguridad y rigor acústico las conexiones entre puertos de hardware físicos (micrófonos, altavoces, auriculares, interfaces USB, MIDI) y los puertos lógicos modulares del `SignalBus`, previniendo bucles de retroalimentación acústica y garantizando captura de audio en modo crudo.

### 1.2 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación de `HardwareAudioEndpoint` en `lib/features/tuner/domain/hardware_audio_endpoint.dart`.
  - Creación de `PortPermissionBroker` en `lib/features/modular_rack/domain/port_permission_broker.dart`.
  - Integración en `TunerViewModel`: estado de transductores, métodos de autorización de monitoreo y protección anti-feedback.
  - Pruebas unitarias de dominio (`test/features/modular_rack/port_permission_broker_test.dart`).
- **Excluido (Out-of-Scope):**
  - Implementación de drivers nativos USB en C++ (se utiliza la capa de abstracción de audio existente).

---

## 2. Analisis de Dependencias y Tecnologias

- **Dart SDK:** `^3.11.5` puro en la capa de dominio.
- **Flutter SDK:** Canal estable oficial.
- **Riesgo Tecnológico:** Cero. Entidad matemática pura que no añade dependencias externas ni altera los hilos principales.

---

## 3. Plan Paso a Paso de Ejecucion (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos de Transductores y Broker de Permisos)
- [ ] Crear `HardwareAudioEndpoint` y enum `AudioEndpointType` (Dart puro).
- [ ] Crear `PortPermissionBroker` con lógica de autorización:
  - `canAuthorizeConnection(PortId source, PortId destination)`
  - `canAuthorizeLiveMonitoring({required bool isHeadphonesConnected})`
  - `canAuthorizeAudioEmission({required bool isCalibrationActive})`
  - `filterAllowedConnections(List<ModuleConnection> connections, {required bool isHeadphonesConnected})`

### Paso 2: Orquestacion en TunnerViewModel
- [ ] Incorporar `final PortPermissionBroker _permissionBroker` en `TunerViewModel`.
- [ ] Exponer getter `bool get canActivateLiveMonitoring`.
- [ ] Agregar métodos reactivos: `setHeadphonesConnected(bool connected)` y validación en `toggleLiveMonitoring()`.

### Paso 3: Pruebas Automatizadas y Verificacion
- [ ] Escribir `test/features/modular_rack/port_permission_broker_test.dart` cubriendo todos los casos de autorización, bloqueo anti-feedback y modo exclusivo de calibración.
- [ ] Ejecutar `flutter analyze` (garantizar 0 issues).
- [ ] Ejecutar `flutter test` (garantizar 100% passing).

---

## 4. Criterios de Aceptacion y Definition of Done (DoD)

1. Cero imports de Flutter o plugins en las entidades de dominio creadas.
2. Cero emojis en código y comentarios.
3. 100% de pruebas aprobadas sin regresiones en la suite completa.
4. Documentación referenciada en `README.md` y `CONTRIBUTING.md`.
