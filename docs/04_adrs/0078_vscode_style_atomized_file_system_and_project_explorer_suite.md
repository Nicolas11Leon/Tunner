# ADR 0078: Arquitectura Atómica del Sistema de Archivos y Explorador Jerárquico Estilo VS Code

## Estado
Aprobado

## Contexto
El usuario ha expresado la necesidad de contar con un sistema de archivos de lectura y escritura completamente operativo, atómico e hiper-escalable, integrado con un explorador jerárquico al estilo Visual Studio Code donde los músicos y productores puedan:
1. Navegar fluidamente entre archivos y carpetas anidadas con respuesta instantánea.
2. Crear nuevos archivos (`.tunner`, `.musicxml`, `.wav`, `.tpreset`, `.djblueprint`) y nuevas carpetas desde la barra superior de acciones o menús contextuales.
3. Filtrar rápidamente mediante una barra de búsqueda en tiempo real.
4. Mantener cada función, clase e interfaz al máximo nivel de atomización para garantizar 100% de escalabilidad y desacoplamiento.

## Decisión
Se implementa una arquitectura limpia y altamente atomizada estructurada en tres capas estrictas:

1. **Capa de Dominio Puro (`lib/core/file_system/domain`):**
   - `StudioFileType`: Enumeración de tipos de archivo admitidos con metadatos técnicos (extensión canónica, color distintivo, etiqueta descriptiva).
   - `StudioFileSystemNode`: Clase base sellada e inmutable con ID único, nombre, ruta relativa y timestamp de modificación.
   - `StudioFileEntity`: Nodo hoja que representa un archivo físico o virtual (con tamaño en bytes, tipo de archivo y referencia de contenido).
   - `StudioFolderEntity`: Nodo rama que almacena una lista inmutable de nodos hijos (`List<StudioFileSystemNode>`) y estado de colapso/expansión.
   - `StudioFileSystemRepository`: Contrato abstracto puro (sin dependencias de Flutter) para persistencia, codificación/decodificación y operaciones de disco.

2. **Capa de Infraestructura y Datos (`lib/core/file_system/data`):**
   - `StudioWorkspaceFileSystemService`: Gestor reactivo (`ChangeNotifier`) en memoria que indexa el árbol de nodos, ejecuta búsquedas y filtrados en tiempo real (<2ms), implementa operaciones CRUD (crear, renombrar, mover, borrar, colapsar/expandir) y delega la serialización binaria comprimida al códec existente `TunnerBinaryProjectCodec` y `LocalProjectStorageRepository`.

3. **Capa de Presentación Atomizada (`lib/core/file_system/presentation`):**
   - `StudioVsCodeExplorerWidget`: Contenedor principal del explorador con barra de herramientas, campo de búsqueda y árbol de renderizado recursivo.
   - `StudioFolderTreeTile`: Widget atomizado para renderizar carpetas con chevrons rotativos y conteo de elementos.
   - `StudioFileTreeTile`: Widget atomizado para renderizar archivos con icono coloreado por tipo, tamaño e indicador de selección.
   - `StudioExplorerActionHeader`: Barra compacta con botones `[+] Archivo`, `[+] Carpeta`, `[⟳ Refrescar]` y `[↕ Colapsar]`.
   - `StudioCreateNodeModal` y `StudioRenameNodeModal`: Modales interactivos para alta y edición de nombres con validación de extensiones.

## Consecuencias

### Positivas
- Familiaridad cognitiva total: la metáfora de VS Code es el estándar universal para moverse entre archivos y carpetas de forma ágil y ergonómica.
- Máxima atomización: cada componente visual y lógico mide menos de 150-200 líneas, es testeable de forma aislada y no produce acoplamiento espagueti.
- Cero dependencias externas o de red: todas las operaciones corren 100% en local con latencia determinista sub-5ms.
- Rendimiento de 60/120 FPS al usar renderizado inmutable y filtrado optimizado en memoria.

### Negativas / Mitigaciones
- La recursión en árboles muy profundos puede requerir gestión de estados de scroll: se mitiga aplanando la lista para renderizado eficiente si la profundidad excede 10 niveles.
