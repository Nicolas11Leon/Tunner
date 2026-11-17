# Implementation Plan: Master Pro Audio Hardware Console & Unified Studio Sync Suite

Este documento define la arquitectura formal, desglose por épicas y fases secuenciales para dotar a **Tunner** de una consola maestra de hardware, matriz de enrutamiento y sincronización de transporte global de grado profesional (estilo Ableton Live / Pro Tools).

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE8-STUDIO-AUDIO-CONSOLE-2026-001`
- **Título de la Implementación:** Master Pro Audio Hardware Console, Dynamic Device Matrix & Unified Studio Clock Sync
- **Fase del Proyecto:** Fase 8 (Universal Hardware I/O & Studio Kernel Interoperability)
- **Estado:** Propuesto
- **ADR Relacionado:** [0092_master_hardware_console_and_global_studio_sync.md](../04_adrs/0092_master_hardware_console_and_global_studio_sync.md)
- **Documentos Funcionales Base:** 
  - [102_uc_master_hardware_console_and_dynamic_device_matrix.md](../02_use_cases/102_uc_master_hardware_console_and_dynamic_device_matrix.md)
  - [103_uc_master_clock_and_global_studio_transport_sync.md](../02_use_cases/103_uc_master_clock_and_global_studio_transport_sync.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Construir una **Consola Maestra de E/S de Hardware y Reloj de Estudio Global** accesible en cualquier momento desde el shell de la aplicación (`Ctrl+Shift+I` o botón de acceso directo en la barra superior), permitiendo al usuario:
1. Enumerar, monitorear y conmutar en caliente dispositivos de entrada física (micrófonos, interfaces USB de baja latencia) y salida (monitores de estudio, auriculares, DACs).
2. Monitorear los niveles del bus maestro estéreo L/R en tiempo real con vúmetros balísticos de 60 FPS, detección de picos en dB, nivel RMS y LED de sobrecarga acústica (*clipping*).
3. Atenuar (-20 dB DIM), sumar a MONO o silenciar (MUTE) la salida maestra, con fader táctil proporcional.
4. Enrutar matricialmente los canales emisores (Deck DJ A/B, Metrónomo, Mic In, Teclado/Sintetizador, Grabador) hacia los destinos de salida física y procesamiento interno.
5. Sincronizar el reloj de tempo global (*Master Clock*) en compás y fase entre el Metrónomo, la Consola DJ y el scroll interactivo de partituras mediante compensación determinista de deriva temporal.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Consola maestra flotante y dockable (`StudioMasterHardwareConsoleWidget`).
  - Entidad de dominio de reloj maestro (`StudioMasterClockService`) con soporte para sincronización de BPM, compás y fase.
  - Vúmetro estéreo balístico reactivo L/R integrado en el bus maestro.
  - Fader maestro con escala de decibelios real: $f(x) = 20 \log_{10}(x)$ y limitador suave (*soft-clipper limiter*) anti-distorsión digital.
  - Persistencia de la matriz de enrutamiento y selección de dispositivos en el perfil del usuario.
- **Excluido (Out-of-Scope):**
  - Drivers propietarios ASIO cerrados de Windows que requieran DLLs privativas no libres (se utiliza soporte de audio multiplataforma estándar mediante canales nativos y FFI modular).
  - Protocolo Ableton Link en red distribuida (restringido a sincronización local in-process offline estricta según la constitución de Tunner).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.5`
  - Flutter SDK: `3.41.9` (Canal Stable)
  - Motor de Audio Core: `IStudioAudioEngine` y `IStudioAudioInputEngine`
- **Riesgo Tecnológico:**
  - Cero busy-waiting loops: el reloj maestro utiliza `Timer.periodic` compensado por delta de microsegundos (`Stopwatch`) para evitar deriva temporal acumulativa.
  - Latencia objetivo: Sub-10 ms en búferes de 128 a 512 muestras.
  - Rendimiento UI: Los vúmetros operan mediante repintado aislado en `CustomPainter` desacoplado del árbol de widgets principal para garantizar 60/120 FPS fluidos.

---

## 3. Desglose Arquitectónico por Épicas y Fases

### ÉPICA 1: Hardware I/O Engine & Dynamic Device Matrix (Fase 1: Dominio e Infraestructura de Hardware)
- **Objetivo:** Orquestar la detección, configuración de latencia y estado de los transductores físicos.
- **Entregables:**
  - [ ] `StudioMasterAudioMixer`: Bus maestro que centraliza todos los canales de salida, aplica ganancia maestra y realiza limitación suave.
  - [ ] `AudioDeviceMatrixEntity`: Estructura inmutable que mapea canales virtuales de estudio hacia endpoints físicos de entrada y salida.
  - [ ] Conmutación en caliente de dispositivos sin bloquear el hilo de ejecución principal ni detener la reproducción activa.
  - [ ] Pruebas unitarias de mezcla estéreo, atenuación DIM y cálculo de dB RMS.

### ÉPICA 2: Consola Maestra de E/S Flotante y Dockable (Fase 2: Presentación Táctil Pro)
- **Objetivo:** Proporcionar la interfaz de usuario de control de audio profesional.
- **Entregables:**
  - [ ] `StudioMasterHardwareConsoleWidget`: Panel de consola con estética de rack de estudio profesional.
  - [ ] `StudioStereoMasterVuMeter`: Vúmetro dual estéreo L/R con balística de caída rápida (*peak-hold decay*), marcas de escala de -60 dB a +3 dB y alerta roja de clipping.
  - [ ] Fader maestro vertical con indicador numérico de ganancia ($-\infty$ a $+6\text{ dB}$).
  - [ ] Botones táctiles de utilidad de estudio:
    - `MUTE`: Silenciado instantáneo del bus maestro.
    - `DIM`: Atenuación rápida de $-20\text{ dB}$ para escucha de referencia.
    - `MONO`: Suma monoaural $M = \frac{L + R}{2}$ para comprobación de cancelación de fase acústica.
  - [ ] Atajo de teclado global `Ctrl+Shift+I` para invocar la consola desde cualquier pestaña de Tunner.

### ÉPICA 3: Matriz Universal de Enrutamiento y Patchbay Visual (Fase 3: Ruteo Inter-Herramientas)
- **Objetivo:** Interconectar cualquier fuente de audio con cualquier destino de análisis o reproducción.
- **Entregables:**
  - [ ] Tabla de conexiones matricial: permite asignar qué módulos suenan en auriculares y cuáles en altavoces principales.
  - [ ] Aislamiento de monitoreo CUE para DJs: pre-escucha de Deck B en auriculares mientras Deck A suena en el Master sin contaminar la audiencia.
  - [ ] Enrutamiento del micrófono de entrada hacia el Transcriptor Polifónico o hacia el Afinador Strobe sin duplicar procesamiento DSP.

### ÉPICA 4: Reloj Maestro de Transporte Unificado (Fase 4: Sincronización Global de Tempo y Fase)
- **Objetivo:** Sincronizar todos los componentes rítmicos y temporales del estudio.
- **Entregables:**
  - [ ] `StudioMasterClock`: Motor de transporte central con control de tempo (BPM: 20 a 300), compás (2/4, 3/4, 4/4, 6/8) y subdivisión.
  - [ ] Sincronización de transporte unificado:
    - Botón `PLAY ALL`: Inicia simultáneamente el metrónomo, la pista activa de la consola DJ y el cursor de partitura.
    - Botón `STOP ALL`: Detiene deterministamente todos los generadores y retorna los cursores a cero.
  - [ ] Tap Tempo Global: Algoritmo de detección de tempo por promedio ponderado de intervalos entre pulsaciones táctiles.

### ÉPICA 5: Integración, Persistencia y Verificación Exhaustiva (Fase 5: Calidad y CI)
- **Objetivo:** Validación integral sin regresiones y persistencia de configuración.
- **Entregables:**
  - [ ] Persistencia local de la configuración de audio (dispositivo seleccionado, buffer size, ganancia maestra).
  - [ ] Suite de pruebas unitarias y de widgets con cobertura total para todos los componentes nuevos.
  - [ ] Validación con `flutter analyze --no-fatal-infos` (0 advertencias).
  - [ ] Validación con `flutter test` (100% pruebas pasando).
  - [ ] Compilación y verificación del binario nativo de Linux.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit `a9d7d18` (`fix(analysis): resolve all unused fields, unnecessary imports, and static warnings`).
- **Mitigación Inmediata:**
  - La consola maestra y el reloj operan como servicios modulares desacoplados sobre el bus de `IStudioAudioEngine` existente. En caso de conflicto de sincronización, los módulos pueden operar en modo de reloj autónomo (*free-run mode*) sin afectar la reproducción independiente de la consola DJ o el afinador.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md).
- [ ] Cero busy-waiting loops en el reloj maestro y procesadores de vúmetro.
- [ ] Latencia objetivo inferior a 10 ms en buffers configurables.
- [ ] Vúmetros balísticos funcionando fluidamente a 60/120 FPS sin degradar la UI.
- [ ] 100% de la suite de pruebas pasando en local y en GitHub Actions CI.
- [ ] Documentación técnica completa: Caso de Uso formal y ADR aprobados.
