# Caso de Uso 103: Reloj Maestro de Transporte Unificado y Sincronización Global de Estudio

Este documento define la especificación canónica, diagramas de flujo y modelos de sincronización para el Reloj Maestro de Transporte Global (*Studio Master Clock*) de **Tunner**.

---

## 1. Diagrama de Casos de Uso Formal (Mermaid)

```mermaid
flowchart TD
    User(["Usuario / Compositor / DJ"])

    subgraph Master_Transport_Sync ["Sistema de Transporte y Reloj Maestro"]
        UC103_1["Iniciar Transporte Global ('PLAY ALL')"]
        UC103_2["Pausar / Detener Transporte Global ('STOP ALL')"]
        UC103_3["Ajustar Tempo Maestro (BPM: 20 a 300)"]
        UC103_4["Calcular Tempo por Pulsaciones ('TAP TEMPO')"]
        UC103_5["Alinear Compás y Fase (Downbeat Sync)"]
        UC103_6["Sincronizar Decks DJ con Reloj Maestro"]
        UC103_7["Sincronizar Metrónomo y Clics Acústicos"]
        UC103_8["Sincronizar Cursor de Lectura de Partituras"]
    end

    User --> UC103_1
    User --> UC103_2
    User --> UC103_3
    User --> UC103_4
    UC103_1 --> UC103_5
    UC103_5 --> UC103_6
    UC103_5 --> UC103_7
    UC103_5 --> UC103_8
```

---

## 2. Diagrama de Secuencia de Sincronización de Fase (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Usuario
    participant UI as QuickActionDock / Topbar
    participant Clock as StudioMasterClockService
    participant Metro as AudioSynthesizerService (Metrónomo)
    participant DJ as DjConsoleViewModel (Decks DJ)
    participant Score as SheetMusicViewer (Partitura)

    Usuario->>UI: Pulsa botón maestro 'PLAY ALL'
    UI->>Clock: startTransport(bpm: 120.0, meter: 4/4)
    Clock->>Clock: Iniciar timer compensado con Stopwatch (cero deriva)
    
    par Emisión de Pulso en Fase
        Clock->>Metro: triggerDownbeat(beatIndex: 1, isAccent: true)
        Metro->>Metro: Reproducir clic de tiempo fuerte (downbeat PCM)
    and Sincronización DJ Deck
        Clock->>DJ: syncToClock(bpm: 120.0, phaseOffsetMs: 0)
        DJ->>DJ: Alinear reproducción del plato al downbeat
    and Desplazamiento de Partitura
        Clock->>Score: advancePlayhead(measure: 1, beat: 1)
        Score->>Score: Animar cursor vertical a 60/120 FPS
    end

    Usuario->>UI: Pulsa 'TAP TEMPO' repetidamente (4 pulsaciones a 128 BPM)
    UI->>Clock: registerTapEvent()
    Clock->>Clock: Promedio aritmético de deltas temporales (intervalos de 468.75 ms)
    Clock-->>UI: Tempo actualizado a 128.0 BPM
    Clock->>DJ: adjustTempo(128.0 BPM)
    Clock->>Metro: adjustTempo(128.0 BPM)
```

---

## 3. Especificación Formal del Caso de Uso

### 3.1 Precondiciones
1. La aplicación Tunner está en ejecución y los módulos que requieren sincronización (Consola DJ, Metrónomo, Partitura) están instanciados.
2. No existen procesos de E/S que bloqueen el bucle de eventos principal.

### 3.2 Postcondiciones
1. El reloj de transporte emite eventos periódicos de pulso rítmico (*quarter notes*, *eighth notes*, *sixteenth notes*) con precisión de microsegundos.
2. La deriva temporal acumulativa $\Delta t_{\text{deriva}}$ se mantiene en $0.0\text{ ms}$ mediante compensación por `Stopwatch` del sistema operativo.
3. El estado de reproducción de todos los módulos suscriptores es consistente.

### 3.3 Flujo Principal
1. El usuario define el tempo maestro en la barra superior o pulsa `TAP TEMPO` en el teclado o pantalla táctil.
2. Al pulsar el botón `PLAY ALL` (o presionar la barra espaciadora en modo estudio), el `StudioMasterClockService` emite la señal de arranque con marca temporal $T_0$.
3. Cada pulso de reloj despacha eventos síncronos a los suscriptores:
   - El canal de metrónomo dispara el búfer PCM correspondiente.
   - La consola DJ calcula el factor de velocidad $R = \frac{\text{BPM}_{\text{maestro}}}{\text{BPM}_{\text{track}}}$ y ajusta el pitch sin discontinuidad.
   - El visor de partituras desplaza el cursor a lo largo de las cabezas de nota según la duración métrica correspondiente.
4. Al pulsar `STOP ALL`, el transporte se detiene y todos los módulos pausan su reproducción y resetean el playhead.

### 3.4 Flujos Alternativos y de Error
- **Desincronización por carga elevada de CPU:** Si el procesador experimenta un retraso temporal puntual, el reloj maestro calcula el número de ticks transcurridos en tiempo real mediante `elapsedMicroseconds` y adelanta la fase instantáneamente en lugar de acumular retraso, preservando la métrica global.
