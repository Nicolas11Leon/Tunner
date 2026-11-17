# Caso de Uso 91: Sistema de Archivo Real con Persistencia en Disco y Explorador VS Code

Documento de especificación formal del Caso de Uso 91 para la persistencia física en disco local (`dart:io`) y navegación interactiva jerárquica de archivos y carpetas del espacio de trabajo en Tunner Studio.

---

## Metadatos del Documento

- **ID del Caso de Uso:** `UC-91`
- **Título Oficial:** Persistencia Real de Sistema de Archivos en Disco y Explorador Jerárquico VS Code
- **Estado:** Aprobado
- **Fase Asociada:** Fase 2 (Sistema de Archivo Real)
- **Actores:** Productor Musical, Músico Educativo, Sistema de Archivos del SO (`dart:io`)

---

## 1. Resumen Ejecutivo

El presente caso de uso formaliza el desacoplamiento de la memoria volátil en el Explorador de Archivos de Tunner, garantizando que todos los proyectos, partituras MusicXML, capturas de audio WAV, presets de afinación y blueprints de consolas DJ sean leídos y escritos de forma persistente en el disco físico del usuario (`~/Documents/TunnerProjects` o directorio de aplicación local). Asimismo, se habilita la reubicación de elementos entre carpetas (movimiento físico de nodos) y la recarga inmediata del árbol tras modificaciones externas.

---

## 2. Diagramas de Casos de Uso y Secuencia

### 2.1 Diagrama de Casos de Uso (Mermaid)

```mermaid
graph TD
    User["Músico / Productor"]
    
    subgraph Tunner Studio ["Tunner Studio - Core File System"]
        UC1["Explorar Jerarquía de Carpetas y Archivos"]
        UC2["Crear Archivo con Extensión Musical (.musicxml, .wav, .tpreset)"]
        UC3["Crear Carpeta de Sesión o Instrumento"]
        UC4["Mover Archivo o Carpeta entre Directorios"]
        UC5["Renombrar Elemento en Disco"]
        UC6["Eliminar Archivo o Directorio Físico"]
        UC7["Refrescar Árbol desde el Disco"]
    end

    subgraph OS ["Sistema Operativo Local"]
        DiskIO["dart:io Directory & File Persistence"]
    end

    User --> UC1
    User --> UC2
    User --> UC3
    User --> UC4
    User --> UC5
    User --> UC6
    User --> UC7

    UC1 -.-> DiskIO
    UC2 -.-> DiskIO
    UC3 -.-> DiskIO
    UC4 -.-> DiskIO
    UC5 -.-> DiskIO
    UC6 -.-> DiskIO
    UC7 -.-> DiskIO
```

### 2.2 Diagrama de Secuencia: Creación y Movimiento de Archivos en Disco (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor User as Usuario (Explorador VS Code)
    participant UI as StudioVsCodeExplorerWidget
    participant Service as StudioWorkspaceFileSystemService
    participant Repo as LocalDiskStudioFileSystemRepository
    participant Disk as Sistema de Archivos (dart:io)

    User->>UI: Solicita Crear Archivo ("Sonata.musicxml", parent: "/Partituras")
    UI->>Service: createFile(name, parentFolderId, type)
    Service->>Repo: saveFile(relativePath, bytes)
    Repo->>Disk: File.writeAsBytes(bytes, flush: true)
    Disk-->>Repo: Confirmación de I/O exitoso
    Repo-->>Service: Ok
    Service->>UI: notifyListeners() (Árbol inmutable actualizado)
    UI-->>User: Visualiza nodo hoja con metadatos reales y tamaño en KB

    User->>UI: Solicita Mover Archivo ("Sonata.musicxml" -> "/Obras Maestras")
    UI->>Service: moveNode(fileId, targetFolderId)
    Service->>Repo: movePath(oldRelativePath, newRelativePath)
    Repo->>Disk: File.rename(newAbsolutePath)
    Disk-->>Repo: Operación atómica de renombramiento en disco completa
    Repo-->>Service: Ok
    Service->>UI: notifyListeners() (Reestructuración jerárquica)
    UI-->>User: Archivo reubicado bajo la nueva carpeta
```

---

## 3. Especificación Detallada del Flujo

### 3.1 Precondiciones
1. La aplicación Tunner se ejecuta en un entorno con permisos de lectura y escritura en almacenamiento local.
2. El directorio base del espacio de trabajo está inicializado o el repositorio cuenta con permisos para crear la carpeta raíz en disco.

### 3.2 Flujo Principal
1. **Inicialización y Carga:** Al arrancar el módulo de explorador, `StudioWorkspaceFileSystemService` invoca `loadRootWorkspace()` en el repositorio.
2. Si el directorio en disco no existe, se genera la estructura física canónica (`Partituras & Notación`, `Tomas de Audio & WAV`, `Presets de Afinación`, `Modelos Consola DJ`) sembrando las plantillas iniciales.
3. El usuario interactúa con la interfaz de árbol estilo VS Code (expandir/colapsar carpetas, filtrar por nombre).
4. El usuario crea, renombra, mueve o elimina un elemento.
5. El servicio actualiza el estado reactivo en memoria y ejecuta la operación física en disco correspondiente mediante `LocalDiskStudioFileSystemRepository`.
6. Si ocurre un cambio externo, el usuario presiona el botón "Refrescar" y el servicio vuelve a inspeccionar el disco físico, reconstruyendo el árbol fielmente.

### 3.3 Flujos Alternativos y Manejo de Errores
- **Fallo de permisos de E/S:** Si el directorio no cuenta con permisos de escritura, la operación de E/S captura la excepción `FileSystemException`, registra un log seguro y mantiene la integridad del árbol sin provocar cierres inesperados.
- **Conflicto de nombres:** Si un archivo con el mismo nombre ya existe en el destino, se añade un sufijo numérico determinista `_1` antes de la extensión.

### 3.4 Postcondiciones
- Todos los cambios estructurales y de contenido quedan escritos en almacenamiento no volátil.
- Reinicios posteriores de la aplicación cargan con fidelidad absoluta los archivos creados por el usuario.
