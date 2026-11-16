# ADR 0075: Formato Universal de Archivos de Consolas Virtuales y Sistema de Docking Multi-Panel tipo DAW

## Estado
Aprobado

## Contexto
El usuario ha establecido dos directrices cruciales para **Tunner**:
1. **Democratización por Emulación:** Debe ser posible emular cualquier consola física del mercado en software, sin necesidad de poseer el hardware costoso. Esto requiere un formato de especificación de consola (`.djconsole` en JSON estándar) que defina la disposición de los componentes físicos, sus zonas interactivas vectoriales y su asociación con teclas del teclado físico.
2. **Sistema de Ventanas y Acoplamiento (Docking) tipo DAW:** El espacio de trabajo debe permitir arrastrar ventanas y herramientas a paneles divididos (izquierda, derecha, inferior o maximizado), similar a DAWs profesionales como Ableton Live, FL Studio y entornos como VS Code, permitiendo al usuario configurar su espacio visual según sus necesidades de producción.

## Decisión
Se implementa una arquitectura desacoplada basada en Clean Architecture:
1. **Capa de Dominio de Emulación:**
   - `DjConsoleBlueprintEntity`: Especificación serializable de una consola física completa, incluyendo metadatos (nombre, fabricante, versión de protocolo), dimensiones de aspecto, color del chasis y una lista de zonas de control (`DjSkinZoneEntity`) asociadas a acciones DSP y atajos QWERTY.
   - `DjConsoleFileCodec`: Serializador y deserializador seguro con validación de esquema JSON y valores por defecto tolerantes a fallos.
2. **Capa de Dominio de Docking:**
   - `StudioDockZone`: Enumeración de zonas (`left`, `right`, `bottom`, `center`, `floating`).
   - `StudioDockLayoutEntity`: Estado inmutable de los paneles acoplados y sus proporciones de división (split ratio de 0.1 a 0.9).
   - `StudioDockablePanelEntity`: Descripción de un panel arrastrable (identificador, título, icono, widget constructor y zona actual).
3. **Capa de Presentación:**
   - `StudioWorkspaceDockingContainer`: Contenedor reactivo con soporte para `DragTarget` y divisores de arrastre redimensionables (`StudioSplitterDivider`).
   - `StudioDockableWindowWrapper`: Tarjeta contenedora de ventana con barra de agarre (`Draggable`) para reubicación fluida.
   - `DjConsoleModelBuilderModal`: Diseñador interactivo que permite al usuario crear y editar consolas emuladas desde cero en pantalla y guardarlas como archivos `.djconsole`.

## Consecuencias

### Positivas
- Acceso gratuito e ilimitado para cualquier estudiante o DJ a emular cualquier consola de hardware con su teclado.
- Flexibilidad ergonómica superior en escritorios con monitores de cualquier tamaño o múltiples pantallas.
- Cero dependencias binarias externas: funcionamiento 100% offline y local.
- Extensibilidad de la comunidad: los archivos `.djconsole` pueden compartirse fácilmente como texto plano JSON.

### Negativas / Mitigaciones
- Complejidad en la gestión de estados de múltiples paneles divididos: se resuelve mediante `StudioDockLayoutEngine` inmutable y pruebas de regresión automáticas.
