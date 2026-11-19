# Plan de Implementación: Ola 4 - Notación SMuFL, Parsers/Exporters, Navegación, Terminal DSL y Pedagogía

## 1. Identificador y Metadatos
- **ID:** `PLAN-PRE-V1-WAVE4-2026-004`
- **Rama Git:** `fix/pre-v1-wave4-smufl-parsers-navigation-dsl-and-pedagogy`
- **Issue Asociado:** Issue #81 en GitHub
- **Objetivo:** Asegurar la precisión en exportadores e importadores de partituras, motor SMuFL, foco en atajos de teclado, terminal DSL y diagnósticos pedagógicos.

---

## 2. Componentes y Tareas Específicas

### 2.1 Parsers y Exporters de Partitura (F-35, F-36)
- **Archivos:**
  - `lib/features/universal_importer/domain/pdf_score_vector_renderer.dart`
  - `lib/features/universal_importer/domain/musicxml_parser.dart`
  - `lib/features/universal_importer/domain/canonical_midi_exporter.dart`
  - `lib/features/universal_importer/domain/midi_file_parser.dart`
  - `lib/features/universal_importer/domain/abc_score_parser.dart`
- **Tareas:**
  1. Verificar que `PdfScoreVectorRenderer` dibuje cabezas de notas huecas para blancas/redondas y accidentales correctos (bemoles/sostenidos).
  2. Blindar `MidiFileParser` y `AbcScoreParser` contra divisiones por cero o bucles infinitos en compases vacíos o tempos de 0 BPM.

### 2.2 Motor SMuFL y Coordinación de Reproducción (F-37, F-38)
- **Archivos:**
  - `lib/features/sheet_music/domain/score_playback_coordinator.dart`
  - `lib/features/sheet_music/presentation/smufl_glyph_path_engine.dart`
  - `lib/features/sheet_music/presentation/score_editor_modal.dart`
- **Tareas:**
  1. En `ScorePlaybackCoordinator`, asegurar el parsing de notas en bemol (p. ej. `Sib3`, `Mib4`) y emisión sincronizada de `noteOff`.
  2. En `SmuflGlyphPathEngine`, verificar trazado de cabezas de notas huecas (`noteheadHalf`, `noteheadWhole`) y negras (`noteheadBlack`).

### 2.3 Navegación, Terminal DSL y Pedagogía (F-09, F-39, F-40, F-41, F-42)
- **Archivos:**
  - `lib/features/studio_workstation/presentation/studio_keyboard_navigation_overlay.dart` (o correspondiente)
  - `lib/core/dsl/domain/tunner_dsl_interpreter.dart`
  - `lib/features/pedagogy/domain/adaptive_scaffolding_engine.dart`
- **Tareas:**
  1. Blindar atajos de teclado para que no se disparen cuando el foco esté dentro de un campo de texto editable.
  2. Verificar despacho secuencial de comandos en el intérprete DSL.
  3. Asegurar que `AdaptiveScaffoldingEngine` no genere tolerancias negativas o divisiones anómalas.

---

## 3. Verificación
1. `flutter analyze --no-fatal-infos` (0 advertencias).
2. Pruebas unitarias de parsers, SMuFL, navegación y pedagogía pasando al 100%.
3. Creación de Pull Request hacia `qa` con squash merge y cierre de Issue #81.
