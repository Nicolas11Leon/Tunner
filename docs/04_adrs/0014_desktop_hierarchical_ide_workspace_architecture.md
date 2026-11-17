# ADR 0014: Adopción del Sistema Jerárquico Desktop Multivel Estilo IDE para Tunner

## Estado
Aprobado.

## Contexto
El usuario y la dirección de producto de Tunner requieren una experiencia de escritorio de grado profesional (similar a Antigravity IDE, Visual Studio Code y Adobe Audition / Creative Cloud), descartando esquemas de navegación móvil o tab-bars simplistas en pantallas de alta resolución.
La captura de referencia enviada por el creador muestra una distribución jerárquica basada en carpetas colapsables con chevron, iconos de carpeta (`folder` / `folder_open`), nodos anidados de sesiones de trabajo con drag handle / status dot y badges de tiempo, accesos superiores a Automatizaciones/Personalizaciones, y un acceso fijo en la base a Ajustes (`⚙ Settings`).

## Decisión
1. **Molécula `StudioTreeView` Multivel:**
   - Se evoluciona el componente de árbol para soportar carpetas anidadas (`StudioTreeFolder`), con iconos de carpeta interactivos que alternan entre abierto y cerrado, animaciones de rotación para chevrons, y nodos hijos con indentación precisa de 16px a 24px.
   - Cada nodo hijo puede incluir un indicador de estado en vivo (dot de actividad), glifo técnico, texto truncado con puntos suspensivos y metadato/badge secundario (`1h ago`, `En vivo`, etc.).
2. **Organismo `StudioDesktopAppShell`:**
   - Incorpora la estructura exacta de Antigravity:
     - Cabecera de sidebar con accesos directos de alto nivel (*Automatizaciones*, *Personalizaciones*).
     - Encabezado de sección *Projects* con botones de filtrado y nuevo elemento (`+`).
     - Árbol jerárquico scrolleable.
     - Pie persistente con botón `Settings` y tarjeta de instrumento activo.
     - Barra de comandos / prompt interactivo en la base del workspace para interacción acústica rápida.
3. **Preservación de Rendimiento y Arquitectura Limpia:**
   - Todos los cambios se mantienen en la capa de presentación dentro de `lib/core/design_system/` y `lib/features/navigation/presentation/`.
   - Cero dependencias adicionales; cero busy-waiting. Renderizado reactivo mediante `ValueNotifier` y `StatefulWidget` ligero.

## Consecuencias
- **Positivas:**
  - Experiencia de usuario indistinguible de los DAWs y editores de código de estándar industrial.
  - Organización jerárquica clara de todos los módulos complejos de Tunner (Afinación, Rack, Grabación, Laboratorio Acústico, Partituras).
  - Máxima ergonomía en monitores ultrawide y pantallas de laptop/escritorio.
- **Negativas / Mitigaciones:**
  - Mayor cantidad de widgets en el árbol de presentación; mitigado mediante `const` constructors y layouts sin recalculo innecesario.
