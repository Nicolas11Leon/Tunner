# Plan de Implementación: Motor Canónico de Audio Core (Studio Audio Engine) y Transporte Unificado

## Metadatos del Plan
- **ID del Plan:** `PLAN-FASE1-CORE-AUDIO-2026-99`
- **Título de la Implementación:** Unificación Integral del Motor de Salida de Audio Core y Transporte Determinista
- **Fase del Proyecto:** Fase 1 / Infraestructura Core
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0089: Motor Canónico de Audio Core (StudioAudioEngine) y Transporte Unificado](docs/04_adrs/0089_core_studio_audio_engine_and_unified_transport.md)
- **Documento Funcional Base:** [Caso de Uso 99: Motor Canónico de Audio Core (Studio Audio Engine) y Transporte Unificado](docs/02_use_cases/99_uc_core_studio_audio_engine_and_unified_transport.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Crear en `lib/core/audio/` el motor oficial de reproducción y transporte de audio de Tunner Studio, erradicando todas las implementaciones dispersas de reproductores y resolviendo de forma definitiva la condición de carrera que impedía pausar la música en la Consola DJ. La refactorización debe ser completa y abarcar todos los subsistemas de audio de la aplicación sin dejar componentes a medias.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación de `lib/core/audio/domain/`:
    - `studio_transport_status.dart` (estados deterministas del transporte).
    - `studio_audio_track_state.dart` (modelo inmutable del canal de audio).
    - `i_studio_audio_channel.dart` (contrato de canal de audio individual).
    - `i_studio_audio_engine.dart` (contrato del motor central).
  - Creación de `lib/core/audio/infrastructure/`:
    - `studio_audio_channel.dart` (implementación de canal con control de estados síncronos).
    - `studio_audio_engine.dart` (pool y gestión de canales nativos).
    - `memory_studio_audio_engine.dart` (implementación simulada para pruebas).
  - Refactorización exhaustiva de los módulos consumidores:
    - Consola DJ (`DjDeckAudioService` e interfaces asociadas).
    - Sintetizador de audio y metrónomo (`AudioSynthesizerService`).
    - Grabador y reproductor de práctica (`AudioPlaybackService`).
  - Pruebas unitarias de regresión y cobertura de transporte.
- **Excluido (Out-of-Scope):**
  - Modificación de la lógica matemática de pitch detection (YIN/McLeod) en el isolate de entrada de micrófono (pertenece a análisis y no a reproducción).

---

## 2. Análisis de Dependencias y Tecnologías
- **Dart SDK:** `^3.11.x`
- **Audioplayers:** `^6.1.0` (utilizado exclusivamente en la capa de infraestructura `core/audio/infrastructure/`).
- **Clean Architecture:** Capa de dominio 100% pura Dart, sin librerías de terceros ni Flutter UI.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio Core de Audio (`lib/core/audio/domain/`)
- [ ] Definir `StudioTransportStatus` (`stopped`, `playing`, `paused`, `seeking`, `error`).
- [ ] Implementar la entidad inmutable `StudioAudioTrackState`.
- [ ] Definir el contrato `IStudioAudioChannel` para control de transporte individual.
- [ ] Definir el contrato `IStudioAudioEngine` para registro y administración de canales.

### Paso 2: Capa de Infraestructura Core (`lib/core/audio/infrastructure/`)
- [ ] Implementar `StudioAudioChannel` con bandera síncrona de pausa y guarda estricta en `setVolume` (nunca resumir si está pausado).
- [ ] Implementar `StudioAudioEngine` gestionando el pool de canales.
- [ ] Implementar `MemoryStudioAudioEngine` para pruebas unitarias.

### Paso 3: Migración Completa de Consumidores (Cero Refactorización a Medias)
- [ ] Refactorizar `DjDeckAudioService` para utilizar `IStudioAudioEngine` en Deck A y Deck B, corrigiendo `pauseDeck` y `playDeck` (resume).
- [ ] Refactorizar `AudioSynthesizerService` para canalizar clicks, diapasones y notas mediante `IStudioAudioEngine`.
- [ ] Refactorizar `AudioPlaybackService` para canalizar tomas de grabación mediante `IStudioAudioEngine`.

### Paso 4: Pruebas Automatizadas y Verificación
- [ ] Crear suite de pruebas de transporte para `StudioAudioEngine` (validando pausa determinista e inmunidad a despausado por volumen).
- [ ] Ejecutar suite de pruebas de Consola DJ.
- [ ] Compilar y verificar el binario ejecutable en Linux.
