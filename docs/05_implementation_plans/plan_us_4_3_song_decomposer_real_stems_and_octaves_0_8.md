# Plan de Implementacion: US-4.3 Descomposicion Algoritmica Real por Stems y Rango Completo 0..8 / BPM 20..300

## Metadatos
- **ID:** PLAN-US-4.3
- **Historia de Usuario Asociada:** US-4.3 (#149)
- **Estado:** Approved
- **Fecha:** 2026-11-22
- **Autor:** Nicolas Leon (SM/PO/Devs)
- **Rama:** `feature/us-4.3-song-decomposer-real-stems-and-octaves-0-8`

---

## 1. Archivos Afectados
- `lib/features/song_library/domain/song_package_entity.dart`
- `lib/features/song_library/domain/song_decomposer_service.dart`
- `lib/features/song_library/presentation/song_decomposer_modal.dart`
- `lib/features/song_library/presentation/studio_assets_modals.dart`
- `test/features/song_library/us_4_3_song_decomposer_real_stems_test.dart`

## 2. Pasos de Implementacion
1. Agregar `final Map<String, HierarchicalScore> stemScores` (default `const {}`) a `SongPackage` junto con `copyWith`.
2. Actualizar `SongDecomposerService.parseMelodyText` para devolver un compas de silencio ante entrada vacia.
3. Implementar generacion real de `harmony_stem`, `bass_stem` y `rhythm_stem` en `SongDecomposerService.decomposeCustomScore` y poblar `stemScores`.
4. Ampliar `_buildQuickNoteKeypad` en `SongDecomposerModal` a octavas `0..8` con desplazamiento horizontal.
5. Reemplazar el dropdown de 4 valores en `_StudioNewScoreDialog` por selector continuo/numerico en `[20..300]` BPM.
6. Crear suite `us_4_3_song_decomposer_real_stems_test.dart` y validar `flutter analyze --no-fatal-infos` y `flutter test test/features/song_library/`.

## 3. Estrategia de Rollback
Revertir la rama `feature/us-4.3-song-decomposer-real-stems-and-octaves-0-8` sin fusionar en `qa`.
