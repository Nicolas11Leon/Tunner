# Caso de Uso 140: Consola DJ Interactiva, DSP en Vivo, Pedagogia y Media Vault (Ola UX-4)

## 1. Descripcion General
Este caso de uso formaliza el soporte de arrastre gestual (`onPanUpdate`) en la consola DJ, procesamiento DSP audible en vivo (ecualizacion, filtros, kills, delay), activacion directa de microfono en modales pedagogicos y de analisis (sin requerir regresar al afinador), audicion comparativa en la suite vocal de afinacion y la manipulacion de clips en la boveda multimedia (Media Vault).

---

## 2. Diagrama de Caso de Uso (Mermaid)

```mermaid
flowchart TD
    User([DJ / Vocalista / Estudiante])

    subgraph "Tunner Studio - Ola UX-4"
        UC1[Arrastrar Perillas y Faders en Consola DJ]
        UC2[Procesar DSP y Guardar Grabacion DJ a Disco]
        UC3[Activar Microfono Directamente en Modales Pedagogicos]
        UC4[Audicionar Tomas Antes y Despues en Vocal Auto-Tune]
        UC5[Manipular y Reproducir Clips en Media Vault]
    end

    User --> UC1
    User --> UC2
    User --> UC3
    User --> UC4
    User --> UC5
```

---

## 3. Diagrama de Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant DJUI as DjStudioWorkstationView / MappingOverlay
    participant DJVM as DjConsoleViewModel
    participant PedagogyModal as GuidedLessons / ChordAnalyzer
    participant TunerVM as TunerViewModel

    Note over User, DJVM: 1. Arrastre Gestual en Consola DJ
    User->>DJUI: Pan vertical sobre perilla de EQ / Filtro
    DJUI->>DJVM: setDeckEqLow(deck, delta) / setDeckFilter(deck, val)
    DJVM-->>DJUI: Actualizacion angular de la perilla y procesamiento DSP

    Note over User, TunerVM: 2. Activacion Directa de Microfono
    User->>PedagogyModal: Clic en "Encender Microfono"
    PedagogyModal->>TunerVM: toggleRecording()
    TunerVM-->>PedagogyModal: isRecording == true, analisis de pitch en vivo inmediato

    Note over User, DJVM: 3. Grabacion DJ a Disco
    User->>DJUI: Clic en Detener Grabacion DJ
    DJUI->>DJVM: stopRecording()
    DJVM->>DJVM: saveRecordingToDisk()
    DJVM-->>User: Notificacion con ruta de archivo WAV exportado
```

---

## 4. Precondiciones y Postcondiciones

### Precondiciones
1. La aplicacion Tunner Studio se encuentra en ejecucion en el entorno de escritorio o movil.
2. Los subsistemas de audio digital operan localmente sin dependencias de red externa.

### Postcondiciones
1. El usuario puede modular perillas y faders mediante gestos de arrastre táctil o raton con respuesta gráfica inmediata.
2. La sesion grabada en la consola DJ se guarda fisicamente como archivo `.wav` en el almacenamiento local.
3. El microfono se puede encender y apagar directamente desde los modales de lecciones guiadas y analisis de acordes.
4. Las pistas de audio de práctica y clips multimedia pueden audicionarse y manipularse interactivamente.
