# Implementation Plan: Composition Root, DIP y Eliminación de Singletons (Ola 3)

**Issue Asociado:** #70 (Pre-v1.0.0 - Ola 3)  
**Rama:** `refactor/pre-v1-dependency-injection-and-dip`  
**Rama Base:** `qa`  
**Fecha:** `2026-11-19`  

---

## 1. Resumen y Objetivos

Abstraer el acceso a archivos de plataforma fuera de `TunerViewModel`, centralizar el ensamblaje de servicios en un `StudioCompositionRoot` en `lib/app/`, y habilitar instanciación gestionada sin estado global compartido en los 4 Singletons existentes.

---

## 2. Tareas de Implementación

- [ ] **Paso 1:** Crear `IPlatformFileGateway` (`core/file_system/domain/`) y `PlatformFileGateway` (`core/file_system/data/`), y migrar `TunerViewModel` para eliminar imports directos de `file_picker` y `path_provider`.
- [ ] **Paso 2:** Agregar constructores `.isolated()` / gestionados a `StudioAudioEngine`, `StudioPatchbayRoutingService`, `StudioThemeCatalogService` y `StudioWorkspaceFileSystemService`.
- [ ] **Paso 3:** Crear `lib/app/studio_composition_root.dart` e integrarlo en `lib/main.dart` y `MainAppShell` (resolviendo servicios vía `Provider` cuando estén disponibles).
- [ ] **Paso 4:** Añadir pruebas de aislamiento y Composition Root, y validar `flutter analyze` (`0` issues) + `flutter test`.
