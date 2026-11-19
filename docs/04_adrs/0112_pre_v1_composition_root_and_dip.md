# Architecture Decision Record: ADR-0112 - Composition Root, Abstracción de Plataforma y Ciclo de Vida de Servicios

---

## Metadatos del Documento

- **ID del ADR:** `ADR-0112`
- **Título:** Composition Root, Abstracción de Plataforma y Desacoplamiento de Singletons Globales
- **Estado:** `Accepted`
- **Fecha:** `2026-11-19`
- **Fase Asociada:** `Pre-Release Gate v1.0.0 - Ola 3`
- **Contexto Técnico:** Issue #70
- **Autor / Revisor Principal:** `Nicolas Leon (Mantenedor Principal)`

---

## 1. Contexto

La auditoría identificó 61 importaciones directas de `Presentation -> Data/Infrastructure`, llamadas directas a `FilePicker` y `path_provider` dentro de `TunerViewModel`, instanciación dispersa de servicios en `lib/main.dart` y `MainAppShell`, y 4 Singletons globales (`StudioAudioEngine`, `StudioPatchbayRoutingService`, `StudioThemeCatalogService`, `StudioWorkspaceFileSystemService`).

---

## 2. Decisión Arquitectónica

1. **Puerto `IPlatformFileGateway`:**
   - Encapsular `FilePicker.pickFiles` y `getApplicationDocumentsDirectory` detrás de `IPlatformFileGateway` en `core/file_system/domain/` + `PlatformFileGateway` en `core/file_system/data/`.
2. **Composition Root (`lib/app/studio_composition_root.dart`):**
   - Crear `StudioCompositionRoot` como única fábrica de infraestructura invocada desde `lib/main.dart` y consumida por `MultiProvider`.
   - Mantener en `MainAppShell` la resolución opcional desde `Provider` (con creación local de respaldo únicamente en tests aislados que montan `MainAppShell` sin `StudioCompositionRoot`).
3. **Constructores Aislados para Servicios Gestionados:**
   - Añadir constructores `isolated()` (y soporte para reemplazar el acoplamiento estático) en `StudioAudioEngine`, `StudioPatchbayRoutingService`, `StudioThemeCatalogService` y `StudioWorkspaceFileSystemService` para que el Composition Root y los tests operen con instancias limpias sin estado compartido residual.

---

## 3. Consecuencias

### Positivas
- Desacoplamiento completo de plugins nativos (`file_picker`, `path_provider`) respecto a `TunerViewModel`.
- Aislamiento determinista de pruebas al evitar estado global compartido cuando se utiliza `StudioCompositionRoot` o `.isolated()`.
- Punto único de mantenimiento para el cableado de servicios en producción.
