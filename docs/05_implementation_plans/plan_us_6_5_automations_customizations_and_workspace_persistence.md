# Plan de Implementación US-6.5: Automatizaciones, Customización y Persistencia de Workspaces

- **Issue:** #171
- **Estado:** Completado
- **Casos de Uso:** UC-154
- **ADR:** ADR-0146

## Tareas Técnicas
1. Extender `AppUserSettingsEntity` con `dspEngineName`, `targetRenderFps`, `centsPrecision` y `workspaceConfiguration`.
2. Actualizar `TunerViewModel`:
   - `armAutoRecord()` / `disarmAutoRecord()` con disparo por `rms >= 0.03` en `onRmsLevelChanged`.
   - `startGuidedWarmupRoutine()` con `Timer.periodic` de 300 s en círculo de quintas (12 pasos de 25 s).
   - `updateStudioCustomizations(...)` y `updateWorkspaceConfiguration(...)` con carga/guardado en `AppUserSettingsEntity`.
3. Corregir `StudioAutomationsModal` (SnackBars no invertidos y botón de armar/desarmar auto-grabación).
4. Conectar `StudioCustomizationsModal` a `TunerViewModel.updateStudioCustomizations`.
5. Aplicar `viewModel.workspaceConfiguration` en `LearningPracticeWorkspaceView`, `CompositionNotationWorkspaceView` y `ProductionAcousticLabWorkspaceView`.
6. Añadir pruebas unitarias y de widget en `test/features/workspaces/us_6_5_automations_customizations_and_workspace_test.dart`.
