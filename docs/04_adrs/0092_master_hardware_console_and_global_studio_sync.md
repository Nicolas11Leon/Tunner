# ADR 0092: Consola Maestra de E/S de Hardware, Matriz Dinámica y Sincronización Global de Estudio

- **Estado:** Propuesto
- **Fecha:** 2026-11-17
- **Autor:** Equipo de Ingeniería Tunner
- **Casos de Uso Relacionados:** [UC-102](../02_use_cases/102_uc_master_hardware_console_and_dynamic_device_matrix.md), [UC-103](../02_use_cases/103_uc_master_clock_and_global_studio_transport_sync.md)
- **Plan de Implementación:** [plan_master_pro_audio_hardware_console_and_unified_studio_sync.md](../05_implementation_plans/plan_master_pro_audio_hardware_console_and_unified_studio_sync.md)

---

## 1. Contexto

La arquitectura de **Tunner** cuenta con motores de audio centralizados (`IStudioAudioEngine` e `IStudioAudioInputEngine`) que gestionan la salida multicanal de baja latencia y la captura por anillo de memoria circular (`AudioRingBuffer`). Sin embargo, a medida que la plataforma se consolida como una estación de trabajo de audio digital (DAW) completa para educación musical, producción y actuación en directo, surgen los siguientes requerimientos fundamentales:
1. **Falta de un centro de control maestro:** La selección de dispositivos físicos de hardware, el monitoreo del volumen maestro y la calibración de latencia se encontraban dispersos en modales separados.
2. **Ausencia de medición balística unificada:** No existía un medidor estéreo L/R master con detección de transitorios de pico y medición de saturación (*clipping*).
3. **Disparidad de transporte y tempo:** El metrónomo, los decks de la consola DJ y el visor de partituras operaban con relojes internos independientes, imposibilitando la sincronización en fase durante sesiones conjuntas.

---

## 2. Decisión

Se decide implementar una **Consola Maestra de E/S de Hardware (`StudioMasterHardwareConsoleWidget`)** y un **Servicio de Reloj Maestro de Transporte (`StudioMasterClockService`)** bajo las siguientes directrices arquitectónicas:

1. **Bus Maestro Estéreo (`StudioMasterAudioMixer`):**
   - Todos los canales de audio activos convergen en un único bus maestro antes de emitirse a los controladores físicos de audio del sistema operativo.
   - Incorpora control de volumen con escala logarítmica de decibelios:
     $$\text{Ganancia Lineal} = 10^{\frac{\text{dB}}{20}}$$
   - Incorpora funciones de estudio esenciales: `MUTE` (silenciado instantáneo), `DIM` (atenuación de $-20\text{ dB}$ para escucha de referencia) y `MONO` (suma de canales para comprobación de fase acústica).
   - Incorpora un limitador suave (*soft-clipper limiter*) para prevenir distorsión armónica digital cuando la suma de canales excede $0\text{ dBFS}$.

2. **Vúmetro Estéreo Balístico L/R a 60 FPS:**
   - Implementado mediante `CustomPainter` desacoplado del árbol de widgets principal, con caída de aguja exponencial (*decay* de $20\text{ dB/s}$) y retención de pico transitorio (*peak-hold* de $1.2\text{ s}$).
   - Indicador de saturación en color rojo reactivo cuando la señal supera $-0.1\text{ dBFS}$.

3. **Reloj Maestro de Transporte sin Deriva (`StudioMasterClockService`):**
   - Utiliza `Stopwatch` del sistema operativo para recalcular la posición de fase absoluta en cada tick, eliminando por completo la deriva temporal acumulativa inherente a `Timer.periodic`.
   - Soporta sincronización de tempo (BPM: 20 a 300), compás y subdivisión métrica.
   - Implementa los comandos globales de transporte: `PLAY ALL` (reproduce sincrónicamente metrónomo, consola DJ y partituras), `PAUSE ALL` y `STOP ALL`.

4. **Persistencia y Acceso Rápido:**
   - Accesible globalmente mediante el atajo de teclado `Ctrl+Shift+I` o a través del botón de consola en la barra superior.
   - Persistencia local de los transductores de hardware seleccionados y la configuración de latencia de búfer en el perfil del usuario.

---

## 3. Consecuencias

### Consecuencias Positivas
- **Experiencia de Usuario Profesional:** El músico o educador dispone de una consola de grado estudio para controlar todo el hardware de audio desde un único panel centralizado.
- **Sincronización Rítmica Determinista:** La consola DJ, el metrónomo y las partituras pueden tocar al unísono con coherencia métrica y de fase absoluta.
- **Prevención de Daño Acústico y Clipping:** El limitador suave y la medición en tiempo real impiden chasquidos y distorsión digital indeseada en monitores de estudio y auriculares.

### Consecuencias Negativas / Retos Mitigados
- **Carga de CPU:** El cálculo continuo de niveles RMS y la animación de vúmetros a 60 FPS podría aumentar el consumo de batería; se mitiga limitando el repintado exclusivamente a los rectángulos sucios del canvas del vúmetro y suspendiendo el timer de medición cuando la consola no es visible.
- **Variabilidad de hardware entre plataformas:** La conmutación de dispositivos en caliente depende de las capacidades del sistema operativo (ALSA en Linux, CoreAudio en macOS, AudioTrack en Android); se mitiga encapsulando el enrutamiento detrás de la interfaz abstracta `IStudioAudioEngine` con fallback automático al dispositivo por defecto ante desconexiones físicas.
