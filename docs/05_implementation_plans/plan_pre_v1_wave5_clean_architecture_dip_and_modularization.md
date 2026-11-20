# Plan de Implementación: Ola 5 - Clean Architecture Estricta, Inversión de Dependencias (DIP) y Descomposición Modular

## 1. Identificador
`PLAN-PRE-V1-WAVE5-CLEAN-ARCH-2026-005`

## 2. Objetivos
1. Erradicar importaciones directas de `presentation -> data/infra` en los módulos `harmonic_tutor`, `song_library`, `media_vault`, `instrument`, `dj_console`, `modular_rack` y `core/channels`.
2. Eliminar importaciones de `dart:io`, `file_picker` y `path_provider` en widgets de presentación (`media_vault_workspace_modal.dart`, `dj_track_loader_modal.dart`, `rack_unit_card.dart`, `multitask_master_console_widget.dart`).
3. Reemplazar los 15 bloques `catch (_) {}` vacíos restantes por captura defensiva con registro en `StudioDebugLogger.instance`.
4. Migrar llamadas dispersas de `debugPrint` hacia `IStudioLogger`.
5. Reubicar o proveer contratos canónicos y re-exports para `tuner_viewmodel.dart`, `tuner_screen.dart` y `tunner_theme.dart`.
6. Garantizar `flutter analyze --no-fatal-infos` con 0 problemas y suite `flutter test` al 100% en verde.

## 3. Plan Paso a Paso

### Paso 1: Reubicación y Abstracción de Catálogos y Motores Puros en Dominio
- Mover/exponer `DjHardwareCatalog` en `lib/features/dj_console/domain/` con re-export en `data/`.
- Mover/exponer `ProceduralInstrumentSynthesizer` en `lib/features/instrument/domain/` con re-export en `data/`.
- Mover/exponer `HarmonicReferenceSynth` en `lib/features/harmonic_tutor/domain/` con re-export en `data/`.
- Exponer interfaz o puerto de repositorio para `SongDecomposerService` y mover `SongDecompositionTemplate` a `domain/`.
- Definir puerto de enrutamiento `IStudioPatchbayRouter` en `lib/core/channels/domain/` implementado por `StudioPatchbayRoutingService`.

### Paso 2: Desacoplar I/O de Presentación
- En `MediaVaultWorkspaceModal`: extraer la lógica de selector de archivos y persistencia de exportación a `MediaVaultViewModel` utilizando `IPlatformFileGateway` o delegación limpia.
- En `DjTrackLoaderModal`: abstraer la selección de archivo mediante el gateway o ViewModel.
- En `RackUnitCard` y `MultitaskMasterConsoleWidget`: retirar `import 'dart:io'` y usar paths gestionados por el ViewModel.

### Paso 3: Erradicar Bloques `catch (_) {}` y Migrar Logs
- Reemplazar bloques de captura vacíos en `AppUserSettingsEntity`, `DjKeymapPersistenceService`, `DjConsoleBlueprintStorageService`, `LocalDiskStudioFileSystemRepository` y `TunerViewModel`.
- Actualizar llamadas críticas de diagnóstico para utilizar `StudioDebugLogger.instance`.

### Paso 4: Pruebas y Verificación
- Crear `test/features/architecture/wave5_clean_architecture_and_dip_hardening_test.dart` verificando que no existan violaciones en las capas modificadas y comprobando la integridad de DI y puertos.
- Ejecutar `flutter analyze --no-fatal-infos` (0 issues).
- Ejecutar suite de pruebas de regresión.
