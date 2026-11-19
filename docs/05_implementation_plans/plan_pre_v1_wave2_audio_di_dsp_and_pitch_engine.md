# Plan de Implementacion: Ola 2 - Unificacion DI, Audio Core, DSP y Reloj/Metronomo

- **ID del Plan:** `PLAN-PRE-V1-WAVE2-AUDIO-2026-002`
- **Titulo de la Implementacion:** Unificacion DI de Audio, Matematica DSP y Precision Acustica MPM
- **Fase del Proyecto:** Pre-v1.0.0 Feature Hardening (Ola 2)
- **Estado:** Aprobado
- **ADR Relacionado:** [0116_pre_v1_audio_di_dsp_and_pitch_engine_hardening.md](../04_adrs/0116_pre_v1_audio_di_dsp_and_pitch_engine_hardening.md)
- **Documento Funcional Base:** [127_uc_pre_v1_audio_di_dsp_and_pitch_engine_hardening.md](../02_use_cases/127_uc_pre_v1_audio_di_dsp_and_pitch_engine_hardening.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Resolver de raiz los hallazgos de severidad S1/S3 clasificados en la Ola 2 (`F-01, F-02, F-03, F-04, F-05, F-06, F-07, F-08, F-10, F-11, F-12, F-13, F-14, F-15, F-16`), unificando la inyeccion de dependencias del motor de audio en `StudioCompositionRoot`, corrigiendo la matematica de la cadena Master DSP (soft-clipper, reverb pasatodo, panner, filtros biquad), garantizando la precision acustica del motor MPM ($A_0 - C_8$, tasa dinamica 44.1/48 kHz, temperamentos anclados a $A_4$) y asegurando la emision inmediata en $t=0$ del reloj/metronomo.

### 1.2 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `lib/core/di/studio_composition_root.dart`
  - `lib/core/audio/infrastructure/studio_audio_engine.dart`
  - `lib/core/audio/infrastructure/studio_audio_input_engine.dart`
  - `lib/core/audio/infrastructure/studio_master_audio_mixer.dart`
  - `lib/core/audio/infrastructure/effects/schroeder_reverb_engine.dart`
  - `lib/core/audio/infrastructure/spatial/binaural_panner_engine.dart`
  - `lib/core/audio/infrastructure/dsp/studio_master_biquad_filter.dart`
  - `lib/core/audio/infrastructure/studio_master_dsp_chain.dart`
  - `lib/core/audio/infrastructure/studio_audio_device_matrix_service.dart`
  - `lib/features/tuner/domain/mcleod_pitch_method.dart`
  - `lib/features/tuner/data/pitch_detector_service.dart`
  - `lib/features/tuner/domain/temperament_engine.dart`
  - `lib/features/tuner/domain/note_entity.dart`
  - `lib/features/clock/domain/studio_master_clock_service.dart`
  - `lib/features/metronome/data/metronome_service.dart`
  - `lib/features/metronome/presentation/tap_tempo_modal.dart`
  - Pruebas unitarias de audio, DSP, afinacion y reloj.
- **Excluido (Out-of-Scope):**
  - Sintetizadores SoundFont polifonicos y Auto-Tune de voz (reservado para Ola 3).
  - Parsers de partitura MusicXML/MIDI y glifos SMuFL (reservado para Ola 4).

---

## 2. Analisis de Dependencias y Tecnologias

- **Dart SDK:** `^3.11.5`.
- **Flutter SDK:** Canal stable oficial.
- **Sin paquetes externos nuevos:** La arquitectura y formulaciones matematicas se resuelven puramente con Dart estandar y C99/FFI.

---

## 3. Plan Paso a Paso de Ejecucion

### Paso 1: Unificacion de DI en `StudioCompositionRoot` (F-01, F-02, F-16)
1. Inyectar la instancia unica de `IStudioAudioEngine` e `IStudioAudioInputEngine` en todos los ViewModels y servicios.
2. Asegurar que `dispose()` de servicios hijos no detenga los canales de audio compartidos.
3. Sincronizar bidireccionalmente `StudioThemeController` con `TunnerThemePalette`.
4. Anadir soporte de seleccion de dispositivo de entrada por `id` en `StudioAudioInputEngine`.

### Paso 2: Correccion Matematica de la Cadena Master DSP (F-13, F-14, F-15)
1. En `StudioMasterAudioMixer`: implementar soft-clipper cubico $C^1$-continuo sin salto en $\pm0.95$.
2. En `SchroederReverbEngine` y `AllPassFilter`: aplicar ecuacion de diferencias canonica con ganancia unitaria $|H(z)| = 1$ y escala por `sampleRate`.
3. En `BinauralPannerEngine`: garantizar continuidad de fase y retardo interaural en $\pm180^\circ$.
4. En `StudioMasterBiquadFilter`: implementar metodo `updateParameters(...)` in-place.
5. En `StudioMasterDspChain`: asegurar normalizacion conjunta de convolucion y `gain.abs()`.

### Paso 3: Motor MPM y Exactitud Acustica de Afinacion (F-03, F-04, F-05, F-06, F-07, F-08)
1. En `PitchDetectorService` y `McLeodPitchMethod`:
   - Filtrado IIR continuo entre bloques sucesivos sin reinicializacion en ventana solapada.
   - Omitir primer cruce por cero negativo antes de evaluar el maximo del NSDF.
   - Ampliar buffer a 4096 muestras para resolver $A_0 = 27.5\text{ Hz}$.
   - Pasar `sampleRate` real detectado en hardware (44.1 / 48 kHz).
   - Manejo seguro de chunks con conteo de bytes impar.
   - Ajustar timeout de silencio a 200 ms.
2. En `TemperamentEngine`:
   - Anclar calculos fijando $A_4 = 440.0\text{ Hz}$ inmutable en todos los temperamentos historicos (eliminando desfase de -15.64 cents en Just Intonation).
   - Ajustar tablas de Vallotti y Young II con valores canónicos de la literatura musical.
   - Corregir preset typo `'werckmeister_iii'`.
3. En `NoteEntity`: soportar notas enarmonicas con bemoles y nombres internacionales en ingles.

### Paso 4: Reloj Maestro, Metronomo y Tap Tempo (F-10, F-11, F-12)
1. En `StudioMasterClockService`: emitir Pulso 1 inmediatamente en $t=0$.
2. En `MetronomeService`:
   - Escalar el compas segun `meterDenominator`.
   - Conteo de entrada (Count-In) exacto de $N$ pulsos con acento acustico en el pulso 1.
   - Evitar condiciones de carrera al arrancar/detener Isolates.
3. En `TapTempoModal`: respuesta instantanea desde 20 BPM con detector `onTapDown`.

### Paso 5: Verificacion y Pruebas
1. Ejecutar `./scripts/build_native_dsp.sh`.
2. Ejecutar `flutter analyze --no-fatal-infos` (0 advertencias).
3. Ejecutar la suite de pruebas unitarias (`flutter test`).
4. Commit y apertura de Pull Request hacia `qa` con `Closes #79`.

---

## 4. Criterios de Aceptacion (Definition of Done)
- [ ] Cero split-brain en DI: el control de volumen/mute master de hardware afecta a todo el audio.
- [ ] Cadena Master DSP sin discontinuidades ni ganancias divergentes en reverb pasatodo.
- [ ] MPM con buffer de 4096 muestras detectando notas desde $A_0 = 27.5\text{ Hz}$ con `sampleRate` dinamico.
- [ ] $A_4 = 440.0\text{ Hz}$ inmutable en todos los temperamentos historicos.
- [ ] Pulso 1 del metronomo emitiendose en $t=0$.
- [ ] 0 issues en `flutter analyze` y 100% de tests en verde.
