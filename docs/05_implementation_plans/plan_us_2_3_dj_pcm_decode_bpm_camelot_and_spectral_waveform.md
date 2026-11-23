# Plan de Implementación: US-2.3

## 1. Alcance y Objetivos
1. Crear el decodificador universal `PcmWavDecoder` en `lib/features/dj_console/domain/pcm_wav_decoder.dart`.
2. Actualizar `DjTrackLoaderModal` para decodificar archivos WAV locales y alimentar `loadTrackWithBeatTrackingAsync`.
3. Implementar `getVuLevel(deckId)` en `DjConsoleViewModel` con cálculo de energía RMS real de 33 ms y conectarlo en `DjVerticalChannelStrip`.
4. Escribir pruebas unitarias de decodificación y medición VU en `test/features/dj_console/us_2_3_dj_pcm_decode_and_vu_test.dart`.

---

## 2. Archivos Afectados
1. `lib/features/dj_console/domain/pcm_wav_decoder.dart` (Nuevo)
2. `lib/features/dj_console/presentation/dj_track_loader_modal.dart`
3. `lib/features/dj_console/presentation/dj_console_view_model.dart`
4. `lib/features/dj_console/presentation/dj_vertical_channel_strip.dart`
5. `test/features/dj_console/us_2_3_dj_pcm_decode_and_vu_test.dart` (Nuevo)

---

## 3. Plan de Pruebas y Validación
- `flutter analyze --no-fatal-infos`: Cero warnings ni errores.
- `flutter test`: 100% de pruebas pasando.
