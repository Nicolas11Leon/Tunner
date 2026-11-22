# ADR-0139: Persistencia Real .tnt/.tunner, Pre-validacion de Sinergia en Patchbay y Resolucion DI en ModularStudioRackView

- **Estado:** Aceptado
- **Fecha:** 2026-11-22
- **Historia de Usuario:** US-5.2 (EPIC-05)
- **Issue:** #157

## Contexto

En la auditoria forense del modulo `modular_rack` se detectaron tres brechas funcionales:
1. `MultitaskMasterConsoleWidget` no permitia cargar proyectos `.tunner` desde el menu y su dialogo de importacion `.tnt` era meramente informativo sin invocar `importToolPresetFromFile`.
2. `StudioPatchbayModal` declaraba el parametro `focusPort` pero lo ignoraba en `build()`, y no consultaba `SynergyPolicyEngine.validateConnection` para exponer visualmente conflictos pedagogicos (`rejectionReason`) o hiper-sinergias (`pedagogicalNote`).
3. `ModularStudioRackView` instanciaba `ModularRackViewModel()` directamente cuando `viewModel == null`, cayendo en `NoOpProjectStorageRepository` aunque `StudioCompositionRoot` ya disponia de `createModularRackViewModel()` con `LocalProjectStorageRepository`.

## Decision

1. **Abstraccion de selector de archivos en Domain:** Inyectar `IPlatformFileGateway?` opcional en `ModularRackViewModel` (provisto por `StudioCompositionRoot.createModularRackViewModel()`) y exponer `pickAndLoadProject()` y `pickAndImportToolPreset()` junto con soporte de ruta explicita para entornos headless/CLI.
2. **Resolucion de dependencias en Presentation sin violar Clean Architecture:** En `ModularStudioRackView`, resolver `StudioCompositionRoot` via `context.read<StudioCompositionRoot>()` dentro de un bloque controlado (sin importar `data/` desde `presentation/`), manteniendo el fallback a `ModularRackViewModel()` unicamente cuando no exista `StudioCompositionRoot` en el arbol (como en pruebas unitarias de widgets aisladas).
3. **Pre-validacion reactiva en `StudioPatchbayModal`:** Reordenar y destacar el bloque correspondiente a `focusPort` y evaluar cada pareja salida-entrada con `SynergyPolicyEngine.validateConnection` para presentar retroalimentacion visual y textual inmediata.

## Consecuencias

- **Positivas:**
  - Persistencia real en disco para proyectos `.tunner` y presets `.tnt` desde la UI de estudio.
  - Cumplimiento estricto de las fronteras de Clean Architecture (`arch_1_clean_architecture_boundaries_test.dart`).
  - Transparencia pedagogica y acustica en el Patchbay antes de intentar conexiones bloqueadas.
- **Negativas / Compensaciones:**
  - En pruebas de widget sin `StudioCompositionRoot`, el fallback sigue usando `NoOpProjectStorageRepository` salvo que se inyecte un `ModularRackViewModel` configurado en el test.
