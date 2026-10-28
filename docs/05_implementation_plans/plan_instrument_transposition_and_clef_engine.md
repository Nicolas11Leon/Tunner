# Plan de Implementación: Motor de Transposición Tonal, Instrumentos Transpositores y Claves

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-TRANS-2026-001`
- **Título de la Implementación:** Motor Universal de Transposición, Instrumentos Transpositores y Clave de Fa
- **Fase del Proyecto:** Fase 11 (Instrumentos Transpositores y Claves)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0027](../04_adrs/0027_instrument_transposition_and_clef_engine.md)
- **Documento Funcional Base:** [doc_instrument_transposition_and_clef_engine.md](../01_product_vision/doc_instrument_transposition_and_clef_engine.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Integrar soporte completo para instrumentos transpositores (Si♭, Mi♭, Fa, La, Sol) con visualización dual de nota escrita y nota real sonando en el afinador, soporte de Clave de Fa en el renderizado de partituras, catálogo extendido de conservatorio y transposición atómica de obras musicales.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido:**
  - Actualización de `InstrumentProfileEntity` con `InstrumentClef` (treble, bass) y catálogo de 21 instrumentos.
  - Exposición de `writtenNoteName` en `TunerViewModel`.
  - Visualización dual (nota escrita vs. sonando) en `TunerScreen` (Modo Esencial y Modo Pro).
  - Actualización de `RealSheetMusicPainter` para renderizar Clave de Fa ("𝄢") y calcular alturas diatónicas relativas a Sol2 cuando aplique.
  - Método `transposeActiveScoreForInstrument` en `TunerViewModel`.
  - Modal de selección de instrumento con filtrado por familia acústica y selector de transposición.
  - Pruebas unitarias completas de transposición, claves y widgets.
- **Excluido:**
  - Claves históricas poco comunes (Do en 1ra o Do en 2da línea), reservadas para música renacentista especializada.

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Entidades de Instrumento y Transposición)
- [x] Actualizar `lib/features/instrument/domain/instrument_profile_entity.dart`:
  - Enum `InstrumentClef { treble, bass }`.
  - Actualizar `InstrumentKey` con `aKey(-3)`, `gKey(-5)`, `highOctaveC(+12)`.
  - Añadir perfiles: Piccolo, Flauta Alto en Sol, Clarinete en La, Corno Inglés, Trombón, Fagot, Tuba, Saxofón Soprano y Saxofón Barítono.
- [x] Actualizar `InstrumentTranspositionService` para asegurar manejo robusto de todas las claves y enarmonías.
- [x] Pruebas unitarias de dominio en `test/features/instrument/instrument_transposition_test.dart`.

### Paso 2: Capa de Renderizado y Presentación Vectorial (Clave de Fa)
- [x] Actualizar `lib/features/sheet_music/presentation/real_sheet_music_painter.dart`:
  - Parámetro `InstrumentClef clef = InstrumentClef.treble`.
  - Renderizado vectorial de Clave de Fa ("𝄢") en posición canónica.
  - Adaptación de `_getNoteStep` para calcular offsets diatónicos respecto a Sol2 en Clave de Fa o Mi4 en Clave de Sol.
- [x] Pruebas de renderizado en `test/features/instrument/instrument_transposition_ui_test.dart`.

### Paso 3: Capa de Orquestación y ViewModel
- [x] Actualizar `lib/features/tuner_viewmodel.dart`:
  - Getter `writtenNoteName` que mapea `_noteName` usando `_transpositionService.getWrittenNote(_noteName, _activeInstrument)`.
  - Getter `hasTransposition` (`_activeInstrument.transpositionSemitones != 0`).
  - Método `transposeActiveScoreForInstrument(InstrumentProfileEntity target)`.
- [x] Actualizar `TunerScreen` para mostrar la nota escrita del instrumento en el hero display con badge de nota de concierto.
- [x] Pruebas de integración en `test/features/instrument/instrument_transposition_ui_test.dart`.

### Paso 4: Verificación y Aprobación
- [x] 100% de pruebas pasando (273/273 tests).
- [x] Cero issues en `flutter analyze`.
- [x] Cero emojis en código, comentarios y commits.
