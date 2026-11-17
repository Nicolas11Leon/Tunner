# Implementation Plan: Real Disk Filesystem Persistence & VS Code-Style Explorer Suite

Documento que define la especificación rigurosa para conectar el explorador de archivos estilo VS Code de Tunner con persistencia real en el disco local (`dart:io`), eliminando el almacenamiento volátil en memoria y permitiendo navegación, creación, edición, renombrado, movimiento y eliminación de archivos y carpetas en almacenamiento permanente.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-FILESYSTEM-2026-0081`
- **Título de la Implementación:** Real Disk Filesystem Persistence & VS Code-Style Explorer Suite
- **Fase del Proyecto:** Fase 2 (Sistema de Archivo Real)
- **Estado:** Aprobado
- **ADR Relacionado:** [`docs/04_adrs/0081_real_disk_filesystem_persistence_and_vscode_explorer_suite.md`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/04_adrs/0081_real_disk_filesystem_persistence_and_vscode_explorer_suite.md)
- **Documento Funcional Base:** [`docs/02_use_cases/91_uc_real_disk_filesystem_persistence_and_vscode_explorer_suite.md`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/02_use_cases/91_uc_real_disk_filesystem_persistence_and_vscode_explorer_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Reemplazar la estructura estática en memoria RAM de `StudioWorkspaceFileSystemService` por una implementación completa de infraestructura (`LocalDiskStudioFileSystemRepository`) que interactúe directamente con el sistema de archivos del sistema operativo mediante `dart:io`. Garantizar que cualquier archivo o carpeta creado, renombrado, movido o eliminado en el explorador estilo VS Code se persista físicamente en el directorio del usuario (`~/Documents/TunnerProjects` o directorio de aplicación), manteniendo sincronización bidireccional y navegación instantánea.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Implementación concreta `LocalDiskStudioFileSystemRepository` que implementa `StudioFileSystemRepository`.
  - Implementación de pruebas herméticas `MemoryStudioFileSystemRepository` para tests unitarios.
  - Extensión de `StudioFileSystemRepository` para soportar `createFolder` y escaneo jerárquico recursivo real.
  - Integración asíncrona en `StudioWorkspaceFileSystemService` de persistencia en disco sin bloquear el hilo de interfaz de usuario.
  - Capacidad de mover archivos y carpetas entre directorios (`moveNode` y modal contextual en la interfaz).
  - Botón de refresco activo en la cabecera del explorador para re-escanear cambios externos del sistema de archivos.
- **Excluido (Out-of-Scope):**
  - Almacenamiento en la nube o sincronización remota por red (prohibido por el principio Offline-First de AGENTS.md).
  - Edición binaria de formatos externos no soportados.

---

## 2. Análisis de Dependencias y Tecnologías

- **Tecnologías Utilizadas:**
  - `dart:io`: APIs nativas de `Directory`, `File`, `FileSystemEntity` para operaciones de E/S síncronas/asíncronas en disco.
  - `path_provider: ^2.1.6`: Localización estándar del directorio de documentos del sistema (`getApplicationDocumentsDirectory`).
  - Dart SDK: `^3.11.5`.
- **Riesgo Tecnológico:**
  - Nulo. `dart:io` es parte de la biblioteca estándar de Dart y no añade dependencias nativas externas.
  - En pruebas unitarias headless (`flutter test`), se utiliza `MemoryStudioFileSystemRepository` o directorios temporales aislados (`Directory.systemTemp`) para evitar interferencias con el sistema del desarrollador.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Domain Layer)
- [x] Verificar `StudioFileSystemNode`, `StudioFileEntity`, `StudioFolderEntity`, `StudioFileType`.
- [x] Extender `StudioFileSystemRepository` con el método `createFolder(String relativePath)`.
- [x] Añadir soporte inmutable en `StudioFolderEntity` para mover nodos entre carpetas (`moveChild(String nodeId, String targetFolderId)`).

### Paso 2: Capa de Infraestructura / Datos (Data Layer)
- [x] Crear `LocalDiskStudioFileSystemRepository` implementando `StudioFileSystemRepository`:
  - Resolución del directorio raíz (`rootDirectory`).
  - Auto-creación de jerarquía y semillado de plantillas canónicas si el directorio está vacío.
  - Lectura, escritura, borrado, renombrado y movimiento físico de archivos y carpetas.
- [x] Crear `MemoryStudioFileSystemRepository` implementando `StudioFileSystemRepository` para pruebas aisladas.
- [x] Refactorizar `StudioWorkspaceFileSystemService` para inyectar `StudioFileSystemRepository` y sincronizar cada acción CRUD con el repositorio.

### Paso 3: Capa de Presentación (Presentation Layer)
- [x] Actualizar `StudioExplorerActionHeader` para conectar el botón de recarga (`refresh`) con `service.refreshFromDisk()`.
- [x] Añadir acción "Mover a..." en el menú contextual de `StudioFileTreeTile` y `StudioFolderTreeTile`.
- [x] Crear modal `showMoveNodeModal` en `StudioFileSystemModals` para seleccionar carpeta de destino de forma fluida.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Crear `test/core/file_system/local_disk_file_system_repository_test.dart`.
- [x] Ejecutar `flutter analyze` asegurando cero advertencias.
- [x] Ejecutar suite de pruebas completa `flutter test`.

---

## 4. Estrategia de Rollback

Si se detectan problemas de permisos en plataformas restringidas, se utiliza el fallback automático a almacenamiento temporal en memoria o aislamiento seguro en el directorio de caché de la aplicación sin abortar el flujo del usuario.

---

## 5. Criterios de Aceptación (Definition of Done)
1. Los archivos creados en el explorador de Tunner existen físicamente en el disco.
2. Al reiniciar la aplicación, los archivos y carpetas creados se conservan íntegramente.
3. Se puede mover cualquier archivo a otra carpeta y el cambio se refleja físicamente en disco.
4. Cobertura completa de pruebas unitarias pasando al 100%.
5. Cero dependencias de red, cumpliendo el principio Offline First.
