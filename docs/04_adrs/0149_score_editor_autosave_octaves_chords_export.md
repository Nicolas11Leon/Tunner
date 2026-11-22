# ADR 0149: Persistencia Automatica de Ediciones en ScoreEditor, Consola Mezcladora, Octavas 0..8, Acordes y Exportacion Real

## Estado
Aprobado

## Contexto
Durante la auditoria de madurez del editor de partituras (`ScoreEditorModal`) y su integracion con la capa de estado (`TunerViewModel`) y persistencia (`AppUserSettingsEntity`), se detectaron cinco brechas funcionales y de consistencia:
1. **Perdida silenciosa de ediciones de partitura:** Los metodos de edicion en `TunerViewModel` (`insertOrUpdateScoreNote`, `deleteScoreNote`, `undoScoreEdit`, `redoScoreEdit`, `addScoreMeasure`, `removeScoreMeasure`, `transposeActiveScore`) mutaban `_activePackage` en memoria sin actualizar `_workspaceScores` ni invocar `_triggerAutoSave()`, provocando que las ediciones se perdieran al reiniciar la aplicacion.
2. **Perdida de estado del mezclador multicanal:** `setTrackVolume`, `toggleTrackMute` y `toggleTrackSolo` modificaban `_mixerConsole` en memoria pero `AppUserSettingsEntity` no serializaba `mixerConsole` ni dichos metodos disparaban `_triggerAutoSave()`.
3. **Guard incompleto en `ScoreEditorOperations.transposeScore`:** Solo verificaba `noteName == "--"` o `"rest"`, pero los silencios canonicos creados con `HierarchicalNote.rest(...)` tienen `isRest = true` y `noteName = ""`.
4. **Restricciones en `ScoreEditorModal`:** El selector de octavas estaba limitado a `2..7` en botones y `1..8` en teclado (excluyendo sub-graves como piano `La0` y notas agudas de octava `8`), faltaban duraciones con puntillo (`12, 6, 3` ticks), no se exponia la insercion polifonica `insertChordNotes` en la interfaz, y los botones de MusicXML y ABC copiaban al portapapeles sin guardar a disco mientras MIDI y PDF mostraban el `SnackBar` antes de completar `saveExportedBytes`.

## Decision
1. **Sincronizacion centralizada `_commitActiveScoreMutation()` en `TunerViewModel`:**
   - Extraer un metodo privado `_commitActiveScoreMutation()` que reemplace `_activePackage` dentro de `_workspaceScores` por su `id` (o lo inserte en el indice `0` si aun no pertenece al espacio de trabajo), actualice la referencia en `_curatedLibrary` si coincide, y ejecute `unawaited(_triggerAutoSave())`.
   - Invocar `_commitActiveScoreMutation()` en todas las mutaciones de partitura (`insertOrUpdateScoreNote`, `insertScoreChordNotes`, `deleteScoreNote`, `undoScoreEdit`, `redoScoreEdit`, `addScoreMeasure`, `removeScoreMeasure`, `transposeActiveScore`, `transposeActiveScoreForInstrument`).
   - En `loadPersistedState()`, restaurar `_activePackage` desde `_workspaceScores` cuando coincida con `settings.activeScoreId` o con el paquete activo, asegurando la continuidad exacta entre sesiones.
2. **Serializacion de `MixerConsoleEntity` y `AppUserSettingsEntity`:**
   - Agregar `toMap()` y `MixerConsoleEntity.fromMap(...)` en `lib/features/mixer/domain/mixer_track_entity.dart`.
   - Incorporar `final MixerConsoleEntity? mixerConsole` y `final String? activeScoreId` en `AppUserSettingsEntity` manteniendo constructores `const` y retrocompatibilidad con JSONs antiguos.
   - Disparar `unawaited(_triggerAutoSave())` en `setTrackVolume`, `toggleTrackMute` y `toggleTrackSolo`, y restaurar `settings.mixerConsole` en `loadPersistedState()`.
3. **Guard explicito para silencios en `ScoreEditorOperations.transposeScore`:**
   - Evaluar `if (note.isRest || note.noteName.isEmpty || note.noteName == "--" || note.noteName.toLowerCase() == "rest") return note;` antes de transponer frecuencias.
4. **Capacidades completas de edicion y exportacion en `ScoreEditorModal`:**
   - Ampliar botones y flechas de teclado al rango de octavas `0..8`.
   - Agregar chips de duracion con puntillo para `12` ticks (Blanca con puntillo), `6` ticks (Negra con puntillo) y `3` ticks (Corchea con puntillo).
   - Exponer un modo de insercion polifonica de acordes conectado via `TunerViewModel.insertScoreChordNotes` y `ScoreEditorController.insertScoreChordNotes` hacia `ScoreEditorOperations.insertChordNotes`.
   - Centralizar la exportacion en disco mediante `await vm.platformFileGateway.saveExportedBytes(...)` en los 4 botones (`.musicxml`, `.mid`, `.abc`, `.pdf`) antes de mostrar el `SnackBar` (verificando `mounted`), manteniendo el copiado al portapapeles como complemento en MusicXML y ABC.

## Consecuencias
- **Positivas:**
  - Persistencia determinista y atómica tanto de partituras editadas como de niveles/mute/solo del mezclador offline.
  - Cobertura de octavas completas `0..8` alineada con el estandar de piano de 88 teclas (`A0` a `C8`) y todos los instrumentos orquestales.
  - Soporte completo de compases compuestos y figuras con puntillo directamente desde el editor grafico.
  - Exportacion real verificable en disco para los 4 formatos universales sin falsos positivos previos al guardado.
- **Negativas / Compensaciones:**
  - El archivo `tunner_settings.json` incrementa ligeramente su tamano al incluir `mixerConsole`; se mitiga manteniendo `mixerConsole` opcional y serializando solo objetos compactos.
  - Los handlers de exportacion en `ScoreEditorModal` pasan a ser asincronos, requiriendo verificacion explicita de `mounted` tras `await` para respetar `use_build_context_synchronously`.
