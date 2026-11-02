# Implementation Plan: In-Process SoundFont SF2 Synthesizer and Acoustic Instrument Studio

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-SOUNDFONT-SF2-SYNTH-2026-040`
- **Título de la Implementación:** `Motor de Síntesis SoundFont SF2, Resampling Cúbico Hermite y Presets Instrumentales Acústicos`
- **Fase del Proyecto:** `Fase 3`
- **Estado:** `Completado`
- **ADR Relacionado:** `docs/04_adrs/0036_in_process_soundfont_sf2_synthesizer.md`
- **Documento Funcional Base:** `docs/02_use_cases/40_uc_soundfont_sf2_instrument_synthesis.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Implementar un **motor de síntesis SoundFont (SF2 / SoundFont 2.04) en Pure Dart**, con:
1. Parser de estructuras RIFF/SF2 (bloques `LIST:pdta`, `LIST:sdta`, `LIST:INFO`).
2. Interpolador cúbico de Hermite (4-point spline) para transposición de muestras sin aliasing.
3. Generador de envolvente SoundFont VolEG (Attack, Hold, Decay, Sustain, Release) y filtro biquad opcional.
4. Banco esencial embebido (*Tunner Acoustic Essentials*) con timbres de *Grand Piano*, *Concert Flute*, *Violin*, *Cello* y *Classical Guitar*.
5. Soporte para cargar archivos `.sf2` externos del usuario de forma 100% offline.
6. Integración en `TunerViewModel`, modal de selección instrumental y widgets de reproducción.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Modelos y entidades de dominio en `lib/features/audio_synthesizer/domain/sf2/`.
  - Motor de oscilación y remuestreo wavetable.
  - Generador de buffers WAV en memoria (`Uint8List`).
  - Pruebas unitarias completas de parsing y renderizado de audio.
  - Selector de instrumento en UI con feedback auditivo.
- **Excluido (Out-of-Scope):**
  - Efectos VST3 de terceros o plugins nativos DLL/so.

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.5`.
- **Cero dependencias externas:** Implementación 100% en Dart puro (`dart:typed_data`, `dart:math`).
- **Riesgo Tecnológico:** **Bajo**. Estructuras de datos binarias estándar validadas con tests unitarios.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Parser SF2)
- [x] Crear `lib/features/audio_synthesizer/domain/sf2/sf2_models.dart`:
  - `Sf2SampleHeader`, `Sf2Preset`, `Sf2Instrument`, `Sf2Zone`, `Sf2Generator`.
- [x] Crear `lib/features/audio_synthesizer/domain/sf2/sf2_parser.dart`:
  - Decodificador binario RIFF Little-Endian para chunks SF2.
- [x] Crear `lib/features/audio_synthesizer/domain/sf2/sf2_wavetable_oscillator.dart`:
  - Remuestreador Hermite cúbico y generador VolEG.
- [x] Crear `lib/features/audio_synthesizer/domain/sf2/tunner_acoustic_soundfont_bank.dart`:
  - Banco canónico procedural/embebido con timbres acústicos esenciales (Piano, Flauta, Violín, Cello, Guitarra).

### Paso 2: Capa de Infraestructura / Datos y Servicio de Audio
- [x] Crear `lib/features/audio_synthesizer/data/soundfont_synthesizer_service.dart`:
  - Manejo de presets, carga de archivos `.sf2` y síntesis a WAV reproducible.
- [x] Integrar con `TunerViewModel` para permitir reproducción de notas de afinador y partituras con el timbre seleccionado.

### Paso 3: Capa de Presentación (UI / Widgets)
- [x] Crear modal / bottom sheet `InstrumentSoundFontSelectorModal` para elegir instrumento y probar notas.
- [x] Agregar acceso directo en `TunerScreen` junto a los controles de afinación.

### Paso 4: Pruebas Unitarias y Verificación
- [x] Crear `test/features/audio_synthesizer/sf2_parser_and_synthesis_test.dart`:
  - Pruebas de interpolación Hermite, envolvente VolEG, síntesis de notas y respuesta matemática.
- [x] Ejecutar `flutter test` garantizando 100% de tests pasando (380/380 tests pasando).
- [x] Commit y push a `main`.

---

## 4. Estrategia de Rollback
- Revertir al commit `7041088` en caso de incompatibilidad binaria.

---

## 5. Criterios de Aceptación (Definition of Done)
- [x] Parser SF2 lee correctamente headers, zones y samples.
- [x] Interpolación Hermite genera audio nítido sin chasquidos.
- [x] Timbres acústicos (Piano, Flauta, Violín, Cello, Guitarra) disponibles de inmediato.
- [x] Cobertura de pruebas unitarias superior al 95%.
- [x] 0 regresiones en el árbol completo de Flutter.
