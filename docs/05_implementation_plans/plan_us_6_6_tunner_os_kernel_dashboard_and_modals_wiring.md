# Plan de Implementación US-6.6: TunnerOsKernel, Dashboard HUD, ToolSearchModal y ExerciseGenerator

- **Issue:** #173
- **Estado:** Completado
- **Casos de Uso:** UC-155
- **ADR:** ADR-0147

## Tareas Técnicas
1. Extender `TunnerOsKernel` con persistencia real en `fileSystemRepository` para `project export` y `vocal cert`, audio real en `synth note` (`onTriggerSynthNote`) y lectura de captura real en `vocal eval`/`cert`.
2. Inyectar `inputEngine`, `outputEngine`, `fileSystemRepository` y puertos de audio/captura desde `MainAppShell`.
3. Enlazar HUD de latencia/búfer en `HomeDashboardScreen` y `StudioDesktopAppShell` a `AudioDeviceMatrixEntity`, y conectar plantillas `template_score_bach`, `template_dj_elisa` y `template_take_acoustic`.
4. Abrir `SpectralComparatorModal` y `HarmonicDroneModal` en `ToolSearchModal`.
5. Añadir `ExerciseRhythm.half` y `ExerciseRhythm.whole` en `ExerciseGeneratorModal`, registrar ejercicio generado en `workspaceScores` dentro de `TunerViewModel.generateAndLoadExercise` y navegar al Tab 4 (Atril).
6. Verificar con `flutter analyze`, tests unitarios/widget en `test/features/navigation/us_6_6_kernel_dashboard_and_modals_test.dart` y `arch_1_clean_architecture_boundaries_test.dart`.
