# Plan de Implementacion US-5.3: Reproduccion Acustica Real del Timeline Multi-Track en MediaVault, Mute/Solo en Vivo y Persistencia en Disco

- **Issue:** #159
- **Rama:** `feature/us-5.3-media-vault-real-playback-and-persistence`
- **Base:** `qa`
- **Estado:** Completado (Validado con `flutter analyze --no-fatal-infos` 0 issues y 19/19 tests aprobados)

## 1. Objetivo

Dotar a `MediaVaultViewModel` de reproduccion acustica real del timeline multi-track con respuesta en vivo a Mute/Solo, completar `rawBytes`/`pcmSamples` musicales reales en las semillas de `InMemoryMediaVaultRepository`, y persistir el catalogo de la boveda en disco via `StudioFileSystemRepository`.

## 2. Archivos a Modificar

1. `lib/features/media_vault/domain/media_asset_entity.dart`
   - Agregar `toJson()` y `MediaAssetEntity.fromJson(...)`.
2. `lib/features/media_vault/domain/in_memory_media_vault_repository.dart`
   - Poblar `rawBytes` reales en los 4 activos semilla (WAV 16-bit, MusicXML 3.1, SMF MIDI Type 0) y `pcmSamples` / `waveformPeaks` musicales reales.
3. `lib/features/media_vault/presentation/media_vault_viewmodel.dart`
   - Inyectar `IStudioAudioEngine? audioEngine` e `IAudioSynthesizerService? audioSynthesizer`.
   - Reproducir mixdown WAV real en `togglePlayback()` y relanzar en vivo en `toggleTrackMute()` / `toggleTrackSolo()` y al reiniciar el ciclo del loop.
   - Detener audio en `stopPlayback()` y pausa via `audioEngine?.stopAll()`.
   - Persistir y restaurar `media_vault/catalog_v1.json` mediante `StudioFileSystemRepository`.
4. `lib/app/studio_composition_root.dart`
   - Inyectar `audioEngine` y `AudioSynthesizerService(audioEngine: audioEngine)` en `createMediaVaultViewModel()`.
5. Pruebas: `test/features/media_vault/us_5_3_media_vault_playback_and_persistence_test.dart`

## 3. Criterios de Verificacion

- `flutter analyze --no-fatal-infos` -> `No issues found!`
- `flutter test --no-pub test/features/media_vault/ test/core/architecture/arch_1_clean_architecture_boundaries_test.dart` -> 100% aprobado.
