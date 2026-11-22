# Plan de Implementacion US-5.4: Cableado MediaVault en DjConsoleModal, Timeline Drag/Waveforms y Exportacion Real

- **Issue:** #161
- **Caso de Uso:** `UC-167` (`docs/02_use_cases/167_uc_media_vault_dj_wiring_timeline_drag_and_real_exports.md`)
- **ADR:** `ADR-0159` (`docs/04_adrs/0159_media_vault_timeline_drag_waveforms_and_canonical_exports.md`)
- **Rama:** `feature/us-5.4-media-vault-dj-timeline-drag-and-exports`
- **Base:** `qa`
- **Estado:** Completado (Validado con `flutter analyze --no-fatal-infos` 0 issues y 19/19 tests aprobados)

## 1. Objetivo

Completar la integracion de `MediaVaultViewModel` en `DjConsoleModal` y `MainAppShell`, habilitar colocacion por coordenada X, arrastre horizontal de clips (`moveClip`), renderizado de `waveformPeaks`, pista `track_sampler_sfx`, exportacion real MIDI/MusicXML/ABC/JSON y estimacion real de BPM/Camelot en WAV.

## 2. Archivos a Modificar

1. `lib/features/media_vault/presentation/media_vault_viewmodel.dart`
   - Agregar `void Function(MediaAssetEntity asset, MediaSynergyTarget target)? onDispatchToTool;` mutable o metodo `loadTimeline(TimelineProjectEntity)` cuando se importa `.tunner.json` con `timeline`.
2. `lib/features/dj_console/presentation/dj_console_modal.dart`
   - Instanciar `_mediaVaultViewModel` con `StudioCompositionRoot` (o `UniversalMediaIoService` fallback) y manejar los 5 `MediaSynergyTarget`s en `onDispatchToTool`.
3. `lib/features/navigation/presentation/main_app_shell.dart`
   - Conectar `onDispatchToTool` para los 5 `MediaSynergyTarget`s (`djDeckA`, `djDeckB`, `djSamplerPad`, `scoreEditor`, `mixerChannel`).
4. `lib/features/media_vault/presentation/media_vault_workspace_modal.dart`
   - Calcular `dropMs` desde `details.offset` en `onAcceptWithDetails`.
   - Envolver cada clip en `GestureDetector` horizontal conectado a `vm.moveClip`.
   - Pintar `asset.waveformPeaks` dentro de cada clip y agregar `track_sampler_sfx` al menu contextual.
5. `lib/features/media_vault/data/universal_media_io_service.dart`
   - Exportar notas reales en `_exportSimpleMidi`, `_exportMusicXml` y `_exportAbc` via `CanonicalMidiExporter`, `CanonicalMusicXmlExporter`, `CanonicalAbcExporter`.
   - Serializar/restaurar `timeline` y `rawBytesBase64` en `_exportBundleJson` / `_importTunnerJson`.
   - Estimar `bpm` y `camelotKey` reales al importar WAV mediante `BpmBeatTrackerEngine` y `DjHarmonicCamelotEngine`.
6. Pruebas: `test/features/media_vault/us_5_4_media_vault_dj_timeline_and_exports_test.dart`

## 3. Criterios de Verificacion

- `flutter analyze --no-fatal-infos` -> `No issues found!`
- `flutter test --no-pub test/features/media_vault/ test/core/architecture/arch_1_clean_architecture_boundaries_test.dart` -> 100% aprobado.
