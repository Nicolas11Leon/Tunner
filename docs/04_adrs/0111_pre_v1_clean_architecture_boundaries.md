# Architecture Decision Record: ADR-0111 - Purificación de Capa de Dominio y Fronteras Clean Architecture

---

## Metadatos del Documento

- **ID del ADR:** `ADR-0111`
- **Título:** Purificación de Capa de Dominio (100% Dart Puro) y Eliminación de Inversiones Core hacia Features
- **Estado:** `Accepted`
- **Fecha:** `2026-11-19`
- **Fase Asociada:** `Pre-Release Gate v1.0.0 - Ola 2`
- **Contexto Técnico:** Issue #69
- **Autor / Revisor Principal:** `Nicolas Leon (Mantenedor Principal)`

---

## 1. Contexto

El análisis estático de dependencias detectó 10 archivos dentro de carpetas `domain/` que importaban `package:flutter/*`, 4 importaciones `domain -> infrastructure` en `tunner_os_kernel.dart`, 10 importaciones invertidas `core -> features`, y 1 importación `infrastructure -> presentation`. Adicionalmente, `tuner_viewmodel.dart` y `tuner_screen.dart` residían en la raíz de `lib/features/` y `tunner_theme.dart` en `lib/core/theme/`.

---

## 2. Decisión Arquitectónica

1. **Dominio 100% Dart Puro:**
   - Agregar `meta: ^1.17.0` a `pubspec.yaml` para `@immutable` puro.
   - Sustituir `Color` por `int` (`argb32`) e `IconData` por identificadores tipados (`String` / enum) en entidades de dominio, proveyendo getters/extensiones en `presentation/`.
   - Separar `StudioPanelDescriptor` (dominio puro) de `StudioDockablePanelEntity` (widget descriptor en `core/docking/presentation/`).
   - Separar el reloj temporal puro en `StudioMasterClockEngine` (`domain/`) del adaptador reactivo `StudioMasterClockService` (`core/audio/presentation/` o wrapper `ChangeNotifier`).
2. **Desacoplamiento `Core <-> Features` y `Terminal`:**
   - Reubicar los 3 modales acoplados (`studio_automations_modal.dart`, `studio_customizations_modal.dart`, `studio_settings_modal.dart`) en `features/navigation/presentation/modals/`.
   - Definir puertos abstractos en `core/file_system/domain/` (`IProjectStorageGateway`) y `core/dsl/domain/` (`IDslStudioGateway`) para desacoplar `StudioWorkspaceFileSystemService`, `StudioOsAudioKernelBridge` y `TunnerOsKernel`.
   - Ubicar `TunnerOsKernel` como orquestador en `core/terminal/application/tunner_os_kernel.dart` (dejando en `core/terminal/domain/` únicamente los value objects y contratos puros).
3. **Reubicación Canónica con Retrocompatibilidad Segura:**
   - Mover `tuner_viewmodel.dart` y `tuner_screen.dart` a `features/tuner/presentation/` y `tunner_theme.dart` a `core/design_system/presentation/`, dejando archivos barrel de re-export en las rutas originales únicamente donde los tests existentes lo referencian (para migración limpia sin rupturas).

---

## 3. Consecuencias

### Positivas
- La capa `domain/` completa del proyecto compila y se prueba sin ninguna dependencia de Flutter SDK.
- El módulo `core/` queda completamente reutilizable e independiente de `features/`.
- Cero violaciones de frontera `Infrastructure -> Presentation`.
