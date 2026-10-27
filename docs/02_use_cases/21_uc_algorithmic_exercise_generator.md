# Caso de Uso 21: Generador Algorítmico de Ejercicios y Escalas de Conservatorio

Este documento describe la especificación formal del generador procedural de escalas y rutinas técnicas en **Tunner**.

---

## 1. Diagrama de Caso de Uso (Mermaid)

```mermaid
flowchart TD
    Actor([Músico / Estudiante])

    subgraph Tunner Core System
        UC1[Abrir Generador de Ejercicios]
        UC2[Seleccionar Tonalidad Raíz y Tipo de Ejercicio]
        UC3[Seleccionar Patrón Rítmico y Tempo]
        UC4[Generar Secuencia Diatónica / Interválica]
        UC5[Empaquetar en Compases Canónicos 4/4]
        UC6[Cargar SongPackage en el Atril Digital]
        UC7[Iniciar Práctica con Playback ADSR o Evaluación 4D]
    end

    Actor --> UC1
    UC1 --> UC2
    UC2 --> UC3
    UC3 --> UC4
    UC4 --> UC5
    UC5 --> UC6
    UC6 --> UC7
    UC7 --> Actor
```

---

## 2. Diagrama de Secuencia y Flujo Detallado (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Musico as Músico / Intérprete
    participant UI as TunnerScreen
    participant Modal as ExerciseGeneratorModal
    participant VM as TunnerViewModel
    participant Gen as AlgorithmicExerciseGenerator
    participant Score as HierarchicalScore
    participant Painter as ScorePainter (SMuFL)

    Musico->>UI: Presiona botón "Generador de Ejercicios" (fitness_center / school)
    UI->>Modal: ExerciseGeneratorModal.show(context)
    Musico->>Modal: Elige Tónica "Sol", Tipo "Escala Menor Armónica", Rítmica "Corcheas"
    Musico->>Modal: Pulsa "Generar y Practicar"
    Modal->>VM: generateExercisePackage(root, type, rhythm, bpm)
    VM->>Gen: generate(root, type, rhythm, bpm, activeInstrument)
    Gen->>Gen: Calcular notas diatónicas y acotar a tesitura
    Gen->>Gen: Ensamblar MeasureEntity en 16 ticks
    Gen-->>VM: SongPackage generado
    VM->>VM: setActivePackage(newPackage)
    VM->>Painter: Repintar pentagrama con nuevo ejercicio SMuFL
    Modal-->>Musico: Cierra modal y enfoca compás 1 listo para estudio
```

---

## 3. Especificación Formal del Caso de Uso

### 3.1 Actores
* **Actor Principal:** Músico, docente o estudiante de conservatorio.

### 3.2 Precondiciones
1. Una sesión de afinación o estudio activa en Tunner.

### 3.3 Postcondiciones
1. Se crea un `SongPackage` completo con el título de la escala o ejercicio.
2. La partitura se muestra en el pentagrama vectorial y está lista para tocar, escuchar o exportar.

### 3.4 Flujo Principal
1. El usuario abre el modal del Generador de Ejercicios.
2. Selecciona la nota raíz (ej. Do, Re, Mi, Fa, Sol, La, Si con alteraciones $\sharp/\flat$).
3. Selecciona la categoría: Escala Mayor, Menor Armónica, Menor Melódica, Pentatónica, Arpegio Mayor/Menor, Terceras continuas o Notas Largas.
4. Selecciona la figura rítmica deseada (Negras, Corcheas o Semicorcheas).
5. Pulsa el botón "Generar y Practicar".
6. El sistema crea la partitura en milisegundos y la despliega en el atril de Tunner.
