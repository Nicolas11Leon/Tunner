# Especificación de Caso de Uso: Suite de Efectos en Vivo, Detección Automática de BPM y Grabador Master de Mezcla DJ

## Metadatos del Caso de Uso

- **ID del Caso de Uso:** `UC-66-DJ-PERFORMANCE-FX-BEAT-TRACKING-AND-MIX-RECORDER`
- **Nombre Canónico:** Aplicación de filtros bipolares y retardos sincronizados, cálculo algorítmico de BPM y grabación de mezcla maestra en tiempo real
- **Fase Asociada:** Fase 3 (Herramientas Creativas Avanzadas) & Fase 4 (Estudio de Producción)
- **Actor Principal:** DJ / Productor Musical / Estudiante de Mezcla
- **Actores Secundarios:** Motor de Efectos DSP (`DjAudioProcessor`), Estimador de BPM (`BpmBeatTrackerEngine`), Codificador RIFF WAV (`DjMixWavEncoder`), Teclado QWERTY
- **Estado:** Approved

---

## 1. Descripción Breve y Propósito

Permite al usuario enriquecer su sesión de mezcla en la Consola DJ Virtual mediante el uso de filtros de barrido continuo (Low-Pass y High-Pass) en cada deck, unidades de retardo cuantizadas al compás musical ($1/2, 1/4, 1/8, 1/16$), detección automática del tempo (BPM) al importar pistas o stems de audio, y la grabación en tiempo real de la interpretación maestra para su exportación como archivo WAV de alta fidelidad sin saturación digital.

---

## 2. Diagrama de Caso de Uso (Mermaid)

```mermaid
flowchart LR
    Usuario((DJ / Musico))
    TecladoOS((Teclado Fisico QWERTY))

    subgraph TunnerSystem ["Sistema Tunner (Monolito Modular Local)"]
        UC66(["UC-66: Suite de Efectos, BPM y Grabacion DJ"])
        BeatTracker(["Detector de BPM (BpmBeatTrackerEngine)"])
        FilterFX(["Filtro Bipolar Sweep (DjChannelFxEntity)"])
        DelayFX(["Delay Sincronizado a Beat (DjAudioProcessor)"])
        Recorder(["Grabador Master (DjLiveMixRecorderEntity)"])
        WavEncoder(["Encoder RIFF WAV (DjMixWavEncoder)"])
    end

    Usuario --> UC66
    TecladoOS --> UC66
    UC66 --> BeatTracker
    UC66 --> FilterFX
    UC66 --> DelayFX
    UC66 --> Recorder
    Recorder --> WavEncoder
```

---

## 3. Diagrama de Secuencia Detallado (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor DJ as DJ / Usuario
    participant UI as DjConsoleModal
    participant VM as DjConsoleViewModel
    participant BT as BpmBeatTrackerEngine
    participant DO as DjPerformanceOrchestrator
    participant AP as DjAudioProcessor
    participant MR as DjMixWavEncoder

    DJ->>UI: Carga pista de audio o stem en Deck A
    UI->>VM: loadTrackWithAutoBpm(deckId='A', audioData)
    VM->>BT: estimateBpmFromBuffer(audioData)
    BT-->>VM: BPM calculado = 126.4
    VM->>DO: loadTrack('A', bpm=126.4, ...)
    VM-->>UI: Actualiza BPM en Deck A (126.4)

    DJ->>UI: Modula filtro bipolar en Deck A (hacia HPF +0.6)
    UI->>VM: setChannelFilter('A', 0.6)
    VM->>DO: updateChannelFx('A', filterPosition=0.6)
    DO->>AP: configureFilterBiquad(fc=850 Hz, mode=HPF)

    DJ->>UI: Activa Delay sincronizado a 1/4 de beat
    UI->>VM: toggleChannelDelay('A', division=0.25)
    VM->>DO: updateChannelFx('A', isDelayActive=true)

    DJ->>UI: Presiona boton de Grabacion (REC)
    UI->>VM: startLiveRecording()
    VM->>DO: beginRecording()
    Note over VM,AP: Suma post-crossfader se captura en buffer circular

    DJ->>UI: Presiona boton DETENER REC
    UI->>VM: stopLiveRecording()
    VM->>DO: finalizeRecording()
    VM->>MR: encodePcmToWav(buffer, sampleRate=44100)
    MR-->>VM: Archivo WAV generado (mix_session_master.wav)
    VM-->>UI: Muestra SnackBar con confirmacion de archivo y tamano
```

---

## 4. Precondiciones y Postcondiciones

### 4.1 Precondiciones
1. La aplicación Tunner se encuentra en ejecución y el usuario ha desplegado la Consola de DJ Virtual.
2. Existen pistas de audio, stems del sintetizador o demostraciones sintéticas disponibles para reproducir.

### 4.2 Postcondiciones
1. La señal procesada en cada deck aplica el filtrado bipolar y los ecos cuantizados sin producir discontinuidades de fase ni chasquidos (*pops/clicks*).
2. El tempo detectado de cada pista se refleja inmediatamente en el motor de sincronización (Sync).
3. La sesión de mezcla grabada se almacena en memoria o disco en formato WAV de 16 bits sin pérdida, respetando el límite dinámico de $0\text{ dBFS}$.

---

## 5. Flujo Principal de Ejecución (Paso a Paso)

1. El usuario abre la Consola de DJ Virtual y presiona el botón "Cargar Pista / Stem".
2. Selecciona un archivo o stem; el motor `BpmBeatTrackerEngine` calcula de inmediato el tempo y actualiza el BPM del deck.
3. El usuario inicia la reproducción con la tecla `W` o el botón Play.
4. Para realizar una transición hacia el Deck B, el usuario gira la perilla de Filtro del Deck A hacia la derecha ($+0.7$), activando el filtro paso-altos y retirando los graves.
5. El usuario enciende el efecto Delay sincronizado a $1/4$ en el Deck A para generar una cola rítmica espacial.
6. El usuario introduce el Deck B con el crossfader centrado.
7. Al iniciar la mezcla, el usuario presiona el botón "REC" en la cabecera de la consola; un cronómetro de grabación comienza a correr.
8. Una vez finalizada la transición, el usuario presiona "DETENER REC"; el codificador compila el archivo WAV maestro y notifica el éxito de la exportación.

---

## 6. Flujos Alternativos y Excepciones

### 6.1 Flujo Alternativo 1: Atajos de Teclado para Control de Efectos
- El usuario utiliza atajos físicos configurados:
  - `F`: Filtro a la izquierda (corte Low-Pass).
  - `G`: Filtro a la derecha (corte High-Pass).
  - `H`: Filtro al centro (Reset a Bypass).
  - `R`: Conmutar Grabación Maestro (REC On/Off).

### 6.2 Excepciones y Condiciones de Borde
- **Búfer de audio con señal demasiado corta para detección de BPM:** Si el archivo tiene una duración menor a 1 segundo, el detector recurre al tempo nominal estándar de 120.0 BPM como valor por defecto seguro.
- **Saturación en realimentación de Delay:** El factor de realimentación (*feedback*) se encuentra estrictamente limitado a $0.8$ para impedir oscilación incontrolada (*runaway feedback*).