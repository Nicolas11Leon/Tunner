# ADR 0081: Persistencia Real del Sistema de Archivos en Disco y Explorador VS Code

- **Estado:** Aprobado
- **Fecha:** 2026-11-16
- **Contexto:**
  Hasta la versión actual, el explorador de proyectos y espacio de trabajo de Tunner utilizaba una jerarquía en memoria RAM (`StudioFolderEntity` en `StudioWorkspaceFileSystemService`) sin vinculación con el disco duro o almacenamiento del usuario. Como resultado, las modificaciones (archivos creados, eliminados, renombrados o importados) se perdían al cerrar la sesión o reiniciar la aplicación. Para satisfacer los requisitos de producción y la rigurosa arquitectura modular de Tunner, es indispensable una capa de persistencia real en disco que implemente el contrato abstracto de dominio `StudioFileSystemRepository` utilizando `dart:io` sin violar el principio Offline First ni introducir latencias en la interfaz gráfica.

---

## Decisión Arquitectónica

1. **Implementación de Infraestructura (`LocalDiskStudioFileSystemRepository`):**
   - Se crea una clase en la capa de datos (`lib/core/file_system/data/local_disk_studio_file_system_repository.dart`) que implementa `StudioFileSystemRepository`.
   - Utiliza `dart:io` para interactuar de forma no bloqueante con el almacenamiento del dispositivo (`Directory`, `File`).
   - Ubica los proyectos de manera predeterminada en el directorio de documentos del usuario (`~/Documents/TunnerProjects`) o una ruta configurable.
   - Si el directorio base no existe al iniciar, se inicializa automáticamente en disco con la estructura canónica de carpetas y plantillas de estudio.

2. **Implementación Aislada para Pruebas (`MemoryStudioFileSystemRepository`):**
   - Para garantizar que la suite de pruebas automatizadas se ejecute en milisegundos sin dejar residuos en el sistema anfitrión ni fallar en entornos CI sin sistema de archivos real, se proporciona una implementación en memoria completa y aislada del contrato.

3. **Operaciones CRUD Atómicas y Sincronizadas:**
   - La capa de presentación y el servicio `StudioWorkspaceFileSystemService` mantienen la inmutabilidad de los nodos `StudioFolderEntity` y `StudioFileEntity`.
   - Cada operación de creación, modificación, movimiento y eliminación despacha la correspondiente mutación física en disco de forma asíncrona con `flush: true`.
   - Se implementa el método `moveNode(String nodeId, String targetFolderId)` tanto en el dominio inmutable como en la persistencia física (`File.rename` o copia segura).

4. **Sincronización Bidireccional y Resguardo Acústico:**
   - Se integra la acción de refresco manual (`refreshFromDisk()`) para re-escanear el árbol físico y sincronizar archivos añadidos o modificados fuera de la aplicación.

---

## Consecuencias

### Positivas
- **Persistencia Permanente:** Los proyectos, tomas de audio, partituras y presets del usuario se preservan entre reinicios de la aplicación.
- **Interoperabilidad:** El usuario puede abrir la carpeta `~/Documents/TunnerProjects` en su explorador del sistema operativo y encontrar exactamente sus archivos con sus extensiones estándar (`.musicxml`, `.wav`, `.tpreset`, `.djblueprint`, `.tunner`).
- **Clean Architecture Estricta:** La capa de dominio permanece 100% pura en Dart, desacoplada de `dart:io`, mientras la capa de datos encapsula la persistencia física.

### Negativas / Mitigaciones
- **Manejo de Errores de Permisos:** En plataformas con sandbox estricto, se capturan y manejan de forma segura las excepciones `FileSystemException`, notificando al usuario a través del sistema de tokens y banners del estudio sin bloquear la ejecución.
