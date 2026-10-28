# Caso de Uso 26: Medición y Calibración Rítmica por Tap Tempo Determinista (Deterministic Tap Tempo)

Este documento formaliza la especificación funcional, los diagramas de casos de uso y de secuencia del motor de medición de tempo por pulsación táctil manual y diagnóstico de estabilidad rítmica en **Tunner**.

---

## 1. Diagrama de Caso de Uso (Mermaid)

```mermaid
flowchart TD
    Actor([Músico / Director de Orquesta / Estudiante])

    subgraph Tap Tempo & Rhythmic Synchronization Studio
        UC1[Pulsar Botón de Tap Tempo Rítmicamente]
        UC2[Registrar Marcas de Tiempo de Alta Resolución]
        UC3[Calcular Intervalos Inter-Pulsación IOI]
        UC4[Filtrar Jitter y Calcular Promedio Ponderado]
        UC5[Calcular BPM Resultante y Término Italiano]
        UC6[Evaluar Varianza y Estabilidad Métrica en Milisegundos]
        UC7[Sincronizar Automáticamente el Metrónomo de Alta Resolución]
    end

    Actor --> UC1
    UC1 --> UC2
    UC2 --> UC3
    UC3 --> UC4
    UC4 --> UC5
    UC4 --> UC6
    UC5 --> UC7
    Actor --> UC7
```

---

## 2. Diagrama de Secuencia y Flujo Detallado (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Musico as Músico
    participant UI as TapTempoWidget
    participant VM as TunerViewModel
    participant Engine as TapTempoEngine
    participant Metro as HighResMetronomeService

    Musico->>UI: Pulsa el botón Tap Tempo (Tap 1)
    UI->>VM: recordTapTempo()
    VM->>Engine: registerTap(DateTime.now())
    Engine-->>VM: TapTempoResult(tapCount: 1, bpm: 120, status: "Registrando primer pulso...")
    VM-->>UI: Muestra "Toca de nuevo al ritmo..."

    Musico->>UI: Pulsa el botón Tap Tempo (Tap 2, 500 ms después)
    UI->>VM: recordTapTempo()
    VM->>Engine: registerTap(DateTime.now())
    Engine-->>VM: TapTempoResult(tapCount: 2, bpm: 120, jitterMs: 0.0, mark: "Allegro")
    VM->>Metro: updateTempo(120)
    VM-->>UI: Actualiza BPM en metrónomo y pantalla inmediatamente (120 BPM)

    Musico->>UI: Pulsa taps adicionales (Tap 3, Tap 4...)
    Engine->>Engine: Aplica promedio ponderado y evalúa desviación estándar (Jitter)
    Engine-->>VM: TapTempoResult(bpm: 122, jitterMs: 8.4, stability: "Metronómico")
    VM-->>UI: Muestra badge de estabilidad "Metronómico (±8.4 ms)"
```

---

## 3. Especificación Formal

### 3.1 Precondiciones
1. El usuario tiene abierto Tunner.
2. Los servicios de metrónomo acústico se encuentran disponibles.

### 3.2 Flujo Principal (Happy Path)
1. El usuario toca el botón de Tap Tempo de manera regular siguiendo el pulso deseado.
2. La primera pulsación inicializa el cronómetro y abre la ventana temporal de medición.
3. A partir de la segunda pulsación consecutiva, el motor calcula el intervalo entre pulsaciones consecutivas $\Delta t_i = t_i - t_{i-1}$.
4. El motor aplica un promedio móvil ponderado donde las pulsaciones más recientes tienen mayor peso relativo.
5. El valor de BPM resultante se actualiza en el metrónomo activo y en la interfaz de usuario.
6. El motor calcula la desviación estándar $\sigma$ en milisegundos y muestra una evaluación cualitativa de la precisión métrica del músico.

### 3.3 Postcondiciones
1. El metrónomo adopta la velocidad pulsada por el usuario.
2. Si transcurren más de 2.5 segundos sin pulsaciones, el acumulador se reinicia automáticamente sin afectar el BPM fijado.

### 3.4 Flujos Alternativos y Excepciones
- **Pulsación Aislada:** Si el usuario realiza una sola pulsación y se detiene, el tempo actual no se altera y tras 2500 ms el estado vuelve a reposo.
- **Pulsaciones Fuera de Rango:** Si la velocidad pulsada es menor a 30 BPM o mayor a 300 BPM, el resultado se trunca al rango válido $[30, 300]$ BPM.
