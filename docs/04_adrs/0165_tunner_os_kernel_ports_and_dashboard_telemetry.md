# ADR-0165: Puertos de TunnerOsKernel, Telemetría Dinámica del HUD y Cableado de Modales

- **Estado:** Aceptado
- **Fecha:** 2026-11-22
- **Historia de Usuario:** US-6.6

## Contexto
`TunnerOsKernel` se instanciaba en `MainAppShell` sin `inputEngine`, `outputEngine` ni `fileSystemRepository`, dejando `io list`, `fs ls`, `project export` y `vocal cert` sin persistencia en disco ni reproducción real en `synth note`. Asimismo, `HomeDashboardScreen` y `StudioDesktopAppShell` mostraban cadenas de latencia estáticas, `ToolSearchModal` redirigía a tabs en vez de abrir `SpectralComparatorModal` y `HarmonicDroneModal`, y `ExerciseGeneratorModal` omitía `half`/`whole`, no guardaba en `workspaceScores` ni navegaba al Atril.

## Decisión
1. Inyectar `inputEngine`, `outputEngine` y `fileSystemRepository` desde `MainAppShell` hacia `TunnerOsKernel`, añadiendo puertos puros (`onTriggerSynthNote`, `onReadCapturedFrequencies`, `onReadCapturedAmplitudes`) en `lib/core/terminal/` para respetar Clean Architecture.
2. Persistir `.tunner` en `exports/` y `.pdf` en `certificates/` vía `StudioFileSystemRepository.saveFile`.
3. Calcular latencia y búfer en `HomeDashboardScreen` y `StudioDesktopAppShell` a partir de `AudioDeviceMatrixEntity` (`bufferSize / sampleRate * 1000`).
4. Conectar las tarjetas de plantilla del Dashboard, abrir `SpectralComparatorModal`/`HarmonicDroneModal` en `ToolSearchModal` y completar `ExerciseGeneratorModal` (`half`/`whole`, `workspaceScores`, navegación a Tab 4).

## Consecuencias
- **Positivas:** Termina el cableado de extremo a extremo de la plataforma sin dependencias inversas entre `core/` y `features/`.
- **Neutras:** Todos los puertos nuevos son opcionales para mantener compatibilidad con pruebas aisladas.
