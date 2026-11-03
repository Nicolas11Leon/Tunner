# Bitácora Maestra de Pruebas Manuales y Auditoría de Calidad: Tunner

Este documento es el centro neurálgico de aseguramiento de calidad manual y seguimiento de campo para la plataforma **Tunner**. Permite al creador del proyecto y a los evaluadores verificar el estado funcional de cada componente, auditar qué aspectos faltan por probar en hardware real e ingresar las anotaciones de bitácora.

---

## 1. Resumen Ejecutivo del Estado de Pruebas Manuales

- **Total de Casos de Uso Documentados:** 42 Casos de Uso (UC-01 al UC-42).
- **Cobertura de Pruebas Automatizadas:** 389 tests unitarios pasando al 100%.
- **Metodología de Campo:** [Metodología de Pruebas Manuales](00_manual_testing_methodology.md).
- **Convenciones de Estado:** `[ ] Pendiente`, `[x] Aprobado en Dispositivo`, `[!] Con Observaciones`, `[-] Bloqueado`.

---

## 2. Matriz Maestra de Pruebas Manuales por Caso de Uso

| ID | Caso de Uso | Área Funcional | Checklist Manual en Caso de Uso | Estado Global |
| :---: | :--- | :--- | :---: | :---: |
| **UC-01** | [Detección Acústica de Tono](../02_use_cases/01_uc_acoustic_pitch_detection.md) | Afinador & DSP | [Ver Sección Manual](../02_use_cases/01_uc_acoustic_pitch_detection.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-02** | [Reloj de Audio de Alta Precisión](../02_use_cases/02_uc_high_res_audio_clock.md) | Metrónomo & Clock | [Ver Sección Manual](../02_use_cases/02_uc_high_res_audio_clock.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-03** | [Cursor de Partitura Interactivo](../02_use_cases/03_uc_interactive_score_playhead.md) | Partituras & Playhead | [Ver Sección Manual](../02_use_cases/03_uc_interactive_score_playhead.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-04** | [Afinador Estroboscópico Virtual](../02_use_cases/04_uc_virtual_strobe_tuner.md) | Afinador Visual | [Ver Sección Manual](../02_use_cases/04_uc_virtual_strobe_tuner.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-05** | [Tono Acústico de Referencia](../02_use_cases/05_uc_audio_reference_tone.md) | Síntesis & Diapasón | [Ver Sección Manual](../02_use_cases/05_uc_audio_reference_tone.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-06** | [Motor Notación SMuFL](../02_use_cases/06_uc_smufl_sheet_music_engine.md) | Tipografía Musical | [Ver Sección Manual](../02_use_cases/06_uc_smufl_sheet_music_engine.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-07** | [Mezclador Stems Multipista](../02_use_cases/07_uc_multitrack_stem_mixer.md) | Estudio de Audio | [Ver Sección Manual](../02_use_cases/07_uc_multitrack_stem_mixer.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-08** | [Lector y Descompositor de Canciones](../02_use_cases/08_uc_song_reader_and_decomposer.md) | Biblioteca de Temas | [Ver Sección Manual](../02_use_cases/08_uc_song_reader_and_decomposer.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-09** | [Evaluación de Práctica y Analítica](../02_use_cases/09_uc_practice_evaluation_and_performance_analytics.md) | Pedagogía & Analítica | [Ver Sección Manual](../02_use_cases/09_uc_practice_evaluation_and_performance_analytics.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-10** | [Transposición Multi-Instrumento](../02_use_cases/10_uc_multi_instrument_transposition_and_multidimensional_metrics.md) | Instrumentos | [Ver Sección Manual](../02_use_cases/10_uc_multi_instrument_transposition_and_multidimensional_metrics.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-11** | [Temas Adaptativos y Personalización](../02_use_cases/11_uc_adaptive_aesthetic_theming_and_user_customization.md) | UI & Personalización | [Ver Sección Manual](../02_use_cases/11_uc_adaptive_aesthetic_theming_and_user_customization.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-12** | [Grabador de Práctica y Loopback](../02_use_cases/12_uc_practice_audio_recorder_and_loopback.md) | Grabador de Audio | [Ver Sección Manual](../02_use_cases/12_uc_practice_audio_recorder_and_loopback.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-13** | [Calibración A4 y Persistencia](../02_use_cases/13_uc_reference_pitch_calibration_and_local_persistence.md) | Ajustes & Afinación | [Ver Sección Manual](../02_use_cases/13_uc_reference_pitch_calibration_and_local_persistence.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-14** | [Importador MusicXML y MIDI](../02_use_cases/14_uc_universal_musicxml_midi_importer.md) | Importador Universal | [Ver Sección Manual](../02_use_cases/14_uc_universal_musicxml_midi_importer.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-15** | [Clics de Metrónomo y Diapasón](../02_use_cases/15_uc_acoustic_metronome_clicks_and_tuning_diapason.md) | Metrónomo Acústico | [Ver Sección Manual](../02_use_cases/15_uc_acoustic_metronome_clicks_and_tuning_diapason.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-16** | [Algoritmo McLeod (MPM)](../02_use_cases/16_uc_mcleod_pitch_method_pitch_detection.md) | DSP & Algoritmos | [Ver Sección Manual](../02_use_cases/16_uc_mcleod_pitch_method_pitch_detection.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-17** | [Motor de Reproducción de Partituras](../02_use_cases/17_uc_score_playback_audio_engine.md) | Partituras & Audio | [Ver Sección Manual](../02_use_cases/17_uc_score_playback_audio_engine.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-18** | [Editor Interactivo y Exportador](../02_use_cases/18_uc_interactive_score_editor_and_canonical_exporter.md) | Edición de Partituras | [Ver Sección Manual](../02_use_cases/18_uc_interactive_score_editor_and_canonical_exporter.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-19** | [Transcripción Micrófono a Partitura](../02_use_cases/19_uc_live_mic_to_score_transcription.md) | Transcripción en Vivo | [Ver Sección Manual](../02_use_cases/19_uc_live_mic_to_score_transcription.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-20** | [Espectrograma Armónico FFT](../02_use_cases/20_uc_fft_harmonic_spectrogram.md) | Laboratorio Acústico | [Ver Sección Manual](../02_use_cases/20_uc_fft_harmonic_spectrogram.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-21** | [Generador Algorítmico de Ejercicios](../02_use_cases/21_uc_algorithmic_exercise_generator.md) | Pedagogía Musical | [Ver Sección Manual](../02_use_cases/21_uc_algorithmic_exercise_generator.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-22** | [Modo de Experiencia Dual (Esencial/Pro)](../02_use_cases/22_uc_dual_experience_mode.md) | UI & UX | [Ver Sección Manual](../02_use_cases/22_uc_dual_experience_mode.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-23** | [Temperamentos Históricos](../02_use_cases/23_uc_historical_temperaments_engine.md) | Afinación Microtonal | [Ver Sección Manual](../02_use_cases/23_uc_historical_temperaments_engine.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-24** | [Estudio de Drones Armónicos](../02_use_cases/24_uc_harmonic_drone_studio.md) | Drones & Resonancia | [Ver Sección Manual](../02_use_cases/24_uc_harmonic_drone_studio.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-25** | [Reconocimiento Polifónico de Acordes](../02_use_cases/25_uc_polyphonic_chord_recognition.md) | Armonía & Detección | [Ver Sección Manual](../02_use_cases/25_uc_polyphonic_chord_recognition.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-26** | [Tap Tempo Determinista](../02_use_cases/26_uc_deterministic_tap_tempo.md) | Metrónomo Táctil | [Ver Sección Manual](../02_use_cases/26_uc_deterministic_tap_tempo.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-27** | [Ingesta Multiformato y Transcripción](../02_use_cases/27_uc_multiformat_ingestion_and_audio_to_score_transcription.md) | Importador & OCR | [Ver Sección Manual](../02_use_cases/27_uc_multiformat_ingestion_and_audio_to_score_transcription.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-28** | [Importador PDF y Pipeline OMR](../02_use_cases/28_uc_pdf_sheet_music_importer_and_omr_pipeline.md) | OMR & Partituras | [Ver Sección Manual](../02_use_cases/28_uc_pdf_sheet_music_importer_and_omr_pipeline.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-29** | [Supresión de Sangrado de Clic](../02_use_cases/29_uc_acoustic_echo_suppression_and_metronome_bleed_elimination.md) | DSP & Filtro Eco | [Ver Sección Manual](../02_use_cases/29_uc_acoustic_echo_suppression_and_metronome_bleed_elimination.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-30** | [Exportador Canónico de PDF Musical](../02_use_cases/30_uc_canonical_pdf_sheet_music_exporter.md) | Vector PDF Export | [Ver Sección Manual](../02_use_cases/30_uc_canonical_pdf_sheet_music_exporter.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-31** | [Transposición y Claves Musicales](../02_use_cases/31_uc_instrument_transposition_and_clef_engine.md) | Notación & Claves | [Ver Sección Manual](../02_use_cases/31_uc_instrument_transposition_and_clef_engine.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-32** | [Grabación Multipista y Comparador](../02_use_cases/32_uc_multitrack_recording_and_spectral_comparator.md) | Análisis Espectral | [Ver Sección Manual](../02_use_cases/32_uc_multitrack_recording_and_spectral_comparator.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-33** | [Reporte de Progreso y Diploma PDF](../02_use_cases/33_uc_pedagogical_progress_and_certificate_pdf_report.md) | Pedagogía & PDF | [Ver Sección Manual](../02_use_cases/33_uc_pedagogical_progress_and_certificate_pdf_report.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-34** | [Perfiles Pedagógicos Adaptativos](../02_use_cases/34_uc_adaptive_pedagogical_profiles_and_scaffolding.md) | Perfiles & Rutas | [Ver Sección Manual](../02_use_cases/34_uc_adaptive_pedagogical_profiles_and_scaffolding.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-35** | [Hub de Espacios de Trabajo (Workspaces)](../02_use_cases/35_uc_project_workspaces_hub.md) | Gestión de Proyectos | [Ver Sección Manual](../02_use_cases/35_uc_project_workspaces_hub.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-36** | [Exportación Stems y Síntesis MIDI](../02_use_cases/36_uc_audio_stem_export_and_midi_synthesis.md) | DAW & Exportador | [Ver Sección Manual](../02_use_cases/36_uc_audio_stem_export_and_midi_synthesis.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-37** | [Detección Polifónica Multitono](../02_use_cases/37_uc_live_polyphonic_multitone_pitch_detection.md) | DSP Multitono | [Ver Sección Manual](../02_use_cases/37_uc_live_polyphonic_multitone_pitch_detection.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-38** | [Lecciones Guiadas Interactivas](../02_use_cases/38_uc_interactive_guided_lessons_and_step_practice.md) | Gamificación & Aula | [Ver Sección Manual](../02_use_cases/38_uc_interactive_guided_lessons_and_step_practice.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-39** | [Autotune Vocal y Corrección Formantes](../02_use_cases/39_uc_vocal_autotune_and_pitch_correction.md) | Voz & Síntesis | [Ver Sección Manual](../02_use_cases/39_uc_vocal_autotune_and_pitch_correction.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-40** | [Síntesis SoundFont SF2](../02_use_cases/40_uc_soundfont_sf2_instrument_synthesis.md) | SoundFonts & Wavetable | [Ver Sección Manual](../02_use_cases/40_uc_soundfont_sf2_instrument_synthesis.md#8-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-41** | [Calibración y Adaptación de Micrófono](../02_use_cases/41_uc_microphone_calibration_and_adaptation.md) | Hardware Mic & Ruido | [Ver Sección Manual](../02_use_cases/41_uc_microphone_calibration_and_adaptation.md#6-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |
| **UC-42** | [Síntesis Guitarras y Bajo](../02_use_cases/42_uc_soundfont_modern_guitars_and_bass_synthesis.md) | Guitarras & Bajo SF2 | [Ver Sección Manual](../02_use_cases/42_uc_soundfont_modern_guitars_and_bass_synthesis.md#6-guía-de-pruebas-manuales-y-bitácora-de-validación) | `[ ] Pendiente` |

---

## 3. Bitácora de Campo Consolidada (Registro de Pruebas Realizadas)

Esta sección se va completando a medida que el creador y su equipo de testers ejecuten pruebas manuales en sus dispositivos físicos:

| Fecha | UC Evaluado | Tester | Dispositivo & SO | Micrófono / Setup | Veredicto | Hallazgos, Comentarios o Mejoras Detectadas |
| :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| *Pendiente* | - | - | - | - | - | *Iniciar primer ciclo de pruebas manuales con UC-41 y UC-01* |

---

## 4. Guía Rápida para el Flujo de Prueba de Campo

1. **Paso 1:** Abrir la aplicación en dispositivo físico (Android, iOS o Desktop).
2. **Paso 2:** Calibrar el micrófono en el modal de calibración (UC-41) asegurando que el piso de ruido esté adaptado a la habitación.
3. **Paso 3:** Realizar la prueba del afinador principal (UC-01) emitiendo notas con instrumento o generador de frecuencias.
4. **Paso 4:** Probar el metrónomo (UC-02, UC-15, UC-26) y verificar la supresión de sangrado acústico del clic (UC-29).
5. **Paso 5:** Registrar cualquier detalle o discrepancia en este documento y en el checklist individual del Caso de Uso correspondiente.
