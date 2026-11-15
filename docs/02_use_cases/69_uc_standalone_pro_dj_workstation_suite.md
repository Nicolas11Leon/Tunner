# Caso de Uso UC-69: Estación de Trabajo DJ Profesional Autónoma en PC (4-Stems, Mezcla Armónica Camelot, Ondas Paralelas RGB, Auto-Loops, Sampler y Split-Cue)

---

## 1. Identificación del Caso de Uso

- **ID:** `UC-69`
- **Nombre:** `Ejecución de Sesión Profesional de DJ en PC sin Hardware Externo (Standalone Pro DJ Workstation)`
- **Actores Principales:** `DJ / Productor Musical / Estudiante de Mezcla en PC`
- **Actores Secundarios:** `DjPerformanceOrchestrator`, `DjAudioProcessor`, `DjHarmonicCamelotEngine`, `DjTransitionSfxSynthesizer`, `DjGamepadInputService`
- **Fase:** `Fase 2`
- **Prioridad:** `Crítica (Core Differentiator)`
- **Documento Técnico Relacionado:** `[DOC-DJ-2026-069](../01_product_vision/doc_standalone_pro_dj_workstation_architecture.md)`

---

## 2. Diagrama de Casos de Uso (Mermaid)

```mermaid
flowchart LR
    DJ["Actor: DJ en PC (Teclado / Mouse / Gamepad)"]

    subgraph Workstation["Estacion de Trabajo DJ Profesional (Tunner)"]
        UC69_1["UC-69.1: Aislar Stems en Vivo (Vocal / Drums / Bass / Melody)"]
        UC69_2["UC-69.2: Sincronizar Armonia con Rueda de Camelot (Key-Sync)"]
        UC69_3["UC-69.3: Alinear Beats en Ondas Paralelas RGB y Phase Meter"]
        UC69_4["UC-69.4: Ejecutar Auto-Loops Cuantizados, Slip Mode y Beat Jump"]
        UC69_5["UC-69.5: Disparar Pads del Sampler de Transiciones (Risers / Drops)"]
        UC69_6["UC-69.6: Activar Automix Inteligente con Bass-Swap"]
        UC69_7["UC-69.7: Monitorear Pre-Escucha en Modo Split-Cue Mono"]
    end

    DJ --> UC69_1
    DJ --> UC69_2
    DJ --> UC69_3
    DJ --> UC69_4
    DJ --> UC69_5
    DJ --> UC69_6
    DJ --> UC69_7
```

---

## 3. Diagrama de Flujo y Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor DJ as DJ (PC / Teclado / Gamepad)
    participant UI as DjConsoleModal & ParallelWaveforms
    participant VM as DjConsoleViewModel
    participant Orch as DjPerformanceOrchestrator
    participant Harm as DjHarmonicCamelotEngine
    participant DSP as DjAudioProcessor & SfxSynth

    DJ->>UI: Carga Pista en Deck B y activa vista Pro Workstation
    UI->>VM: analizarBPMYTonalidad(deckB)
    VM->>Harm: detectCamelotKey(audioSamples)
    Harm-->>VM: CamelotKey (ej. 9A) + Compatibilidad con Deck A (8A -> HARMONIC STEP)
    VM-->>UI: Renderiza Onda Espectral RGB y Badge Camelot 9A (Verde)

    DJ->>UI: Presiona KEY SYNC en Deck B
    UI->>VM: syncKey('B')
    VM->>Orch: calcularSemitonosOptimos(deckB: 9A, target: 8A)
    Orch-->>VM: pitchSemitonesShift = -2 (o ajuste cromático equivalente)
    VM-->>UI: Actualiza Key a 8A (PERFECT MATCH)

    DJ->>UI: Silencia Stem DRUMS y BASS en Deck B (Deja solo VOCAL para Mashup)
    UI->>VM: toggleStem('B', DjStemType.drums) / toggleStem('B', DjStemType.bass)
    VM->>Orch: actualizarEstadoStems(deckB)
    Orch->>DSP: mixBuffers con aislamiento Mid/Side y Crossover Linkwitz-Riley

    DJ->>UI: Activa SLIP MODE y presiona Auto-Loop 1/2 Beat + Halve (1/4 Beat)
    UI->>VM: toggleSlipMode('A') + engageAutoLoop('A', 0.5) + halveLoop('A')
    VM->>Orch: Mantiene puntero t_slip en segundo plano mientras cicla t_audible
    DJ->>UI: Dispara Pad Sampler "White Noise Riser" y suelta el Loop en el Drop
    UI->>VM: triggerSamplerPad(padIndex: 1) + exitLoop('A')
    VM->>DSP: Sintetiza Riser y salta t_audible -> t_slip exactamente a tiempo
    DSP-->>UI: Salida Master L / Cue R (Split-Cue) sin saturación
```

---

## 4. Especificación de Condiciones y Flujos

### 4.1 Precondiciones
1. El módulo `DjConsoleModal` está inicializado en memoria local sin requerir conexión a internet.
2. El motor `DjPerformanceOrchestrator` dispone de al menos dos canales virtuales (`Deck A` y `Deck B`) y el banco de `Sampler` de 8 pads.

### 4.2 Postcondiciones
1. Las transformaciones de *Stems*, *Key-Shift*, *Auto-Loop*, *Slip Mode*, *Sampler* y *Automix* se reflejan instantáneamente tanto en el flujo de audio mezclado (y en la grabación WAV en vivo) como en el renderizador de ondas paralelas RGB y en los LEDs del skin de hardware.
2. Ninguna operación bloquea el hilo de interfaz gráfica (manteniendo $60/120\text{ FPS}$).

### 4.3 Flujo Principal (Escenario de Éxito Completo)
1. **Inspección Visual Espectral y Armónica:** El DJ observa en la parte superior del modal el **Visualizador de Ondas Espectrales Paralelas RGB**, donde el `Deck A` reproduce una pista a $124.0\text{ BPM}$ en tonalidad `8A` ($A\text{ minor}$) y el `Deck B` tiene preparada una pista a $128.0\text{ BPM}$ en `9A` ($E\text{ minor}$).
2. **Pre-Escucha en PC (*Split-Cue*):** El DJ activa el botón `PFL CUE` en el `Deck B` y habilita `SPLIT-CUE` para escuchar el `Deck B` por el canal derecho (audífonos) mientras el `Deck A` suena limpio por el canal izquierdo (altavoz principal).
3. **Sincronización de Tempo y Armonía:** El DJ presiona `SYNC` y `KEY SYNC` en el `Deck B`. El sistema iguala el tempo a $124.0\text{ BPM}$ con *Key-Lock* activo y alinea la clave armónica con el `Deck A`, mostrando el indicador `PERFECT HARMONIC MATCH`.
4. **Mezcla Creativa por Stems (Mashup en Vivo):** El DJ desactiva los botones de stem `DRUMS` y `BASS` en el `Deck B`, dejando únicamente activo el stem `VOCAL`. Mueve el crossfader al centro: la voz del `Deck B` flota limpiamente sobre la base instrumental del `Deck A`.
5. **Build-up con Auto-Loop, Slip Mode y Sampler:** El DJ activa `SLIP`, engancha un bucle cuantizado de `1 Beat` en el `Deck A`, lo reduce a `1/2` y `1/4` de beat usando el botón `1/2x`, y dispara el pad `RISER` del Sampler.
6. **Resolución en el Drop:** Al terminar la subida, el DJ desactiva el bucle y activa el stem `BASS` y `DRUMS` del `Deck B` mientras dispara el pad `SUB DROP`. Gracias al `Slip Mode`, la canción retoma exactamente en el primer tiempo del compás del drop.

### 4.4 Flujos Alternativos y de Error
- **FA-01 (Transición Asistida por Automix con Bass-Swap):** Si el DJ presiona el botón `AUTOMIX (A -> B)`, el motor inicia una transición temporizada; al llegar al $50\%$ del recorrido del crossfader, intercambia suavemente la ganancia de bajos (`gainLow`) entre `Deck A` y `Deck B` para evitar sobrepeso de sub-graves.
- **FA-02 (Interrupción Manual del Automix):** Si durante el *Automix* el usuario arrastra manualmente el crossfader o presiona una tecla de corte rápido, el motor desactiva el piloto automático de forma transparente.
- **FE-01 (Límite de División de Bucle):** Si el DJ intenta dividir un bucle más allá de $1/32$ de beat, el sistema mantiene el piso en $1/32$ e ignora divisiones adicionales para prevenir artefactos acústicos.
