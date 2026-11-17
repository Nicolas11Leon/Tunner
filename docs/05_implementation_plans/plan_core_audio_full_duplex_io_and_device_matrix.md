# Plan de Implementación: Sistema Canónico de Entrada y Salida Full-Duplex en Core Audio con Matriz de Dispositivos

## Metadatos del Plan
- **ID del Plan:** `PLAN-FASE1-CORE-AUDIO-IO-2026-100`
- **Título de la Implementación:** Arquitectura Unificada de Entradas y Salidas de Audio Full-Duplex en Core con Ring Buffer
- **Fase del Proyecto:** Fase 1 / Infraestructura Core
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0090: Arquitectura Unificada de Entradas y Salidas de Audio en Core con Ring Buffer y Gestión de Dispositivos](docs/04_adrs/0090_core_audio_full_duplex_io_and_device_matrix.md)
- **Documento Funcional Base:** [Caso de Uso 100: Sistema Canónico de Entrada y Salida Full-Duplex en Core Audio con Matriz de Dispositivos](docs/02_use_cases/100_uc_core_audio_full_duplex_io_and_device_matrix.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Implementar en `lib/core/audio/` el motor canónico de entrada de audio (`IStudioAudioInputEngine`), completando la infraestructura de audio Full-Duplex de Tunner Studio con gestión dinámica de interfaces de sonido, ring buffer de alto rendimiento y telemetría acústica en tiempo real (RMS dBFS y Peak dBFS).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación de entidades y utilidades en `lib/core/audio/domain/`:
    - `audio_device_entity.dart` (modelado de interfaces de audio).
    - `audio_pcm_frame.dart` (cuadro de audio inmutable y normalizado).
    - `audio_ring_buffer.dart` (buffer circular continuo lock-free).
    - `i_studio_audio_input_engine.dart` (contrato formal del motor de captura).
  - Creación de implementaciones en `lib/core/audio/infrastructure/`:
    - `studio_audio_input_engine.dart` (implementación de captura basada en streaming nativo).
    - `memory_studio_audio_input_engine.dart` (mock de alta fidelidad para pruebas unitarias).
  - Integración con la suite de afinación (`PitchDetectorService` y `TunerViewModel`).
  - Pruebas unitarias de cobertura exhaustiva y compilación de release.
- **Excluido (Out-of-Scope):**
  - Drivers propietarios ASIO directos en Windows (se utiliza el puente nativo estándar de la plataforma).

---

## 2. Análisis de Dependencias y Tecnologías
- **Dart SDK:** `^3.11.x`
- **Flutter SDK:** Canal estable oficial.
- **Record Package:** `record: ^5.1.2` (utilizado exclusivamente en la capa de infraestructura `core/audio/infrastructure/`).
- **Clean Architecture:** Capa de dominio 100% pura en Dart, sin dependencias de plugins externos ni de Flutter UI.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio de Entrada (`lib/core/audio/domain/`)
- [ ] Implementar `AudioDeviceEntity` con atributos de dispositivo, canales y estado.
- [ ] Implementar `AudioPcmFrame` con muestras flotantes, cálculo de dBFS y timestamps.
- [ ] Implementar `AudioRingBuffer` circular lock-free con operaciones de lectura/escritura seguras.
- [ ] Definir el contrato `IStudioAudioInputEngine`.

### Paso 2: Capa de Infraestructura de Entrada (`lib/core/audio/infrastructure/`)
- [ ] Implementar `StudioAudioInputEngine` con enumeración de dispositivos y stream continuo hacia el Ring Buffer.
- [ ] Implementar `MemoryStudioAudioInputEngine` para validaciones unitarias en CI.

### Paso 3: Integración de Consumidores
- [ ] Adaptar `PitchDetectorService` para aceptar y coordinar con `IStudioAudioInputEngine`.
- [ ] Verificar interoperabilidad con `TunerViewModel`.

### Paso 4: Pruebas Automatizadas y Verificación
- [ ] Escribir pruebas unitarias para `AudioRingBuffer`, `AudioPcmFrame` y `StudioAudioInputEngine`.
- [ ] Ejecutar suites de pruebas y compilar el binario nativo en Linux.
