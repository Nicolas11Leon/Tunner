# Caso de Uso 90: Motor de Emisión de Audio Real para Consola DJ y Teclado Maestro

## Metadatos
- **ID:** `UC-090`
- **Nombre:** Emisión de Audio Real en Parlantes para Consola DJ y Teclado Maestro
- **Módulo:** DJ Console & Instrument Workstation
- **Fase:** Fase 1 (Sinceramiento y Emisión Acústica Real)
- **Actores:** Músico / DJ / Estudiante, Motor de Audio de Sistema Operativo (`AudioPlayer`), `DjConsoleViewModel`, `UniversalMasterKeyboardWidget`.

---

## 1. Diagrama de Casos de Uso (Mermaid)

```mermaid
flowchart TD
    User["Músico / DJ"]
    
    subgraph TunnerSystem["Tunner Studio Audio Workstation"]
        UC1["Reproducir / Pausar Deck DJ con Sonido Real"]
        UC2["Modificar Curva de Crossfader Audible"]
        UC3["Ajustar Pitch y Velocidad de Reproducción en Vivo"]
        UC4["Cargar Archivo Local Real WAV/MP3"]
        UC5["Tocar Nota en Teclado Maestro con Emisión de Timbre Real"]
    end
    
    subgraph AudioEngine["Subsistema de Audio del SO"]
        DevOut["Parlantes / Auriculares Físicos"]
    end

    User --> UC1
    User --> UC2
    User --> UC3
    User --> UC4
    User --> UC5

    UC1 --> DevOut
    UC2 --> DevOut
    UC3 --> DevOut
    UC4 --> UC1
    UC5 --> DevOut
```

---

## 2. Diagrama de Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor DJ as Músico / DJ
    participant UI as DjConsoleModal / KeyboardWidget
    participant VM as DjConsoleViewModel
    participant AudioSvc as DjDeckAudioService
    participant AP as AudioPlayer (Deck A / Deck B)
    participant HW as Hardware Audio Output

    Note over DJ,HW: 1. Reproducción de Audio en Consola DJ
    DJ->>UI: Presiona Botón PLAY (Deck A)
    UI->>VM: togglePlay('A')
    VM->>AudioSvc: playDeck('A')
    AudioSvc->>AP: play(BytesSource(grooveBytes) / FileSource(path))
    AP->>HW: Stream de Audio PCM
    HW-->>DJ: Sonido audible en parlantes

    Note over DJ,HW: 2. Modulación de Crossfader y Volumen
    DJ->>UI: Mueve Crossfader hacia el centro
    UI->>VM: setCrossfaderPosition(0.0)
    VM->>AudioSvc: updateGains(volA: 0.707, volB: 0.707)
    AudioSvc->>AP: setVolume(gain)
    AP->>HW: Atenuación suave y audible

    Note over DJ,HW: 3. Pulsación en Teclado Maestro
    DJ->>UI: Toca tecla C4 en Teclado
    UI->>AudioSvc: playSynthesizedNote(midiNote: 60)
    AudioSvc->>AP: play(wavBytes)
    AP->>HW: Tono audible inmediato (Piano/Flauta/Guitarra)
    HW-->>DJ: Escucha acústica real
```

---

## 3. Especificación del Caso de Uso

### 3.1 Precondiciones
1. El dispositivo cuenta con un dispositivo de salida de audio configurado en el sistema operativo (altavoces, auriculares o interfaz USB).
2. La aplicación Tunner se encuentra en ejecución en primer plano.

### 3.2 Postcondiciones
1. Las pistas cargadas en Deck A y Deck B emiten ondas sonoras audibles por la salida de audio seleccionada.
2. La velocidad de reproducción y la frecuencia fundamental varían audiblemente de forma proporcional al fader de pitch.
3. El teclado maestro emite el tono acústico correspondiente al instrumento seleccionado con su envolvente ADSR audible.

### 3.3 Flujo Principal (Happy Path)
1. El usuario abre la Consola DJ.
2. El sistema inicializa los reproductores de audio para Deck A y Deck B cargando pistas de demostración audibles con bucles de ritmo completos.
3. El usuario pulsa el botón **PLAY** en Deck A.
4. El sistema inicia la reproducción audible y simultáneamente activa la rotación visual del jog wheel y el medidor VU.
5. El usuario desliza el control de Pitch; el sistema ajusta la tasa de reproducción en el hardware en tiempo real sin interrupciones.
6. El usuario mueve el Crossfader; el sistema aplica la curva de potencia constante $\cos(\theta)/\sin(\theta)$ atenuando y amplificando los decks en los altavoces.
7. El usuario pulsa una tecla en el Teclado Maestro; el sistema sintetiza y reproduce instantáneamente la nota con latencia sub-20ms.

### 3.4 Flujos Alternativos y Excepciones
* **F-ALT 1: Carga de archivo externo local no compatible o dañado.**
  * Si el usuario selecciona un archivo corrupto, el servicio atrapa el error de decodificación, emite una advertencia visual y mantiene el buffer previo sin cerrar la aplicación.
* **F-ALT 2: Salida de audio desconectada durante la reproducción.**
  * El reproductor pausa la reproducción de forma segura y reanuda cuando el dispositivo del sistema se restablece.
