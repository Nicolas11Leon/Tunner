# Auditoria Forense MCP-Readiness: Core Audio y Channels (`lib/core/audio/`, `lib/core/channels/`)

**Fecha:** 2026-11-23  
**Alcance:** `lib/core/audio/` (48 archivos `.dart`) y `lib/core/channels/` (10 archivos `.dart`) — **Total: 58 archivos `.dart`**  
**Objetivo:** Evaluar la viabilidad de ejecucion Headless Pure Dart para servidor Model Context Protocol (MCP), identificar brechas de arquitectura/concurrencia y especificar los primitivos MCP (`Resources`, `Tools`, `Prompts`).

---

## 1. Inventario Archivo por Archivo

### 1.1 `lib/core/audio/domain/` (26 archivos)

| Archivo | Clases / Enums Principales | Metodos / Contratos Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- |
| `audio_device_entity.dart` | `AudioDeviceDirection`, `AudioDeviceEntity` | `systemDefault()`, `defaultOutput()`, `cueHeadphones()`, `toJson()`, `fromJson()` | UC-062, UC-100, UC-102 |
| `audio_device_matrix_entity.dart` | `AudioDeviceMatrixEntity` | `defaultConfiguration()`, `effectiveMasterGain`, `latencyMs`, `toJson()`, `fromJson()`, `copyWith()` | UC-100, UC-102, UC-104 |
| `audio_pcm_frame.dart` | `AudioPcmFrame` | `samples`, `sampleRate`, `rmsDb`, `peakDb`, `timestampMicros` | UC-100, UC-146 |
| `audio_ring_buffer.dart` | `AudioRingBuffer` | `write()`, `read()`, `peekLatest()`, `clear()`, `capacity` (potencia de 2 lock-free) | UC-100, UC-146 |
| `ffi/i_native_dsp_bridge.dart` | `INativeDspBridge` | `isNativeAvailable`, `engineName`, `applyGain()`, `vectorSum()`, `autoCorrelate()` | UC-114, UC-118, UC-119 |
| `ffi/native_dsp_bridge_fallback.dart` | `NativeDspBridgeFallback` | Implementacion Pure Dart de `applyGain()`, `vectorSum()`, `autoCorrelate()` | UC-114, UC-119, UC-148 |
| `i_studio_audio_channel.dart` | `IStudioAudioChannel` | `loadFile()`, `loadBytes()`, `play()`, `pause()`, `stop()`, `seek()`, `setVolume()`, `setPlaybackRate()`, `setLooping()`, `stateStream` | UC-090, UC-099 |
| `i_studio_audio_device_matrix_port.dart` | `IStudioAudioDeviceMatrixPort` | `matrix`, `restoreMatrix()` | UC-102, UC-130, UC-141 |
| `i_studio_audio_device_matrix_service.dart` | `IStudioAudioDeviceMatrixService` | Contrato completo de matriz de hardware, EQ 3 bandas, compresor, ganancia, mute/dim/mono, `processMasterStereoSamples()`, `startMasterRecording()`, `stopMasterRecording()` | UC-102, UC-104, UC-147, UC-180 |
| `i_studio_audio_engine.dart` | `IStudioAudioEngine` | `getChannel()`, `activeChannelIds`, `stopAll()`, `disposeChannel()`, `dispose()` | UC-090, UC-099 |
| `i_studio_audio_hardware_persistence_service.dart` | `IStudioAudioHardwarePersistenceService` | `loadMatrix()`, `saveMatrix()`, `clear()` | UC-102, UC-126 |
| `i_studio_audio_input_engine.dart` | `IStudioAudioInputEngine` | `listInputDevices()`, `setInputDevice()`, `startCapture()`, `stopCapture()`, `pcmFrameStream`, `rmsDbStream`, `peakDbStream` | UC-062, UC-100, UC-146 |
| `i_studio_master_capture_service.dart` | `IStudioMasterCaptureService` | `startCapture()`, `appendStereoSamples()`, `stopCapture()`, `durationStream`, `dispose()` | UC-012, UC-147 |
| `i_studio_master_clock.dart` | `IStudioMasterClock` | `bpm`, `meterNumerator`, `meterDenominator`, `status`, `currentBeat`, `currentMeasure`, `onBeat`, `onDownbeat`, `setBpm()`, `setMeter()`, `startTransport()`, `pauseTransport()`, `stopTransport()`, `registerTap()` | UC-002, UC-103 |
| `i_studio_master_clock_service.dart` | `IStudioMasterClockService` | Extiende `IStudioMasterClock` e `IStudioListenable` + callbacks `onPlayAll`, `onPauseAll`, `onStopAll`, `onBpmChanged` | UC-103, UC-141 |
| `reverb/all_pass_filter.dart` | `AllPassFilter` | `processSample()`, `clear()` (filtro paso-todo Schroeder) | UC-110 |
| `reverb/comb_filter.dart` | `CombFilter` | `processSample()`, `setFeedback()`, `setDamping()`, `clear()` (filtro peine con damping) | UC-110 |
| `reverb/ir_convolution_processor.dart` | `IrConvolutionProcessor` | `convolve()`, `convolveStereo()`, `generateSyntheticIr()` | UC-110 |
| `reverb/schroeder_reverb_engine.dart` | `SchroederReverbEngine` | `roomSize`, `damping`, `wetMix`, `dryMix`, `width`, `processStereo()`, `processMonoToStereo()`, `clear()` | UC-110 |
| `spatial/binaural_panner_engine.dart` | `BinauralPannerEngine` | `setAzimuth()`, `setElevation()`, `setDistance()`, `processMonoToStereo()`, `itdMs`, `distanceGain`, `reset()` | UC-111 |
| `spatial/binaural_panner_entity.dart` | `BinauralPannerEntity` | `azimuthDegrees`, `elevationDegrees`, `distanceMeters`, `headRadiusMeters`, `speedOfSoundMps`, `copyWith()` | UC-111 |
| `studio_audio_track_state.dart` | `StudioAudioTrackState` | Estado inmutable de pista (`channelId`, `status`, `currentPositionMs`, `durationMs`, `volume`, `playbackRate`, `isLooping`, `sourceTitle`) | UC-099 |
| `studio_master_audio_mixer.dart` | `StudioStereoLevelMeterData`, `StudioMasterAudioMixer` | `linearGainFromDb()`, `dbFromLinearGain()`, `clippingThresholdDb`, medicion RMS/Peak | UC-104, UC-147 |
| `studio_master_biquad_filter.dart` | `StudioBiquadType`, `StudioMasterBiquadFilter` | `lowShelf()`, `peaking()`, `highShelf()`, `lowPass()`, `highPass()`, `updateParameters()`, `processStereoSample()`, `reset()` | UC-104, UC-147 |
| `studio_master_dynamics_processor.dart` | `StudioMasterDynamicsProcessor` | `thresholdDb`, `ratio`, `attackMs`, `releaseMs`, `currentGainReductionDb`, `processStereoSample()`, `reset()` | UC-104, UC-147 |
| `studio_transport_status.dart` | `StudioTransportStatus` | Enum `stopped`, `playing`, `paused` | UC-099, UC-103 |

### 1.2 `lib/core/audio/infrastructure/` (15 archivos)

| Archivo | Clases / Exports Principales | Metodos / Responsabilidades Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- |
| `ffi/native_dsp_ffi_bridge.dart` | Export condicional (`stub` vs `native`) | Selecciona `native_dsp_ffi_bridge_native.dart` si existe `dart.library.ffi` | UC-114, UC-120 |
| `ffi/native_dsp_ffi_bridge_native.dart` | `NativeDspFfiBridge`, `_NativeScratchPool` | Carga `libtunner_dsp.{so,dylib,dll}` via `dart:ffi`, pool reutilizable `calloc`, `Finalizer`, fallback automatico a Pure Dart | UC-114, UC-118, UC-119, UC-148 |
| `ffi/native_dsp_ffi_bridge_stub.dart` | `NativeDspFfiBridge` (stub Web) | Delega todas las operaciones a `NativeDspBridgeFallback` | UC-114 |
| `memory_audio_hardware_persistence_service.dart` | `MemoryAudioHardwarePersistenceService` | Persistencia en memoria de `AudioDeviceMatrixEntity` para pruebas/headless | UC-102, UC-145 |
| `memory_studio_audio_engine.dart` | `MemoryStudioAudioChannel`, `MemoryStudioAudioEngine` | Motor de canales de audio 100% Pure Dart sin plugins nativos | UC-099, UC-145 |
| `memory_studio_audio_input_engine.dart` | `MemoryStudioAudioInputEngine` | Motor de captura PCM simulado en memoria con `injectPcmFrame()` | UC-100, UC-145 |
| `memory_studio_master_capture_service.dart` | `MemoryStudioMasterCaptureService` | Captura maestra en memoria sin escritura WAV a disco | UC-147, UC-145 |
| `studio_audio_channel.dart` | `StudioAudioChannel` | Canal de reproduccion respaldado por `package:audioplayers` con cola de volumen anti-race | UC-090, UC-099, UC-176 |
| `studio_audio_device_matrix_service.dart` | `StudioAudioDeviceMatrixService` | Orquestador de matriz hardware, cadena EQ+Compresor+Gain, bucle VU a 30 FPS y captura maestra WAV | UC-102, UC-104, UC-147, UC-180 |
| `studio_audio_engine.dart` | `StudioAudioEngine` | Pool de instancias `StudioAudioChannel` indexadas por `channelId` | UC-090, UC-099 |
| `studio_audio_hardware_persistence_service.dart` | `StudioAudioHardwarePersistenceService` | Persistencia JSON atomica (`.tmp` + `rename`) de `AudioDeviceMatrixEntity` | UC-102, UC-126 |
| `studio_audio_input_engine.dart` | `StudioAudioInputEngine` | Captura PCM desde microfono/interfaz USB usando `package:record` + `AudioRingBuffer` | UC-062, UC-100, UC-146 |
| `studio_master_capture_service.dart` | `StudioMasterCaptureService` | Codificador WAV PCM 16-bit LE asincrono con cola `_writeChain` y parcheo de cabecera RIFF al finalizar | UC-012, UC-147 |
| `studio_master_clock_service.dart` | `StudioMasterClockService` | Reloj maestro sin deriva basado en `Stopwatch` + acumulador de fase + `Timer` adaptativo + Tap Tempo | UC-002, UC-103, UC-144 |
| `studio_master_dsp_chain.dart` | `StudioMasterDspChain`, `DspBenchmarkResult` | Cadena vectorial acelerada por `INativeDspBridge`: `processMasterBlock()`, `mixChannels()`, `computeCorrelations()`, `runBenchmark()` | UC-114, UC-119, UC-148 |

### 1.3 `lib/core/audio/presentation/` (7 archivos)

| Archivo | Clases Principales | Rol UI / Observacion | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- |
| `panels/hardware_endpoints_panel.dart` | `HardwareEndpointsPanel` | Selector UI de dispositivos de entrada/salida y tamano de buffer | UC-102, UC-180 |
| `panels/master_clock_panel.dart` | `MasterClockPanel` | Controles UI de BPM, compas, transporte y Tap Tempo | UC-103, UC-180 |
| `panels/master_strip_panel.dart` | `MasterStripPanel` | Fader maestro, Mute, Dim, Mono y vumetro estereo | UC-102, UC-104, UC-180 |
| `panels/mastering_chain_panel.dart` | `MasteringChainPanel` | Controles UI de EQ 3 bandas y compresor de masterizacion | UC-104, UC-180 |
| `panels/matrix_routing_panel.dart` | `MatrixRoutingPanel` | Matriz visual de enrutamiento de canales hacia `master`, `cue` o `mute` | UC-102, UC-180 |
| `studio_master_hardware_console_widget.dart` | `StudioMasterHardwareConsoleWidget` | Contenedor atomizado de la consola maestra de hardware | UC-102, UC-180 |
| `studio_master_meter_mini_pill_widget.dart` | `StudioMasterMeterMiniPillWidget` | Indicador compacto de niveles maestros y estado de grabacion | UC-104, UC-147 |

### 1.4 `lib/core/channels/` (10 archivos)

| Archivo | Clases / Enums Principales | Metodos / Contratos Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- |
| `data/studio_patchbay_routing_service.dart` | Re-export de `domain/studio_patchbay_routing_service.dart` | Compatibilidad historica de importacion | UC-087, UC-181 |
| `domain/i_studio_patchbay_routing_service.dart` | `IStudioPatchbayRoutingService` | `registerPlug()`, `connectPlugToChannel()`, `disconnectPlug()`, `createCustomChannel()`, `renameChannel()`, `removeCustomChannel()`, `publishChannelParameters()`, `dispatchSignalFromPlug()`, `setChannelGain()`, `toggleChannelMute()`, `loadFromMatrix()` | UC-087, UC-165, UC-181 |
| `domain/studio_channel_bus.dart` | `StudioChannelBus` | `defaultTrunkChannels()` (Canales A, B, C, D), `createCustom()`, `withPlaybackParameters()`, `withName()`, `copyWith()` | UC-082, UC-087 |
| `domain/studio_modular_plug.dart` | `StudioModularPlug` | Entidad de conector modular (`id`, `label`, `type`, `toolId`, `connectedChannelId`, `isInput`, `isOutput`, `isConnected`) | UC-082, UC-087, UC-165 |
| `domain/studio_patchbay_matrix_entity.dart` | `StudioDspOpcode`, `StudioDspInstruction`, `StudioPatchbayMatrixEntity` | `initial()`, `findSourcesForChannel()`, `findSinksForChannel()`, `connectPlug()`, `disconnectPlug()`, `addChannel()`, `removeChannel()`, `toDspInstructionSequence()` | UC-082, UC-087, UC-165 |
| `domain/studio_patchbay_routing_service.dart` | `StudioPatchbaySemanticTokens`, `StudioPatchbayRoutingService` | Implementacion Pure Dart con `StudioPureNotifierMixin`, factory singleton + `.isolated()`, entrega full-duplex de parametros y buffers PCM | UC-082, UC-087, UC-165, UC-181 |
| `domain/studio_plug_type.dart` | `StudioPlugType` | Enum de direcciones/tipos de conector (`audioOut`, `audioIn`, `midiOut`, `midiIn`, `clockOut`, `clockIn`, etc.) | UC-087 |
| `presentation/studio_channel_modals.dart` | `StudioChannelPalette`, `StudioCreateChannelModal`, `StudioRenameChannelModal` | Modales Flutter para crear/renombrar canales personalizados | UC-087 |
| `presentation/studio_channel_patchbay_bar_widget.dart` | `StudioChannelPatchbayBarWidget` | Barra visual del patchbay modular | UC-087, UC-165 |
| `presentation/studio_modular_plug_widget.dart` | `StudioModularPlugWidget` | Widget interactivo de plug con animacion de pulso de senal | UC-087, UC-165 |

---

## 2. Auditoria de Brechas (Gaps) y Preparacion Headless (MCP-Readiness)

### 2.1 Acoplamientos Bloqueantes con `package:flutter/` y Plugins de Plataforma

Todo `lib/core/audio/domain/` (26 archivos) y todo `lib/core/channels/domain/` (6 archivos) son **100% Pure Dart**. Sin embargo, la capa `lib/core/audio/infrastructure/` presenta **7 archivos con bloqueos directos** para compilacion en un binario CLI Pure Dart (`dart run` / `dart compile exe`):

1. **`native_dsp_ffi_bridge_native.dart` (CRITICO):**
   - Importa `package:flutter/foundation.dart show kIsWeb;` unicamente para evaluar `if (kIsWeb)` en un archivo que solo se compila cuando `dart.library.ffi` existe (nunca en Web).
   - Importa `StudioDebugLogger`, el cual depende transitivamente de `package:flutter/foundation.dart`.
   - **Impacto:** Bloquea que el servidor MCP Headless utilice aceleracion nativa C/SIMD `libtunner_dsp`.
2. **`studio_audio_device_matrix_service.dart` (CRITICO):**
   - Extiende `ChangeNotifier` (`package:flutter/foundation.dart`) en lugar de usar el mixin Pure Dart ya existente `StudioPureNotifierMixin` (`lib/core/domain/i_studio_listenable.dart`).
   - Instancia por defecto `StudioMasterCaptureService()` y usa `StudioDebugLogger`.
3. **`studio_master_clock_service.dart` (CRITICO):**
   - Extiende `ChangeNotifier` y usa `VoidCallback` desde `package:flutter/foundation.dart`. Deberia migrar a `StudioPureNotifierMixin` y `void Function()`.
4. **`studio_master_capture_service.dart` (MEDIO - trivial de corregir):**
   - Importa `package:flutter/foundation.dart` solo por la re-exportacion accidental de `ByteData` y `Uint8List` (que pertenecen a `dart:typed_data`), mas `StudioDebugLogger`.
5. **`studio_audio_hardware_persistence_service.dart` (MEDIO):**
   - Importa `package:path_provider/path_provider.dart` directamente. Aunque ya admite `documentsPathProvider` inyectado por constructor, el `import` estatico impide compilar el archivo en Pure Dart CLI sin separacion condicional o inyeccion pura.
6. **`studio_audio_channel.dart` y `studio_audio_engine.dart` (ALTO):**
   - `StudioAudioChannel` depende de `package:audioplayers` y `package:flutter/foundation.dart`. En modo Headless MCP debe inyectarse `MemoryStudioAudioEngine` (ya Pure Dart) o un motor nativo FFI/PortAudio/miniaudio.
7. **`studio_audio_input_engine.dart` (ALTO):**
   - Depende de `package:record` y `package:flutter/foundation.dart`. En modo Headless MCP debe inyectarse `MemoryStudioAudioInputEngine` o una implementacion FFI/ALSA/CoreAudio.

### 2.2 Brechas Funcionales, Concurrencia y Limitaciones de Isolates

1. **Convolucion IR sincrona O(N * M) en `IrConvolutionProcessor`:**
   - `convolve()` ejecuta convolucion directa en dominio temporal sin FFT Overlap-Add ni ejecucion en `Isolate`. Una senal de 5 segundos con una IR de 2 segundos a 44.1 kHz (~19.4 mil millones de multiplicaciones) bloquearia el event loop del servidor MCP durante decenas de segundos, rompiendo el heartbeat JSON-RPC.
2. **Timer VU permanente en `StudioAudioDeviceMatrixService`:**
   - El constructor arranca incondicionalmente `_startMeterLoop()` (`Timer.periodic(33ms)`). En un servidor MCP CLI headless sin UI suscrita a `masterMeterStream`, este timer genera 30 wakeups/seg innecesarios (viola la disciplina de cero sobrecarga de CPU en reposo).
3. **Dispositivos de salida sintéticos en `StudioAudioDeviceMatrixService`:**
   - `_getAvailableOutputs()` devuelve una lista estatica hardcodeada de 3 dispositivos (`default_output`, `cue_headphones`, `external_dac_usb`), y `selectOutputDevice()` solo muta el estado de `_matrix` sin reconfigurar el backend real de audio.
4. **Doble cadena DSP desconectada:**
   - Existen dos cadenas de masterizacion paralelas: `StudioAudioDeviceMatrixService.processMasterStereoSamples()` (EQ Biquad 3 bandas + `StudioMasterDynamicsProcessor` en `List<double>`) y `StudioMasterDspChain` (ganancia/mono/mezcla en `Float32List` acelerada por FFI). No estan unificadas; `StudioAudioDeviceMatrixService` no usa `INativeDspBridge` ni integra `SchroederReverbEngine` o `BinauralPannerEngine`.
5. **Falta de serializacion JSON en `lib/core/channels/`:**
   - `StudioChannelBus`, `StudioModularPlug`, `StudioPatchbayMatrixEntity` y `StudioDspInstruction` carecen de metodos `toJson()` / `fromJson()`, impidiendo exponer directamente el grafo del patchbay como Resource MCP sin adaptadores manuales.
   - `StudioChannelBus.isSolo` existe en el modelo de dominio, pero `IStudioPatchbayRoutingService` no expone `toggleChannelSolo()` ni `dispatchSignalFromPlug()` aplica logica de Solo.
6. **Overhead de Timers en `StudioPatchbayRoutingService`:**
   - `_triggerPlugPulse()` crea un `Timer(200ms)` en cada llamada a `dispatchSignalFromPlug()` y `publishChannelParameters()`. Bajo streaming PCM de alta frecuencia (ej. 43 bloques/seg), genera allocacion continua de timers para animacion visual innecesaria en headless.
7. **Opcodes DSP sin ejecutor (`StudioDspInstruction`):**
   - `StudioPatchbayMatrixEntity.toDspInstructionSequence()` genera bytecode `StudioDspOpcode`, pero no existe una maquina virtual/ejecutor que lo aplique sobre `StudioMasterDspChain`.

---

## 3. Especificacion de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripcion | Estructura JSON |
| :--- | :--- | :--- |
| `tunner://audio/matrix` | Configuracion completa de la matriz de hardware, EQ 3 bandas, compresor, ganancias, ruteo de canales y estado de grabacion maestra. | `AudioDeviceMatrixEntity.toJson()` (`sampleRate`, `bufferSize`, `latencyMs`, `masterGain`, `isMuted`, `isDimmed`, `isMono`, `eqLowDb`, `eqMidDb`, `eqHighDb`, `isEqBypassed`, `compThresholdDb`, `compRatio`, `isCompBypassed`, `activeInputDevice`, `activeOutputDevice`, `channelRoutings`, `isMasterRecording`) |
| `tunner://audio/clock` | Estado en tiempo real del Reloj Maestro y transporte global. | `{ "bpm": 120.0, "meter": "4/4", "status": "stopped|playing|paused", "currentMeasure": 1, "currentBeat": 1, "isDownbeat": true, "beatIntervalMs": 500.0, "elapsedMs": 0 }` |
| `tunner://audio/meters` | Ultima lectura telemetrica de niveles estereo RMS, Peak dBFS, clipping y reduccion de ganancia del compresor. | `{ "leftRms": 0.0, "rightRms": 0.0, "leftPeakDb": -96.0, "rightPeakDb": -96.0, "isClipping": false, "gainReductionDb": 0.0 }` |
| `tunner://audio/dsp/status` | Estado del puente nativo FFI C/SIMD y ultimo resultado de benchmark. | `{ "isNativeAvailable": true, "engineName": "Native C/Rust SIMD (libtunner_dsp.so)", "reverb": { "roomSize": 0.5, "damping": 0.5, "wetMix": 0.33, "dryMix": 0.8, "width": 1.0 }, "binaural": { "azimuthDegrees": 0.0, "elevationDegrees": 0.0, "distanceMeters": 1.0, "itdMs": 0.0 } }` |
| `tunner://channels/patchbay` | Topologia completa de buses de canal, plugs modulares registrados, conexiones activas y secuencia compilada de opcodes DSP. | `{ "channels": [ { "id": "canal_a", "name": "...", "shortCode": "CH A", "colorHex": 4278255615, "gain": 1.0, "isMuted": false, "isSolo": false, "activeTrackTitle": "...", "activeBpm": 120.0, "activeCamelotKey": "8B", "isPlaying": false } ], "plugs": [ { "id": "...", "label": "...", "type": "...", "toolId": "...", "connectedChannelId": "canal_a" } ], "dspOpcodes": [ "..." ] }` |

### 3.2 Tools (`tunner_*`)

| Tool Name | Parametros (JSON Schema Resumido) | Salida | Mapeo Exacto en Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_audio_set_master_gain` | `{ gainLinear?: number (0..1.5), gainDb?: number (-60..+3.5) }` | `{ masterGain, effectiveMasterGain }` | `IStudioAudioDeviceMatrixService.setMasterGain()` / `setMasterGainDb()` |
| `tunner_audio_toggle_master_control` | `{ control: "mute" \| "dim" \| "mono" \| "eq_bypass" \| "comp_bypass" }` | `{ control, active: boolean }` | `StudioAudioDeviceMatrixService.toggleMute()` / `toggleDim()` / `toggleMono()` / `toggleEqBypass()` / `toggleCompBypass()` |
| `tunner_audio_configure_eq` | `{ lowDb?: number (-12..12), midDb?: number (-12..12), highDb?: number (-12..12) }` | `{ eqLowDb, eqMidDb, eqHighDb, isEqBypassed }` | `IStudioAudioDeviceMatrixService.setEqLow()` / `setEqMid()` / `setEqHigh()` |
| `tunner_audio_configure_compressor` | `{ thresholdDb?: number (-30..0), ratio?: number (1..20) }` | `{ compThresholdDb, compRatio, isCompBypassed }` | `IStudioAudioDeviceMatrixService.setCompThreshold()` / `setCompRatio()` |
| `tunner_audio_select_device` | `{ direction: "input" \| "output", deviceId: string }` | `{ direction, activeDevice }` | `IStudioAudioDeviceMatrixService.selectInputDevice()` / `selectOutputDevice()` |
| `tunner_audio_set_buffer_size` | `{ bufferSize: 128 \| 256 \| 512 \| 1024 }` | `{ bufferSize, latencyMs }` | `IStudioAudioDeviceMatrixService.setBufferSize()` |
| `tunner_audio_route_channel` | `{ channelId: string, destinationBus: "master" \| "cue" \| "mute" }` | `{ channelId, destinationBus }` | `IStudioAudioDeviceMatrixService.setChannelRouting()` |
| `tunner_audio_master_capture` | `{ action: "start" \| "stop", destinationPath?: string }` | `{ isMasterRecording, filePath? }` | `IStudioAudioDeviceMatrixService.startMasterRecording()` / `stopMasterRecording()` |
| `tunner_clock_control` | `{ action: "play" \| "pause" \| "stop" \| "toggle" \| "tap", bpm?: number (20..300), numerator?: number (1..16), denominator?: number (1..16) }` | Estado completo del reloj (`bpm`, `meter`, `status`, `currentMeasure`, `currentBeat`) | `IStudioMasterClockService.startTransport()` / `pauseTransport()` / `stopTransport()` / `togglePlayPause()` / `registerTap()` / `setBpm()` / `setMeter()` |
| `tunner_dsp_benchmark` | `{ iterations?: int (1..5000, default 100), blockSize?: int (128..16384, default 2048) }` | `{ engineName, isNative, elapsedMicroseconds, throughputMegaSamplesPerSec }` | `StudioMasterDspChain.runBenchmark()` |
| `tunner_dsp_configure_reverb` | `{ roomSize?: number (0..1), damping?: number (0..1), wetMix?: number (0..1), dryMix?: number (0..1), width?: number (0..1) }` | Configuracion actualizada de `SchroederReverbEngine` | Setters de `SchroederReverbEngine` |
| `tunner_dsp_configure_binaural` | `{ azimuthDegrees?: number (-180..180), elevationDegrees?: number (-90..90), distanceMeters?: number (>0) }` | `{ azimuthDegrees, elevationDegrees, distanceMeters, itdMs, distanceGain }` | `BinauralPannerEngine.setAzimuth()` / `setElevation()` / `setDistance()` |
| `tunner_dsp_render_ir_convolution` | `{ inputWavPath: string, irWavPath?: string, syntheticRt60?: number, outputWavPath: string, normalize?: boolean }` | `{ outputWavPath, outputSamples, elapsedMs }` | `IrConvolutionProcessor.convolveStereo()` / `generateSyntheticIr()` (ejecutado en `Isolate.run`) |
| `tunner_patchbay_manage_channel` | `{ action: "create" \| "rename" \| "remove" \| "set_gain" \| "toggle_mute", channelId?: string, name?: string, shortCode?: string, colorHex?: int, gain?: number (0..2) }` | Estado actualizado del canal o lista de canales | `IStudioPatchbayRoutingService.createCustomChannel()` / `renameChannel()` / `removeCustomChannel()` / `setChannelGain()` / `toggleChannelMute()` |
| `tunner_patchbay_connect_plug` | `{ action: "connect" \| "disconnect", plugId: string, channelId?: string }` | `{ plugId, connectedChannelId }` | `IStudioPatchbayRoutingService.connectPlugToChannel()` / `disconnectPlug()` |
| `tunner_patchbay_publish_params` | `{ channelId: string, title?: string, bpm?: number, key?: string, isPlaying?: boolean, positionMs?: int }` | Estado actualizado de `StudioChannelBus` | `IStudioPatchbayRoutingService.publishChannelParameters()` |

### 3.3 Prompts Guiados para Agentes IA

1. **`tunner_mastering_chain_setup`**: Guia al agente para leer `tunner://audio/matrix` y `tunner://audio/meters`, diagnosticar niveles RMS/Peak/clipping y aplicar una curva EQ de 3 bandas + compresion controlada segun el genero objetivo (ej. vocal academico, mezcla club, acustico).
2. **`tunner_patchbay_routing_wizard`**: Lee `tunner://channels/patchbay`, analiza que plugs de origen/destino estan desconectados y propone/ejecuta un grafo de enrutamiento libre de bucles para sincronizar BPM y audio entre Score, DJ y Rack Modular.
3. **`tunner_audio_diagnostics_and_latency_audit`**: Ejecuta `tunner_dsp_benchmark`, inspecciona `tunner://audio/dsp/status` y `tunner://audio/matrix`, y emite recomendaciones tecnicas sobre tamano de buffer, latencia en ms y disponibilidad de `libtunner_dsp`.

---

## 4. Plan de Ajustes Tecnicos Previos (Pre-MCP Hardening)

1. **Erradicar `package:flutter/foundation.dart` de la infraestructura de audio (Prioridad S0):**
   - `native_dsp_ffi_bridge_native.dart`: Eliminar `import 'package:flutter/foundation.dart' show kIsWeb;`. Sustituir la guardia web (innecesaria en el target `dart.library.ffi`) y desacoplar `StudioDebugLogger` inyectando `IStudioLogger` Pure Dart.
   - `studio_audio_device_matrix_service.dart` y `studio_master_clock_service.dart`: Reemplazar `extends ChangeNotifier` por `with StudioPureNotifierMixin`, reemplazar `VoidCallback` por `void Function()`, y reemplazar `StudioDebugLogger` por `IStudioLogger`.
   - `studio_master_capture_service.dart`: Reemplazar `import 'package:flutter/foundation.dart';` por `import 'dart:typed_data';` e inyectar `IStudioLogger`.
   - `studio_audio_hardware_persistence_service.dart`: Extraer la resolucion de `getApplicationDocumentsDirectory()` a un proveedor inyectable o archivo con import condicional para que el servicio base sea 100% Pure Dart.
2. **Modo Headless determinista sin timers ociosos (Prioridad S1):**
   - Agregar flag `bool enableMeterDecayLoop = true` en `StudioAudioDeviceMatrixService` (desactivado en servidor MCP CLI) y `bool enableVisualPulseTimers = true` en `StudioPatchbayRoutingService`.
3. **Offloading de convolucion IR a Isolate (Prioridad S1):**
   - Envolver `IrConvolutionProcessor.convolve()` / `convolveStereo()` en un helper asincrono `convolveInIsolate()` usando `Isolate.run` y planificar migracion a convolucion particionada por FFT (Overlap-Add) para reducir complejidad de $O(N \cdot M)$ a $O(N \log M)$.
4. **Serializacion JSON y completitud de `lib/core/channels/` (Prioridad S1):**
   - Implementar `toJson()` / `fromJson()` en `StudioChannelBus`, `StudioModularPlug`, `StudioPatchbayMatrixEntity` y `StudioDspInstruction`.
   - Agregar `toggleChannelSolo(String channelId)` en `IStudioPatchbayRoutingService` y aplicar semantica real de Solo en `dispatchSignalFromPlug()`.
5. **Unificacion de cadena Master DSP y puentes IPC (Prioridad S2):**
   - Integrar `StudioMasterDspChain` (FFI) dentro de `StudioAudioDeviceMatrixService` para que el procesamiento maestro aproveche SIMD nativo y pueda inyectar `SchroederReverbEngine` y `BinauralPannerEngine`.
   - Definir eventos IPC (`audio.matrix.updated`, `audio.clock.state`, `channels.patchbay.updated`) para reflejar mutaciones originadas desde herramientas MCP en la UI Flutter viva cuando exista un cliente grafico conectado.
