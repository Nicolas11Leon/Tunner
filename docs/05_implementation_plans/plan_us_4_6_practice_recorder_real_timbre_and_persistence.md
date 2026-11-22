# Plan de Implementacion: US-4.6 Grabadora sin Tomas Falsas, Analisis FFT/DFT Real, Persistencia MultiTrack y Playhead Espectral

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE4-PRACTICE-RECORDER-2026-01`
- **Titulo de la Implementacion:** Eliminacion de Tomas Falsas, Centroide/THD Real via HarmonicSeriesAnalyzer, Downsampling Proporcional, Persistencia MultiTrack y Playhead en SpectralComparatorModal
- **Fase del Proyecto:** Fase 4 / Hardening Acustico Integral (US-4.6)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0155](docs/04_adrs/0155_practice_recorder_real_timbre_and_persistence.md)
- **Documento Funcional Base:** [Caso de Uso 163](docs/02_use_cases/163_uc_practice_recorder_real_timbre_and_persistence.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Garantizar que la grabadora de practica, el comparador espectral multipista y el reproductor de auto-escucha operen unicamente sobre datos fisicos reales medidos del audio, persistan las sesiones multipista entre reinicios y muestren la posicion de reproduccion real en el comparador espectral.

### 1.2 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `lib/features/practice_recorder/presentation/practice_recorder_controller.dart`: limpieza de semillas falsas, eliminacion de fallback 440 Hz, calculo timbrico real con `HarmonicSeriesAnalyzer.analyze(...)`, downsampling proporcional de picos de forma de onda y restauracion de `multiTrackSession`.
  - `lib/features/practice_recorder/domain/multitrack_session_entity.dart`: endurecimiento resiliente de parsing en `fromMap` y lista mutable al inicializar vacia.
  - `lib/features/persistence/domain/app_user_settings_entity.dart`: serializacion y deserializacion resiliente de `MultiTrackSessionEntity`.
  - `lib/features/tuner/data/pitch_detector_service.dart` y `lib/features/tuner/presentation/tuner_viewmodel.dart`: entrega sincronizada de `latestAudioSamples` a `recordSampleForMultiTrack` y autoguardado de `multiTrackSession`.
  - `lib/features/practice_recorder/presentation/practice_recording_player_modal.dart`: eliminacion de las 40 barras falsas en `_WaveformPainter` cuando `peaks.isEmpty`.
  - `lib/features/practice_recorder/presentation/spectral_comparator_modal.dart`: suscripcion reactiva al progreso de reproduccion y envio de `currentPlaybackPositionNormalized` a `SpectralComparatorPainter`.
  - Pruebas unitarias y de widgets en `test/features/practice_recorder/us_4_6_practice_recorder_real_timbre_test.dart` y actualizacion de pruebas legadas afectadas por la eliminacion de semillas falsas.
- **Excluido (Out-of-Scope):**
  - Modificaciones en el motor nativo C/FFI o en el formato de archivos `.wav` generados por `StudioWorkspaceSeedProvider`.
  - Cambios en importadores OMR o consola DJ fuera de las pruebas de integracion afectadas por la eliminacion de tomas falsas.

---

## 2. Analisis de Dependencias y Tecnologias

- **Versiones de Librerias / SDKs:**
  - Dart SDK: `^3.11.x` (segun `pubspec.yaml` del proyecto).
  - Flutter SDK: `/home/nicomania11/desarrollo/flutter/bin/flutter`.
  - Dependencias: Cero paquetes nuevos; se reutiliza `HarmonicSeriesAnalyzer` (Dart puro existente en `lib/features/acoustic_lab/domain/harmonic_series_analyzer.dart`).
- **Riesgo Tecnologico:**
  - No introduce dependencias nativas ni FFI adicionales.
  - El analisis DFT dirigido de 8 armonicos sobre una ventana de hasta 1024 muestras tiene complejidad O(8 * N) con throttle de 20 ms en `recordSampleForMultiTrack`, sin afectar los 60/120 FPS de la interfaz.

---

## 3. Plan Paso a Paso de Ejecucion (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Entidades y Persistencia Pura)
- [x] Documentar el caso de uso 163, ADR 0155 y el presente plan de implementacion.
- [ ] Actualizar `MultiTrackSessionEntity` / `PracticeTakeEntity` para garantizar tolerancia en `fromMap` y listas mutables al inicializar vacias.
- [ ] Agregar `final MultiTrackSessionEntity? multiTrackSession;` a `AppUserSettingsEntity` con soporte `const defaultSettings`, `copyWith`, `toMap()` y `fromMap()` resiliente ante datos heredados o corruptos.

### Paso 2: Capa de Datos y Senal PCM (Sincronizacion de Ventana)
- [ ] Ajustar `PitchDetectorService` para invocar `onClarityDetected` y `onAudioWindowCaptured` antes de `onPitchDetected`, asegurando que `latestAudioSamples` este actualizado al registrar la muestra multipista.

### Paso 3: Controlador y Capa de Presentacion
- [ ] Refactorizar `PracticeRecorderController`:
  - Vaciar `initDefaultMultiTrackSession` (lista mutable vacia, selecciones A/B en null) y eliminar las tomas falsas en `seedDefaultRecordingsIfEmpty`.
  - Eliminar fallback de `playNoteTone` / 440 Hz en `playActiveRecording` y `playTakeAudio`; remover la dependencia innecesaria de `IAudioSynthesizerService`.
  - Integrar `HarmonicSeriesAnalyzer.analyze` y calculo de RMS real en `recordSampleForMultiTrack`.
  - Implementar `downsampleWaveformPeaks` con max-pooling proporcional y compacto acotado del acumulador bruto para cubrir toda la duracion de la toma.
  - Restaurar `settings.multiTrackSession` en `loadSettingsInto` y autoguardar cambios de sesion multipista.
- [ ] Actualizar `TunerViewModel` para pasar `audioSamples: _latestAudioSamples` en `recordSampleForMultiTrack` y persistir `multiTrackSession` en `_triggerAutoSave`.
- [ ] Actualizar `_WaveformPainter` en `practice_recording_player_modal.dart` para omitir las 40 barras falsas cuando `peaks.isEmpty`.
- [ ] Actualizar `SpectralComparatorModal` con `ListenableBuilder` sobre `widget.viewModel` y calculo de `currentPlaybackPositionNormalized` hacia `SpectralComparatorPainter`.

### Paso 4: Pruebas, Verificacion y Limpieza
- [ ] Crear `test/features/practice_recorder/us_4_6_practice_recorder_real_timbre_test.dart` cubriendo todos los criterios de aceptacion.
- [ ] Verificar y actualizar cualquier prueba existente que asumiera tomas falsas presembradas.
- [ ] Ejecutar `/home/nicomania11/desarrollo/flutter/bin/flutter analyze --no-fatal-infos` (0 issues).
- [ ] Ejecutar pruebas unitarias objetivo y regresion completa.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauracion Git:** Commit base `e946b95` en `origin/qa`.
- **Mitigacion Inmediata:** Reversion atomica de la rama `feature/us-4.6-practice-recorder-real-timbre-and-persistence` antes de merge a `qa`. Dado que `multiTrackSession` es opcional y nullable en `AppUserSettingsEntity`, los archivos JSON persistidos siguen siendo compatibles con versiones anteriores.

---

## 5. Criterios de Aceptacion (Definition of Done)

- [ ] Codigo adherido estrictamente a `AGENTS.md` (cero emojis, Clean Architecture, Dart puro en dominio).
- [ ] Cero tomas falsas en `initDefaultMultiTrackSession` y `seedDefaultRecordingsIfEmpty`.
- [ ] Cero fallbacks de pitido de 440 Hz ante ausencia de archivo valido.
- [ ] `spectralCentroidHz` y `thdPercent` reales calculados por `HarmonicSeriesAnalyzer.analyze`.
- [ ] Downsampling proporcional de `_currentWaveformPeaks` cubriendo toda la duracion de grabacion.
- [ ] Serializacion y restauracion de `MultiTrackSessionEntity` en `AppUserSettingsEntity`.
- [ ] `_WaveformPainter` sin 40 barras sinteticas cuando `peaks.isEmpty`.
- [ ] `SpectralComparatorModal` pasando `currentPlaybackPositionNormalized` real a `SpectralComparatorPainter`.
- [ ] `flutter analyze --no-fatal-infos` con 0 issues y 100% pass en suites de pruebas.
