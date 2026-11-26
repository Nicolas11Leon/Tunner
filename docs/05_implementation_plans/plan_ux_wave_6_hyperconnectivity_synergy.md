# Plan de Implementacion Maestro: Hiperconectividad Pro-Studio (Ola 6: US-HC-01 a US-HC-08)

Este documento formaliza el plan maestro de ingenieria, el backlog canonico y la hoja de ruta paso a paso para la Ola 6 de Hiperconectividad Pro-Studio en **Tunner**, completando la interconexion full-duplex entre el Inspector Contextual, la Boveda Multimedia, el Rack Modular, el Coordinador de Partituras, la Consola DJ, el Analizador de Acordes, el Evaluador de Practica, el Entrenador Auditivo Ebbinghaus, la Grabadora y el Descompositor de Canciones.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-HC-WAVE6-HYPERCONNECTIVITY-2026-0195`
- **Titulo de la Implementacion:** `Ola 6 de Hiperconectividad Pro-Studio: Bus Inter-Herramientas, Puentes Pedagogicos y Flujos Full-Duplex Offline`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `Propuesto`
- **ADR Relacionado:**
  - [ADR 0195: Inspector Contextual Vivo y Enrutamiento por Canal desde Boveda Multimedia](../04_adrs/0195_live_contextual_inspector_and_vault_channel_routing.md)
  - [ADR 0196: Enlace Bidireccional de Smart Controls con DSP y SignalBus](../04_adrs/0196_bidirectional_smart_controls_dsp_and_signal_bus_binding.md)
  - [ADR 0197: Coordinador Unificado de Bucle A-B en Partitura y Puente de Exportacion Patchbay](../04_adrs/0197_score_ab_loop_coordinator_and_patchbay_export_bridge.md)
  - [ADR 0198: Inyeccion en Vivo de SongPackage en Consola DJ y Retorno a Boveda](../04_adrs/0198_dj_workstation_live_score_package_injection_and_vault.md)
  - [ADR 0199: Puente de Analizador de Acordes hacia Dron Armonico y Tutor de Entonacion Justa](../04_adrs/0199_chord_analyzer_to_harmonic_drone_and_ji_tutor_bridge.md)
  - [ADR 0200: Generacion de Ejercicios Remediales desde Notas Criticas del Reporte de Practica](../04_adrs/0200_remedial_drill_generation_from_practice_report_critical_notes.md)
  - [ADR 0201: Puente Adaptativo de Intervalos Vencidos Ebbinghaus en Entrenador Auditivo](../04_adrs/0201_ebbinghaus_adaptive_ear_trainer_due_intervals_bridge.md)
  - [ADR 0202: Puentes de Grabadora en 1 Clic e Ingestion de Tomas en Descompositor](../04_adrs/0202_recorder_one_click_bridges_and_decomposer_take_ingestion.md)
- **Documento Funcional Base:**
  - [Especificacion Tecnica del Bus de Hiperconectividad](../03_technical_specifications/hyperconnectivity_interoperability_bus_specification.md)
  - [UC-203 (US-HC-01)](../02_use_cases/203_uc_live_contextual_inspector_and_vault_channel_routing.md)
  - [UC-204 (US-HC-02)](../02_use_cases/204_uc_bidirectional_smart_controls_dsp_and_signal_bus_binding.md)
  - [UC-205 (US-HC-03)](../02_use_cases/205_uc_score_ab_loop_coordinator_and_patchbay_export_bridge.md)
  - [UC-206 (US-HC-04)](../02_use_cases/206_uc_dj_workstation_live_score_package_injection_and_vault.md)
  - [UC-207 (US-HC-05)](../02_use_cases/207_uc_chord_analyzer_to_harmonic_drone_and_ji_tutor_bridge.md)
  - [UC-208 (US-HC-06)](../02_use_cases/208_uc_remedial_drill_generation_from_practice_report_critical_notes.md)
  - [UC-209 (US-HC-07)](../02_use_cases/209_uc_ebbinghaus_adaptive_ear_trainer_due_intervals_bridge.md)
  - [UC-210 (US-HC-08)](../02_use_cases/210_uc_recorder_one_click_bridges_and_decomposer_take_ingestion.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Cerrar las ocho brechas de integracion inter-modulo detectadas en **Tunner** para que cualquier artefacto musical (nota detectada, acorde polifonico, toma grabada, reporte de notas criticas, partitura en vivo, intervalo vencido, mezcla DJ o ajuste macro DSP) fluya sin friccion ni reentrada manual de datos entre las distintas estaciones del estudio en arquitectura 100% local (Offline-First).

### 1.2 Backlog Canonico de la Ola 6 (`US-HC-01` a `US-HC-08`)

| ID Historia | Caso de Uso | ADR | Titulo de la Historia de Usuario | Widgets / Keys Canonicos Verificables | Suite de Pruebas Automatizadas Planificada |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `US-HC-01` | [UC-203](../02_use_cases/203_uc_live_contextual_inspector_and_vault_channel_routing.md) | [ADR 0195](../04_adrs/0195_live_contextual_inspector_and_vault_channel_routing.md) | Inspector Contextual Vivo en `MainAppShell` y Enrutamiento por Canal desde Boveda Multimedia | `live_contextual_inspector_content`, `inspector_quick_route_patchbay_btn`, `vault_channel_routing_selector` | `test/core/navigation/us_hc_01_live_contextual_inspector_and_vault_routing_test.dart` |
| `US-HC-02` | [UC-204](../02_use_cases/204_uc_bidirectional_smart_controls_dsp_and_signal_bus_binding.md) | [ADR 0196](../04_adrs/0196_bidirectional_smart_controls_dsp_and_signal_bus_binding.md) | Vinculacion Bidireccional de las 6 Macro-Perillas Smart Controls con DSP y `SignalBus` | `studio_smart_controls_macro_bar`, `smart_control_noise_gate_knob`, `smart_control_drone_mix_knob`, `smart_control_retune_speed_knob`, `smart_control_room_reverb_knob` | `test/features/modular_rack/us_hc_02_bidirectional_smart_controls_dsp_binding_test.dart` |
| `US-HC-03` | [UC-205](../02_use_cases/205_uc_score_ab_loop_coordinator_and_patchbay_export_bridge.md) | [ADR 0197](../04_adrs/0197_score_ab_loop_coordinator_and_patchbay_export_bridge.md) | Coordinacion Real de Bucle A-B en `TunerViewModel` y Puente Multi-Canal Patchbay / Exportacion | `btn_set_loop_point_a`, `btn_set_loop_point_b`, `btn_score_patchbay_channel_selector`, `btn_export_ab_loop_segment` | `test/features/workspaces/us_hc_03_score_ab_loop_coordinator_and_patchbay_bridge_test.dart` |
| `US-HC-04` | [UC-206](../02_use_cases/206_uc_dj_workstation_live_score_package_injection_and_vault.md) | [ADR 0198](../04_adrs/0198_dj_workstation_live_score_package_injection_and_vault.md) | Inyeccion en Vivo de `workspaceScores` en Consola DJ y Exportacion Directa de Mezclas a Boveda | `dj_loader_workspace_scores_tab`, `dj_loader_media_vault_tab`, `dj_export_mix_to_vault_btn` | `test/features/dj_console/us_hc_04_dj_live_score_injection_and_vault_export_test.dart` |
| `US-HC-05` | [UC-207](../02_use_cases/207_uc_chord_analyzer_to_harmonic_drone_and_ji_tutor_bridge.md) | [ADR 0199](../04_adrs/0199_chord_analyzer_to_harmonic_drone_and_ji_tutor_bridge.md) | Puentes en 1 Clic desde `ChordAnalyzerModal` hacia `HarmonicDroneModal` y `HarmonicTutorModal` | `chord_to_harmonic_drone_btn`, `chord_to_ji_tutor_btn` | `test/features/chord_analyzer/us_hc_05_chord_to_harmonic_drone_and_ji_tutor_bridge_test.dart` |
| `US-HC-06` | [UC-208](../02_use_cases/208_uc_remedial_drill_generation_from_practice_report_critical_notes.md) | [ADR 0200](../04_adrs/0200_remedial_drill_generation_from_practice_report_critical_notes.md) | Generacion Determinista de Ejercicios Remediales desde `criticalNotes` de `PracticeReportModal` | `report_generate_remedial_drill_btn` | `test/features/practice_evaluator/us_hc_06_remedial_drill_from_critical_notes_test.dart` |
| `US-HC-07` | [UC-209](../02_use_cases/209_uc_ebbinghaus_adaptive_ear_trainer_due_intervals_bridge.md) | [ADR 0201](../04_adrs/0201_ebbinghaus_adaptive_ear_trainer_due_intervals_bridge.md) | Seleccion Adaptativa de Intervalos Vencidos Ebbinghaus en `BlindEarTrainerModal` | `ear_trainer_ebbinghaus_adaptive_toggle`, `ear_trainer_due_count_badge` | `test/features/ear_training/us_hc_07_ebbinghaus_adaptive_ear_trainer_bridge_test.dart` |
| `US-HC-08` | [UC-210](../02_use_cases/210_uc_recorder_one_click_bridges_and_decomposer_take_ingestion.md) | [ADR 0202](../04_adrs/0202_recorder_one_click_bridges_and_decomposer_take_ingestion.md) | Puentes de Grabadora en 1 Clic (Descompositor / Boveda / DJ) e Ingestion de Tomas Activas | `recorder_send_to_decomposer_btn`, `recorder_send_to_media_vault_btn`, `recorder_send_to_dj_deck_btn`, `decomposer_ingest_active_take_btn` | `test/features/practice_recorder/us_hc_08_recorder_bridges_and_decomposer_ingestion_test.dart` |

### 1.3 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Puesta en marcha de `rightInspectorContent` en `MainAppShell` y ruteo por canal en `MediaVaultViewModel` (`US-HC-01`).
  - Sincronizacion bidireccional de las 6 macro-perillas de `StudioSmartControlsMacroBar` con `TunerViewModel` y `ModularRackViewModel.signalBus` (`US-HC-02`).
  - Respeto al rango `[M_A, M_B]` de `ScorePlaybackCoordinator` en el bucle de `TunerViewModel` y seleccion de canal/exportacion en `CompositionNotationWorkspaceView` (`US-HC-03`).
  - Inyeccion de `SongPackage` vivos en `DjConsoleViewModel` / `DjTrackLoaderModal` y persistencia de mezclas en `MediaVaultViewModel` (`US-HC-04`).
  - Mapeo puro y botones de puente desde `ChordAnalyzerModal` hacia `HarmonicDroneModal` y `HarmonicTutorViewModel` (`US-HC-05`).
  - Metodo `generateRemedialDrillFromCriticalNotes` en `AlgorithmicExerciseGenerator` y disparador en `PracticeReportModal` (`US-HC-06`).
  - Adaptador de cola vencida `EbbinghausSpacedRepetitionEngine` en `BlindEarTrainerModal` y `BlindEarTrainerEngine` (`US-HC-07`).
  - Puentes de despacho de `PracticeRecordingEntity` desde `PracticeRecordingPlayerModal` / `PracticeRecorderDock` hacia `SongDecomposerModal`, `MediaVaultViewModel` y `DjConsoleViewModel` (`US-HC-08`).
- **Excluido (Out-of-Scope):**
  - Microservicios remotos, sincronizacion en la nube o telemetria externa (prohibido por [AGENTS.md](../../AGENTS.md)).
  - Cambios en los algoritmos nativos C/Rust de deteccion YIN/MPM o en la tipografia vectorial SMuFL base.

---

## 2. Analisis de Dependencias y Tecnologias

- **Versiones de Librerias / SDKs:**
  - Dart SDK: `^3.11.x` (null-safety estricto, entidades inmutables en `domain/`).
  - Flutter SDK: Canal estable oficial para Linux y Windows Desktop.
  - Gestion de estado: `provider`, `ChangeNotifier` y `ValueListenable` sin introducir dependencias externas nuevas.
- **Riesgo Tecnologico:**
  - **Introduce dependencias nativas o FFI?** No. Toda la capa de puentes y adaptadores se implementa en Pure Dart y composicion de ViewModels existentes.
  - **Afecta el rendimiento del bucle principal de Flutter?** No; las actualizaciones cruzan el bus mediante eventos discretos con guardas anti-reentrancia (`sourceId` y `_isSyncingFromBus`) y sintesis pesada aislada fuera del hilo de pintura.

---

## 3. Plan Paso a Paso de Ejecucion (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matematicos y Adaptadores Puros)
- [ ] Ampliar `MediaSynergyTarget` (`lib/features/media_vault/domain/media_synergy_target.dart`) con soporte explicito para enrutamiento por canal de Patchbay.
- [ ] Crear `ChordHarmonicBridgeMapper` (`lib/features/chord_analyzer/domain/`) para traducir `ChordEntity` a `HarmonicDroneConfig` y contexto `HarmonicTutorSessionEntity`.
- [ ] Implementar `AlgorithmicExerciseGenerator.generateRemedialDrillFromCriticalNotes` (`lib/features/exercise_generator/domain/algorithmic_exercise_generator.dart`).
- [ ] Implementar el adaptador de intervalos vencidos de `EbbinghausSpacedRepetitionEngine` (`lib/features/ear_training/domain/`).
- [ ] Definir los contratos de conversion de `PracticeRecordingEntity` hacia ingestion del descompositor y activos de boveda.

### Paso 2: Capa de Infraestructura / Orquestacion de Buses y ViewModels
- [ ] Conectar `MainAppShell` con `StudioPatchbayRoutingService` para despachar activos de `MediaVaultViewModel` a canales nombrados (`canal_a`..`canal_d` y personalizados).
- [ ] Vincular bidireccionalmente `ModularRackViewModel` (`signalBus`) y `TunerViewModel` para los 6 parametros de `StudioSmartControlsMacroBar`.
- [ ] Unificar el avance de compas de `TunerViewModel` con `ScorePlaybackCoordinator.isMeasureLoopActive`, `loopStartMeasureIndex` y `loopEndMeasureIndex`.
- [ ] Agregar `DjConsoleViewModel.injectSongPackageToDeck` y exportacion directa de `_lastRecordedWavBytes` hacia `MediaVaultViewModel`.

### Paso 3: Capa de Presentacion (Inspector, Barras Macro y Puentes en 1 Clic)
- [ ] Implementar la construccion contextual de `rightInspectorContent` por pestana en `MainAppShell` (`US-HC-01`).
- [ ] Completar el enlace bidireccional de las 6 perillas en `StudioSmartControlsMacroBar` (`US-HC-02`).
- [ ] Agregar selector de canal de Patchbay y exportacion de bucle A-B en `CompositionNotationWorkspaceView` (`US-HC-03`).
- [ ] Agregar pestanas de `workspaceScores` y `MediaVault` en `DjTrackLoaderModal` y boton de exportacion a boveda en `DjStudioWorkstationView` (`US-HC-04`).
- [ ] Agregar los botones `chord_to_harmonic_drone_btn` y `chord_to_ji_tutor_btn` en `ChordAnalyzerModal` (`US-HC-05`).
- [ ] Agregar `report_generate_remedial_drill_btn` en `PracticeReportModal` (`US-HC-06`).
- [ ] Integrar `ear_trainer_ebbinghaus_adaptive_toggle` y `ear_trainer_due_count_badge` en `BlindEarTrainerModal` (`US-HC-07`).
- [ ] Incorporar los puentes en 1 clic en `PracticeRecordingPlayerModal`, `PracticeRecorderDock` y `SongDecomposerModal` (`US-HC-08`).

### Paso 4: Pruebas, Verificacion y Limpieza
- [ ] Implementar y ejecutar las 8 suites `us_hc_01` a `us_hc_08` con cobertura de dominio $\ge 90\%$.
- [ ] Ejecutar las suites de regresion de la Ola 5 (`us_ux_05` a `us_ux_10`) y canales Patchbay (`studio_patchbay_test.dart`).
- [ ] Ejecutar `flutter analyze --no-fatal-infos` verificando `0 issues`.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

Cada historia `US-HC-01` a `US-HC-08` se disena como extension aditiva y desacoplada sobre los ViewModels y modales actuales:
- **Punto de Restauracion Git:** Commit base estable posterior al cierre de la Ola 5 (`US-UX-05` a `US-UX-10`).
- **Mitigacion Inmediata:**
  - En `US-HC-01`, `rightInspectorContent` sigue siendo opcional en `StudioDesktopAppShell`; si ocurre regresion visual, `MainAppShell` puede devolver `null`.
  - En `US-HC-02`, las guardas `_isSyncingFromBus` permiten aislar el enlace DSP sin romper la edicion manual de perillas.
  - En `US-HC-03`, si `isMeasureLoopActive` es `false`, `TunerViewModel` mantiene exactamente la aritmetica modular previa `(_currentMeasureIndex + 1) % maxMeasures`.
  - En `US-HC-04` a `US-HC-08`, todos los puentes son disparadores explicitos de UI en 1 clic o modos conmutables (`ear_trainer_ebbinghaus_adaptive_toggle`), conservando intactos los flujos clasicos preexistentes.

---

## 5. Criterios de Aceptacion (Definition of Done)

Para que este plan se considere completado y listo para merge:
- [ ] Codigo adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md) (Pure Dart en dominio, Offline-First, cero emojis en documentacion).
- [ ] Cero `busy-waiting` loops en Isolates, timers de reloj y buses de eventos.
- [ ] Las 8 suites de pruebas (`us_hc_01` a `us_hc_08`) y suites de regresion pasando al 100%.
- [ ] `flutter analyze --no-fatal-infos` sin advertencias ni errores.
- [ ] Los 8 ADRs (`0195` a `0202`), los 8 Casos de Uso (`203` a `210`) y la Especificacion Tecnica de Hiperconectividad aprobados y verificados en `docs/`.
- [ ] Aprobacion explicita del creador/mantenedor principal.
