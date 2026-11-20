# Plan de Implementacion: Ola UX-3 (Interaccion Tactil, Editor de Partituras, Superficies Rack y Grabadora)

## 1. Objetivos y Alcance
Remediar las fallas de interaccion directa por clic y tactil descritas en el Issue #102:
- Corregir el enlace de grabacion de audio en `MultitaskMasterConsoleWidget` y `QuickActionDockWidget` hacia `isAudioRecording`.
- Enlazar la reproduccion audible en `selectAndPreviewScoreNote` de `TunerViewModel`.
- Mejorar `ScoreEditorModal` (auto-avance de ticks al insertar y altura ergonomica con previsualizacion grafica).
- Conectar reproduccion de audio en las superficies de instrumentos del Rack Modular (`InstrumentEmulationSurfaceWidget` / `RackUnitCard`).
- Implementar toggle limpio y aislamiento acustico para el tono de referencia La4.
- Redirigir el modal de stems en la pestana de partituras a `StemMixerModal`.

## 2. Archivos Afectados
- `lib/features/modular_rack/presentation/multitask_master_console_widget.dart`
- `lib/features/navigation/presentation/quick_action_dock_widget.dart`
- `lib/features/tuner_viewmodel.dart`
- `lib/features/score_editor/presentation/score_editor_modal.dart`
- `lib/features/modular_rack/presentation/instrument_emulation_surface_widget.dart`
- `lib/features/modular_rack/presentation/rack_unit_card.dart`
- `lib/features/navigation/presentation/main_app_shell.dart`
- `test/features/instrument/ux_wave_3_tactile_and_recorder_test.dart`

## 3. Plan de Verificacion
- Ejecutar `flutter test test/features/instrument/ux_wave_3_tactile_and_recorder_test.dart`.
- Ejecutar `flutter analyze --no-fatal-infos`.
- Ejecutar suite completa `flutter test --no-pub`.
