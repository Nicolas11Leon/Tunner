# Plan de Implementacion US-6.2: Evaluacion Medida, Reportes Reales y Clasificador Armonico DFT

- **Issue:** #165
- **Rama:** `feature/us-6.2-real-pedagogy-timing-and-harmonic-classifier`
- **Base:** `qa`
- **Estado:** Completado (Validado con `flutter analyze --no-fatal-infos` 0 issues y 49/49 tests aprobados)

## 1. Objetivo

Reemplazar todas las metricas sinteticas en evaluacion de practica, reportes pedagogicos, clasificador de instrumento y desglose armonico H1–H8 por mediciones reales calculadas sobre sub-ticks y `HarmonicSeriesAnalyzer`.

## 2. Archivos a Modificar

1. `lib/features/tuner/presentation/tuner_viewmodel.dart`
   - Acumular sub-ticks por nota (`_pendingEvalNote`, `_pendingFirstAttackTick`, `_pendingInTuneTicks`) y calcular `timingDeltaMs` y `sustainRatio` reales al finalizar la nota.
   - Usar `HarmonicSeriesAnalyzer` sobre `_latestAudioSamples` en `_evaluateSmartInstrumentFromPitch`.
2. `lib/features/score_editor/presentation/score_editor_controller.dart`
   - Actualizar `buildPedagogicalSessionData` para aceptar `TimbreAnalysisResult?` y `List<NoteEvaluationEntity>?`, eliminando constantes sinteticas y curva `math.sin`.
3. `lib/features/pedagogy_report/presentation/pedagogical_report_modal.dart`
   - Inicializar `_instrumentController` con `vm.activeInstrument.name` y pasar `TimbreAnalysisResult` real desde `vm.latestAudioSamples` a `buildPedagogicalSessionData`.
4. `lib/features/chord_analyzer/presentation/polyphonic_live_voicing_widget.dart`
   - Calcular alturas H1–H8 reales mediante `HarmonicSeriesAnalyzer` sobre `audioSamples` provistos.
5. Pruebas: `test/features/pedagogy_report/us_6_2_real_pedagogy_and_harmonics_test.dart`

## 3. Criterios de Verificacion

- `flutter analyze --no-fatal-infos` -> `No issues found!`
- `flutter test --no-pub test/features/pedagogy_report/ test/features/acoustic_lab/ test/features/chord_analyzer/ test/core/architecture/arch_1_clean_architecture_boundaries_test.dart` -> 100% aprobado.
