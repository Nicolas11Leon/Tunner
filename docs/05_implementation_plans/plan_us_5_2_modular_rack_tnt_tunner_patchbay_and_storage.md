# Plan de Implementacion US-5.2: Importacion/Carga .tnt y .tunner, Patchbay con Foco/Sinergia y Almacenamiento Real

- **Issue:** #157
- **Caso de Uso:** `UC-165` (`docs/02_use_cases/165_uc_modular_rack_tnt_tunner_patchbay_and_storage.md`)
- **ADR:** `ADR-0157` (`docs/04_adrs/0157_modular_rack_tnt_tunner_patchbay_synergy_and_di_storage.md`)
- **Rama:** `feature/us-5.2-modular-rack-tnt-tunner-patchbay-and-storage`
- **Base:** `qa`
- **Estado:** Completado (Validado con `flutter analyze --no-fatal-infos` 0 issues y 72/72 tests aprobados)

## 1. Objetivo

Completar el ciclo real de persistencia de proyectos `.tunner` y herramientas `.tnt`, activar el parametro `focusPort` y la retroalimentacion de `SynergyPolicyEngine` en `StudioPatchbayModal`, y asegurar que `ModularStudioRackView` use `LocalProjectStorageRepository` mediante `StudioCompositionRoot`.

## 2. Archivos a Modificar

1. `lib/features/modular_rack/presentation/modular_rack_viewmodel.dart`
   - Agregar `IPlatformFileGateway? fileGateway` opcional en constructor.
   - Implementar `pickAndLoadProject()` y `pickAndImportToolPreset()` con extensiones `['tunner']` y `['tnt']`.
   - Resolver ruta de guardado por defecto usando `fileGateway.getDocumentsDirectoryPath()` cuando este disponible.
2. `lib/app/studio_composition_root.dart`
   - Inyectar `fileGateway: platformFileGateway` en `createModularRackViewModel()`.
3. `lib/features/modular_rack/presentation/modular_studio_rack_view.dart`
   - Resolver `StudioCompositionRoot` en el `create` del `ChangeNotifierProvider` (con try/catch fallback para tests aislados).
4. `lib/features/modular_rack/presentation/multitask_master_console_widget.dart`
   - Agregar opcion `'load_project'` (`Cargar Proyecto (.tunner)`) al menu de proyectos.
   - Reemplazar el dialogo informativo `_showImportToolDialog` y agregar `_showLoadProjectDialog` con boton de explorador nativo (`pickAndImportToolPreset` / `pickAndLoadProject`) y campo de ruta manual (`importToolPresetFromFile` / `loadProjectFromFile`), con manejo de errores via `SnackBar`.
5. `lib/features/modular_rack/presentation/studio_patchbay_modal.dart`
   - Resaltar y priorizar salidas/entradas vinculadas a `focusPort`.
   - Evaluar `SynergyPolicyEngine.validateConnection(sourcePort: outPort, destinationPort: inp)` para diferenciar visualmente rutas aprobadas, hiper-sinergias y rutas rechazadas (`rejectionReason` / `pedagogicalNote`).
6. Pruebas: `test/features/modular_rack/us_5_2_modular_rack_persistence_and_patchbay_test.dart`

## 3. Criterios de Verificacion

- `flutter analyze --no-fatal-infos` -> `No issues found!`
- `flutter test --no-pub test/features/modular_rack/ test/core/architecture/arch_1_clean_architecture_boundaries_test.dart` -> 100% aprobado.
