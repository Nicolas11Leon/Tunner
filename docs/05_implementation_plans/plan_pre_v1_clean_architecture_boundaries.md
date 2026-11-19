# Implementation Plan: Purificación de Capa Domain y Desacoplamiento Core <-> Features (Ola 2)

**Issue Asociado:** #69 (Pre-v1.0.0 - Ola 2)  
**Rama:** `refactor/pre-v1-clean-architecture-boundaries`  
**Rama Base:** `qa`  
**Fecha:** `2026-11-19`  

---

## 1. Resumen y Objetivos

Eliminar el 100% de las importaciones de Flutter en `**/domain/**`, las inversiones `Core -> Features`, las importaciones `Domain -> Infrastructure` y `Infrastructure -> Presentation`, y reubicar archivos sueltos en sus capas canónicas.

---

## 2. Tareas de Implementación

- [ ] **Paso 1 (`meta` y `@immutable`):** Añadir `meta: ^1.17.0` en `pubspec.yaml` y migrar `studio_file_system_node.dart`, `patchbay_routing_connection.dart`, `tunner_project_package.dart` y `tunner_tool_preset.dart`.
- [ ] **Paso 2 (`Color` / `IconData` / `Widget` fuera de `domain/`):** Purificar `studio_theme_skin_entity.dart`, `visual_interface_profile.dart`, `app_tool_item.dart`, `acoustic_rigor_profile.dart` y `studio_dockable_panel_entity.dart`.
- [ ] **Paso 3 (`StudioMasterClockService` puro):** Extraer motor de dominio puro y mantener adaptador `ChangeNotifier` en capa externa.
- [ ] **Paso 4 (Desacoplar `Core -> Features` y `Infra -> Presentation`):** Mover los 3 modales de `core/design_system/molecules/` a `features/navigation/presentation/modals/`; introducir puertos abstractos para `StudioWorkspaceFileSystemService`, `StudioOsAudioKernelBridge` y `TunnerOsKernel`.
- [ ] **Paso 5 (Reubicación de archivos sueltos + Verificación):** Reubicar `tuner_viewmodel.dart`, `tuner_screen.dart` y `tunner_theme.dart`; validar `0` issues en `flutter analyze` y `100%` en `flutter test`.
