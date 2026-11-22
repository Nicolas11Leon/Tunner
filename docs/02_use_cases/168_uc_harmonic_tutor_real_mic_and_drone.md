# UC-168: Eliminacion de Simulacion en HarmonicTutorModal y Conexion en Tiempo Real al Microfono y Dron (UC-67)

## 1. Informacion General

| Campo | Valor |
| :--- | :--- |
| **ID** | UC-168 |
| **Historia de Usuario** | US-6.1 (EPIC-06) |
| **Actores** | Musico / Estudiante (Usuario), `HarmonicTutorModal`, `HarmonicTutorViewModel`, `ToolSearchModal`, `TunerViewModel` |
| **Precondiciones** | El usuario abre el Tutor de Entonacion Armonica desde `ToolSearchModal` (o directamente con `HarmonicTutorModal.show`). |
| **Postcondiciones** | No existen botones de simulacion en produccion; la captura de microfono en vivo alimenta `onPitchDetected(telemetry.frequency)` mediante `TunerViewModel.telemetryListenable`; el dron guia sintetiza audio real a traves de `TunerViewModel.audioSynthesizer`. |

---

## 2. Diagrama de Casos de Uso

```mermaid
flowchart LR
    Usuario((Musico / Estudiante))
    subgraph TutorArmonico["Tutor de Entonacion Armonica (JI)"]
        UC1["Activar / Detener Microfono en Vivo"]
        UC2["Recibir Telemetria de Pitch en Tiempo Real"]
        UC3["Activar / Detener Dron Guia Armonico"]
        UC4["Visualizar Batimientos y Rol Armonico"]
    end
    TunerVM[("TunerViewModel (telemetryListenable + audioSynthesizer)")]

    Usuario --> UC1
    Usuario --> UC3
    UC1 --> TunerVM
    TunerVM --> UC2
    UC2 --> UC4
    UC3 --> TunerVM
```

---

## 3. Diagrama de Secuencia

```mermaid
sequenceDiagram
    actor U as Usuario
    participant TS as ToolSearchModal
    participant HT as HarmonicTutorModal
    participant HVM as HarmonicTutorViewModel
    participant TVM as TunerViewModel

    TS->>HVM: Crea HarmonicTutorViewModel(onPlayDroneSamples, onStopDrone)
    TS->>TVM: telemetryListenable.addListener(onTelemetry)
    TS->>HT: HarmonicTutorModal.show(viewModel: HVM, onToggleMicrophone, isMicrophoneActive)

    U->>HT: Pulsa "Activar Microfono en Vivo"
    HT->>TVM: toggleRecording()
    loop Cada frame DSP de pitch
        TVM-->>HVM: onPitchDetected(telemetry.frequency)
        HVM->>HT: Actualiza HarmonicBeatGauge y consejo JI
    end

    U->>HT: Pulsa "Activar Dron Guia"
    HT->>HVM: toggleDrone()
    HVM->>TVM: audioSynthesizer.startDroneLoop(wavBytes)

    U->>HT: Cierra el modal
    HT-->>TS: whenComplete -> removeListener(onTelemetry) & HVM.dispose()
```

---

## 4. Flujo Principal

1. Al seleccionar `'open_harmonic_tutor'` en `ToolSearchModal`, se instancia `HarmonicTutorViewModel` conectado a `TunerViewModel.audioSynthesizer` (`startDroneLoop` / `stopDroneLoop` usando `WavPcmCodec`).
2. `ToolSearchModal` suscribe un listener a `TunerViewModel.telemetryListenable` que reenvia cada `telemetry.frequency > 0` a `HarmonicTutorViewModel.onPitchDetected`, y lo desuscribe al cerrar el modal.
3. En `HarmonicTutorModal`, la tarjeta `'SIMULACION DE PRÁCTICA AUDITIVA'` se elimina por completo y se reemplaza por `'CAPTURA ACÚSTICA EN VIVO (MICRÓFONO)'`, mostrando el estado del microfono, la frecuencia detectada y el boton para alternar la captura real.

---

## 5. Flujos Alternativos y de Error

- **FA-1 (Sin microfono activo o frecuencia 0 Hz):** Mientras `telemetry.frequency <= 0`, `onPitchDetected` ignora la lectura y el gauge conserva el analisis de referencia sin producir valores NaN.
- **FA-2 (Cierre del modal con dron activo):** Al cerrar `HarmonicTutorModal`, el `whenComplete` ejecuta `tutorVm.dispose()`, deteniendo el dron guia (`onStopDrone`) y removiendo el listener de telemetria.
- **FA-3 (Uso aislado de `HarmonicTutorModal` sin `onToggleMicrophone`):** Si el modal se renderiza en pruebas aisladas sin callback de microfono, el boton muestra estado en espera sin lanzar excepciones.
