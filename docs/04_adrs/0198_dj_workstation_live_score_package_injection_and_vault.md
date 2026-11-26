# ADR 0198: Inyeccion en Vivo de SongPackage en Consola DJ y Retorno a Boveda Multimedia

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-206](../02_use_cases/206_uc_dj_workstation_live_score_package_injection_and_vault.md)

---

## 1. Contexto

`DjTrackLoaderModal` (`lib/features/dj_console/presentation/dj_track_loader_modal.dart`) permite cargar unicamente presets sinteticos (`studioLibrary`), obras estaticas de `SongDecomposerService.getCuratedLibrary()` y archivos locales por ruta. En consecuencia, las partituras creadas, editadas o transcritas por el usuario en `TunerViewModel.workspaceScores` y los activos de audio almacenados en `MediaVaultViewModel` no son accesibles directamente desde los decks A y B de la consola DJ. De forma analoga, las sesiones grabadas por `DjLiveMixRecorderEntity` en `DjConsoleViewModel` (`_lastRecordedWavBytes`) carecen de un puente de 1 clic para depositar la mezcla WAV en `MediaVaultViewModel`.

---

## 2. Decision

1. **Inyeccion Directa de `SongPackage` en `DjConsoleViewModel` (`lib/features/dj_console/presentation/dj_console_view_model.dart`):** Implementar `injectSongPackageToDeck(String deckId, SongPackage package)`, que sintetiza los stems polifonicos mediante `DjAudioProcessor.synthesizeSongPackageTrack(...)`, calcula BPM y codigo Camelot y carga el deck destino sincronizando `_deckAudioPlayer` y el analisis espectral RGB.
2. **Pestanas Vivas en `DjTrackLoaderModal`:** Incorporar las pestanas `Partituras del Proyecto` (`Key('dj_loader_workspace_scores_tab')`) conectada a `TunerViewModel.workspaceScores` (mas `activePackage`) y `Boveda Multimedia` (`Key('dj_loader_media_vault_tab')`) conectada a `MediaVaultViewModel`.
3. **Exportacion Directa de Mezcla DJ hacia Boveda:** Anadir en `DjStudioWorkstationView` (`lib/features/dj_console/presentation/dj_studio_workstation_view.dart`) el disparador `Key('dj_export_mix_to_vault_btn')` para convertir la ultima mezcla WAV grabada en un `MediaAssetEntity` y registrarlo en `MediaVaultViewModel`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Ciclo Cerrado Composicion -> DJ -> Boveda:** Una melodia compuesta en el editor de partituras o extraida por OMR/descomposicion puede mezclarse al instante en Deck A/B y regresar como master WAV a la Boveda Multimedia.
- **Operacion 100% Offline:** Toda sintesis de stems y codificacion WAV permanece dentro del mismo binario local.

### 3.2 Compromisos y Mitigaciones
- **Consola DJ Montada de Forma Independiente:** Si `TunerViewModel` o `MediaVaultViewModel` no estan presentes en el arbol de `Provider`, `DjTrackLoaderModal` muestra un estado informativo limpio en las pestanas nuevas sin lanzar `ProviderNotFoundException`.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/dj_console/us_hc_04_dj_live_score_injection_and_vault_export_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
