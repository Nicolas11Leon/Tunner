# ADR 0067: Separación Estricta entre Documentos del Proyecto y Suite de Herramientas en el Explorador Lateral

## Estado
Aprobado

## Contexto
En versiones anteriores de la interfaz de navegación de Tunner, la sección de la barra lateral agrupaba de manera indistinta documentos creados por el usuario (partituras, tomas de audio, presets) y herramientas de software del sistema (como el Rack Modular de efectos metido dentro de la carpeta de tomas de audio, o carpetas completas para el Espectrograma FFT y el Tutor de Lecciones bajo el título de "Projects & Documentos").

Esta mezcla generaba confusión conceptual en el usuario:
- Un documento/asset es un archivo o recurso del usuario con estado persistible (una partitura MusicXML, un archivo WAV grabado, un preset de afinación calibrado).
- Una herramienta es un componente de software interactivo o módulo procesador (afinador estroboscópico, analizador de armónicos, tutor rítmico, rack de pedales).

Siguiendo el estándar de diseño de DAWs y entornos profesionales (como Adobe Creative Cloud, Ableton Live o Logic Pro), los activos del proyecto y los instrumentos/efectos deben estar claramente segregados para preservar una jerarquía mental limpia y una densidad visual calculada.

## Decisión
Se decide separar formalmente la barra lateral en dos `StudioTreeSection` principales:
1. **`DOCUMENTOS DEL PROYECTO (tunner)`:**
   - Contiene únicamente carpetas de assets de usuario:
     - `Partituras del Proyecto (${workspaceScores.length})`
     - `Tomas de Grabación WAV (${recordingHistory.length})`
     - `Presets de Afinación (${customTuningPresets.length})`
   - Se erradica cualquier herramienta de estas carpetas.
2. **`SUITE DE HERRAMIENTAS`:**
   - Contiene carpetas clasificadas por disciplina técnica:
     - `Afinación & Entonación` (Afinador Estroboscópico, Dron Armónico, Dashboard).
     - `Análisis Acústico & Laboratorio` (Espectrograma FFT en Vivo, Analizador Polifónico).
     - `Pedagogía & Conservatorio` (Tutor de Compás y Rushing, Entrenador Auditivo a Ciegas).
     - `Producción & Enrutamiento` (Rack Modular de Pedales DSP).

## Consecuencias

### Positivas
- **Claridad Conceptual Total:** El usuario sabe con certeza qué es un archivo de su proyecto y qué es una herramienta de análisis o procesamiento.
- **Estética de Grado Estudio:** Mayor elegancia visual, orden jerárquico y alineación con estándares de ingeniería de software para audio profesional.
- **Modularidad:** Facilita añadir nuevas herramientas o nuevos tipos de documentos sin desordenar la interfaz.

### Negativas / Mitigaciones
- **Mayor altura vertical:** Dos secciones con múltiples carpetas pueden requerir scroll si la ventana tiene baja resolución vertical.  
  *Mitigación:* Todas las carpetas son colapsables (`StudioTreeFolder`) y la navegación por comandos de la barra inferior permite el acceso directo instantáneo.
