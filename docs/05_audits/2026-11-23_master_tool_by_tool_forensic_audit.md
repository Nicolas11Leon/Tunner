# Auditoría Forense Integral por Herramienta — Tunner v1.0

## Metadatos del Documento

- **ID del Documento:** `DOC-AUDIT-2026-001`
- **Título Oficial:** `Auditoría Forense Completa por Herramienta (33 Módulos / 108,440 LOC / 7 Ejes)`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-11-23`
- **Última Modificación:** `2026-11-23`
- **Fase Asociada:** `Global / Pre-v1.0 Hardening & Visual Identity`
- **Autor / Revisor Principal:** `Nicolas Leon / Antigravity`

---

## 1. Resumen Ejecutivo

Se ejecutó una auditoría forense estática sobre el **100% de `lib/` (`108,440` líneas de Dart en 33 módulos)** evaluando 7 ejes: (1) Atomización / God Classes, (2) Clean Architecture, (3) Inyección de Dependencias (DI/DIP), (4) Funciones mockeadas/hardcodeadas/mínimas, (5) Adherencia al sistema visual Pro OLED Monochrome (`StudioThemeScope`/`StudioDesignTokens`), (6) Seguridad de imágenes/assets/rendering/iconografía (`StudioIcon`) y (7) Buenas prácticas y ciclo de vida.

### Hallazgos Globales Clave
- **Cero usos inseguros de `Image.asset` sin `errorBuilder`** y **cero emojis decorativos** en la interfaz.
- **Fractura estética crítica (`S0`):** Conviven dos sistemas de tema incompatibles (`TunnerThemePalette` legacy vs `StudioDesignTokens`). Solo `home_dashboard_screen.dart` adopta `StudioThemeScope` + `StudioIcon` (7 usos), mientras persisten **>400 colores neón/hardcoded** y **>300 `Icons.*`** sin migrar.
- **Concentración en God Classes (`S0`):** 19 archivos superan las 700 LOC, encabezados por `tuner_viewmodel.dart` (3,105 LOC), `dj_studio_workstation_view.dart` (1,764 LOC), `main_app_shell.dart` (1,498 LOC), `dj_console_view_model.dart` (1,439 LOC), `tuner_screen.dart` (1,380 LOC) y `tunner_os_kernel.dart` (1,306 LOC).
- **Violaciones de Clean Architecture y DI (`S0`):** `app_user_settings_entity.dart` importa `flutter/material.dart` vía `tunner_theme.dart`; generadores PDF binarios + `package:crypto` viven en `domain/`; `StudioCompositionRoot` es parcial y múltiples vistas instancian infraestructura concreta o singletons ocultos.
- **Bloqueos de hilo UI/Audio y Fugas (`S0`):** DFT en `Widget.build()`, OMR/WAV/PDF/TD-PSOLA/ZLib síncronos en UI sin `Isolate.run`, `writeFromSync` en callback de audio, `AnimationController..repeat()` permanente en `harmonic_beat_gauge.dart`, y fugas de suscripciones en `studio_audio_channel.dart` y `main_app_shell.dart`.
- **Funciones simuladas / datos falsos (`S0`):** `TunnerDslInterpreter` dispara todas las notas en `t=0` (`rest` no-op); `tunner_os_kernel.dart` emite telemetría y certificados vocales sintéticos; `task_catalog_index.dart` precarga maestrías falsas (`S/A/B`); `blind_ear_trainer_engine.dart` ignora rangos de frecuencia; `harmonic_tutor_view_model.dart` arranca en `261.63 Hz` falso; `vocal_stability_evaluator.dart` aprueba silencio con `50.0`; `pedagogical_report_modal.dart` traga errores de exportación.

---

## 2. Matriz de Auditoría Herramienta por Herramienta

| # | Herramienta / Módulo | Hallazgos Críticos (`S0` / `S1`) | Plan Correctivo |
|---|---|---|---|
| 1 | `lib/core/audio` | `studio_master_hardware_console_widget.dart` (1,148 LOC) importa infraestructura; `studio_master_capture_service.dart:92` `writeFromSync` en audio thread; `studio_audio_channel.dart:58-68` fuga 3 `.listen()`; `bufferSize` ignorado en `studio_audio_input_engine.dart:115`; 30 `Colors.*` y 20 `Icons.*`. | Plan 02, 03, 04 |
| 2 | `lib/features/tuner` | `tuner_viewmodel.dart` (3,105 LOC, >20 concretos internos); `tuner_screen.dart` (1,380 LOC); `calibrateAmbientNoiseFloor` hardcodea `detectedDcOffset: 0.0` con `Future.delayed(1600ms)`; `strobe_tuner_widget.dart:283` sin `clipRect`/clamping; 0% `StudioThemeScope`, 66 `Icons.*`. | Plan 01, 02, 03, 04 |
| 3 | `lib/features/drone` | `harmonic_drone_modal.dart` (471 LOC, `build()` 444 LOC) acoplado a `TunerViewModel`; coeficientes aditivos sin guardas Nyquist; 0% `StudioThemeScope`, 4 `Icons.*`. | Plan 01, 03, 04 |
| 4 | `lib/features/metronome` | `tap_tempo_modal.dart` (`build()` 308 LOC); `metronome_service.dart:68` hardcodea `subTicksPerBeat` rompiendo compases compuestos (`6/8`, `9/8`, `12/8`); sin `dispose()`; 0% `StudioThemeScope`. | Plan 01, 04 |
| 5 | `lib/features/audio_synthesizer` | `instrument_soundfont_selector_modal.dart:103-111` usa `FilePicker` y parsea SF2/WAV síncrono en UI; `stem_audio_synthesizer.dart:38` hardcodea `A4=440.0`; 0% `StudioThemeScope`, 17 `Icons.*`. | Plan 01, 02, 04 |
| 6 | `lib/features/acoustic_lab` | `harmonic_spectrogram_modal.dart:23-31` ejecuta DFT (`HarmonicSeriesAnalyzer.analyze`) síncrono dentro de `build()` a 44.1 kHz fijos; 0% `StudioThemeScope`. | Plan 01, 04 |
| 7 | `lib/features/chord_analyzer` | `polyphonic_live_voicing_widget.dart:320` ejecuta DFT en `build()`; `chord_radar_widget.dart:53` radio negativo sin clamping ni `clipRect` + 12 `TextPainter` por frame; 0% `StudioThemeScope`. | Plan 01, 04 |
| 8 | `lib/features/instrument` | Catálogo duplicado (`universal_instrument_definition.dart` 1,029 LOC vs `instrument_profile_entity.dart` 409 LOC); frecuencias fijas a 440 Hz; `drum_pads_tactile_widget.dart:48` overflow + 8 colores neón hardcoded; 0% `StudioThemeScope`, 30 `Icons.*`. | Plan 01, 03, 04 |
| 9 | `lib/features/dj_console` | God Views/VM (`1,764`, `1,439`, `1,037` LOC); duplicación y colisión de IDs globales `'plug_dj_deck_a_in'` entre modal y workstation; importa `studio_composition_root.dart`; gamepad simulado con chips; `scoreEditor` stub; 268 `Color(0x...)`, 166 `Colors.*`, 85 `Icons.*`; painters sin `isFinite`. | Plan 01, 02, 05 |
| 10 | `lib/features/mixer` | Solo 1 archivo (`mixer_track_entity.dart`); literales UI/iconos en dominio; `fromMap` sin `.clamp`/`isFinite`; sin paneo/dB ni `==`/`hashCode`. | Plan 02, 05 |
| 11 | `lib/features/media_vault` | `media_vault_workspace_modal.dart` (979 LOC); `exportTimelineToDisk:111` pasa ruta absoluta como `relativePath`; constructor de repositorio sintetiza ~705k muestras PCM síncronas con fecha fija; `_ClipWaveformPainter:968` vulnerable a `NaN`; 16 `Icons.*`. | Plan 01, 05 |
| 12 | `lib/features/modular_rack` | `modular_rack_viewmodel.dart` (1,224 LOC) y `rack_unit_card.dart` (955 LOC acoplado a 12+ modales); abusa de `signalBus.dispose()` como reset; `universal_instrument_search_modal.dart:92` `Icons.clear` no borra texto; paleta slate/cyan hardcoded (67 `Color(0x...)`), 49 `Icons.*`. | Plan 01, 02, 05 |
| 13 | `lib/core/channels` | Singleton global en `StudioPatchbayRoutingService()`; colores hex de UI dentro de dominio (`:111,333`); `studio_channel_modals.dart` 0% `StudioThemeScope` con 8 colores neón; `notifyListeners()` sin guarda `_safeNotify()`; pulso visual pisado entre sinks. | Plan 01, 02, 05 |
| 14 | `lib/features/sheet_music` | `real_sheet_music_painter.dart:162-579` `paint()` de 417 LOC alocando `RegExp`/`Paint`/`Path`/`TextPainter` cada frame; usa `TunnerThemePalette`; `shouldRepaint` omite `timeSignature`/`totalMeasures`; `getMockStudies()` expuesto en dominio. | Plan 01, 04, 06 |
| 15 | `lib/features/score_editor` | `score_editor_modal.dart` (892 LOC, `build()` 691 LOC); `score_editor_controller.dart:510` sintetiza WAV stems y PDF síncronos en hilo UI; 10 instanciaciones concretas; `recommendations` estáticas; `clamp(0, totalMeasures - 1)` crashea si `0`; 0% `StudioThemeScope`, 16 `Icons.*`. | Plan 01, 02, 04, 06 |
| 16 | `lib/features/song_library` | `song_decomposer_modal.dart` (1,201 LOC) llama `parseMelodyText` en `build()`; ignora `ISongDecomposerService`; 0% `StudioThemeScope` en decomposer, 21 `Icons.*`. | Plan 01, 02, 06 |
| 17 | `lib/features/universal_importer` | 0 usos de `Isolate` en 4,918 LOC (`pdf_score_parser.dart` 832 LOC, OMR y MPM WAV bloquean UI); `score_import_tab_view.dart` embebe payloads binarios en UI; conversión nota/MIDI duplicada en 6 archivos; 0% `StudioThemeScope`. | Plan 01, 02, 04, 06 |
| 18 | `lib/features/transcription` | `transcribeAudioFile` síncrono sin `Isolate.run`; ~85% duplicación entre `live_transcription_engine.dart` y `polyphonic_transcription_engine.dart`; `RhythmicQuantizer` sin puntillos ni tresillos. | Plan 04, 06 |
| 19 | `lib/features/practice_recorder` | `practice_recorder_controller.dart` (568 LOC) re-downsamplea 16k muestras en UI cada frame; `spectral_comparator_modal.dart:70` corre `compareTakes` en cada tick; `audio_playback_service.dart` fuga `_audioEngine`; 0% `StudioThemeScope`, neón hardcoded, 17 `Icons.*`. | Plan 01, 02, 04 |
| 20 | `lib/features/vocal_autotune` | `vocal_autotune_modal.dart` (843 LOC); `vocal_pedagogy_controller.dart:190` llama `processPracticeTake` síncrono existiendo `processPracticeTakeAsync`; `deltaSeconds: 0.05` fijo; filas comparten `isPlayingAudio` global; 0% `StudioThemeScope`, 11 `Icons.*`. | Plan 01, 04, 06 |
| 21 | `lib/features/project_format` | `local_project_storage_repository.dart` ejecuta ZLib maxLevel síncrono en UI y usa `dart:io` directo; vulnerabilidad zip-bomb en `tunner_binary_project_codec.dart:61-67` (descomprime antes de validar tamaño). | Plan 02, 04 |
| 22 | `lib/features/ear_training` | `blind_ear_trainer_modal.dart` (744 LOC); `blind_ear_trainer_engine.dart:125` ignora `min/maxBaseFrequencyHz` usando 8 notas A3-A4; modo micrófono dispara en primer frame sin ventana de estabilidad; overflow en badges; 0% `StudioThemeScope`, 8 `Icons.*`. | Plan 01, 06 |
| 23 | `lib/features/guided_lessons` | `guided_lessons_modal.dart` (755 LOC) duplica lógica de evaluación acústica en `build()` + stepper `Row` con overflow garantizado; `task_catalog_index.dart:186` hardcodea maestrías falsas (`S/A/B`) y `_tokenize` destruye acentos/`ñ`; 0% `StudioThemeScope`, 25 `Icons.*`. | Plan 01, 06 |
| 24 | `lib/features/harmonic_tutor` | `harmonic_tutor_view_model.dart:26` inicia con `261.63 Hz` falso e `isListening: true`; `_regenerateDrone` trunca a 2 voces y 2000 ms; `harmonic_beat_gauge.dart:30` `AnimationController..repeat()` infinito; 0% `StudioThemeScope`. | Plan 01, 04, 06 |
| 25 | `lib/features/practice_evaluator` | `practice_report_modal.dart` (563 LOC) con overflows garantizados (`:120-158, 243-273`); silencios con sonido hardcodean `100%`/`early`; 0% `StudioThemeScope`, 9 `Icons.*`. | Plan 01, 06 |
| 26 | `lib/features/pedagogy` | `pedagogical_certificate_pdf_generator.dart` binario + `package:crypto` en `domain/` (código huérfano duplicado); `vocal_stability_evaluator.dart:47` devuelve `50.0` y `0 cents` ante silencio; `utf8.encode` corrompe tildes en PDF. | Plan 02, 06 |
| 27 | `lib/features/pedagogy_profiles` | `adaptive_scaffolding_engine.dart:65,128` ignora `isSharp` y hardcodea `'Tol: +-5c'`; 0% `StudioThemeScope`, 6 `Icons.*`. | Plan 01, 06 |
| 28 | `lib/features/pedagogy_report` | `pedagogical_report_pdf_generator.dart` (758 LOC) en `domain/` con `crypto`, typo `"TUNER"` y líneas sin word-wrap; `pedagogical_report_modal.dart:369` I/O sin `await` tragando errores con SnackBar de éxito falso; 0% `StudioThemeScope`. | Plan 01, 02, 06 |
| 29 | `lib/features/exercise_generator` | Overflows garantizados (`:68-99, 139-163`); octavas limitadas a `2..6`; compás fijo `4/4` sin enarmonía; `palette` casteada como `dynamic`; 0% `StudioThemeScope`. | Plan 01, 06 |
| 30 | `lib/app` & `lib/features/navigation` | `StudioCompositionRoot` incompleto; `main_app_shell.dart` (1,498 LOC) instancia infraestructura concreta, fugas en callbacks de `masterClockService`, pasa datos vocales falsos (`10x frequency`, `0.85`), descarta salida de `onCommandSubmitted`, mezcla `TunnerThemePalette` con `StudioThemeScope`; 117 `Icons.*`. | Plan 01, 02, 03, 06 |
| 31 | `lib/core/design_system` & `lib/core/theme` | `studio_desktop_app_shell.dart` (1,058 LOC) hardcodea colores cian en switcher `Archivos/Herramientas`, telemetría fija y `Comprobar Actualizaciones` stub; conflicto entre `TunnerThemePalette` y `StudioDesignTokens`; `StudioIcon` dispara carga fallida sin manifiesto; `setTokens` ignora cambios con mismo ID. | Plan 01, 03 |
| 32 | `lib/core/docking` & `lib/core/file_system` | `docking` 0% `StudioThemeScope` (50 colores neón), zona `floating` desaparece paneles, `DefaultTabController` sin `ValueKey(length)` crashea, acoplado a `dj_console`; `file_system` usa singletons y hardcodea `'ZLIB BINARY'`. | Plan 01, 02, 05 |
| 33 | `lib/core/terminal`, `lib/core/dsl`, `lib/core/packaging`, `workspaces`, `customization`, `persistence` | `tunner_os_kernel.dart` (1,306 LOC) con comandos falsos (`io list`, `dsp status`, `fs ls`, `vocal eval/cert`) y fuga en `dispose()`; `TunnerDslInterpreter` sin reloj (`rest` no-op, todo en `t=0`); `workspaces` y `customization` 100% legacy duplicando gestor de temas; `app_user_settings_entity.dart` importa Flutter y no persiste `StudioDesignTokens`. | Plan 01, 02, 03, 04, 06 |

---

## 3. Mapa de Planes de Implementación Generados

1. **[Plan 01: Unificación OLED Monochrome, `StudioIcon` y Saneamiento Visual/Rendering](../03_plans/plan_audit_01_oled_theme_unification_and_studio_icon_migration.md)**
2. **[Plan 02: Clean Architecture, Composition Root Completo, DI y Persistencia Pura](../03_plans/plan_audit_02_clean_architecture_di_composition_root_and_persistence.md)**
3. **[Plan 03: Atomización Extrema de God Classes (Tuner, Shell, Master Console, Kernel)](../03_plans/plan_audit_03_god_class_atomization_tuner_shell_and_kernel.md)**
4. **[Plan 04: Rendimiento Real-Time, Isolates DSP/PDF/ZLib, Planificador DSL y Cero Fugas](../03_plans/plan_audit_04_dsp_isolates_real_audio_and_dsl_scheduler.md)**
5. **[Plan 05: Refactorización Profunda de DJ Console, Modular Rack, Mixer, Media Vault y Docking](../03_plans/plan_audit_05_dj_console_modular_rack_mixer_and_media_vault.md)**
6. **[Plan 06: Cero Mocks y Verdad Acústica en Suite Pedagógica, Notación, Importer y Kernel](../03_plans/plan_audit_06_pedagogy_notation_truthfulness_and_zero_mocks.md)**
