# ADR 0091: Pro Studio Dashboard Hub, Activos Canónicos de Workspace y Terminal Interactiva Tunner OS

## Estado
Aprobado

## Contexto
El Dashboard de inicio de Tunner Studio se mostraba en una única columna vertical que dejaba amplias zonas vacías en pantallas panorámicas de escritorio. Además, el explorador lateral de archivos reportaba conteos en cero `(0)`, omitiendo proyectos de ejemplo para exploración inmediata.

Asimismo, la visión del creador requiere que la aplicación opere como una estación universal y un "sistema operativo musical", dotada de una interfaz de línea de comandos (CLI) y terminal interactiva donde el usuario pueda controlar el transporte de audio, cargar pistas, consultar el sistema de archivos y navegar entre herramientas mediante comandos textuales rápidos.

## Decisión
1. **Rediseño del Dashboard Principal (`HomeDashboardScreen`):**
   - Implementar un **Grid de 2 Columnas responsivo** para escritorio ($\ge 950\text{ px}$), integrando de forma prominente la tarjeta de la **Consola DJ Pro Workstation** (Deck A/B, Jog Wheels, Sampler) junto al Afinador, Lecciones Didácticas, Rack Modular y Partituras.
   - Diseñar un **HUD de Telemetría Core Audio en Vivo**: Frecuencia de muestreo (44.1/48.0 kHz), latencia (< 8ms), Ring Buffer Lock-Free (16k) y VU meter dinámico de dBFS de entrada.
   - Incorporar una sección de **Plantillas de Creación Inmediata** (.tunner, .tndj, .tnpreset).
2. **Poblado Dinámico del Árbol de Archivos de Workspace:**
   - Pre-cargar en el repositorio (`StudioFileSystemRepository`) proyectos funcionales de demostración:
     - `Suite_No1_Bach.tunner` (Partitura polifónica con stems).
     - `Fur_Elise_Club_Mix.tndj` (Sesión completa de 2 Decks para la Consola DJ).
     - `Cyberpunk_Night_Groove.wav` (Audio estéreo de alta fidelidad).
     - `Guitarra_Drop_D_Standard.tnpreset` (Preset de afinación acústica con temperamento).
3. **Núcleo de Terminal y CLI Tunner OS (`lib/core/terminal/`):**
   - `TunnerOsKernel`: Intérprete léxico de comandos desacoplado de la UI, con soporte para:
     - `tuner run <modulo>` (navegación a pestañas 1-5).
     - `dj load <deck> <track>` | `dj play <deck>` | `dj pause <deck>` | `dj bpm <deck> <val>`.
     - `io list` | `io set-input <id>` | `dsp status`.
     - `fs ls` | `fs cat <archivo>` | `fs info`.
     - `theme set <nombre>` | `help`.
   - `TunnerOsTerminalDrawer`: Cajón interactivo desplegable estilo Quake / VS Code con atajo global `Ctrl + ~`, historial de comandos con flechas arriba/abajo y salida tipográfica monospaciada.

## Consecuencias

### Positivas
- **Aprovechamiento Ergonómico:** Se maximiza la densidad informativa del dashboard en monitores de alta resolución.
- **Acceso Inmediato:** El usuario puede probar el audio y las partituras con un solo clic en los proyectos pre-cargados.
- **Control Unificado Estilo OS:** La terminal permite automatizar y pilotar todo el software mediante teclado para usuarios avanzados y flujos en vivo.

### Negativas / Mitigaciones
- Mayor superficie interactiva en la pantalla principal.
- Mitigación: Se organiza mediante secciones visualmente contrastadas con la paleta de tokens del sistema de diseño atómico.
