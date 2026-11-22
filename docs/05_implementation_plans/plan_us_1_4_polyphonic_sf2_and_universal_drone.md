# Plan de Implementación: US-1.4 Salida Polifónica, Carga de SF2, Diapasón sin Clics y Dron Universal A0-C8

## Metadatos del Plan
- **ID del Plan:** `PLAN-US-1.4-2026-01`
- **Título de la Implementación:** Salida de Audio Polifónico, Importador SF2, Diapasón Continuo y Rango Acústico Universal A0-C8
- **Fase del Proyecto:** Fase 1 / Hardening Cero Hardcoding
- **Estado:** Aprobado
- **ADR Relacionado:** [ADR 0141](docs/04_adrs/0141_polyphonic_pool_sf2_loader_and_universal_drone.md)
- **Documento Funcional Base:** [Caso de Uso 149](docs/02_use_cases/149_uc_polyphonic_pool_sf2_loader_and_universal_drone.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Conectar `PolyphonicVoicePool` a generación WAV, integrar importación de SoundFonts `.sf2` reales desde disco, lograr continuidad de fase perfecta en el diapasón y extender el rango de dron a $A_0 \dots C_8$.

### 1.2 Límites del Alcance
- **Incluido (In-Scope):**
  - Implementación de `renderWavBlock` en `PolyphonicVoicePool`.
  - Botón y flujo de importación de `.sf2` en `InstrumentSoundFontSelectorModal`.
  - Alineación de cruce por cero y ciclos enteros en `PcmWavSynthesizer.generateSineToneWav`.
  - Ampliación de rango $0 \dots 8$ en `HarmonicDroneConfig` y `HarmonicDroneModal`.
  - Pruebas unitarias completas en `test/features/audio_synthesizer/us_1_4_polyphonic_sf2_and_drone_test.dart`.
- **Excluido (Out-of-Scope):**
  - Motor de DJ de 4 stems (cubierto en EPIC-02).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Síntesis y Dron)
- En `lib/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart`:
  - Agregar `renderWavBlock({required double durationSeconds, int sampleRate = 44100})`.
- En `lib/features/audio_synthesizer/domain/pcm_wav_synthesizer.dart`:
  - Calcular ciclos exactos $M$ y muestras $N$ para garantizar que el tono senoidal cierre en cruce por cero sin rampa abrupta en modo continuo.
- En `lib/features/drone/domain/harmonic_drone_config.dart`:
  - Actualizar aserción a `octave >= 0 && octave <= 8`.

### Paso 2: Capa de Presentación (Modales y UI)
- En `lib/features/audio_synthesizer/presentation/instrument_soundfont_selector_modal.dart`:
  - Agregar botón de importación de `.sf2` mediante `FilePicker`.
- En `lib/features/drone/presentation/harmonic_drone_modal.dart`:
  - Extender la lista de octavas para permitir selección de 0 a 8.

### Paso 3: Pruebas y Validación
- Crear pruebas unitarias para renderizado WAV, diapasón sin clics y octavas 0 a 8.
- Ejecutar `flutter analyze --no-fatal-infos` (0 issues).
- Ejecutar suite de pruebas.
