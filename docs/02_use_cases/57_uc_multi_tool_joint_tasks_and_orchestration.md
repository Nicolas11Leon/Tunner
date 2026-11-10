# Caso de Uso 57: Tareas Conjuntas Multi-Herramienta y Orquestación Atómica de Señales

## 1. Descripción
Permitir la ejecución de tareas pedagógicas y técnicas complejas que orquestan sincrónicamente tres o más herramientas de Tunner (`strobe_tuner`, `metronome`, `score_notation`, `practice_recorder`, `harmonic_drone`, `spectrogram`, `chord_analyzer`, `guided_lessons`, `master_keyboard`). El sistema configura automáticamente la topología de cableado virtual en el `SignalBus`, distribuye los eventos de reloj temporal y audio PCM, y presenta un tablero unificado de ejecución.

---

## 2. Diagrama de Casos de Uso (Mermaid)

```mermaid
flowchart TD
    User((Músico / Estudiante))
    TTCIndex[Catálogo TTC / Salto Rápido J]
    Orchestrator[Orquestador Multi-Herramienta]
    SignalBus[Bus Maestro SignalBus]
    Tool1[Módulo 1: Metrónomo Clock]
    Tool2[Módulo 2: Pentagrama SMuFL]
    Tool3[Módulo 3: Afinador MPM]
    Tool4[Módulo 4: Tutor Evaluador]

    User -->|Selecciona tarea conjunta TTC| TTCIndex
    TTCIndex -->|Instancia tarea con requiredToolIds >= 3| Orchestrator
    Orchestrator -->|Aplica topología de conexiones| SignalBus
    Orchestrator -->|Monta módulos en Rack/Studio| User
    Tool1 -->|temporalClock| SignalBus
    Tool3 -->|pitch & cents| SignalBus
    SignalBus -->|Distribuye eventos en vivo < 1ms| Tool2
    SignalBus -->|Distribuye eventos en vivo < 1ms| Tool4
```

---

## 3. Diagrama de Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Estudiante
    participant Modal as QuickJumpModal (J)
    participant Orchestrator as TaskOrchestrator
    participant Bus as SignalBus
    participant Metro as Metrónomo (Clock)
    participant Score as Pentagrama SMuFL
    participant Tuner as Afinador MPM
    participant Tutor as Tutor Evaluador

    Estudiante->>Modal: Pulsa J y selecciona SGT.02.SMUF.005 (Lectura en Vuelo)
    Modal->>Orchestrator: launchJointTask(task)
    Orchestrator->>Bus: configureTopology([metro->score, tuner->score, metro+tuner->tutor])
    Orchestrator->>Estudiante: Despliega Rack Multi-Herramienta Orquestado
    Estudiante->>Metro: Inicia Transporte (Espacio)
    loop Bucle de Práctica Sincronizada
        Metro->>Bus: emit(temporalClock)
        Bus->>Score: avanzarPlayhead()
        Estudiante->>Tuner: Entrada Micrófono
        Tuner->>Bus: emit(pitchEvaluation: note, cents)
        Bus->>Score: colorearNotaEnVivo(cents)
        Bus->>Tutor: registrarPrecision(rushingDraggingMs, cents)
    end
    Estudiante->>Metro: Detiene Transporte
    Tutor->>Estudiante: Emite Calificación Global (S/A/B/C) con desglose rítmico y tonal
```

---

## 4. Precondiciones
1. La tarea seleccionada debe ser una instancia de `PedagogicalTaskEntity` con `requiredToolIds.length >= 3`.
2. Las herramientas requeridas deben estar registradas en el catálogo de herramientas del sistema.
3. El motor de audio y el `SignalBus` deben estar inicializados sin bloqueos.

---

## 5. Flujo Principal
1. El usuario selecciona una tarea conjunta mediante el catálogo TTC, la consola de navegación o el atajo `J`.
2. El sistema reconoce la bandera `isMultiTool == true` y extrae la topología de conexiones requerida.
3. Se inicializan y montan las herramientas requeridas en la vista de práctica multi-herramienta.
4. El `SignalBus` activa las suscripciones cruzadas entre puertos de reloj, tono y audio.
5. El usuario inicia la sesión de práctica; cada herramienta recibe y transmite sus señales de forma reactiva sin busy-waiting.
6. Al finalizar el ejercicio, se consolida la evaluación pedagógica multidisciplinaria.

---

## 6. Flujos Alternativos y Excepciones
- **Micrófono sin permisos:** Si una de las herramientas requiere entrada acústica y no hay permisos de grabación, el sistema alerta amigablemente y permite practicar en modo emulación o con entrada MIDI/Teclado.
- **Rendimiento degradado del dispositivo:** Si la tasa de refresco cae por debajo de 60 FPS durante la multitarea, las herramientas visuales no críticas reducen su muestreo FFT sin alterar la precisión del reloj temporal del metrónomo.
