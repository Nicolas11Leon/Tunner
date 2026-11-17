# ADR 0093: Suite Unificada de Orquestación Maestra, Cadena DSP de Masterización y Captura en Vivo

- **Estado:** Propuesto
- **Fecha:** 2026-11-17
- **Autor:** Equipo de Ingeniería Tunner
- **Casos de Uso Relacionados:** [UC-104](../02_use_cases/104_uc_master_studio_orchestration_and_dsp_suite.md)
- **Plan de Implementación:** [plan_master_studio_orchestration_dsp_and_capture_suite.md](../05_implementation_plans/plan_master_studio_orchestration_dsp_and_capture_suite.md)

---

## 1. Contexto

Con la implementación de la Consola Maestra de E/S de Hardware ([ADR 0092](0092_master_hardware_console_and_global_studio_sync.md)), Tunner cuenta con ruteo de canales virtuales hacia buses físicos, vúmetros estéreo a 60 FPS, control logarítmico de ganancia y persistencia de sesión. Sin embargo, para consolidar la plataforma como un entorno integral de producción, práctica y grabación profesional ("lo mejor de cada área"), se identifican cuatro requerimientos complementarios:

1. **Sincronización Bidireccional de Transporte:** El reloj maestro (`StudioMasterClockService`) necesita coordinar de forma bidireccional el metrónomo, el atril de partituras/stems y la consola DJ para arrancar, pausar y detener todo el ecosistema al unísono con bloqueo de compás y compás fraccionario.
2. **Cadena DSP de Masterización en Bus Maestro:** La señal combinada de múltiples fuentes virtuales (sintetizador SF2, reproductor de stems, DJ Decks, metrónomo acústico) requiere modelado tonal (ecualizador de 3 bandas) y control dinámico de picos (compresor/limitador) para evitar fatiga auditiva y clipping digital.
3. **Captura Directa de Mezcla (Master Mixdown to WAV):** Se requiere un mecanismo en tiempo real para grabar la mezcla maestra completa en un archivo WAV PCM estándar (16/24 bits) y organizarlo automáticamente dentro del explorador de proyectos de Tunner.
4. **Interoperabilidad Terminal y CLI:** Los usuarios avanzados y automatizaciones necesitan comandos concisos en `TunnerOsKernel` para modular la consola y el transporte sin recurrir a la UI táctil.

---

## 2. Decisión

Se adopta una arquitectura modular unificada que expande el núcleo de audio en las siguientes capas:

### 2.1 Procesamiento DSP de Masterización (`lib/core/audio/domain/`)
- **Filtros Digitales Biquad (Audio EQ Cookbook):**
  - Implementación de ecuaciones directas de Robert Bristow-Johnson:
    - **Low Shelf:** Control de realce o atenuación de graves a 100 Hz ($\pm 12\text{ dB}$).
    - **Mid Peaking Bell:** Modelado de frecuencias medias a 1 kHz con ancho de banda $Q = 0.707$ ($\pm 12\text{ dB}$).
    - **High Shelf:** Realce de presencia y aire a 8 kHz ($\pm 12\text{ dB}$).
- **Compresor Dinámico con Medición de Reducción de Ganancia (GR Meter):**
  - Detección de envolvente con coeficientes de ataque ($1\text{ ms}$ a $50\text{ ms}$) y liberación ($20\text{ ms}$ a $500\text{ ms}$).
  - Cálculo de ganancia reducida en decibelios:
    $$\Delta\text{Gain (dB)} = \begin{cases} 0 & \text{si } X_{\text{dB}} \le \text{Threshold} \\ (\text{Threshold} - X_{\text{dB}}) \left(1 - \frac{1}{\text{Ratio}}\right) & \text{si } X_{\text{dB}} > \text{Threshold} \end{cases}$$
  - Salida de telemetría de Reducción de Ganancia ($GR$) integrada en el flujo de vúmetros.

### 2.2 Captura y Exportación a Disco (`StudioMasterCaptureService`)
- Grabación sin pérdidas en formato WAV con cabecera estándar RIFF (44 bytes), codificación PCM signed 16-bit little endian o 24-bit.
- Almacenamiento desacoplado en el sistema de archivos de espacio de trabajo local (`StudioWorkspaceFileSystemService`) bajo la ruta estándar `recordings/master_mix_YYYYMMDD_HHMMSS.wav`.
- Control de estado reactivo: `isRecording`, `elapsedDuration`, `bytesWritten`.

### 2.3 Orquestación de Transporte Global
- Enlace de `StudioMasterClockService` con:
  - `TunerViewModel`: inicio/pausa de metrónomo acústico y partitura.
  - `DjConsoleViewModel`: sincronización de BPM y arranque conjunto de pistas.
- Atajo de teclado global y botones unificados `PLAY ALL` / `STOP ALL`.

### 2.4 Comandos CLI en Tunner OS Kernel
- Integración de los comandos `/master`, `/eq`, `/comp`, `/route`, `/clock` y `/buffer` con autocompletado en la barra de prompt de `StudioDesktopAppShell`.

---

## 3. Consecuencias

### Consecuencias Positivas
- **Flujo de Trabajo Coherente e Integral:** Combina reproducción sincronizada, ecualización, dinámica de estudio, volcado a archivo y control por teclado/CLI.
- **Rigor Matemático y Cero Dependencias Externas:** Todos los algoritmos DSP (filtros Biquad, detector de envolvente de compresión y codificador WAV) se ejecutan en Dart puro en el proceso local.
- **Transparencia Acústica:** Conmutadores de Bypass independientes para EQ y Compresor garantizan latencia cero y cero coloración cuando están desactivados.

### Consecuencias Negativas / Mitigaciones
- **Mayor Carga de CPU en Procesamiento DSP Continuo:** Mitigado calculando los coeficientes de filtro biquad una sola vez al modificar parámetros y reutilizándolos en el bucle de muestras con estructuras de datos en memoria compactas.
