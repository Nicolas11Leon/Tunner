# Plan de Implementación: Pureza de Capas Clean Architecture e Inversión de Dependencias Estricta (ARCH-1)

## Metadatos del Plan
- **ID del Plan:** `PLAN-ARCH-1-DIP-2026-01`
- **Título de la Implementación:** `Pureza de Dominio Dart Puro, Desacoplamiento Core -> Features e Inversión DIP en Presentación`
- **Fase del Proyecto:** `Pre-Release v1.0.0 — Ola ARCH-1`
- **Estado:** `En Progreso`
- **ADR Relacionado:** `docs/04_adrs/0130_arch_1_clean_architecture_dip.md`
- **Documento Funcional Base:** `docs/02_use_cases/141_uc_arch_1_clean_architecture_dip.md`

## 1. Alcance y Objetivos de la Implementación
### 1.1 Objetivo Primario
Eliminar las 11 inversiones `core -> features`, los 3 imports de Flutter en `/domain/` y todos los imports directos `presentation -> data` sin alterar el comportamiento funcional de la aplicación ni romper las 1,205 pruebas existentes.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Contratos de dominio en `lib/core/file_system/domain/`, `lib/core/channels/domain/`, `lib/core/terminal/domain/`, `lib/features/media_vault/domain/`.
  - `studio_theme_switcher.dart`, `local_disk_studio_file_system_repository.dart`, `tunner_os_kernel.dart`.
  - `tuner_viewmodel.dart`, `media_vault_viewmodel.dart`, `main_app_shell.dart`, `studio_composition_root.dart` y los 4 modales con `PlatformFileGateway`.
  - Suite de verificación arquitectónica `test/core/architecture/arch_1_clean_architecture_boundaries_test.dart`.
- **Excluido (Out-of-Scope):**
  - Decomposición interna de `TunerViewModel` (pertenece a `ARCH-2`).
  - Refactorización de widgets monolíticos (pertenece a `ARCH-3`).

## 2. Análisis de Dependencias y Tecnologías
- **Dart / Flutter:** No se añaden dependencias externas. Todo el desacoplamiento se realiza mediante interfaces abstractas de Dart puro e inyección por constructor en `StudioCompositionRoot`.

## 3. Plan Paso a Paso de Ejecución
- [ ] **Paso 1:** Purificar `/domain/` eliminando `package:flutter/foundation.dart` de `i_studio_workspace_file_system.dart`, `i_studio_patchbay_routing_service.dart` y `studio_patchbay_routing_service.dart`.
- [ ] **Paso 2:** Desacoplar `core -> features` en `studio_theme_switcher.dart`, `local_disk_studio_file_system_repository.dart` y `tunner_os_kernel.dart`.
- [ ] **Paso 3:** Eliminar imports `presentation -> data` en `media_vault_viewmodel.dart`, los 4 modales con `PlatformFileGateway`, y `tuner_viewmodel.dart`, completando el cableado en `studio_composition_root.dart` y `main_app_shell.dart`.
- [ ] **Paso 4:** Añadir pruebas de verificación de fronteras arquitectónicas y ejecutar `flutter analyze --no-fatal-infos` + `flutter test`.

## 4. Estrategia de Rollback
- **Punto de Restauración Git:** Commit `60e92b5` en rama `qa`.
- **Mitigación:** Reversión de rama `refactor/arch-1-clean-architecture-dip` antes de merge.

## 5. Criterios de Aceptación (Definition of Done)
- [ ] Cero imports de Flutter en `/domain/`.
- [ ] Cero imports de `features/` en `lib/core/`.
- [ ] Cero imports de `data/` en `/presentation/`.
- [ ] `flutter analyze --no-fatal-infos` con 0 incidencias y suite de pruebas al 100%.
