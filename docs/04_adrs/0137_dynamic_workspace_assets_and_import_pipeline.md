# ADR 0016: Adopción del Sistema Dinámico de Carpetas de Assets y Canales de Creación e Importación

## Estado
Aprobado.

## Contexto
El usuario y la dirección de producto han especificado que las carpetas de assets (partituras, tomas de audio, presets de afinación, sesiones de estudio) deben iniciar **vacías por defecto** en lugar de mostrar datos ficticios o hardcodeados, ofreciendo opciones claras y profesionales para **crear un nuevo documento desde cero** o **importar archivos existentes** (`.musicxml`, `.mid`, `.wav`, etc.).

## Decisión
1. **Extensión de `StudioTreeFolder`:**
   - Incorporar soporte para `Widget? actionButton` en la cabecera de la carpeta (ej. botón `+` para añadir rápidamente).
   - Incorporar soporte para `emptyPlaceholderAction`: cuando `items.isEmpty`, la carpeta renderiza acciones contextuales amigables de primer nivel (`[+] Crear Nuevo...`, `[⬇] Importar Archivo...`), evitando estados muertos o silenciosos.
2. **Diálogos de Creación e Importación Profesional:**
   - Se implementan modales con sistema de diseño atómico `StudioDesignTokens`:
     - `StudioNewScoreDialog`: creación paramétrica de partituras limpias con compás, tonalidad y tempo.
     - `StudioImportScoreDialog`: decodificación de archivos MusicXML / MIDI o selección del canon maestro.
     - `StudioNewTuningPresetDialog`: guardado de presets de afinación (Hz y temperamentos).
3. **Persistencia e Integración de Dominio:**
   - Todo documento nuevo o importado se gestiona mediante las operaciones inmutables existentes de `TunerViewModel` (`addSongPackage`, `importScoreFromBytes`, `startPracticeRecording`), garantizando integridad en memoria y persistencia automática en disco.

## Consecuencias
- **Positivas:**
  - Máxima fidelidad profesional: la suite se comporta como una estación de trabajo real donde el usuario crea, importa y organiza sus propios proyectos y documentos musicales.
  - Cero datos huérfanos o ficticios confusos.
  - Experiencia de creación e importación fluida con feedback visual inmediato.
- **Negativas / Mitigaciones:**
  - Requiere asegurar que cuando una carpeta esté vacía, el usuario entienda claramente cómo crear su primer documento (mitigado con los botones de acción integrados dentro de la carpeta vacía).
