# Implementation Plan: Phase 4 Practice Audio Recorder & Loopback Auto-Listening Studio

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE4-RECORDER-LOOPBACK-2026-011`
- **Título de la Implementación:** `Grabadora de Práctica Local en Alta Fidelidad y Reproductor de Auto-Escucha con Forma de Onda`
- **Fase del Proyecto:** `Fase 4`
- **Estado:** `Aprobado`
- **ADR Relacionado:** `docs/04_adrs/0008_practice_audio_recorder_and_loopback_playback.md`
- **Documento Funcional Base:** `docs/01_product_vision/doc_practice_audio_recorder_and_loopback.md` y `docs/02_use_cases/12_uc_practice_audio_recorder_and_loopback.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Implementar un subsistema modular de grabación y auto-escucha (*audio loopback*) dentro del monolito **Tunner**. Permitirá al músico grabar tomas de práctica en vivo con un solo toque, visualizar dinámicamente la duración y la forma de onda acústica capturada, y reproducir inmediatamente el audio grabado a diferentes velocidades ($0.75\times$, $1.0\times$, $1.25\times$) para autoevaluación crítica y enlace con el reporte de práctica.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad de dominio pura `PracticeRecordingEntity` con metadatos de toma, duración, picos de amplitud y fecha.
  - Contratos de dominio abstractos `IPracticeRecorderService` y `IAudioPlaybackService`.
  - Implementaciones de infraestructura en `lib/features/practice_recorder/data/` (`PracticeRecorderService` y `AudioPlaybackService`).
  - Orquestación en `TunerViewModel`: métodos `startPracticeRecording()`, `stopPracticeRecording()`, `playActiveRecording()`, `pauseActiveRecording()`, `seekPlayback()`, `setPlaybackRate()`, `discardActiveRecording()`.
  - Componentes de interfaz de usuario en `lib/features/practice_recorder/presentation/`:
    - `PracticeRecorderBar`: Barra compacta con botón de grabación animado (pulso rojo en vivo), contador de duración y botón de reproducción rápida.
    - `PracticeRecordingPlayerModal`: Modal de estudio para auto-escucha crítica con forma de onda interactiva (CustomPainter), controles de transporte (Play/Pause/Replay), fader de velocidad y botón de eliminar/guardar.
    - Integración de auto-escucha en `PracticeReportModal`.
  - Suite exhaustiva de pruebas unitarias y de integración para la entidad, los contratos, el ViewModel y los widgets.
- **Excluido (Out-of-Scope):**
  - Subida a servidores externos de audio o almacenamiento en la nube (el diseño es 100% offline).
  - Edición destructiva multipista tipo DAW (la consola mezcladora ya gestiona stems preconfigurados).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`
  - Flutter SDK: Canal estable
  - `record: ^6.2.1`: Motor de captura y codificación de micrófono validado.
  - `audioplayers: ^6.7.1`: Motor de reproducción de audio local multiplataforma.
  - `path_provider: ^2.1.6`: Localización determinista del directorio de almacenamiento local de la aplicación.
- **Riesgo Tecnológico:**
  - Cero busy-waiting: todos los streams de grabación y reproducción son asíncronos y basados en eventos.
  - Cero impacto en el renderizado a 60/120 FPS del pentagrama y afinador.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Entidades y Contratos Puros)
- [ ] Crear `lib/features/practice_recorder/domain/practice_recording_entity.dart`.
- [ ] Crear `lib/features/practice_recorder/domain/i_practice_recorder_service.dart`.
- [ ] Crear `lib/features/practice_recorder/domain/i_audio_playback_service.dart`.
- [ ] Pruebas unitarias en `test/features/practice_recorder/practice_recording_entity_test.dart`.

### Paso 2: Capa de Infraestructura / Datos (Servicios de Grabación y Reproducción)
- [ ] Crear `lib/features/practice_recorder/data/practice_recorder_service.dart` implementando `IPracticeRecorderService`.
- [ ] Crear `lib/features/practice_recorder/data/audio_playback_service.dart` implementando `IAudioPlaybackService`.
- [ ] Pruebas unitarias con mocks en `test/features/practice_recorder/practice_recorder_service_test.dart`.

### Paso 3: Capa de Orquestación (ViewModel)
- [ ] Inyectar `IPracticeRecorderService` y `IAudioPlaybackService` en `TunerViewModel`.
- [ ] Implementar la gestión de estado de grabación, temporizador de duración, captura de picos y estados de reproducción.
- [ ] Conectar la toma activa con `PracticeReportEntity` al finalizar una práctica evaluada.
- [ ] Pruebas unitarias en `test/features/practice_recorder/tuner_viewmodel_recorder_test.dart`.

### Paso 4: Capa de Presentación (UI y Modales)
- [ ] Crear `lib/features/practice_recorder/presentation/practice_recorder_dock.dart`.
- [ ] Crear `lib/features/practice_recorder/presentation/practice_recording_player_modal.dart` con renderizado de onda (*WaveformPainter*) e interactividad táctil.
- [ ] Integrar el reproductor en `TunerScreen` y en `PracticeReportModal`.
- [ ] Pruebas de widgets en `test/features/practice_recorder/practice_recorder_ui_test.dart`.

### Paso 5: Verificación, Análisis y Cierre
- [ ] Ejecución de `flutter analyze` (0 errores, 0 advertencias).
- [ ] Ejecución de `flutter test` con 100% de pruebas aprobadas.
- [ ] Actualización del informe de auditoría y matriz de fases.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- Si surge alguna incompatibilidad con un canal de audio de plataforma, el servicio se desactiva limpiamente manteniendo el resto del afinador, metrónomo y partitura operativos.
- Hash de referencia git: `5eb2200`.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](AGENTS.md).
- [ ] Cero busy-waiting loops.
- [ ] 100% de pruebas unitarias pasando.
- [ ] Documentación técnica y ADR redactados.
- [ ] Aprobación de la ejecución por el creador.
