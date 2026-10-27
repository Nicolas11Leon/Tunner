# Plan de Implementación: Clics Acústicos de Metrónomo y Diapasón Senoidal

- **ID del Plan:** `PLAN-FASE5-AUDIO-SYNTH-2026-01`
- **Título de la Implementación:** Síntesis PCM en Memoria para Metrónomo Audible y Diapasón de Referencia
- **Fase del Proyecto:** Fase 5 (Vanguardia de Audio Digital)
- **Estado:** Aprobado
- **ADR Relacionado:** [0011_acoustic_metronome_clicks_and_tuning_diapason.md](../04_adrs/0011_acoustic_metronome_clicks_and_tuning_diapason.md)
- **Documento Funcional Base:** [doc_acoustic_metronome_clicks_and_tuning_diapason.md](../01_product_vision/doc_acoustic_metronome_clicks_and_tuning_diapason.md)

---

## 1. Alcance y Objetivos

### 1.1 Objetivo Primario
Implementar un sintetizador de audio procedimental PCM en memoria que emita clics acústicos percusivos en cada pulso del metrónomo (con acento en el pulso 1) y un tono senoidal continuo de diapasón ($A_4$) parametrizable por la frecuencia de concierto (415 Hz a 466 Hz).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Modelo matemático `PcmWavSynthesizer` en dominio puro con cálculo de cabecera RIFF/WAVE de 44 bytes y muestras PCM de 16 bits.
  - Interfaz de dominio `IAudioSynthesizerService`.
  - Implementación de infraestructura `AudioSynthesizerService` utilizando `BytesSource` de `audioplayers`.
  - Implementación en memoria `MemoryAudioSynthesizerService` para pruebas.
  - Integración en `TunerViewModel`: vinculación de `onSubTick` con los clics acústicos y control de volumen/mute mediante la mezcladora.
  - Botón interactivo de diapasón en `ConcertPitchSelectorModal` y barra de herramientas.
  - Pruebas unitarias de síntesis PCM, ViewModel y widgets.
- **Excluido (Out-of-Scope):**
  - Motor SoundFont polifónico para reproducción de partituras (reservado para el Hito 5.3).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Dominio Matemático de Síntesis PCM
- [x] Crear `lib/features/audio_synthesizer/domain/pcm_wav_synthesizer.dart` (puro Dart, fórmulas trigonométricas y cabecera WAV).
- [x] Crear `lib/features/audio_synthesizer/domain/i_audio_synthesizer_service.dart`.
- [x] Escribir pruebas unitarias en `test/features/audio_synthesizer/pcm_wav_synthesizer_test.dart`.

### Paso 2: Infraestructura y Servicios de Audio
- [x] Crear `lib/features/audio_synthesizer/data/audio_synthesizer_service.dart`.
- [x] Crear `lib/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart`.

### Paso 3: Integración en ViewModel y UI
- [x] Inyectar `IAudioSynthesizerService` en `TunerViewModel`.
- [x] Emitir clics en `onSubTick` considerando el canal del metrónomo en `MixerConsoleEntity`.
- [x] Exponer métodos `toggleDiapasonTone()`, `isDiapasonPlaying` y `stopDiapasonTone()`.
- [x] Agregar botón de diapasón en `ConcertPitchSelectorModal` y pantalla principal.

### Paso 4: Pruebas y Validación Exhaustiva
- [x] Pruebas de integración del ViewModel (`tuner_viewmodel_synthesizer_test.dart`).
- [x] Pruebas de interfaz de usuario de diapasón y clics (`diapason_ui_test.dart`).
- [x] Ejecutar `flutter analyze` (0 issues) y `flutter test` (100% éxito).
