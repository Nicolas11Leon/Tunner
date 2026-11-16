# Plan de Implementación: Matriz Universal de Canales de Estudio y Enrutamiento Inter-Herramientas (Score-to-DJ-to-DSP)

Este documento define la arquitectura, hoja de ruta técnica y fundamentos cognitivos para unificar todas las herramientas de **Tunner** (Partituras/MusicXML, Consola DJ, Mezclador de Canales, Afinador Estroboscópico, Sintetizador SF2 y Bóveda Multimedia) a través de una **Matriz Universal de Canales y Enrutamiento Reactivo**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-CHANNEL-MATRIX-ROUTING-2026-0087`
- **Título:** Matriz Universal de Canales, Enrutamiento Inter-Herramientas Basado en Divulgación Progresiva y Ergonomía Cognitiva
- **Fase del Proyecto:** Fase 2 (Instrumentación, Consola DJ y Estaciones de Trabajo)
- **Estado:** Propuesto / En Revisión
- **ADR Relacionado:** [ADR 0077: Matriz Universal de Canales y Enrutamiento Inter-Herramientas](../04_adrs/0077_universal_studio_channel_matrix_and_inter_tool_audio_routing_suite.md)
- **Documento Funcional Base:** [Caso de Uso 87: Matriz Universal de Canales y Enrutamiento Inter-Herramientas](../02_use_cases/87_uc_universal_studio_channel_matrix_and_inter_tool_audio_routing_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Crear un sistema de interconexión atómico, modular y de altísima velocidad (sub-10ms, 60/120 FPS) donde cualquier fuente sonora o musical (partituras MusicXML/MIDI, grabaciones WAV, stems, sintetizador Soundfont, micrófonos en vivo) pueda ser asignada y enrutada dinámicamente a través de un **Sistema Canónico de Canales de Estudio (`StudioChannelEntity` & `StudioChannelMatrixBus`)**, permitiendo por ejemplo:
1. **Arrastrar una melodía o partitura directamente a la Consola DJ (Deck A o Deck B):** El motor sintetiza la partitura mediante Soundfont SF2 o audio renderizado y la carga como una pista con BPM y clave Camelot detectados automáticamente, permitiendo mezclarla, aplicarle scratching, ecualización y efectos contra pistas comerciales o acompañamientos.
2. **Asignación y Configuración Multi-Destino:** Enrutar cualquier canal hacia destinos específicos (Deck DJ, Afinador Estroboscópico, Espectrograma FFT, Mezclador de Stems, Suite de Autotune o Salida Master).
3. **Cero Fricción Cognitiva (HCI & Ergonomía):** Aplicar los principios de **Divulgación Progresiva (Progressive Disclosure)** y **Carga Cognitiva Reducida (Sweller/Shneiderman)**:
   - Nivel superficial: Asignación inmediata por arrastrar-y-soltar ("Drag & Route") y conmutadores rápidos de canal.
   - Nivel profundo: Matriz de ruteo matricial matricial (Sends, Pre/Post-fader, sidechaining y buses auxiliares) revelada únicamente a demanda sin saturar al estudiante o principiante.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad canónica `StudioChannelEntity` e inmutable `StudioChannelMatrixState`.
  - Bus de enrutamiento y orquestación `StudioChannelRoutingBus` (Capa de Dominio e Infraestructura en memoria, 100% offline-first).
  - Componente de interfaz de selección y asignación de canales: `StudioChannelStripHeader`, `StudioChannelQuickAssignDropdown` y conector arrastrable `ChannelPatchCableConnector`.
  - Integración nativa entre el reproductor de partituras (`ScorePlaybackAudioEngine`) y la Consola DJ (`DjConsoleViewModel`).
  - Pruebas unitarias de enrutamiento, latencia cero y pruebas de widgets.
- **Excluido (Out-of-Scope):**
  - Servidores remotos o microservicios de streaming (prohibidos por la regla *Offline-First* y *Zero Microservices* de `AGENTS.md`).

---

## 2. Fundamentos de Interacción Humano-Computadora (HCI) y Ergonomía Cognitiva

Para garantizar que el software sea intuitivo, rápido y didáctico sin parecer "hecho de palitos" ni saturar la pantalla:
1. **Teoría de la Carga Cognitiva (Sweller):**
   - La memoria de trabajo humana solo procesa $4 \pm 1$ elementos simultáneamente.
   - Mostrar matrices de ruteo con 32 buses y 100 perillas a la vez genera *carga cognitiva extraña*.
   - **Solución implementada:** Las herramientas exponen una etiqueta clara de canal (`CH 1: Melodía Flauta`, `CH 2: Beat Sintético`, `CH 3: Voz Micrófono`). Al conectar una herramienta a otra, el sistema auto-configura el bus interno sin obligar al usuario a descifrar árboles de menús complejos.
2. **Divulgación Progresiva (Nielsen Norman Group):**
   - Los controles se ordenan en 2 niveles:
     - **Nivel 1 (Inmediato):** Selector de fuente, destino, fader de volumen, botón Mute/Solo y medidor VU.
     - **Nivel 2 (Avanzado):** Ganancia pre-fader, envíos auxiliares (Reverb, Delay), asignación a grupos de silenciamiento y salida a monitores CUE.
3. **Manipulación Directa y Retroalimentación Tangible (Shneiderman):**
   - Arrastrar un archivo o partitura sobre un canal produce un destello electromagnético de color coincidente, informando instantáneamente que el canal aceptó la señal.
   - Las conexiones activas emiten un flujo de energía visual pulsante que indica actividad de señal de audio.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [ ] Crear [`lib/core/channels/domain/studio_channel_entity.dart`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/lib/core/channels/domain/studio_channel_entity.dart):
  - Modelado de `StudioChannelEntity`: `id`, `name`, `channelIndex`, `colorHex`, `sourceType` (Score, Midi, AudioFile, Microphone, SoundfontSynth), `destinationType` (MasterBus, DjDeckA, DjDeckB, StrobeTuner, Autotune, StemProcessor), ganancia, balance estéreo, mute, solo, armed.
  - Modelado de `StudioChannelMatrixState`: mapa inmutable de canales, asignaciones activas y buses de interconexión.
- [ ] Pruebas unitarias completas de la capa de dominio (`test/core/channels/studio_channel_domain_test.dart`).

### Paso 2: Capa de Infraestructura / Datos (Bus de Enrutamiento en Memoria)
- [ ] Implementar [`lib/core/channels/data/studio_channel_routing_bus.dart`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/lib/core/channels/data/studio_channel_routing_bus.dart):
  - Bus de eventos y flujos de muestras PCM Float32 en memoria.
  - Capacidad de transferir streams sintetizados desde partituras/MIDI hacia los búferes de audio de la Consola DJ con cálculo determinista de latencia (<5 ms).
  - Soporte de desconexión inmediata sin clips de audio ni fugas de memoria.

### Paso 3: Capa de Presentación (Controles Atómicos y Ergonomía Visual)
- [ ] Diseñar el panel de canales modular:
  - `StudioChannelStripWidget`: Fader vertical de precisión, medidor VU estéreo integrado, botones Mute, Solo y selector de enrutamiento rápido.
  - `StudioChannelMatrixModal`: Matriz visual para usuarios avanzados con diagrama de flujo de señal simplificado y divulgación progresiva.
- [ ] Conectar Partituras con Consola DJ:
  - En la vista de partituras/documentos del proyecto: Añadir botón directo `"Enviar a Consola DJ (Deck A / Deck B)"`.
  - Al pulsar o arrastrar, el sistema sintetiza la melodía y actualiza el Deck DJ con el título de la partitura, su BPM calculado y la clave tonal detectada.
- [ ] Integrar el selector de canal en la Consola DJ (`DjStudioWorkstationView`):
  - Cada Deck muestra el selector de canal de entrada (`Fuente: Archivo WAV | Partitura CH 1 | Micrófono en Vivo`).

### Paso 4: Pruebas de Regresión, Calidad y Rendimiento
- [ ] Pruebas de integración de la matriz de canales y de renderizado a 60 FPS.
- [ ] Verificación de cero bucles de espera activa (Zero busy-waiting loops) y gestión determinista de memoria.
- [ ] Ejecución de `flutter analyze` y suite global de pruebas.
- [ ] Compilación de la versión nativa de Linux y verificación en `DISPLAY=:0`.

---

## 4. Criterios de Aceptación (Definition of Done)
1. **Interoperabilidad Total:** Una partitura abierta en el proyecto puede enviarse con 1 clic o arrastrarse a la Consola DJ para reproducirse, mezclarse o afinarse como un canal de audio real.
2. **Matriz de Canales Activa:** El usuario puede nombrar, colorear y enrutar canales hacia la Consola DJ, Afinador Estroboscópico o Salida Master.
3. **Ergonomía Cognitiva:** La interfaz no satura al usuario; muestra solo los controles esenciales y revela opciones complejas bajo demanda.
4. **Calidad de Código:** Cobertura de pruebas unitarias superior al 90%, cero errores en `flutter analyze`, y documentación completa con ADR y Casos de Uso.
