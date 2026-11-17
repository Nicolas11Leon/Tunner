# Implementation Plan: Real Audio Output Engine for DJ Console and Master Keyboard

Este documento define la planificación técnica rigurosa para implementar la emisión de audio real hacia los parlantes y auriculares del sistema operativo tanto en la Consola de DJ Virtual (Deck A, Deck B, Crossfader y Pitch Shifting) como en el Teclado Maestro y Banco SoundFont SF2.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE1-REAL-AUDIO-2026-0090`
- **Título de la Implementación:** Conexión de Hardware de Audio Real para Consola DJ y Teclado Maestro
- **Fase del Proyecto:** Fase 1 (Sinceramiento y Emisión Acústica Real)
- **Estado:** Aprobado
- **ADR Relacionado:** [`docs/04_adrs/0080_real_audio_output_engine_dj_console_and_master_keyboard.md`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/04_adrs/0080_real_audio_output_engine_dj_console_and_master_keyboard.md)
- **Documento Funcional Base:** [`docs/02_use_cases/90_uc_real_audio_output_engine_dj_console_and_master_keyboard.md`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/02_use_cases/90_uc_real_audio_output_engine_dj_console_and_master_keyboard.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Eliminar el comportamiento mudo de la Consola DJ y del Teclado Maestro conectando las acciones de reproducción (`play`, `pause`, `cue`, faders, `crossfader`, `pitchMultiplier` y pulsación de teclas MIDI/piano) a un motor de audio audible basado en `AudioPlayer` y decodificación/síntesis de streams WAV PCM reproducibles en los parlantes físicos del usuario.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación de la interfaz `IDjDeckAudioService` e implementación `DjDeckAudioService` administrando instancias de `AudioPlayer` independientes para Deck A y Deck B.
  - Generación de secuencias rítmicas audibles multicanal para las pistas de demostración cargadas por defecto.
  - Vinculación del fader de canal, fader maestro y crossfader con cálculo matemático de curvas de ganancia continua aplicadas en vivo a `setVolume`.
  - Vinculación del fader de pitch (`adjustPitch`, `resetPitch`) con `setPlaybackRate` para aceleración/desaceleración y cambio de afinación en tiempo real.
  - Conversión en caliente de los buffers de síntesis procedural de `ProceduralInstrumentSynthesizer` a formato WAV reproducible inmediatamente al tocar notas en `UniversalMasterKeyboardWidget`.
  - Capacidad de cargar archivos reales `.wav` locales en Deck A o Deck B desde el selector de pistas.
- **Excluido (Out-of-Scope):**
  - Separación de stems mediante redes neuronales de aprendizaje profundo (Demucs/Spleeter en C++ FFI), la cual pertenece a una fase posterior especializada.
  - Grabación directa de audio analógico externo por entrada de línea.

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.5`
  - Flutter SDK: Canal estable
  - `audioplayers: ^6.7.1` (Utilizado para salida de audio multiplataforma de baja latencia con `BytesSource` y `DeviceFileSource`).
- **Riesgo Tecnológico:**
  - Cero dependencias nativas externas adicionales.
  - No genera busy-waiting ni bloqueos en el hilo de UI de Flutter; las operaciones de reproducción y cálculo de buffers se ejecutan de manera asíncrona.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio y Contratos de Audio
- [ ] Definición del contrato `IDjDeckAudioPlayer` en `lib/features/dj_console/domain/i_dj_deck_audio_player.dart`.
- [ ] Incorporación de métodos de emisión de audio en `DjPerformanceOrchestrator` o inyección en `DjConsoleViewModel`.
- [ ] Pruebas unitarias de la lógica de atenuación del crossfader y cálculo de ganancia.

### Paso 2: Capa de Infraestructura / Datos (Servicio Real de Decks y Teclado)
- [ ] Implementar `DjDeckAudioService` en `lib/features/dj_console/data/dj_deck_audio_service.dart`:
  - Manejo de `AudioPlayer` para Deck A y Deck B.
  - Reproducción continua, pausa, salto a CUE (`seek`), cambio dinámico de volumen y modulación de tempo (`playbackRate`).
  - Generación procedural de bucles audibles demostrativos con Kick, Hi-Hat y bajo sintetizado para que el usuario escuche sonido inmediatamente al pulsar Play.
- [ ] Implementar generador de WAV reproducible en `ProceduralInstrumentSynthesizer` / `AudioSynthesizerService` para la pulsación de notas en el teclado.

### Paso 3: Capa de Presentación (Integración con ViewModels y UI)
- [ ] Conectar `DjConsoleViewModel` con `DjDeckAudioService`:
  - `togglePlay(deckId)` activa la reproducción audible.
  - `triggerCue(deckId)` reposiciona y ejecuta el audio.
  - `setCrossfaderPosition(pos)` y `setChannelGain(...)` ajustan la curva de volumen audible.
  - `adjustPitch(deckId, delta)` ajusta la velocidad audible.
- [ ] Conectar `UniversalMasterKeyboardWidget` para emitir el tono sintetizado en `_playNote` mediante `AudioSynthesizerService.playPcmBuffer` o `playWavBytes`.
- [ ] Conectar `DjTrackLoaderModal` para permitir la selección de archivos WAV locales reales.

### Paso 4: Pruebas, Verificación y Despliegue
- [ ] Pruebas unitarias de `DjDeckAudioService` con mocks y verificación de llamadas a `play`, `pause`, `setVolume` y `setPlaybackRate`.
- [ ] `flutter analyze` reportando 0 problemas.
- [ ] Recompilación y verificación audible en el binario de escritorio.
- [ ] Commit y push sincronizado con el repositorio remoto.
