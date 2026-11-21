# ADR 0015: Arquitectura del Motor de Autocompletado de Comandos y Explorador de Documentos Musicales

## Estado
Aprobado.

## Contexto
El usuario ha expresado satisfacción con el sistema jerárquico de carpetas en el sidebar izquierdo y ha solicitado expandirlo para acceder a **documentos y proyectos musicales completos** (sesiones de afinación, tomas WAV de práctica, partituras MusicXML). Asimismo, requiere que la barra de comandos inferior de la estación de trabajo proporcione **autocompletado interactivo con lista emergente de opciones** al escribir acciones (como `/` y `@`) y un sistema integral de **ayuda interactiva (`/help`)** accesible en todo momento.

## Decisión
1. **Molécula `StudioCommandPromptBar` con Overlay de Autocompletado:**
   - Se crea un componente interactivo con `TextField` y `CompositedTransformTarget` que despliega un popup emergente hacia arriba (`CompositedTransformFollower`) cuando el usuario tipea o enfoca la barra.
   - Soporte para autocompletado en tiempo real con filtrado sibilino (<1 ms).
   - Manejo de comandos con argumentos dinámicos (ej. `/bpm 128`, `/calibrar 442`).
   - Navegación bidireccional por teclado (`ArrowUp`, `ArrowDown`, `Enter`, `Tab`, `Escape`).
   - Botón directo de ayuda `? Help` integrado en el lateral derecho del input.
2. **Sistema de Documentación Universal (`/help`):**
   - El comando `/help` o el botón `?` despliega un modal unificado con el glosario completo de comandos, sus atajos de teclado y sus parámetros admitidos.
3. **Explorador de Documentos y Proyectos en `StudioTreeView`:**
   - La sección `Projects` del sidebar ahora contiene carpetas con documentos reales:
     - Partituras MusicXML curadas (Bach, Beethoven, Estudios).
     - Tomas de audio de práctica guardadas.
     - Sesiones de afinación histórica (A4=415Hz Barroco, A4=440Hz Orquestal).
     - Lecciones estructuradas del conservatorio.

## Consecuencias
- **Positivas:**
  - Ergonomía de trabajo de nivel profesional (comparable a terminales modernas, DAWs y editores como VS Code y Antigravity).
  - Descubrimiento inmediato de todas las funciones sin memorizar menús.
  - Gestión visual de archivos y documentos musicales como entidades de primer nivel.
- **Negativas / Mitigaciones:**
  - Requiere gestión cuidadosa del ciclo de vida del `OverlayEntry` para evitar memory leaks (mitigado con eliminación segura en `dispose()` y `didUpdateWidget()`).
