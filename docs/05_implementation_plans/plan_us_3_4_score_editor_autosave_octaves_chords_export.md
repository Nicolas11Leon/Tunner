# Plan de Implementacion: US-3.4 Persistencia Automatica en ScoreEditor, Octavas 0..8, Modo Acordes y Exportacion Real a Disco

Este documento define el plan tecnico paso a paso para implementar la historia de usuario **US-3.4** en **Tunner**, respetando Clean Architecture y las reglas de `AGENTS.md`.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-SCORE-EDITOR-US34-2026-149`
- **Titulo de la Implementacion:** Persistencia Automatica de Ediciones y Mezclador, Octavas 0..8, Puntillos, Acordes Polifonicos y Exportacion Real a Disco
- **Fase del Proyecto:** Fase 3 (Notacion SMuFL, Edicion Interactiva y Persistencia)
- **Estado:** Completado
- **ADR Relacionado:** [docs/04_adrs/0149_score_editor_autosave_octaves_chords_export.md](../04_adrs/0149_score_editor_autosave_octaves_chords_export.md)
- **Documento Funcional Base:** [docs/02_use_cases/157_uc_score_editor_autosave_octaves_chords_export.md](../02_use_cases/157_uc_score_editor_autosave_octaves_chords_export.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Garantizar que ninguna edicion de partitura o ajuste de consola mezcladora se pierda al cerrar la sesion, habilitar la creacion musical completa desde el modal (octavas `0..8`, figuras con puntillo de `12`, `6` y `3` ticks, y modo polifonico de acordes), proteger la transposicion frente a silencios y asegurar la escritura real a disco en los 4 formatos de exportacion.

### 1.2 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `lib/features/score_editor/domain/score_editor_domain.dart` (guard de silencios en `transposeScore`).
  - `lib/features/mixer/domain/mixer_track_entity.dart` (serializacion `toMap`/`fromMap` de `MixerConsoleEntity`).
  - `lib/features/persistence/domain/app_user_settings_entity.dart` (serializacion/deserializacion de `mixerConsole` y `activeScoreId`).
  - `lib/features/score_editor/presentation/score_editor_controller.dart` y `lib/features/tuner/domain/tuner_session_ports.dart` (puente limpio hacia `insertChordNotes`).
  - `lib/features/tuner/presentation/tuner_viewmodel.dart` (`_commitActiveScoreMutation()`, persistencia de `_mixerConsole`, restauracion en `loadPersistedState()`).
  - `lib/features/score_editor/presentation/score_editor_modal.dart` (octavas `0..8`, chips con puntillo `12, 6, 3`, modo polifonico de acordes y `await saveExportedBytes` en los 4 botones de exportacion).
  - `test/features/score_editor/us_3_4_score_editor_autosave_test.dart` (pruebas unitarias y de widgets).
- **Excluido (Out-of-Scope):**
  - Cambios en algoritmos DSP de deteccion de tono o motores DJ.
  - Reescritura del motor de renderizado vectorizado `RealSheetMusicPainter`.

---

## 2. Analisis de Dependencias y Tecnologias

- **Versiones de Librerias / SDKs:**
  - Dart SDK y Flutter SDK estables del entorno Tunner.
  - Sin incorporacion de paquetes externos ni dependencias de red.
- **Riesgo Tecnologico:**
  - Introduce dependencias nativas o FFI: No.
  - Afecta el rendimiento del bucle principal: No; la persistencia se ejecuta de forma asincrona atomica mediante `ILocalPersistenceService` sin busy-waiting.

---

## 3. Plan Paso a Paso de Ejecucion (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Pure Dart)
- [x] Redactar Caso de Uso 157, ADR 0149 y este Plan de Implementacion.
- [x] Agregar guard `if (note.isRest || note.noteName.isEmpty || ...)` en `ScoreEditorOperations.transposeScore`.
- [x] Agregar `toMap()` y `fromMap(...)` en `MixerConsoleEntity` (`lib/features/mixer/domain/mixer_track_entity.dart`).
- [x] Extender `AppUserSettingsEntity` con `mixerConsole` y `activeScoreId` manteniendo constructores `const` e inmutabilidad.
- [x] Exponer `insertScoreChordNotes` en `IScoreEditorSessionPort`.

### Paso 2: Capa de Coordinacion y ViewModel (`ScoreEditorController` y `TunerViewModel`)
- [x] Agregar `insertScoreChordNotes` en `ScoreEditorController` delegando a `ScoreEditorOperations.insertChordNotes`.
- [x] Implementar `_commitActiveScoreMutation()` en `TunerViewModel` sincronizando `_workspaceScores` y llamando a `unawaited(_triggerAutoSave())`.
- [x] Invocar `_commitActiveScoreMutation()` en `insertOrUpdateScoreNote`, `insertScoreChordNotes`, `deleteScoreNote`, `undoScoreEdit`, `redoScoreEdit`, `addScoreMeasure`, `removeScoreMeasure`, `transposeActiveScore` y `transposeActiveScoreForInstrument`.
- [x] Persistir `_mixerConsole` llamando a `unawaited(_triggerAutoSave())` en `setTrackVolume`, `toggleTrackMute` y `toggleTrackSolo`, e incluir `mixerConsole` y `activeScoreId` en `_triggerAutoSave()` y `loadPersistedState()`.

### Paso 3: Capa de Presentacion (`ScoreEditorModal`)
- [x] Habilitar rango de octavas `0..8` en botones `+/-`, eventos de teclado (`ArrowUp`/`ArrowDown`) e `initState`.
- [x] Agregar chips de duracion con puntillo (`12` ticks Blanca con puntillo, `6` ticks Negra con puntillo, `3` ticks Corchea con puntillo).
- [x] Exponer modo de insercion polifonica de acordes con lista de notas seleccionadas y envio via `vm.insertScoreChordNotes(...)`.
- [x] Actualizar los 4 botones de exportacion (`.musicxml`, `.mid`, `.abc`, `.pdf`) para invocar `await vm.platformFileGateway.saveExportedBytes(...)` antes de mostrar el `SnackBar` de confirmacion.

### Paso 4: Pruebas, Verificacion y Limpieza
- [x] Crear `test/features/score_editor/us_3_4_score_editor_autosave_test.dart` cubriendo autosave de todas las mutaciones, persistencia de mixer, guard de silencios en transposicion, octavas 0..8, duraciones con puntillo, modo acordes y exportacion real a disco en los 4 formatos.
- [x] Ejecutar `flutter analyze --no-fatal-infos` (0 issues).
- [x] Ejecutar pruebas nuevas y suites regresivas de `score_editor`, `persistence` y `universal_importer` (100% pass).

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauracion Git:** Commit base de `origin/qa` (`e946b95`).
- **Mitigacion Inmediata:** Reversion de la rama `feature/us-3.4-score-editor-autosave-octaves-chords-export` sin impacto en datos guardados previos, ya que `mixerConsole` y `activeScoreId` son campos opcionales con fallback seguro en `AppUserSettingsEntity.fromMap`.

---

## 5. Criterios de Aceptacion (Definition of Done)

- [x] Codigo adherido estrictamente a Clean Architecture y reglas de `AGENTS.md` (cero emojis).
- [x] `flutter analyze --no-fatal-infos` reporta 0 issues.
- [x] `flutter test` pasa al 100% en las pruebas de US-3.4 y pruebas existentes relacionadas.
- [x] Documentacion tecnica completa (UC 157 con 2 diagramas Mermaid, ADR 0149 y Plan).
- [ ] Pull Request abierto hacia `qa` vinculado al Issue de GitHub sin ejecutar merge.
