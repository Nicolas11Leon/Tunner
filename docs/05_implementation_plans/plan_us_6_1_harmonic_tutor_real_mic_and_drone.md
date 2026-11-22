# Plan de Implementacion US-6.1: HarmonicTutorModal sin Simulacion y Conectado en Vivo

- **Issue:** #163
- **Caso de Uso:** `UC-168` (`docs/02_use_cases/168_uc_harmonic_tutor_real_mic_and_drone.md`)
- **ADR:** `ADR-0160` (`docs/04_adrs/0160_harmonic_tutor_live_telemetry_and_drone_synth_wiring.md`)
- **Rama:** `feature/us-6.1-harmonic-tutor-real-mic-and-drone`
- **Base:** `qa`
- **Estado:** Completado (Validado con `flutter analyze --no-fatal-infos` 0 issues y 19/19 tests aprobados)

## 1. Objetivo

Eliminar la tarjeta de simulacion en `HarmonicTutorModal`, sustituirla por control de microfono en vivo, y conectar `HarmonicTutorViewModel` a `TunerViewModel.telemetryListenable` y `TunerViewModel.audioSynthesizer` desde `ToolSearchModal`.

## 2. Archivos a Modificar

1. `lib/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart`
   - Agregar parametros opcionales `bool Function()? isMicrophoneActive` y `Future<void> Function()? onToggleMicrophone`.
   - Reemplazar `'SIMULACIÓN DE PRÁCTICA AUDITIVA'` y sus 3 botones por `'CAPTURA ACÚSTICA EN VIVO (MICRÓFONO)'`.
2. `lib/features/navigation/presentation/tool_search_modal.dart`
   - Conectar `onPlayDroneSamples` (codificando WAV con `WavPcmCodec` -> `audioSynthesizer.startDroneLoop`), `onStopDrone` (`audioSynthesizer.stopDroneLoop`), suscripcion a `telemetryListenable` y limpieza en `whenComplete`.
   - Pasar `isMicrophoneActive: () => widget.viewModel.isRecording` y `onToggleMicrophone: widget.viewModel.toggleRecording`.
3. `test/features/harmonic_tutor/presentation/harmonic_tutor_ui_test.dart`
   - Actualizar referencias a los botones eliminados y verificar la nueva tarjeta de microfono en vivo.
4. `test/features/harmonic_tutor/us_6_1_harmonic_tutor_live_wiring_test.dart`
   - Verificar ausencia de botones de simulacion, suscripcion a `telemetryListenable` y disparo de `startDroneLoop`/`stopDroneLoop`.

## 3. Criterios de Verificacion

- `flutter analyze --no-fatal-infos` -> `No issues found!`
- `flutter test --no-pub test/features/harmonic_tutor/ test/core/architecture/arch_1_clean_architecture_boundaries_test.dart` -> 100% aprobado.
