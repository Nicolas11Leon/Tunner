# ADR 0071: Sistema de Ventanas Acoplables/Ajustables, Selector de Espacios DAW y Menú de Alta Gama

## Estado
Aprobado

## Fecha
2026-11-16

## Contexto
La estación de trabajo de escritorio de Tunner requiere una experiencia de usuario idéntica a software de producción de audio comercial de licencia costosa (como Pro Tools, Logic Pro X, Ableton Live 12 y Antigravity IDE). Previamente, la barra lateral tenía un ancho fijo estático y no existía un sistema interactivo de división de paneles (*splitters*) ni pestañas dedicadas de espacios de trabajo en la cabecera superior. El creador del proyecto solicitó explícitamente:
1. Un sistema de ventanas ajustables para ver el contenido completo de manera cómoda.
2. Una apariencia de software comercial de alta gama que reivindique y prestigie la calidad del desarrollo open-source.

## Decisión
1. **Implementar `StudioSplitter`:**
   - Un widget divisor puro de alto rendimiento con detección de puntero (`MouseRegion`), cursor interactivo `SystemMouseCursors.resizeColumn` y feedback táctil de arrastre (`onPanUpdate`).
   - Aplicar límites de seguridad (*clamping*) matemáticos (ancho de sidebar entre 180px y 480px; división dual entre 25% y 75%).
2. **Implementar `StudioWorkspaceTabBar`:**
   - Barra de pestañas fijada en la cabecera superior de la aplicación para conmutar directamente entre los cuatro grandes espacios de trabajo:
     1. `Aprender & Afinar` (Afinador Estroboscópico, Diapasón, Evaluación).
     2. `Rack Modular Pro` (Consola de 10 unidades modulares).
     3. `Notación & Partitura` (Pentagrama, Transcripción, Editor SMuFL).
     4. `Consola DJ & Mezcla` (Decks A/B, Stems, Looper).
3. **Controles de Layout en Barra Superior:**
   - Botón de alternancia rápida de barra lateral `[ ◨ ]` (`Ctrl+B`).
   - Botón de alternancia de vista dual dividida `[ ◫ ]` (`Ctrl+Shift+D`).
4. **Refactorización de Menús Desplegables:**
   - Estilo visual de alta fidelidad: esquinas redondeadas de 6px, borde hairline sutil de 1px, tipografía monoespaciada con alineación de atajos de teclado (`Ctrl+N`, `Ctrl+O`, `Ctrl+S`, `Ctrl+K`), micro-iconos consistentes y cero elementos simulados.
5. **Cero Dependencias Externas:**
   - Toda la arquitectura se construye con widgets canónicos de Flutter, garantizando soporte multiplataforma nativo (Linux, macOS, Windows) y cero sobrecarga de memoria o CPU.

## Consecuencias
### Positivas
- Estética y usabilidad de nivel profesional comercial con acabado premium.
- El usuario puede adaptar la pantalla a monitores ultrawide, portátiles o pantallas táctiles ajustando el divisor.
- Acceso inmediato en un solo clic a cualquier área de trabajo del estudio sin menús anidados confusos.
- Cumplimiento riguroso de las directrices de Clean Architecture y la Constitución del proyecto Tunner (AGENTS.md).

### Negativas / Mitigaciones
- Requiere gestión de estado del layout (ancho de sidebar, visibilidad de paneles, modo dual); se resuelve manteniendo el estado en la estación de trabajo y sincronizando con las preferencias de persistencia.
