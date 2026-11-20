# Caso de Uso 139: Interaccion Tactil, Editor de Partituras, Superficies Rack y Grabadora (Ola UX-3)

## 1. Descripcion General
Este caso de uso formaliza la interaccion directa de puntero (clic) y tactil (touch) en Tunner Studio, asegurando retroalimentacion auditiva y visual inmediata en el Teclado Maestro Universal, las superficies de emulacion de instrumentos del Rack Modular (teclas, trastes, pads), el pentagrama interactivo, el modal de edicion de partituras y los botones de grabacion de practica de audio.

---

## 2. Diagrama de Caso de Uso (Mermaid)

```mermaid
flowchart TD
    User([Musico / Productor])

    subgraph "Tunner Studio - Ola UX-3"
        UC1[Tocar Teclado Maestro con Sostenido y Glissando]
        UC2[Tocar Superficies de Instrumento en Rack Modular]
        UC3[Interactuar y Previsualizar Notas en Pentagrama]
        UC4[Editar y Auto-Avanzar Ticks en ScoreEditorModal]
        UC5[Iniciar / Detener Grabacion de Practica WAV con isAudioRecording]
        UC6[Alternar Tono de Referencia La4 con Toggle Limpio]
    end

    User --> UC1
    User --> UC2
    User --> UC3
    User --> UC4
    User --> UC5
    User --> UC6
```

---

## 3. Diagrama de Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Musico
    participant UI as Interfaz Tactil / Pentagrama
    participant ScoreModal as ScoreEditorModal
    participant Rack as RackUnitCard / EmulationSurface
    participant Audio as AudioSynthesizerService
    participant VM as TunerViewModel

    Note over Musico, VM: 1. Previsualizacion de Notas en Pentagrama
    Musico->>UI: Clic en nota del pentagrama
    UI->>VM: selectAndPreviewScoreNote(noteIndex)
    VM->>Audio: playNoteTone(note.name, note.frequency, 0.4)
    Audio-->>Musico: Audio audible inmediato de la nota

    Note over Musico, VM: 2. Insercion con Auto-Avance en ScoreEditorModal
    Musico->>ScoreModal: Clic en "Insertar Nota"
    ScoreModal->>VM: insertNoteAtCursor(...)
    ScoreModal->>ScoreModal: Auto-avanzar _selectedStartTick += durationTicks
    ScoreModal-->>Musico: Cursor temporal avanza al siguiente pulso

    Note over Musico, VM: 3. Interaccion Tactil en Rack Modular
    Musico->>Rack: Tap en tecla / pad / traste
    Rack->>Audio: playNoteTone(pitch, freq, velocity)
    Audio-->>Musico: Sonido reactivo del instrumento emulado

    Note over Musico, VM: 4. Grabacion de Audio WAV
    Musico->>UI: Clic en Boton REC Maestro
    UI->>VM: isAudioRecording ? stopPracticeRecording() : startPracticeRecording()
    VM-->>UI: Actualizacion del estado visual a GRABANDO
```

---

## 4. Precondiciones y Postcondiciones

### Precondiciones
1. La aplicacion Tunner se encuentra en ejecucion en modo Desktop o Tablet/Movil.
2. El sistema de audio local esta inicializado sin dependencias de red.

### Postcondiciones
1. Cada pulsacion tactil o clic sobre notas del pentagrama, teclas del teclado maestro y superficies del rack modular produce sonido audible local.
2. Los botones de grabacion de tomas de practica en el Dock y en la Consola Maestra reflejan con precision el estado de grabacion WAV (`isAudioRecording`).
3. El editor de partituras avanza el cursor temporal de manera fluida al insertar notas sin forzar ajustes manuales del slider.
4. El tono de referencia La4 es un toggle limpio que puede apagarse al pulsar nuevamente sin falsear el motor del afinador.
