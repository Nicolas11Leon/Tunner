# Plan de Implementación: Ola 3 - Síntesis, Auto-Tune Vocal TD-PSOLA, Grabación de Estudio y Consola DJ Pro

## 1. Identificador y Metadatos
- **ID:** `PLAN-PRE-V1-WAVE3-2026-003`
- **Rama Git:** `fix/pre-v1-wave3-synthesis-autotune-recorder-and-dj-console`
- **Issue Asociado:** Issue #80 en GitHub
- **Objetivo:** Activar y consolidar el procesamiento de audio real en los subsistemas de Síntesis, Auto-Tune Vocal, Grabación y DJ.

---

## 2. Componentes y Tareas Específicas

### 2.1 Síntesis Polifónica y SoundFont SF2 (F-17, F-18, F-19)
- **Archivos:**
  - `lib/features/audio_synthesizer/domain/polyphonic_voice_pool.dart`
  - `lib/features/audio_synthesizer/data/soundfont_synthesizer_service.dart`
  - `lib/features/audio_synthesizer/domain/stem_audio_synthesizer.dart`
- **Tareas:**
  1. Conectar `renderBlock()` en `PolyphonicVoicePool` para sintetizar bloques estéreo continuos calculando ganancias de mezcla y envolventes ADSR.
  2. Implementar correcta lectura de parámetros de zona global y tiempo de Release en `Sf2SoundFontParser`.
  3. Integrar la generación de stems polifónicos en `StemAudioSynthesizer` exportando audio audible real.

### 2.2 Auto-Tune Vocal y TD-PSOLA en Tiempo Real (F-20, F-21, F-22)
- **Archivos:**
  - `lib/features/vocal_autotune/domain/vocal_autotune_processor.dart`
  - `lib/features/vocal_autotune/domain/td_psola_pitch_shifter.dart` (o correspondiente)
  - `lib/features/practice_recorder/domain/multi_track_session_entity.dart`
- **Tareas:**
  1. Implementar TD-PSOLA con periodos fraccionarios exactos y ventanas Hann con 50% OLA.
  2. Cuantización a escalas musicales (Mayor, Menor, Pentatónica, Cromática) preservando transiciones suaves según velocidad de retune (0 a 100 ms).
  3. Resincronizar marcas de tiempo en tomas multi-pista y exportación de tomas vocalmente corregidas.

### 2.3 Consola DJ y Procesador DSP en Vivo (F-25, F-26, F-27, F-28)
- **Archivos:**
  - `lib/features/dj_console/presentation/dj_console_view_model.dart`
  - `lib/features/dj_console/data/dj_audio_processor.dart`
  - `lib/features/dj_console/data/dj_mix_wav_encoder.dart`
- **Tareas:**
  1. Grabar mezcla real a archivo WAV en disco mediante `DjMixWavEncoder` con cabecera estándar RIFF de 44 bytes.
  2. Procesar filtros EQ de 3 bandas (Low, Mid, High), atenuación de stems y efectos en vivo en `DjAudioProcessor`.
  3. Sincronización continua de BPM y Beat-Matching entre Deck A y Deck B sin desfase rítmico.

### 2.4 Matriz Patchbay y Bus Modular (F-29, F-30)
- **Archivos:**
  - `lib/core/channels/data/studio_patchbay_routing_service.dart`
  - `lib/features/modular_rack/domain/signal_bus.dart`
- **Tareas:**
  1. Garantizar deduplicación atómica de eventos en `SignalBus`.
  2. Incorporar atenuación de ganancia y muteo de señal en las conexiones del patchbay.

---

## 3. Plan de Verificación y Criterios de Aceptación
1. `flutter analyze --no-fatal-infos` (0 advertencias).
2. Suites de pruebas unitarias y de integración para cada componente de audio y DSP pasando al 100%.
3. Creación de Pull Request hacia `qa` con squash merge y cierre de Issue #80.
