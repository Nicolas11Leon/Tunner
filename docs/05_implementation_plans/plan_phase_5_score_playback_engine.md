# Plan de Implementación: Score Playback Sound Engine

Este documento define el plan estructurado de ingeniería para la implementación e integración del motor acústico de reproducción de partituras en **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE5-SCORE-PLAYBACK-2026-001`
- **Título de la Implementación:** Motor Acústico Procedural de Reproducción de Partituras en Memoria
- **Fase del Proyecto:** Fase 5 (Vanguardia Acústica y Aprendizaje Musical)
- **Estado:** Aprobado
- **ADR Relacionado:** [docs/04_adrs/0013_score_playback_audio_engine.md](../04_adrs/0013_score_playback_audio_engine.md)
- **Documento Funcional Base:** [docs/01_product_vision/doc_score_playback_audio_engine.md](../01_product_vision/doc_score_playback_audio_engine.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Capacitar al motor de partituras para emitir el sonido real de las notas musicales de la pieza activa sincronizadas con el reloj métrico, respetando la afinación de concierto calibrada y la consola de mezcla multicanal.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Adición de `generateMusicalNoteWav` en `PcmWavSynthesizer` (Clean Architecture Domain).
  - Adición de `playNoteTone` en `IAudioSynthesizerService`.
  - Implementación en `AudioSynthesizerService` (Data) y `MemoryAudioSynthesizerService` (Test double).
  - Integración en `TunerViewModel`: propiedad `isScorePlaybackEnabled`, método `toggleScorePlayback()`, disparo sonoro al inicio de nota en `onSubTick`.
  - Control interactivo en la vista de partitura para activar o silenciar el playback melódico.
  - Tests unitarios y de integración.
- **Excluido (Out-of-Scope):**
  - Carga de archivos SoundFont SF2 desde almacenamiento de disco externo (fase futura).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Pure Dart)
- [x] Documentación técnica, Caso de Uso y ADR redactados.
- [ ] Implementar `generateMusicalNoteWav` en `lib/features/audio_synthesizer/domain/pcm_wav_synthesizer.dart`.
- [ ] Actualizar contrato `lib/features/audio_synthesizer/domain/i_audio_synthesizer_service.dart`.
- [ ] Pruebas unitarias de síntesis de notas musicales en `test/features/audio_synthesizer/pcm_wav_synthesizer_test.dart`.

### Paso 2: Capa de Infraestructura / Datos
- [ ] Implementar `playNoteTone` en `lib/features/audio_synthesizer/data/audio_synthesizer_service.dart` utilizando un reproductor dedicado.
- [ ] Implementar `playNoteTone` y registro en `lib/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart`.

### Paso 3: Capa de Presentación / ViewModel
- [ ] Añadir `isScorePlaybackEnabled` y `toggleScorePlayback()` en `lib/features/tuner_viewmodel.dart`.
- [ ] Disparar `playNoteTone` en `_metronomeService.onSubTick` cuando `subTick == note.startTick` y `noteName != "--"`.
- [ ] Escalar ganancia por `_mixerConsole.getEffectiveGain("voice")`.
- [ ] Añadir botón toggle de playback melódico en la vista de partitura / control de estudio.

### Paso 4: Pruebas y Validación
- [ ] Pruebas unitarias del ViewModel verificando inicio de nota, cálculo de duración en base a BPM y silenciamiento por mixer.
- [ ] Pruebas de widget verificando el toggle de reproducción de partitura en la UI.
- [ ] Verificación con `flutter analyze` y `flutter test`.

---

## 3. Criterios de Aceptación (Definition of Done)
1. 100% Clean Architecture respetada.
2. Cada nota de la partitura genera un sonido armónico cálido con envolvente ADSR sin clicks.
3. El mezclador controla fielmente el volumen o silencio de la melodía.
4. Cero fallos en `flutter analyze` y `flutter test`.
