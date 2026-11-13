# ADR 0060: Arquitectura de la Suite de Efectos en Vivo, Detección de BPM y Grabador de Mezcla Maestra

## Estado
Aprobado (Approved) - 2026-11-13

## Contexto
Tras la implementación de la Consola DJ Virtual de doble reproductor y el motor universal de mapeo QWERTY, se requiere dotar al intérprete de herramientas profesionales de modulación tímbrica, sincronización automática y documentación de la sesión. Sin estas capacidades:
1. El usuario debe adivinar o configurar manualmente el tempo de cada archivo importado.
2. Las transiciones entre pistas carecen de herramientas de barrido espectral habituales en cabina (filtros bipolares de frecuencias) y efectos de eco temporizados.
3. No existe un mecanismo dentro del monolito para registrar y exportar la mezcla realizada en un archivo de audio estéreo permanente sin depender de software de captura externo.

## Decisión
1. **Capa de Dominio (`lib/features/dj_console/domain/`):**
   - **`BpmBeatTrackerEngine`:** Algoritmo en Dart puro que procesa búferes de audio PCM mediante función de flujo de energía transiente (*Onset Energy Detection*) y autocorrelación temporal para deducir el tempo con precisión de medio BPM en el rango $60 - 180\text{ BPM}$.
   - **`DjChannelFxEntity`:** Entidad inmutable que modela la posición del filtro bipolar $k \in [-1.0, 1.0]$, el estado del efecto Delay, la división métrica rítmica ($1/2, 1/4, 1/8, 1/16$), el factor de realimentación y el nivel de mezcla *Dry/Wet*.
   - **`DjLiveMixRecorderEntity`:** Modelo de dominio para control de la sesión de grabación, cálculo de duración en milisegundos y acumulación de muestras estéreo.
   - **Ampliación de `DjAction` y `DjPerformanceOrchestrator`:** Nuevas acciones para barrido de filtro (`deckAFilterSweep`, `deckBFilterSweep`), conmutación de retardo (`deckAToggleDelay`, `deckBToggleDelay`) y control de grabación (`toggleMixRecording`).
2. **Capa de Datos e Infraestructura (`lib/features/dj_console/data/`):**
   - **Evolución de `DjAudioProcessor`:** Incorporación de filtrado biquad en cascada para emulación de barrido Low-Pass y High-Pass con $Q = 1.414$, procesamiento de línea de retardo (*delay line*) y compresión blanda (*soft-clipping tanh*).
   - **`DjMixWavEncoder`:** Codificador binario de alta fidelidad que genera encabezados canónicos RIFF/WAVE PCM estéreo de 16 bits a $44.1\text{ kHz}$ o $48\text{ kHz}$.
3. **Capa de Presentación (`lib/features/dj_console/presentation/`):**
   - Enriquecimiento de `DjConsoleModal`: Perillas rotativas/deslizantes de filtro bipolar, selectores de división de delay por chip, indicador de grabación en vivo con temporizador activo y botón de carga inteligente con auto-detección de BPM.

## Consecuencias

### Positivas
- **Flujo de Trabajo Completo y Profesional:** El usuario cuenta con una estación de mezcla DJ integral, capaz de importar stems, detectar tempos, modular filtros resonantes, crear transiciones con delay sincronizado y exportar su sesión master.
- **Rendimiento Determinista:** Algoritmo de detección de BPM optimizado sin bucles de espera activa; latencia de retardo menor a $2\text{ ms}$ agregada en audio buffers.
- **Calidad de Audio de Conservatorio:** Cero distorsión digital o chasquidos por desbordamiento numérico mediante saturación hiperbólica suave a $0\text{ dBFS}$.

### Negativas / Mitigaciones
- **Consumo de Memoria en Grabaciones Prolongadas:** Sesiones de más de 30 minutos pueden requerir cientos de megabytes en memoria RAM antes de exportarse.
  *Mitigación:* Se implementa un límite de seguridad en el buffer circular y codificación secuencial en chunks pequeños.