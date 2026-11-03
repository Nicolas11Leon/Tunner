# Implementation Plan: Modern Guitars and Electric Bass SoundFont SF2 Synthesis

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-GUITARS-BASS-SF2-2026-043`
- **Título de la Implementación:** `Expansión del Banco SoundFont SF2: Guitarra Acústica Steel, Guitarra Eléctrica y Bajo Eléctrico`
- **Fase del Proyecto:** `Fase 3 (Laboratorio Armónico & Síntesis)`
- **Estado:** `Completado`
- **ADR Relacionado:** `docs/04_adrs/0038_soundfont_modern_guitars_and_electric_bass.md`
- **Documento Funcional Base:** `docs/02_use_cases/42_uc_soundfont_modern_guitars_and_bass_synthesis.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Incorporar al banco canónico SoundFont SF2 (`TunnerAcousticSoundFontBank`) tres instrumentos fundamentales contemporáneos:
1. **Steel String Guitar (General MIDI #25)**.
2. **Electric Guitar Clean (General MIDI #27)**.
3. **Electric Bass Fingerstyle (General MIDI #33)**.
Integrarlos en el modal de selección instrumental y en la suite de pruebas unitarias.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Adición de generadores matemáticos y envolventes VolEG para los 3 instrumentos en `TunnerAcousticSoundFontBank`.
  - Mapeo de íconos y subtítulos en `InstrumentSoundFontSelectorModal`.
  - Pruebas unitarias de síntesis de audio para los 3 nuevos presets.
- **Excluido (Out-of-Scope):**
  - Efectos de distorsión pesada/metal distortion (fuera del foco acústico de afinación actual).

---

## 2. Análisis de Dependencias y Tecnologías
- **Dart SDK:** `^3.11.5`.
- **Cero dependencias externas adicionales.** Pure Dart sobre `dart:typed_data` y `dart:math`.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Modelos Matemáticos y Banco SoundFont)
- [x] Incorporar generadores de onda y perfiles de envolvente VolEG en `TunnerAcousticSoundFontBank`:
  - Steel String Guitar (#25, $E_3 = 52$).
  - Electric Guitar Clean (#27, $E_3 = 52$).
  - Electric Bass Finger (#33, $E_2 = 40$).

### Paso 2: Capa de Presentación (UI Modal)
- [x] Actualizar `_iconForPatch` en `InstrumentSoundFontSelectorModal` para asignar íconos representativos a los patches 25, 27 y 33.

### Paso 3: Pruebas Unitarias y Verificación
- [x] Extender `test/features/audio_synthesizer/sf2_parser_and_synthesis_test.dart` con aserciones para los nuevos presets y renderizado WAV.
- [x] Ejecutar `flutter analyze` y `flutter test`.

---

## 4. Estrategia de Rollback
- Revertir cambios en `tunner_acoustic_soundfont_bank.dart` si se detectase degradación en tiempos de arranque.

---

## 5. Criterios de Aceptación (Definition of Done)
- [x] Los 3 nuevos instrumentos están presentes en `presets` del banco canónico.
- [x] La síntesis de notas para los parches 25, 27 y 33 produce buffers de audio WAV válidos.
- [x] `flutter analyze` mantiene 0 issues y `flutter test` pasa al 100%.

