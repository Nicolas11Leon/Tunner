# Plan de Implementación: US-2.2

## 1. Alcance y Objetivos
Implementar la funcionalidad completa de ganancia TRIM, sincronización tonal Key Sync / Key Lock, monitoreo Split-Cue estéreo y sincronización exhaustiva de transporte en `IDjDeckAudioPlayer`.

---

## 2. Archivos Afectados
1. `lib/features/dj_console/domain/dj_deck_entity.dart`
   - Incorporar `trim` (default 1.0, rango 0.0 a 2.0).
   - Agregar getter computado `trimDb` ($20 \log_{10}(\text{trim})$).
   - Agregar getter `effectivePlaybackRate`.
2. `lib/features/dj_console/domain/dj_performance_orchestrator.dart`
   - Incorporar método `setTrim(String deckId, double trim)`.
   - Incluir `_deckA.trim` y `_deckB.trim` en `getEffectiveGains()`, `deckAGain` y `deckBGain`.
3. `lib/features/dj_console/presentation/dj_console_view_model.dart`
   - Incorporar `setTrim(String deckId, double trim)`.
   - Incorporar `_syncDeckPlaybackRate(String deckId)`.
   - Sincronizar transporte de audio en `syncKey`, `toggleKeyLock`, `adjustPitch`, `resetPitch`, y en `executeAction` (pitch bend, loop, key sync).
   - Implementar `generateSplitCueChunk`.
4. `lib/features/dj_console/presentation/dj_vertical_channel_strip.dart`
   - Conectar la perilla `TRIM` con `deck.trim`, `viewModel.setTrim` y el formateador en decibelios `deck.trimDb`.
5. `test/features/dj_console/us_2_2_dj_trim_key_sync_split_cue_test.dart`
   - Pruebas unitarias completas.

---

## 3. Plan de Pruebas y Validación
- `flutter analyze --no-fatal-infos`: Cero warnings ni errores.
- `flutter test`: 100% de pruebas pasando.
