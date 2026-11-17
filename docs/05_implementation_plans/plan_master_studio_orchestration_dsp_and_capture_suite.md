# Plan de Implementación: Suite Unificada de Orquestación Maestra, Cadena DSP de Masterización y Captura en Vivo

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE5-MASTER-DSP-CAPTURE-2026-0093`
- **Título de la Implementación:** Suite Unificada de Transporte Global, Cadena DSP de Masterización (3-Band EQ & Compressor), Captura Maestra a WAV y Comandos CLI Tunner OS
- **Fase del Proyecto:** Fase 5 (Consolidación de Workstation Pro)
- **Estado:** Propuesto
- **ADR Relacionado:** [ADR 0093](../04_adrs/0093_master_studio_orchestration_and_dsp_suite.md)
- **Documento Funcional Base:** [Caso de Uso 104](../02_use_cases/104_uc_master_studio_orchestration_and_dsp_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Crear un ecosistema de audio profesional completo que fusione armónicamente lo mejor de los 4 pilares:
1. **Sincronización Total de Transporte:** Coordinar el reloj de transporte (`StudioMasterClockService`) con el metrónomo, el reproductor de partituras/stems y la consola DJ para arrancar y detener el estudio al unísono con bloqueo de compás (`PLAY ALL` / `STOP ALL`).
2. **Cadena DSP de Masterización de Grado Estudio:** Implementar en el bus maestro filtros biquad de segundo orden (Low Shelf, Mid Bell con Q, High Shelf) y un procesador dinámico de compresión/limitación con medidor visual de reducción de ganancia (GR en dB).
3. **Captura Maestra en Vivo (Master Mixdown to WAV):** Diseñar un servicio de grabación en tiempo real que capture la mezcla de salida estéreo en formato WAV estándar (16/24-bit PCM) y guarde automáticamente los volcados en el sistema de archivos del espacio de trabajo.
4. **Interoperabilidad Terminal y CLI:** Ampliar el kernel de Tunner OS para exponer comandos rápidos de consola (`/master`, `/eq`, `/comp`, `/route`, `/clock`) accesibles mediante la barra de prompt y atajos de teclado.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Dominio matemático de filtros Biquad (Audio EQ Cookbook de Robert Bristow-Johnson).
  - Algoritmo de compresión de audio con curvas de ataque/liberación, umbral y cálculo de reducción de ganancia en decibelios.
  - Generador/codificador de cabecera y flujo WAV PCM estándar sin dependencias de paquetes externos de terceros.
  - Conexión de transporte global bidireccional entre `StudioMasterClockService`, `TunerViewModel` y `DjConsoleViewModel`.
  - Integración visual en la consola maestra (`StudioMasterHardwareConsoleWidget`) con pestañas o paneles dedicados para MASTERING FX y MASTER REC.
  - Comandos de terminal en `TunnerOsKernel`.
  - Pruebas unitarias de fórmulas DSP, grabación y widgets.
- **Excluido (Out-of-Scope):**
  - Algoritmos de reverberación por convolución FFT de respuesta al impulso (previstos para una fase posterior de efectos espaciales).
  - VST3/AU host plugins de terceros (se prioriza procesamiento en proceso nativo de Dart puro según [AGENTS.md](../../AGENTS.md)).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x` (Canal oficial estable).
  - Flutter SDK: Versión estable oficial.
  - Cero dependencias añadidas: Toda la matemática de filtros biquad, compresión y codificación de cabeceras WAV se escribe en código Dart puro dentro de `lib/core/audio/domain/`.
- **Riesgo Tecnológico:**
  - Sin FFI externo ni dependencias de plataforma: Máxima portabilidad y estabilidad offline en Linux, macOS, Windows, Android e iOS.
  - Sin busy-waiting loops: El cálculo de coeficientes de filtro se realiza únicamente cuando el usuario modifica un potenciómetro; el bucle de procesamiento de muestras opera en tiempo lineal $O(N)$ sobre buffers estéreo.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### ÉPICA 1: Dominio Matemático de la Cadena DSP de Masterización
- [x] Implementar `StudioMasterBiquadFilter` (`lib/core/audio/domain/studio_master_biquad_filter.dart`):
  - Fórmulas de Robert Bristow-Johnson: Low Shelf (100 Hz), Peaking Bell (1 kHz, Q=0.707), High Shelf (8 kHz).
  - Función de procesamiento de buffers estéreo con estados previos de retraso ($x[n-1], x[n-2], y[n-1], y[n-2]$).
- [x] Implementar `StudioMasterDynamicsProcessor` (`lib/core/audio/domain/studio_master_dynamics_processor.dart`):
  - Detección de envolvente con coeficientes de ataque ($1\text{ ms}$ a $50\text{ ms}$) y liberación ($20\text{ ms}$ a $500\text{ ms}$).
  - Cálculo de reducción de ganancia (GR en dB) y escalado lineal.
- [x] Integrar la cadena en `StudioMasterAudioMixer` y en la entidad inmutable `AudioDeviceMatrixEntity`:
  - Propiedades: `eqLowDb`, `eqMidDb`, `eqHighDb`, `isEqBypassed`, `compThresholdDb`, `compRatio`, `isCompBypassed`.
- [x] Pruebas unitarias de filtros biquad, respuestas en frecuencia y reducción de ganancia dinámica.

### ÉPICA 2: Servicio de Captura y Grabación Maestra (Master Mixdown to WAV)
- [x] Diseñar el contrato de dominio `IStudioMasterCaptureService` (`lib/core/audio/domain/i_studio_master_capture_service.dart`).
- [x] Implementar el servicio en infraestructura `StudioMasterCaptureService` (`lib/core/audio/infrastructure/studio_master_capture_service.dart`):
  - Codificador de cabecera WAV RIFF (44 bytes), formato PCM signed 16-bit little-endian.
  - Escritura continua en búfer de memoria / archivo sin bloquear el hilo principal.
  - Integración con `StudioWorkspaceFileSystemService` para guardar automáticamente en `recordings/master_mix_YYYYMMDD_HHMMSS.wav`.
- [x] Pruebas unitarias de generación de cabecera WAV, duración y contenido de audio grabado.

### ÉPICA 3: Sincronización Global de Transporte
- [x] Conectar `StudioMasterClockService` con `TunerViewModel`:
  - Al recibir `startTransport()` o `stopTransport()`, alternar metrónomo en fase y sincronizar tempo base.
- [x] Conectar `StudioMasterClockService` con `CompositionNotationWorkspaceView`:
  - Inicio del cursor de partitura sincronizado.
- [x] Atajo de teclado global de espacio o combinación dedicada para transporte unificado `PLAY ALL / STOP ALL`.

### ÉPICA 4: Comandos de Consola en Tunner OS Kernel CLI
- [x] Extender `TunnerOsKernel` (`lib/core/terminal/domain/tunner_os_kernel.dart`) con comandos:
  - `/master [gain <db> | mute | dim | mono | rec | stop-rec]`
  - `/eq [low <db> | mid <db> | high <db> | bypass]`
  - `/comp [thresh <db> | ratio <r> | bypass]`
  - `/route <channel> <master|cue|mute>`
  - `/clock [play | pause | stop | bpm <val> | tap]`
- [x] Integrar sugerencias de autocompletado en la barra de prompt de `StudioDesktopAppShell`.

### ÉPICA 5: Presentación Táctil en Rack de Hardware, Mini-Pill y CI
- [x] Actualizar `StudioMasterHardwareConsoleWidget`:
  - Panel colapsable o sección "MASTERING FX": potenciómetros/sliders para EQ de 3 bandas (LOW, MID, HIGH) y Compresor (THRESH, RATIO con vúmetro GR animado).
  - Botón táctil `MASTER REC` con LED rojo parpadeante y cronómetro de duración en vivo.
- [x] Actualizar `StudioMasterMeterMiniPillWidget`:
  - Indicador visual cuando la grabación maestra está en curso (`REC ●`).
- [x] Pruebas de widgets e integración en `main_app_shell_test.dart`.
- [x] Verificación con `flutter analyze` y `flutter test`.
- [x] Compilación del binario nativo de Linux y validación en GitHub Actions CI.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit `48b6738` (`feat(audio): implement audio matrix session persistence and live master meter status bar mini-pill`).
- **Mitigación Inmediata:** La cadena DSP cuenta con flags booleanos independientes de Bypass (`isEqBypassed: true`, `isCompBypassed: true`). Si cualquier filtro presentara inestabilidad numérica, el bypass desactiva el cómputo y entrega la señal estéreo directa sin interrupción.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md).
- [x] Cero busy-waiting loops en hilos de procesamiento y temporizadores.
- [x] Latencia acústica de búfer inferior a 10 ms preservada.
- [x] Filtros Biquad numéricamente estables sin derivas de punto flotante ni desbordamientos NaN.
- [x] Archivos WAV de salida completamente reproducibles y con cabeceras válidas.
- [x] 100% de la suite de pruebas automatizadas pasando en local y en GitHub Actions CI.
- [x] Documentación técnica completa: Caso de Uso 104 y ADR 0093 archivados.
