# ADR-0146: Persistencia de Customizaciones DSP, Configuración de Workspaces y Automatizaciones Reales

- **Estado:** Aceptado
- **Fecha:** 2026-11-22
- **Historia de Usuario:** US-6.5

## Contexto
`StudioAutomationsModal` evaluaba `isBpmRampActive` e `isWarmupActive` después de mutar el estado, generando mensajes invertidos en los `SnackBar`. Además, la opción "Armar Auto-Grabación" iniciaba la grabación inmediatamente sin esperar señal acústica, `startGuidedWarmupRoutine` no tenía temporizador de 5 minutos ni progresión por círculo de quintas, `StudioCustomizationsModal` no persistía sus valores en `AppUserSettingsEntity`, y `WorkspaceConfigurationEntity` no estaba enlazado a la persistencia ni a la visibilidad de paneles en las vistas de Workspace.

## Decisión
1. Extender `AppUserSettingsEntity` con `dspEngineName`, `targetRenderFps`, `centsPrecision` y `workspaceConfiguration` (`WorkspaceConfigurationEntity?`).
2. Exponer `updateStudioCustomizations` y `updateWorkspaceConfiguration` en `TunerViewModel`, restaurándolos en `loadPersistedState` y guardándolos en `_triggerAutoSave`.
3. Implementar `_isAutoRecordArmed` con disparo automático en `onRmsLevelChanged` cuando `rms >= 0.03` (sin busy-waiting).
4. Implementar temporizador de 300 s (`Timer.periodic` de 1 s) en `startGuidedWarmupRoutine` rotando las 12 tonalidades del círculo de quintas cada 25 s.
5. Enlazar `workspaceConfiguration` para controlar la visibilidad de paneles en `LearningPracticeWorkspaceView`, `CompositionNotationWorkspaceView` y `ProductionAcousticLabWorkspaceView`.

## Consecuencias
- **Positivas:** Estado 100% persistente entre sesiones, UX consistente en automatizaciones sin mensajes invertidos y cero bucles activos.
- **Neutras:** `AppUserSettingsEntity.fromMap` mantiene retrocompatibilidad con archivos JSON previos usando valores por defecto.
