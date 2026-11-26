# ADR 0202: Puentes de Grabadora en 1 Clic e Ingestion de Tomas en Descompositor

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-210](../02_use_cases/210_uc_recorder_one_click_bridges_and_decomposer_take_ingestion.md)

---

## 1. Contexto

Actualmente, tras grabar una toma en `PracticeRecorderDock` (`lib/features/practice_recorder/presentation/practice_recorder_dock.dart`), `PracticeRecordingPlayerModal` (`lib/features/practice_recorder/presentation/practice_recording_player_modal.dart`) ofrece unicamente `convert_take_to_score_button` para transcribir la toma a partitura. Por su parte, `SongDecomposerModal` (`lib/features/song_library/presentation/song_decomposer_modal.dart`) solo ingiere notacion textual manual (`parseMelodyText`) o archivos externos, sin permitir capturar directamente `viewModel.activeRecording` en 1 clic ni despachar la toma fisica hacia `MediaVaultViewModel` o `DjConsoleViewModel`.

---

## 2. Decision

1. **Puentes de Despacho en 1 Clic desde la Grabadora:** Anadir en `PracticeRecordingPlayerModal` (y accesos rapidos cuando hay toma activa en `PracticeRecorderDock`) tres puentes directos sobre `viewModel.activeRecording`:
   - `Key('recorder_send_to_decomposer_btn')`: abre `SongDecomposerModal` pre-cargado con la toma activa para descomposicion de stems y acompanamieto Minus-One.
   - `Key('recorder_send_to_media_vault_btn')`: empaqueta la toma grabada (`PracticeRecordingEntity`) como `MediaAssetEntity` y la registra en `MediaVaultViewModel`.
   - `Key('recorder_send_to_dj_deck_btn')`: envia los samples/WAV de la toma directamente a `DjConsoleViewModel.loadTrackWithBeatTracking(...)`.
2. **Ingestion Directa de Toma Activa en `SongDecomposerModal`:** Incorporar el boton `Key('decomposer_ingest_active_take_btn')` cuando `viewModel.activeRecording != null`, utilizando el contorno analizado de la toma (`OfflinePracticeTakeAnalyzer` / `convertActiveRecordingToScorePackage`) para poblar y descomponer en pistas el `SongPackage` resultante mediante `SongDecomposerService.decomposeCustomScoreAsync(...)`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Cero Friccion desde Microfono hasta Produccion:** Una idea interpretada frente al microfono pasa en 1 clic a arreglo multi-pista (Descompositor), linea de tiempo (Boveda Multimedia) o mezcla en vivo (Consola DJ).
- **Reutilizacion de Motores Existentes:** Aprovecha `OfflinePracticeTakeAnalyzer`, `SongDecomposerService` y `MediaVaultViewModel` sin duplicar logica DSP.

### 3.2 Compromisos y Mitigaciones
- **Tomas Demasiado Cortas o Silenciosas:** Si `activeRecording` carece de audio util (duracion $< 250\text{ ms}$), los botones notifican de manera no bloqueante que la toma es insuficiente para descomposicion o carga en deck.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/practice_recorder/us_hc_08_recorder_bridges_and_decomposer_ingestion_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
