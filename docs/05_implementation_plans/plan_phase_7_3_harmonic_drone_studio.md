# Plan de Implementación: Fase 7.3 - Estudio de Dron Armónico de Referencia Continua (Tone Drone Studio)

Este plan formaliza la descomposición técnica y pasos de ejecución para construir el Estudio de Dron Armónico continuo en **Tunner**.

---

## 1. Objetivos

1. Construir un sintetizador procedural puro en Dart (`HarmonicDroneSynthesizer`) con bucle sin costuras ni discontinuidades (crossfade circular) en memoria RAM.
2. Permitir configurar nota raíz (Do a Si), octava (2 a 4), armónico de quinta justa/temperada, octava superior y timbres tímbricos (Senoidal, Flauta Cálida, Cello, Órgano).
3. Respetar la calibración de concierto ($A_4$) y el temperamento musical activo al calcular las frecuencias de las componentes.
4. Integrar con el servicio de audio y `TunerViewModel` para reproducción continua en segundo plano mientras el afinador sigue escuchando.
5. Desarrollar la interfaz `HarmonicDroneModal` y su acceso visual directo desde la barra superior de `TunerScreen`.

---

## 2. Tareas por Capa Arquitectónica

### Capa 1: Dominio Puro (Pure Dart)
- [x] Crear `lib/features/drone/domain/drone_timbre.dart`:
  - Enum `DroneTimbre`: `pureSine`, `warmFlute`, `richCello`, `organ`.
- [x] Crear `lib/features/drone/domain/harmonic_drone_config.dart`:
  - Entidad inmutable `HarmonicDroneConfig`:
    - `rootMidiNote` (0 a 11, correspondiente a Do a Si).
    - `octave` (2 a 4).
    - `includeFifth` (bool, default: true).
    - `includeOctave` (bool, default: false).
    - `timbre` (DroneTimbre).
    - `volume` (double 0.0 a 1.0).
    - `harmonicBalance` (double 0.0 a 1.0).
- [x] Crear `lib/features/drone/domain/harmonic_drone_synthesizer.dart`:
  - Generador matemático de buffers WAV PCM 16-bit Mono (44100 Hz).
  - Cálculo de frecuencias fundamentales y de quinta armónica según temperamento musical y calibración A4.
  - Generación de armónicos según el timbre seleccionado con normalización de picos.
  - Algoritmo de loop crossfade (fundido circular de 40 ms) para eliminar clics entre repeticiones cíclicas.
- [x] Crear suite de pruebas de dominio: `test/features/drone/harmonic_drone_synthesizer_test.dart`.

### Capa 2: Infraestructura y Aplicación
- [x] Actualizar `IAudioSynthesizerService` y `AudioSynthesizerService`:
  - Métodos `startDroneLoop(Uint8List wavBuffer, {double volume})` y `stopDroneLoop()`.
  - Propiedad reactiva `isDroneLoopPlaying`.
- [x] Actualizar `TunerViewModel`:
  - Estado `HarmonicDroneConfig droneConfig` e `isDronePlaying`.
  - Métodos `toggleDrone()`, `updateDroneConfig(HarmonicDroneConfig newConfig)`, `stopDrone()`.
  - Conexión con `_audioSynthesizerService` y regeneración dinámica del buffer cuando se cambian parámetros en vivo.

### Capa 3: Presentación (Flutter UI)
- [x] Crear `HarmonicDroneModal` en `lib/features/drone/presentation/harmonic_drone_modal.dart`:
  - Selector de nota fundamental (Do a Si) y octavas.
  - Toggles para quinta armónica y octava superior.
  - Selector de timbre visual con tarjetas intuitivas.
  - Sliders de volumen y balance armónico.
  - Botón principal de Encendido / Detención con indicador de estado sonoro pulsante.
- [x] Integrar botón / chip del Dron en el AppBar de `TunerScreen` en Modo Conservatorio Pro y Modo Esencial.
- [x] Crear suite de pruebas de interfaz: `test/features/drone/harmonic_drone_ui_test.dart`.

---

## 3. Criterios de Aceptación (DoD)
- 100% de pruebas unitarias y de widgets pasando.
- Cero issues en `flutter analyze`.
- Cero emojis en código, comentarios y commits.
- Pull request formal y merge a `main`.
