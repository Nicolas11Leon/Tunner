# Plan de Implementación 04: Rendimiento Real-Time, Isolates DSP/PDF/ZLib, Planificador DSL y Cero Fugas

## Metadatos del Plan

- **ID del Plan:** `PLAN-AUDIT-04-REALTIME-ISOLATES-2026`
- **Título de la Implementación:** `Offloading a Isolates de DSP/OMR/PDF/ZLib, Planificador Temporal Real del DSL y Eliminación de Fugas de Recursos`
- **Fase del Proyecto:** `Fase 6 — Hardening de Rendimiento Real-Time v1.0`
- **Estado:** `Propuesto`
- **ADR Relacionado:** `Por crear (ADR-0169: Zero Main-Thread DSP/IO & Temporal DSL Scheduler)`
- **Documento Funcional Base:** [Auditoría Forense Integral](../05_audits/2026-11-23_master_tool_by_tool_forensic_audit.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Garantizar fluidez estricta a 60/120 FPS y latencia de audio sub-10 ms (`AGENTS.md 4.1 y 4.2`), eliminando toda operación DSP, DFT, OMR, PDF, WAV o ZLib síncrona del hilo de UI/audio, implementando el planificador temporal real en `TunnerDslInterpreter`, corrigiendo todas las fugas de memoria/suscripciones activas y cerrando la vulnerabilidad zip-bomb.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Offloading con `Isolate.run` para: `HarmonicSeriesAnalyzer` (sacar de `Widget.build()` en `harmonic_spectrogram_modal.dart` y `polyphonic_live_voicing_widget.dart` con caché de ventana Hann y `sampleRate` real), `AudioToScoreTranscriptionEngine.transcribeAudioFile`, `PdfScoreParser`/`VectorOmrEngine`, `StemAudioSynthesizer.exportStemsAndMidi`, `VocalAutoTuneProcessor.processPracticeTakeAsync` (conectar desde `vocal_pedagogy_controller.dart:190`), `LocalProjectStorageRepository` (ZLib) y `TunnerPackageCodecService` (ZIP + SHA-256).
  - I/O de audio sin bloqueo: sustituir `_randomAccessFile?.writeFromSync` en `studio_master_capture_service.dart:92` por buffer ring + escritura asíncrona/Isolate.
  - Planificador temporal real en `TunnerDslInterpreter` + `StudioOsAudioKernelBridge` (acumulación de beats/ms, ejecución real de `rest`, `note`, `chord` y `loop` sin disparar todo en `t=0`).
  - Corrección de `metronome_service.dart:68` para compases compuestos (`6/8`, `9/8`, `12/8`) + `dispose()` explícito.
  - Corrección de `A4 = 440.0` hardcoded en `stem_audio_synthesizer.dart`, `polyphonic_voice_pool.dart` y `tunner_acoustic_soundfont_bank.dart` + guardas Nyquist en `harmonic_drone_synthesizer.dart`.
  - Calibración real de DC offset sobre buffer PCM en `tuner_viewmodel.dart:467-487` (eliminar `Future.delayed` + `0.0` fijo).
  - Eliminación de `AnimationController..repeat()` permanente en `harmonic_beat_gauge.dart:30-33` (solo animar cuando hay batimiento activo).
  - Cierre de fugas de ciclo de vida: `studio_audio_channel.dart:58-68`, `studio_audio_input_engine.dart:226`, `audio_playback_service.dart:31-32`, `pitch_detector_service.dart:302`, `main_app_shell.dart:201-221`, `tunner_os_kernel.dart:130`, `practice_recorder_controller.dart:124-141` (downsampling O(1) incremental).
  - Protección zip-bomb por chunks con corte temprano en `tunner_binary_project_codec.dart:61-67`.
- **Excluido (Out-of-Scope):**
  - Refactorización visual de pantallas (Plan 01).

---

## 2. Análisis de Dependencias y Tecnologías

- **SDKs:** `dart:isolate` (`Isolate.run`), `dart:async`, `dart:typed_data`. Sin dependencias externas.
- **Riesgo Tecnológico:** Medio en sincronización de Isolates y buffer de captura WAV; requiere pruebas de estrés y validación determinista.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Eliminación de Fugas Activas y Bloqueos en Audio/UI
- [ ] Guardar y cancelar las 3 `StreamSubscription` en `studio_audio_channel.dart:58-68`; hacer `await stopCapture()` seguro en `studio_audio_input_engine.dart`; liberar `_audioEngine` en `audio_playback_service.dart`, `_inputEngine` en `pitch_detector_service.dart`, `nativeDspBridge`/`audioKernel` en `tunner_os_kernel.dart`, y limpiar callbacks en `main_app_shell.dart:dispose()`.
- [ ] Reemplazar `writeFromSync` en `studio_master_capture_service.dart:92` por cola asíncrona fuera del callback de audio en tiempo real.
- [ ] Detener `AnimationController` en `harmonic_beat_gauge.dart` cuando `status == HarmonicLockStatus.pureConsonance`.

### Paso 2: Offloading a `Isolate.run` y Precisión Acústica
- [ ] Mover análisis armónico (`harmonic_spectrogram_modal.dart`, `polyphonic_live_voicing_widget.dart`) fuera de `build()` a un servicio asíncrono con caché de ventana Hann y `sampleRate` real del dispositivo.
- [ ] Conectar `processPracticeTakeAsync` en `vocal_pedagogy_controller.dart:190` y envolver `transcribeAudioFile`, `PdfScoreParser`, `exportStemsAndMidi`, `LocalProjectStorageRepository` y `TunnerPackageCodecService` en `Isolate.run`.
- [ ] Implementar decodificación ZLib con límite de bytes por chunk en `tunner_binary_project_codec.dart:61-67`.
- [ ] Parametrizar `referencePitch` (A4) y `TemperamentEngine` en `stem_audio_synthesizer.dart`, `polyphonic_voice_pool.dart` y `tunner_acoustic_soundfont_bank.dart`; corregir `subTicksPerBeat` en `metronome_service.dart:68` y medir DC offset real de PCM en `calibrateAmbientNoiseFloor()`.

### Paso 3: Planificador Temporal Real en `TunnerDslInterpreter`
- [ ] Implementar reloj de eventos cronológicos en `TunnerDslInterpreter` + `StudioOsAudioKernelBridge` donde `rest` avanza el cursor temporal y `note`/`chord`/`loop` se programan secuencialmente según BPM y figura rítmica.
- [ ] Cargar `assets/dsl/*.tun` reales desde el bundle en `TunnerDslTemplateCatalog` eliminando los strings duplicados.

### Paso 4: Verificación y Benchmarks
- [ ] Pruebas unitarias de planificador DSL (`rest` + secuenciación temporal), protección zip-bomb, compases compuestos (`6/8`, `9/8`, `12/8`) y DC offset real.
- [ ] `flutter analyze --no-fatal-infos` y `flutter test` completo.

---

## 4. Estrategia de Rollback
- **Punto de Restauración Git:** Commit previo a la rama `perf/audit-04-isolates-realtime-dsl`.
- **Mitigación Inmediata:** Reversión por subsistema (Audio/Leaks, Isolates, DSL Scheduler).

---

## 5. Criterios de Aceptación (Definition of Done)
- [ ] Cero invocaciones DSP/OMR/PDF/ZLib pesadas síncronas en `Widget.build()` o hilo UI.
- [ ] Cero fugas de suscripciones/motores en `dispose()`.
- [ ] Secuencias DSL (`acid_bassline.tun`, `ambient_chords.tun`) reproducen notas en tiempo musical real y respetan `rest`.
- [ ] `flutter analyze` y `flutter test` al 100%.
