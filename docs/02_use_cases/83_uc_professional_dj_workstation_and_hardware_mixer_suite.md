# Caso de Uso 83: Estación de Trabajo DJ Profesional, Mezclador de Grado Club y Carga Real de Audio/Stems

---

## 1. Descripción
Proporcionar una consola DJ de grado profesional inspirada en los estándares de hardware de club (Pioneer DJM, Allen & Heath Xone, Traktor Pro), erradicando sliders horizontales genéricos y reemplazándolos por tiras de canal verticales con ecualizadores rotatorios Isolator de 3 bandas (-26dB a +6dB y switches KILL), medidores VU-Meter duales estéreo, faders de canal de precisión, crossfader con curva variable, carga real de pistas/stems de audio, y visualización tanto en modal como en espacio de trabajo nativo a pantalla completa (`F4`).

---

## 2. Diagrama de Casos de Uso (Mermaid)

```mermaid
flowchart TD
    User["DJ / Productor Musical"]
    
    subgraph DJWorkstation ["Consola DJ Profesional Tunner"]
        UC1["Cargar Pistas y Stems Reales (WAV / MP3 / Stems Master)"]
        UC2["Ajustar EQ de 3 Bandas con Diales Rotatorios y KILL"]
        UC3["Monitorear Niveles con VU-Meters Estéreo Duales"]
        UC4["Realizar Mezcla con Faders Verticales y Crossfader"]
        UC5["Activar Filtro Bipolar (LPF / HPF) y Efectos de Delay"]
        UC6["Disparar Hot Cues, Bucles Cuantizados y Sampler Pads"]
        UC7["Grabar Sesión de Mezcla en Vivo a Archivo WAV"]
    end
    
    User --> UC1
    User --> UC2
    User --> UC3
    User --> UC4
    User --> UC5
    User --> UC6
    User --> UC7
```

---

## 3. Diagrama de Flujo y Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor DJ as DJ / Productor
    participant UI as DjStudioWorkstationView
    participant Strip as DjVerticalChannelStrip
    participant Loader as DjTrackLoaderModal
    participant VM as DjConsoleViewModel
    participant Engine as DjAudioProcessor & BPM Tracker

    DJ ->> UI: Pulsar 'Cargar Pista en Deck A'
    UI ->> Loader: Abrir selector de pistas y stems
    DJ ->> Loader: Seleccionar 'Midnight Cyber Synthwave'
    Loader ->> VM: loadTrackWithBeatTracking('A', samples)
    VM ->> Engine: Analizar BPM y Forma de Onda RGB
    Engine -->> VM: 128.0 BPM, Camelot 8A (Am)
    VM -->> UI: Actualizar Forma de Onda, Título y BPM

    DJ ->> Strip: Girar dial EQ Low (-12 dB) y activar KILL
    Strip ->> VM: setEqGains('A', low: 0.25)
    VM ->> Engine: Aplicar filtro IIR de corte de graves
    Engine -->> Strip: Actualizar VU-Meter Estéreo en tiempo real
```

---

## 4. Precondiciones y Postcondiciones

### 4.1 Precondiciones
- La estación Tunner está en ejecución en escritorio o móvil.
- El usuario navega al espacio de trabajo de la Consola DJ (`F4` o selector de pestañas) o abre el modal.

### 4.2 Postcondiciones
- Cada canal de audio se controla mediante faders y diales verticales con respuesta táctil y numérica.
- Las pistas cargadas corresponden a audio real procesado por el motor de audio DSP.
- La grabación de mezcla genera un archivo `.wav` descargable o guardable en el almacenamiento local.
