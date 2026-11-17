# Plan de Implementación: Sistema Atómico de Archivos de Lectura/Escritura y Explorador de Archivos y Carpetas Estilo VS Code

Este documento formaliza el plan de ingeniería para dotar a **Tunner** de un **Sistema de Archivos de Lectura y Escritura 100% Funcional, Hiper-Comprimido y Atómico**, acompañado de un **Explorador Jerárquico de Archivos y Carpetas estilo VS Code** integrado en la estación de trabajo modular de escritorio.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-VSCODE-FILE-SYSTEM-EXPLORER-2026-0088`
- **Título:** Sistema Atómico de Archivos de Lectura/Escritura y Explorador de Proyectos Estilo VS Code
- **Fase del Proyecto:** Fase 2 (Almacenamiento Binario, Exploración de Proyectos y Estaciones de Trabajo)
- **Estado:** Aprobado para Implementación
- **ADR Relacionado:** [ADR 0078: Arquitectura Atómica del Sistema de Archivos y Explorador Jerárquico](../04_adrs/0078_vscode_style_atomized_file_system_and_project_explorer_suite.md)
- **Documento Funcional Base:** [Caso de Uso 88: Explorador de Archivos y Carpetas Estilo VS Code con Lectura y Escritura Atómica](../02_use_cases/88_uc_vscode_style_atomized_file_system_and_project_explorer_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Transformar la gestión de proyectos y assets en una experiencia **idéntica a un entorno de desarrollo profesional (tipo Visual Studio Code)**, donde el usuario puede navegar a gran velocidad entre carpetas anidadas y archivos, crear nuevos documentos con un clic, renombrar, mover, borrar y abrir cualquier archivo en su herramienta respectiva con latencia sub-5ms, garantizando que:
1. **Sistema de Lectura y Escritura Completo:**
   - Guardado y carga persistente con compresión binaria máxima (`.tunner` proyectos, `.tnt` módulos de rack, `.musicxml` partituras, `.wav` tomas de audio, `.tpreset` calibraciones de afinación, `.djblueprint` consolas).
   - Operaciones atómicas de lectura y escritura en el disco local sin pérdida de datos ni dependencias de nube.
2. **Navegación Fluida Estilo VS Code:**
   - Explorador de árbol profundo (carpetas dentro de carpetas sin límite de profundidad).
   - Acciones superiores rápidas: `[+] Nuevo Archivo`, `[+] Nueva Carpeta`, `[⟳ Refrescar]`, `[↕ Colapsar Todo]`.
   - Filtro reactivo en vivo: barra de búsqueda para encontrar archivos instantáneamente.
   - Apertura contextual al hacer clic: abrir una partitura carga el visor de notación; abrir un WAV lo enruta al canal o Deck DJ; abrir un preset calibra el afinador; abrir un proyecto restaura la sesión completa.
3. **Desacoplamiento y Atomización Máxima:**
   - Cada entidad, repositorio, servicio y widget es una clase pequeña, autocontenida y modular, facilitando el escalado a un sistema de archivos virtual o DSL de bajo nivel.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Modelos de dominio puros: `StudioFileSystemNode`, `StudioFileEntity`, `StudioFolderEntity`, `StudioFileType`.
  - Repositorio y Servicio: `StudioFileSystemRepository`, `StudioWorkspaceFileSystemService` (con gestión de estado reactivo, búsqueda y operaciones CRUD).
  - Componentes visuales atomizados: `StudioVsCodeExplorerWidget`, `StudioFolderTreeTile`, `StudioFileTreeTile`, `StudioExplorerActionHeader`, modales de creación y renombrado.
  - Integración nativa en la barra lateral de `StudioDesktopAppShell` / `main_app_shell.dart`.
  - Pruebas unitarias de dominio, servicio y widgets.
- **Excluido (Out-of-Scope):**
  - Sincronización en servidores remotos de terceros (respeto estricto a la regla Offline-First de Tunner).

---

## 2. Análisis de Dependencias y Principios HCI

1. **Afinidad Mental VS Code (Muscle Memory & Low Cognitive Load):**
   - El explorador de archivos jerárquico es el estándar de oro en la industria del software. Al adoptar chevrons animados, sangrías proporcionales, iconos distintivos por extensión y atajos estándar, el usuario se siente inmediatamente en control.
2. **Atomización Extrema (Clean Architecture & SOLID):**
   - Los nodos son inmutables. Toda mutación genera un nuevo árbol podado o expandido de forma determinista.
   - El renderizado utiliza widgets atomizados reutilizables con `const` constructors para mantener 60/120 FPS sin reconstrucciones innecesarias.
3. **Cero Fugas de Memoria y Cero Latencia:**
   - El filtrado de búsqueda se ejecuta en memoria sobre la estructura indexada, respondiendo en <2 ms.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [ ] Implementar `lib/core/file_system/domain/studio_file_type.dart`:
  - Tipos: `project` (.tunner), `score` (.musicxml, .mxl), `audioWav` (.wav), `rackTool` (.tnt), `tuningPreset` (.tpreset), `djBlueprint` (.djblueprint), `genericFile` (.bin).
  - Metadatos: extensión predeterminada, color de identificación e icono representativo.
- [ ] Implementar `lib/core/file_system/domain/studio_file_system_node.dart`:
  - `StudioFileSystemNode` (clase base sellada).
  - `StudioFileEntity` (nodo hoja con ID, nombre, extensión, tamaño, fecha de modificación, tipo).
  - `StudioFolderEntity` (nodo rama con lista inmutable de hijos y estado de expansión).
- [ ] Implementar `lib/core/file_system/domain/studio_file_system_repository.dart`:
  - Contrato abstracto para creación, lectura, escritura, renombrado, eliminación y movimiento de nodos.

### Paso 2: Capa de Infraestructura / Datos (Servicio de Sistema de Archivos y Códec)
- [ ] Implementar `lib/core/file_system/data/studio_workspace_file_system_service.dart`:
  - Ingesta de proyectos y persistencia atómica en disco local (`LocalProjectStorageRepository` y `TunnerBinaryProjectCodec`).
  - Gestión del árbol de nodos en memoria con métodos CRUD: `createFile`, `createFolder`, `renameNode`, `deleteNode`, `toggleFolder`, `collapseAll`, `filterNodes`.
  - Suscripción reactiva mediante `ChangeNotifier`.

### Paso 3: Capa de Presentación (Explorador VS Code Atomizado)
- [ ] Implementar `lib/core/file_system/presentation/studio_file_tree_tile.dart`:
  - Fila interactiva de archivo con icono de tipo coloreado, tamaño, botón de menú contextual y selección activa.
- [ ] Implementar `lib/core/file_system/presentation/studio_folder_tree_tile.dart`:
  - Fila interactiva de carpeta con chevron expandible, icono de carpeta abierta/cerrada, contador de hijos y soporte de anidamiento recursivo.
- [ ] Implementar `lib/core/file_system/presentation/studio_explorer_action_header.dart`:
  - Barra de herramientas superior estilo VS Code: `[+] Archivo`, `[+] Carpeta`, `[⟳ Refrescar]`, `[↕ Colapsar]`, y buscador de filtrado instantáneo.
- [ ] Implementar `lib/core/file_system/presentation/studio_vscode_explorer_widget.dart`:
  - Contenedor integral de navegación de archivos y carpetas con scroll fluido y atajos.
- [ ] Implementar `lib/core/file_system/presentation/studio_file_system_modals.dart`:
  - Modales atomizados para creación de nuevo archivo, creación de carpeta y renombrado.
- [ ] Integrar el explorador en `StudioDesktopAppShell` / `main_app_shell.dart`:
  - Permitir alternar o enriquecer la sección de Documentos del Proyecto con el explorador VS Code interactivo.

### Paso 4: Pruebas, Verificación y Build Nativo
- [ ] Pruebas unitarias completas de operaciones de árbol y servicio en `test/core/file_system/studio_file_system_test.dart`.
- [ ] `flutter analyze` con 0 errores y 0 advertencias.
- [ ] Compilación Linux nativa y lanzamiento en pantalla.

---

## 4. Criterios de Aceptación (Definition of Done)
1. El usuario puede crear, renombrar y eliminar carpetas y archivos en cualquier nivel de anidamiento.
2. Al hacer clic en un archivo, este se abre instantáneamente en su herramienta correspondiente.
3. El buscador filtra la jerarquía en tiempo real sin congelar la interfaz.
4. Las lecturas y escrituras persisten de forma íntegra usando los códecs binarios de Tunner.
5. Cero dependencias de red, 60/120 FPS estables y cero violaciones a las reglas cardinales.
