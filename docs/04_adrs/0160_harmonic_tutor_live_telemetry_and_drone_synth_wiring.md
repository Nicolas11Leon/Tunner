# ADR-0160: Conexion en Tiempo Real de HarmonicTutorModal a TelemetryListenable y AudioSynthesizer

- **Estado:** Aceptado
- **Fecha:** 2026-11-22
- **Historia de Usuario:** US-6.1 (EPIC-06)
- **Issue:** #163

## Contexto

`HarmonicTutorModal` incluia en produccion una tarjeta `'SIMULACIÓN DE PRÁCTICA AUDITIVA'` con 3 botones de frecuencia simulada (`sim_3rd_tempered_btn`, `sim_3rd_just_btn`, `sim_5th_just_btn`), y `ToolSearchModal` instanciaba `HarmonicTutorViewModel()` sin callbacks de audio ni suscripcion al micrófono real de `TunerViewModel`.

## Decision

1. **Eliminacion total de botones de simulacion en produccion:** Reemplazar la tarjeta de simulacion en `HarmonicTutorModal` por un panel de captura acustica en vivo con estado del microfono (`isMicrophoneActive`), frecuencia en Hz detectada y accion `onToggleMicrophone`.
2. **Enlace reactivo sin acoplar el dominio de `harmonic_tutor`:** Mantener `HarmonicTutorViewModel` desacoplado de `TunerViewModel` mediante sus callbacks `onPlayDroneSamples` / `onStopDrone`, y realizar el cableado completo en `ToolSearchModal` conectando `TunerViewModel.telemetryListenable` y `TunerViewModel.audioSynthesizer` (`WavPcmCodec` -> `startDroneLoop` / `stopDroneLoop`).

## Consecuencias

- **Positivas:**
  - Cero botones de simulacion en UI de produccion.
  - Aguja de batimiento y dron guia 100% funcionales con microfono y sintetizador real.
  - Desuscripcion y limpieza automatica de listeners al cerrar el modal.
- **Negativas / Compensaciones:**
  - Se actualiza `test/features/harmonic_tutor/presentation/harmonic_tutor_ui_test.dart` para probar el gauge mediante `viewModel.onPitchDetected(...)` en lugar de los botones de simulacion removidos.
