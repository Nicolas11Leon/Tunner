# Especificación Canónica: Mapa Exhaustivo de Sinergias Inter-Herramientas, Análisis de Fricción y Plan Maestro de Refactorización

## Metadatos del Documento

- **ID del Documento:** `DOC-ARCH-2026-058`
- **Título Oficial:** Arquitectura de Interoperabilidad Global: Matriz de Sinergia $N \times N$, Detección de Acoplamientos Forzados y Estrategia de Refactorización Modular Atómica
- **Estado:** Approved
- **Fecha de Creación:** 2026-11-09
- **Última Modificación:** 2026-11-09
- **Fase Asociada:** Fase 5 (Modular Studio & Clean Architecture Refactor)
- **Autor / Revisor Principal:** DeepMind Agentic Pair Programmer & Tunner Core Architecture Team

---

## 1. Resumen Ejecutivo (Executive Summary)

A medida que **Tunner** evoluciona de una colección de herramientas individuales de alta precisión (afinador MPM, metrónomo en Isolate, pentagrama SMuFL, grabador, corrector autotune, espectrograma, sintetizador, etc.) hacia una plataforma educativa y de producción musical unificada, surge la necesidad imperativa de formalizar **cómo interactúan las herramientas entre sí**.

Este documento presenta:
1. Un inventario formal de las **16 herramientas modulares** de Tunner.
2. La **Matriz de Interoperabilidad $N \times N$**, clasificando los enlaces en **Hiper-Sinergias ($10\times$)**, **Sinergias Auxiliares** y **Cruces Forzados / Sin Sentido Práctico** (acoplamientos que no aportan valor pedagógico o acústico).
3. El diseño de la **Arquitectura Atómica de Señales** sobre el `SignalBus` maestro.
4. El plan maestro de **Refactorización Integral** para desacoplar las capas de dominio, estandarizar puertos tipados y permitir que cualquier herramienta sea consumida o proyectada en UI/UX sin deuda técnica ni jank visual.

---

## 2. Inventario Formal de Herramientas del Ecosistema Tunner

Cada herramienta de Tunner se define en la capa de dominio como un **Nodo Interoperable (`InteroperableModuleNode`)** con puertos de entrada/salida tipados:

| ID de Herramienta | Nombre Canónico | Puertos de Salida (Productor) | Puertos de Entrada (Consumidor) | Naturaleza Funcional |
| :--- | :--- | :--- | :--- | :--- |
| **`strobe_tuner`** | Afinador Estroboscópico MPM | `pitch_out` (Hz, cents, nota) | `audio_in` (PCM), `calibration_in` | Detección monofónica de ultra-precisión ($\pm0.1\text{ c}$) |
| **`metronome`** | Metrónomo en Isolate | `clock_out` (ticks, downbeats) | `transport_in` (Play/Stop/BPM) | Reloj maestro temporal sin jitter ($< 1\text{ ms}$) |
| **`score_notation`** | Pentagrama Vectorial SMuFL | `score_event_out` (notas leídas) | `clock_in`, `pitch_in`, `score_data_in` | Renderizado gráfico de notación y playhead |
| **`score_editor`** | Editor Interactivo de Partituras | `score_document_out` (MusicXML/MIDI) | `score_event_in`, `audio_transcribe_in` | Manipulación estructural de compases y notas |
| **`transcription`** | Transcriptor Mic-to-Score | `transcription_notes_out` | `audio_in` (PCM), `clock_in` | Conversión acústica transiente $\to$ figura rítmica |
| **`practice_recorder`**| Grabador & Auto-Escucha | `audio_buffer_out`, `waveform_out` | `audio_in`, `clock_in`, `transport_in` | Captura multicanal sin compresión y bucles A-B |
| **`vocal_autotune`** | Corrector de Tono DSP | `audio_processed_out`, `pitch_curve_out`| `audio_in`, `scale_target_in` | Cuantización de fase/frecuencia en tiempo real |
| **`harmonic_drone`** | Dron Armónico & Batimento | `audio_synth_out`, `fundamental_out` | `temperament_in`, `pitch_offset_in` | Generación de tonos puros y quintas acústicas |
| **`spectrogram`** | Espectrograma FFT | `spectral_centroid_out`, `thd_out` | `audio_in` (PCM), `marker_in` | Análisis espectral de sobretonos $H_1-H_8$ |
| **`chord_analyzer`** | Analizador Polifónico de Acordes | `chord_symbol_out`, `voicing_out` | `audio_in` (Polifónico), `midi_in` | Reconocimiento multitonal y radar cromático |
| **`ear_trainer`** | Entrenador Auditivo a Ciegas | `quiz_result_out` | `audio_in`, `user_input_in` | Discriminación interválica a ciegas sin pantalla |
| **`guided_lessons`** | Tutor TTC Rushing/Dragging | `lesson_grade_out`, `kpi_metrics_out` | `clock_in`, `pitch_in`, `task_contract_in` | Evaluación pedagógica de conservatorio |
| **`song_decomposer`**| Descomponedor de Partituras | `stems_score_out` (voces 1..N) | `score_document_in` (XML/MID/PDF) | Separación polifónica para modo "Minus-One" |
| **`mixer`** | Mezclador Multitrack de Stems | `master_mix_out` (WAV/Audio) | `audio_track_1..N_in`, `fader_in` | Balance, paneo, mute, solo y summing digital |
| **`master_keyboard`**| Teclado Maestro & Emulador | `midi_out`, `audio_synth_out` | `key_press_in`, `temperament_in` | Síntesis procedural SoundFont de 60+ instrumentos |
| **`acoustic_lab`** | Calibrador de Micrófono & Filtros| `audio_conditioned_out` | `raw_mic_in`, `instrument_profile_in` | Noise gate, rechazo de voz y compensación de curva |

---

## 3. Matriz de Interoperabilidad: ¿Cómo Trabajan Entre Ellas?

### 3.1 Las 6 Grandes Hiper-Sinergias ($10\times$ Impacto)
Son combinaciones de 3 o más herramientas donde el resultado pedagógico o técnico es infinitamente superior a la suma de las partes aisladas:

```mermaid
graph TD
    subgraph S1["1. Sinergia de Lectura & Vuelo"]
        M1[Metrónomo] -->|temporalClock| SN1[Pentagrama SMuFL]
        ST1[Afinador MPM] -->|pitch & cents| SN1
        SN1 --> GL1[Tutor Rushing/Dragging]
    end

    subgraph S2["2. Sinergia Vocal & Post-Producción"]
        VA2[Autotune DSP] -->|Audio Wet| PR2[Grabador]
        MIC2[Mic Dry] --> PR2
        PR2 --> SE2[Editor Pentagrama]
        PR2 --> MX2[Mixer de Stems]
    end

    subgraph S3["3. Sinergia Afinador Inteligente"]
        AL3[Acoustic Lab] -->|Perfil Tímbrico| INS3[Instrument Engine]
        INS3 -->|Filtros & Rango| ST3[Afinador MPM]
        INS3 -->|Timbre Real| SYN3[Diapasón Synthesizer]
    end

    subgraph S4["4. Sinergia Minus-One & Ensamble"]
        SD4[Descomponedor] -->|Voz 1 Muteada| SN4[Pentagrama SMuFL]
        SD4 -->|Voces 2..N| MK4[Master Synth SF2]
        MK4 --> MX4[Mixer de Stems]
        PR4[Grabador Músico] --> MX4
    end

    subgraph S5["5. Sinergia de Batimento Acústico"]
        HD5[Dron Armónico] -->|Audio Puro| SP5[Espectrograma FFT]
        MIC5[Instrumento Físico] --> SP5
        SP5 -->|fb = |f1 - f2|| ST5[Afinador MPM]
    end

    subgraph S6["6. Sinergia de Armonía & Temperamentos"]
        KB6[Teclado Maestro] -->|MIDI Polifónico| CA6[Analizador Acordes]
        KB6 -->|Audio Sintetizado| ST6[Afinador Temperamentos]
        CA6 --> SP6[Espectrograma H1-H8]
    end
```

---

## 4. Análisis Crítico: ¿Cuáles Combinaciones NO Tienen una Sinergia Clara? (Anti-Patrones y Cruces Forzados)

No todas las herramientas deben conectarse con todas. Conectar módulos sin un caso de uso pedagógico claro genera **deuda técnica, confusión en la interfaz de usuario y sobrecarga computacional innecesaria**. A continuación se identifican los cruces que **no tienen sentido** y deben permanecer desvinculados:

### 4.1 `vocal_autotune` + `ear_trainer` (Entrenador a Ciegas)
- **Razón del rechazo:** El propósito del *Entrenador a Ciegas* es aislar el oído interno para que el estudiante reconozca y cante intervalos puros sin apoyo externo.
- **Conflicto:** Si se inserta el `vocal_autotune` en el flujo de escucha del estudiante durante un test auditivo a ciegas, el algoritmo "corrige" artificialmente su voz antes de que el estudiante se dé cuenta de su propio error, destruyendo el proceso neuro-pedagógico de auto-corrección.
- **Veredicto:** **Prohibido.** El módulo de oído a ciegas debe recibir estrictamente audio puro (`raw_mic`).

### 4.2 `chord_analyzer` (Polifónico) directo sobre `strobe_tuner` (Monofónico MPM) sin Split
- **Razón del rechazo:** El algoritmo MPM (*McLeod Pitch Method*) asume una sola fundamental armónica predominante ($f_0$).
- **Conflicto:** Alimentar un acorde polifónico (ej. Do Mayor con 3 notas simultáneas) directamente a la entrada del afinador estroboscópico sin una etapa previa de descomposición polifónica (*Polyphonic Multi-Tone Splitter*) genera distorsión de fase en la función NSDF, haciendo oscilar la aguja estroboscópica caóticamente sin convergencia.
- **Veredicto:** **Incompatible directamente.** El analizador de acordes debe operar sobre su propio algoritmo FFT/CQT polifónico, mientras que el afinador estroboscópico debe restringirse a fuentes monofónicas o a cada nota individual ya aislada.

### 4.3 `harmonic_drone` + `metronome` a alta velocidad en Pasajes Virtuosos (`TEC.05`)
- **Razón del rechazo:** El dron armónico sostiene una o dos notas fundamentales continuas para afinación contemplativa y entonación por batimento lento.
- **Conflicto:** En ejercicios de escalas virtuosas o arpegios rápidos a 140+ BPM (dominio `TEC`), el choque acústico continuo entre el dron sostenido y las notas de paso, notas cromáticas y apoyaturas genera una cacofonía disonante (*tonal clash*) que ensucia la lectura del espectrograma y satura el espacio auditivo del músico.
- **Veredicto:** **Desaconsejado.** El dron armónico debe reservarse para notas largas (`LONG`), intervalos estáticos (`INTV`) y afinación modal, no para ejercicios de alta agilidad métrica.

### 4.4 `transcription` (Mic-to-Score) + `song_decomposer` (Modo Minus-One) sobre el mismo pentagrama
- **Razón del rechazo:** El descomponedor carga una partitura existente y ya anotada.
- **Conflicto:** Si el motor de transcripción en tiempo real intenta escribir notas captadas del micrófono en el mismo lienzo de pentagrama donde ya están impresas las notas de la obra que se está leyendo, se produce una colisión gráfica caótica de glifos SMuFL superpuestos.
- **Veredicto:** **Separación estricta de pistas.** La transcripción en vivo debe escribirse en un pentagrama esclavo paralelo ("Pentagrama de Ejecución"), mientras que la partitura de la obra permanece en el "Pentagrama Maestro de Referencia".

---

## 5. Arquitectura Atómica de Refactorización

Para que todas las herramientas con sinergia comprobada colaboren fluidamente sin acoplamiento espagueti, se establece la siguiente reestructuración:

### 5.1 Capa de Dominio Desacoplada (Clean Architecture)
```
lib/core/interop/
  ├── signal_bus.dart              # Bus reactivo en memoria con latencia < 1ms
  ├── signal_type.dart             # temporalClock, pitchEstimate, audioPcm, scoreData, etc.
  ├── port_id.dart                 # Value Object inmutable para direccionamiento (modulo.puerto)
  ├── atomic_signal_event.dart     # Evento tipado inmutable transportado por el bus
  └── module_connection.dart       # Enlace punto a punto o broadcast
```

### 5.2 Contrato Universal de Módulo (`InteroperableModuleContract`)
Toda herramienta de Tunner debe implementar este contrato en la capa de datos/infraestructura:
```dart
abstract class InteroperableModuleNode {
  String get moduleId;
  String get displayName;
  List<PortId> get outputPorts;
  List<PortId> get inputPorts;
  bool get isPoweredOn;

  void onSignalReceived(AtomicSignalEvent event);
  void connectOutput(PortId output, PortId targetInput);
  void disconnectOutput(PortId output, PortId targetInput);
}
```

### 5.3 UI/UX Atómica Heredable (Atomic Presentation Tokens)
1. **Átomos:**
   - `TaskCodeBadge`: Renderiza códigos canónicos TTC (`EAR.01.INTV.001`).
   - `MultiToolSynergyBadge`: Renderiza pastillas de hiper-sinergia con los iconos específicos de las herramientas orquestadas.
   - `PortJackWidget`: Conector visual virtual de entrada/salida para la matriz de conexiones del rack.
2. **Moléculas:**
   - `TaskCardBase<T>`: Plantilla extensible para tarjetas de lecciones y tareas.
   - `ToolMiniDock`: Barra flotante que muestra qué herramientas están activas y recibiendo señales.
3. **Organismos:**
   - `ModularStudioRackView`: Espacio de trabajo donde las herramientas se montan como unidades de rack 19" colapsables (`compact` / `expanded`).
   - `TaskQuickJumpModal`: Buscador spotlight instantáneo (tecla `J`) para saltar a cualquier tarea simple o conjunta.

---

## 6. Plan Maestro de Refactorización Paso a Paso

1. **Fase R1: Estandarización de Puertos y Eventos en Dominio (`SignalBus`):**
   - Asegurar que todas las 16 herramientas expongan sus puertos formales de entrada y salida sin dependencias de Flutter.
2. **Fase R2: Integración del Afinador Inteligente con Detección Tímbrica:**
   - Unir `strobe_tuner` + `instrument` + `acoustic_lab` en un flujo unificado donde el micrófono se auto-calibra según el perfil del instrumento.
3. **Fase R3: Suite Vocal & Edición de Tono (Autotune + Grabador + Pentagrama):**
   - Conectar la salida del corrector de tono en tiempo real con el grabador multitrack y el editor vectorial de partituras SMuFL.
4. **Fase R4: Descomponedor Minus-One & Acompañamiento SoundFont:**
   - Orquestar la importación de obras polifónicas con el mixer de stems y la síntesis SoundFont para silenciar la voz del estudiante y grabar sobre el ensamble virtual.
5. **Fase R5: Verificación Exhaustiva y Pruebas de Regresión:**
   - Mantener la regla no negociable de **0 advertencias en `flutter analyze`** y **100% de pruebas unitarias y de widgets aprobadas**.
