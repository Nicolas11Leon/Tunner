# Bitácora Maestra de Pruebas Manuales y Auditoría de Calidad: Tunner

Este documento es el centro neurálgico de aseguramiento de calidad manual y seguimiento de campo para la plataforma **Tunner**. Permite al creador del proyecto y a los evaluadores verificar el estado funcional de cada componente, auditar qué aspectos faltan por probar en hardware real e ingresar las anotaciones de bitácora antes y después de cada hito de lanzamiento.

---

## 1. Resumen Ejecutivo del Estado de Pruebas Manuales y Calidad

- **Versión Evaluada:** `v1.0.0-RC / v1.0.0`
- **Total de Casos de Uso Documentados:** 132 Casos de Uso (UC-01 al UC-132).
- **Total de ADRs Registrados:** 121 Decisiones Arquitectónicas (ADR-0001 al ADR-0121).
- **Cobertura de Pruebas Automatizadas:** 1,154 tests unitarios, de integración y de widgets pasando al 100% (0 fallos).
- **Dart Analyzer:** 0 advertencias / 0 errores (`flutter analyze --no-fatal-infos`).
- **Protocolo de Validación de Campo:** [01_v1_0_0_manual_qa_validation_protocol.md](01_v1_0_0_manual_qa_validation_protocol.md).
- **Metodología de Campo:** [Metodología de Pruebas Manuales](00_manual_testing_methodology.md).
- **Convenciones de Estado:** `[ ] Pendiente`, `[x] Aprobado en Dispositivo`, `[!] Con Observaciones`, `[-] Bloqueado`.

---

## 2. Matriz Maestra de Pruebas Manuales por Áreas Funcionales (UC-01 al UC-132)

### 2.1 Afinación, DSP, Acústica y Calibración
| ID | Caso de Uso | Área Funcional | Enlace al Caso de Uso | Estado Manual |
| :---: | :--- | :--- | :--- | :---: |
| **UC-01** | Detección Acústica de Tono | Afinador & DSP | [Ver UC-01](../02_use_cases/01_uc_acoustic_pitch_detection.md) | `[ ] Pendiente` |
| **UC-04** | Afinador Estroboscópico Virtual | Afinador Visual | [Ver UC-04](../02_use_cases/04_uc_virtual_strobe_tuner.md) | `[ ] Pendiente` |
| **UC-05** | Tono Acústico de Referencia | Síntesis & Diapasón | [Ver UC-05](../02_use_cases/05_uc_audio_reference_tone.md) | `[ ] Pendiente` |
| **UC-10** | Transposición Multi-Instrumento | Instrumentos | [Ver UC-10](../02_use_cases/10_uc_multi_instrument_transposition_and_multidimensional_metrics.md) | `[ ] Pendiente` |
| **UC-13** | Calibración A4 y Persistencia | Ajustes & Afinación | [Ver UC-13](../02_use_cases/13_uc_reference_pitch_calibration_and_local_persistence.md) | `[ ] Pendiente` |
| **UC-16** | Algoritmo McLeod Pitch Method (MPM) | DSP & Algoritmos | [Ver UC-16](../02_use_cases/16_uc_mcleod_pitch_method_pitch_detection.md) | `[ ] Pendiente` |
| **UC-20** | Espectrograma Armónico FFT | Laboratorio Acústico | [Ver UC-20](../02_use_cases/20_uc_fft_harmonic_spectrogram.md) | `[ ] Pendiente` |
| **UC-23** | Temperamentos Históricos | Afinación Microtonal | [Ver UC-23](../02_use_cases/23_uc_historical_temperaments_engine.md) | `[ ] Pendiente` |
| **UC-24** | Estudio de Drones Armónicos | Drones & Resonancia | [Ver UC-24](../02_use_cases/24_uc_harmonic_drone_studio.md) | `[ ] Pendiente` |
| **UC-25** | Reconocimiento Polifónico de Acordes | Armonía & Detección | [Ver UC-25](../02_use_cases/25_uc_polyphonic_chord_recognition.md) | `[ ] Pendiente` |
| **UC-37** | Detección Polifónica Multitono | DSP Multitono | [Ver UC-37](../02_use_cases/37_uc_live_polyphonic_multitone_pitch_detection.md) | `[ ] Pendiente` |
| **UC-41** | Calibración y Adaptación de Micrófono | Hardware Mic & Ruido | [Ver UC-41](../02_use_cases/41_uc_microphone_calibration_and_adaptation.md) | `[ ] Pendiente` |
| **UC-43** | Aislamiento Acústico y Rechazo de Voz | DSP & Filtros | [Ver UC-43](../02_use_cases/43_uc_instrument_acoustic_isolation_and_speech_rejection.md) | `[ ] Pendiente` |
| **UC-59** | Afinador Inteligente y Reconocimiento Tímbrico | Adaptación Acústica | [Ver UC-59](../02_use_cases/59_uc_smart_instrument_tuner_and_acoustic_adaptation.md) | `[ ] Pendiente` |
| **UC-67** | Tutor de Entonación Armónica (Just Intonation) | Afinación Justa | [Ver UC-67](../02_use_cases/67_uc_dynamic_just_intonation_tutor.md) | `[ ] Pendiente` |

### 2.2 Reloj Maestro, Metrónomo, Grabación y Transporte
| ID | Caso de Uso | Área Funcional | Enlace al Caso de Uso | Estado Manual |
| :---: | :--- | :--- | :--- | :---: |
| **UC-02** | Reloj de Audio de Alta Precisión | Metrónomo & Clock | [Ver UC-02](../02_use_cases/02_uc_high_res_audio_clock.md) | `[ ] Pendiente` |
| **UC-12** | Grabador de Práctica y Loopback | Grabador de Audio | [Ver UC-12](../02_use_cases/12_uc_practice_audio_recorder_and_loopback.md) | `[ ] Pendiente` |
| **UC-15** | Clics de Metrónomo y Diapasón | Metrónomo Acústico | [Ver UC-15](../02_use_cases/15_uc_acoustic_metronome_clicks_and_tuning_diapason.md) | `[ ] Pendiente` |
| **UC-26** | Tap Tempo Determinista | Metrónomo Táctil | [Ver UC-26](../02_use_cases/26_uc_deterministic_tap_tempo.md) | `[ ] Pendiente` |
| **UC-29** | Supresión de Sangrado de Clic | DSP & Anti-Bleed | [Ver UC-29](../02_use_cases/29_uc_acoustic_echo_suppression_and_metronome_bleed_elimination.md) | `[ ] Pendiente` |
| **UC-32** | Grabación Multipista y Comparador | Análisis Espectral | [Ver UC-32](../02_use_cases/32_uc_multitrack_recording_and_spectral_comparator.md) | `[ ] Pendiente` |
| **UC-62** | Puertos de E/S de Hardware y Broker de Permisos | Hardware & Permisos | [Ver UC-62](../02_use_cases/62_uc_hardware_io_ports_and_permission_broker.md) | `[ ] Pendiente` |

### 2.3 Notación SMuFL, Partituras, Parsers y Exporters
| ID | Caso de Uso | Área Funcional | Enlace al Caso de Uso | Estado Manual |
| :---: | :--- | :--- | :--- | :---: |
| **UC-03** | Cursor de Partitura Interactivo | Partituras & Playhead | [Ver UC-03](../02_use_cases/03_uc_interactive_score_playhead.md) | `[ ] Pendiente` |
| **UC-06** | Motor Notación SMuFL | Tipografía Musical | [Ver UC-06](../02_use_cases/06_uc_smufl_sheet_music_engine.md) | `[ ] Pendiente` |
| **UC-14** | Importador Universal MusicXML y MIDI | Ingesta Estándar | [Ver UC-14](../02_use_cases/14_uc_universal_musicxml_midi_importer.md) | `[ ] Pendiente` |
| **UC-17** | Motor de Reproducción de Partituras | Audio Partituras | [Ver UC-17](../02_use_cases/17_uc_score_playback_audio_engine.md) | `[ ] Pendiente` |
| **UC-18** | Editor Interactivo y Exportador Canónico | Edición & Memento | [Ver UC-18](../02_use_cases/18_uc_interactive_score_editor_and_canonical_exporter.md) | `[ ] Pendiente` |
| **UC-19** | Transcripción Micrófono a Partitura en Vivo | Transcripción Audio | [Ver UC-19](../02_use_cases/19_uc_live_mic_to_score_transcription.md) | `[ ] Pendiente` |
| **UC-27** | Ingesta Multiformato y Transcripción | Importador Universal | [Ver UC-27](../02_use_cases/27_uc_multiformat_ingestion_and_audio_to_score_transcription.md) | `[ ] Pendiente` |
| **UC-28** | Importador PDF y Pipeline OMR | OMR Vectorial | [Ver UC-28](../02_use_cases/28_uc_pdf_sheet_music_importer_and_omr_pipeline.md) | `[ ] Pendiente` |
| **UC-30** | Exportador Canónico de PDF Musical | Vectorial SMuFL | [Ver UC-30](../02_use_cases/30_uc_canonical_pdf_sheet_music_exporter.md) | `[ ] Pendiente` |
| **UC-31** | Transposición y Claves Musicales | Notación Musical | [Ver UC-31](../02_use_cases/31_uc_instrument_transposition_and_clef_engine.md) | `[ ] Pendiente` |
| **UC-63** | Transcripción Polifónica Micrófono a Partitura | Polifonía & Partituras | [Ver UC-63](../02_use_cases/63_uc_polyphonic_mic_to_score_transcription.md) | `[ ] Pendiente` |

### 2.4 Síntesis, SoundFont SF2, Mezclador y Suite Vocal
| ID | Caso de Uso | Área Funcional | Enlace al Caso de Uso | Estado Manual |
| :---: | :--- | :--- | :--- | :---: |
| **UC-07** | Mezclador Stems Multipista | Mezclador de Audio | [Ver UC-07](../02_use_cases/07_uc_multitrack_stem_mixer.md) | `[ ] Pendiente` |
| **UC-08** | Lector y Descompositor de Canciones | Biblioteca de Temas | [Ver UC-08](../02_use_cases/08_uc_song_reader_and_decomposer.md) | `[ ] Pendiente` |
| **UC-36** | Exportación Stems y Síntesis MIDI | DAW & Exportador | [Ver UC-36](../02_use_cases/36_uc_audio_stem_export_and_midi_synthesis.md) | `[ ] Pendiente` |
| **UC-39** | Auto-Tune Vocal y Corrección Formantes | Suite Vocal | [Ver UC-39](../02_use_cases/39_uc_vocal_autotune_and_pitch_correction.md) | `[ ] Pendiente` |
| **UC-40** | Síntesis SoundFont SF2 | Wavetable & SF2 | [Ver UC-40](../02_use_cases/40_uc_soundfont_sf2_instrument_synthesis.md) | `[ ] Pendiente` |
| **UC-42** | Síntesis Guitarras y Bajo SF2 | Instrumentos Virtuales | [Ver UC-42](../02_use_cases/42_uc_soundfont_modern_guitars_and_bass_synthesis.md) | `[ ] Pendiente` |
| **UC-60** | Suite Vocal: Auto-Tune, Multipista y Edición de Partitura | Suite Vocal Avanzada | [Ver UC-60](../02_use_cases/60_uc_vocal_suite_autotune_multitrack_and_score_pitch_editing.md) | `[ ] Pendiente` |
| **UC-61** | Descompositor Minus-One y Ensamble Virtual | Ensamble Virtual | [Ver UC-61](../02_use_cases/61_uc_score_decomposer_minus_one_virtual_ensemble.md) | `[ ] Pendiente` |

### 2.5 Consola DJ Virtual, Efectos y Enrutamiento Matricial
| ID | Caso de Uso | Área Funcional | Enlace al Caso de Uso | Estado Manual |
| :---: | :--- | :--- | :--- | :---: |
| **UC-65** | Consola DJ Virtual y Mapeo de Teclado | DJ Workstation | [Ver UC-65](../02_use_cases/65_uc_virtual_dj_console_and_keyboard_mapping.md) | `[ ] Pendiente` |
| **UC-66** | DJ Performance FX, Beat Tracking y Grabador de Mix | Efectos DJ & REC | [Ver UC-66](../02_use_cases/66_uc_dj_performance_fx_beat_tracking_and_mix_recorder.md) | `[ ] Pendiente` |
| **UC-68** | Skins de Hardware DJ y Mapeo de Gamepad | Hardware DJ & UI | [Ver UC-68](../02_use_cases/68_uc_dj_hardware_skins_and_gamepad_mapping.md) | `[ ] Pendiente` |
| **UC-69** | Suite de Trabajo DJ Profesional Autónomo | Consola Pro DJ | [Ver UC-69](../02_use_cases/69_uc_standalone_pro_dj_workstation_suite.md) | `[ ] Pendiente` |
| **UC-70** | Baúl Multimedia, Timeline Drag & Drop y E/S Universal | Media Vault | [Ver UC-70](../02_use_cases/70_uc_multimedia_vault_timeline_drag_drop_and_universal_io.md) | `[ ] Pendiente` |

### 2.6 Pedagogía, Analítica y Repetición Espaciada
| ID | Caso de Uso | Área Funcional | Enlace al Caso de Uso | Estado Manual |
| :---: | :--- | :--- | :--- | :---: |
| **UC-09** | Evaluación de Práctica y Analítica 4D | Analítica & Rushing | [Ver UC-09](../02_use_cases/09_uc_practice_evaluation_and_performance_analytics.md) | `[ ] Pendiente` |
| **UC-21** | Generador Algorítmico de Ejercicios | Escalas & Arpegios | [Ver UC-21](../02_use_cases/21_uc_algorithmic_exercise_generator.md) | `[ ] Pendiente` |
| **UC-33** | Reporte de Progreso y Diploma PDF | Certificación PDF | [Ver UC-33](../02_use_cases/33_uc_pedagogical_progress_and_certificate_pdf_report.md) | `[ ] Pendiente` |
| **UC-34** | Perfiles Pedagógicos Adaptativos | Andamiaje | [Ver UC-34](../02_use_cases/34_uc_adaptive_pedagogical_profiles_and_scaffolding.md) | `[ ] Pendiente` |
| **UC-38** | Lecciones Guiadas Interactivas | Gamificación Aula | [Ver UC-38](../02_use_cases/38_uc_interactive_guided_lessons_and_step_practice.md) | `[ ] Pendiente` |

### 2.7 Sistema de Diseño, Shell, Docking y Workspaces
| ID | Caso de Uso | Área Funcional | Enlace al Caso de Uso | Estado Manual |
| :---: | :--- | :--- | :--- | :---: |
| **UC-11** | Temas Adaptativos y Personalización | Sistema de Diseño | [Ver UC-11](../02_use_cases/11_uc_adaptive_aesthetic_theming_and_user_customization.md) | `[ ] Pendiente` |
| **UC-22** | Modo de Experiencia Dual (Esencial/Pro) | UI Dual | [Ver UC-22](../02_use_cases/22_uc_dual_experience_mode.md) | `[ ] Pendiente` |
| **UC-35** | Hub de Espacios de Trabajo (Workspaces) | Proyectos | [Ver UC-35](../02_use_cases/35_uc_project_workspaces_hub.md) | `[ ] Pendiente` |
| **UC-46** | Dashboard Principal y Buscador Universal | Spotlight Hub | [Ver UC-46](../02_use_cases/46_uc_main_dashboard_navigation_and_tool_search.md) | `[ ] Pendiente` |
| **UC-56** | Taxonomía Canónica de Tareas (TTC) y Salto Rápido | Navegación 'J' | [Ver UC-56](../02_use_cases/56_uc_canonical_task_taxonomy_and_rapid_jump_system.md) | `[ ] Pendiente` |
| **UC-71** | Sistema de Diseño Atómico Pro-Studio (Estilo Adobe) | Tokens & UI Pro | [Ver UC-71](../02_use_cases/71_uc_atomized_studio_design_system_and_professional_workspace_overhaul.md) | `[ ] Pendiente` |

### 2.8 Endurecimiento Integral Pre-v1.0.0 y Certificación Final
| ID | Caso de Uso | Área Funcional | Enlace al Caso de Uso | Estado Manual |
| :---: | :--- | :--- | :--- | :---: |
| **UC-126** | Endurecimiento Wave 1: Seguridad, FS y Persistencia | Sistema & Datos | [Ver UC-126](../02_use_cases/126_uc_pre_v1_filesystem_security_package_and_persistence.md) | `[x] Verificado en Tests` |
| **UC-127** | Endurecimiento Wave 2: Audio DI, Master DSP y MPM | Audio Core & DSP | [Ver UC-127](../02_use_cases/127_uc_pre_v1_audio_di_dsp_and_pitch_engine.md) | `[x] Verificado en Tests` |
| **UC-128** | Endurecimiento Wave 3: Síntesis, Auto-Tune, REC y DJ | Síntesis & DAW | [Ver UC-128](../02_use_cases/128_uc_pre_v1_synth_autotune_recorder_and_dj.md) | `[x] Verificado en Tests` |
| **UC-129** | Endurecimiento Wave 4: SMuFL, Parsers, Foco y Pedagogía | Notación & UX | [Ver UC-129](../02_use_cases/129_uc_pre_v1_notation_importers_shell_and_pedagogy.md) | `[x] Verificado en Tests` |
| **UC-130** | Endurecimiento Wave 5: Clean Architecture y Logs | Arquitectura & DIP | [Ver UC-130](../02_use_cases/130_uc_pre_v1_clean_architecture_and_modularization.md) | `[x] Verificado en Tests` |
| **UC-131** | Endurecimiento Wave 6: Empaquetado Multiplataforma | Packaging & Final Gate | [Ver UC-131](../02_use_cases/131_uc_pre_v1_multiplatform_packaging_native_permissions_and_final_gate.md) | `[x] Verificado en Tests` |
| **UC-132** | Certificación de Release Oficial v1.0.0 y QA Manual | Release & Gobernanza | [Ver UC-132](../02_use_cases/132_uc_v1_0_0_official_release_and_manual_qa_certification.md) | `[ ] En Ejecución` |

---

## 3. Bitácora de Campo Consolidada (Registro de Evaluaciones)

| Fecha | Escenario Evaluado | Tester | Dispositivo & SO | Configuración Audio | Veredicto | Hallazgos, Comentarios o Anotaciones |
| :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **2026-11-19** | Batería Completa (1,154 Tests) | Automated CI/CD | Linux x64 Engine | Fallback SIMD & FFI | **Aprobado (100%)** | 0 fallos, 0 regresiones. Cobertura determinista en todos los módulos. |
| *Pendiente* | 10 Escenarios Manuales | @Nicolas11Leon | Hardware Real | Micrófono Físico | *En Espera* | Protocolo documentado en `01_v1_0_0_manual_qa_validation_protocol.md`. |
