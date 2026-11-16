# Plan de Implementación: Suite Modular de Plugs Interactivos, Canales de Parcheo (A, B, C, D) y Arquitectura Escalable de Bajo Nivel

Este documento formaliza el plan de ingeniería para dotar a cada herramienta de **Tunner** de **Plugs Modulares Interactivos (Entrada/Salida)** interconectados mediante **Buses de Canales (Canal A, B, C, D)**, con simulación tangible y preparación para compilación en un futuro lenguaje DSL/DSP de bajo nivel.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-MODULAR-PLUGS-CHANNELS-2026-0087`
- **Título:** Plugs Modulares Interactivos por Herramienta, Buses de Canales A/B/C/D y Motor de Parcheo Escalable a Bajo Nivel
- **Fase del Proyecto:** Fase 2 (Instrumentación, Consola DJ y Estaciones de Trabajo)
- **Estado:** Aprobado para Implementación
- **ADR Relacionado:** [ADR 0077: Suite Modular de Plugs Interactivos y Buses de Canales](../04_adrs/0077_universal_studio_channel_matrix_and_inter_tool_audio_routing_suite.md)
- **Documento Funcional Base:** [Caso de Uso 87: Plugs Modulares Interactivos y Matriz de Canales](../02_use_cases/87_uc_universal_studio_channel_matrix_and_inter_tool_audio_routing_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Transformar la plataforma en un **estudio modular tangible**, donde cada herramienta dispone de puertos físicos virtuales (**Plugs** de entrada y salida de Audio, MIDI y Clock Sync). El usuario puede interconectar herramientas seleccionando o conectando plugs a los canales troncales (**CANAL A, CANAL B, CANAL C, CANAL D**), permitiendo:
1. **Conexión Tangible entre Herramientas:**
   - Plug `[OUT]` de Partitura $\rightarrow$ Conectado a `CANAL A` $\rightarrow$ Plug `[IN]` de Deck A en la Consola DJ.
   - Plug `[OUT MASTER]` de Consola DJ $\rightarrow$ Conectado a `CANAL B` $\rightarrow$ Plug `[IN]` de Afinador Estroboscópico / Espectrograma.
   - Plug `[OUT STEM]` de Aislamiento 4-Stems $\rightarrow$ Conectado a `CANAL C` $\rightarrow$ Grabador de Mezcla WAV.
2. **Interactividad Visual Inmediata (LEDs y Pulso de Señal):**
   - Cada plug cuenta con un bisel metálico industrial y un anillo LED neón que titila al transmitir audio o eventos musicales.
   - Menú rápido emergente al pulsar un plug para asignarlo a `CANAL A`, `CANAL B`, `CANAL C`, `CANAL D` o `Desconectar`.
3. **Escalabilidad a Lenguaje de Bajo Nivel (DSL/DSP Ready):**
   - La arquitectura de parches se estructura mediante opcodes e instrucciones desacopladas (`StudioPatchbayOpcode`: `CONNECT_PLUG`, `SET_GAIN`, `DISCONNECT_BUS`), garantizando que en el futuro pueda ser compilada y ejecutada en C/Rust nativo (`dart:ffi`) o una máquina virtual de audio en tiempo real sin modificar la interfaz de usuario.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Modelos de dominio: `StudioPlugType`, `StudioModularPlug`, `StudioChannelBus` y `StudioPatchbayMatrixEntity`.
  - Servicio de enrutamiento en memoria: `StudioPatchbayRoutingService` (cero latencia de red, 100% offline).
  - Componentes de interfaz: `StudioModularPlugWidget` (Jack 1/4" interactivo), barra de canales `StudioChannelPatchbayBarWidget` y conmutadores rápidos.
  - Integración nativa con `DjStudioWorkstationView` y `ScorePlaybackAudioEngine`.
  - Pruebas unitarias de dominio, servicio y widgets.
- **Excluido (Out-of-Scope):**
  - Servidores remotos de streaming o dependencias propietarias externas.

---

## 2. Fundamentos de Interacción Humano-Computadora (HCI) y Ergonomía

1. **Metáfora Física Tangible (Skeuomorphic Affordance):**
   - Los músicos e ingenieros de sonido entienden instintivamente el concepto de un conector Jack o XLR.
   - Al presentar plugs claramente etiquetados como `[OUT AUDIO]` o `[IN DECK A]`, se reduce a cero la curva de aprendizaje en comparación con complicadas tablas de matrices.
2. **Divulgación Progresiva:**
   - Nivel 1: Conexión inmediata a 1 clic con el selector de Canales A, B, C, D.
   - Nivel 2: Ajuste de volumen y monitorización en la barra de parcheo `StudioChannelPatchbayBarWidget`.
3. **Retroalimentación Sensorial Continua:**
   - Si una partitura está sonando, el plug de salida brilla en verde/cian en sincronía con las notas.
   - Si el canal receptor está activo, su medidor VU y anillo de plug se iluminan.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [ ] Implementar `lib/core/channels/domain/studio_modular_plug.dart`:
  - `StudioPlugType`: `audioInput`, `audioOutput`, `midiInput`, `midiOutput`, `clockSyncInput`, `clockSyncOutput`.
  - `StudioModularPlug`: Entidad inmutable con id, etiqueta, herramienta propietaria, tipo, canal conectado (`canal_a`, `canal_b`, `canal_c`, `canal_d`) y estado de señal.
- [ ] Implementar `lib/core/channels/domain/studio_channel_bus.dart`:
  - Canales canónicos: `A (Cian)`, `B (Ámbar)`, `C (Esmeralda)`, `D (Púrpura)`.
  - Fader de ganancia, silenciamiento (Mute), lista de plugs emisores y receptores.
- [ ] Implementar `lib/core/channels/domain/studio_patchbay_matrix_entity.dart`:
  - Matriz global inmutable de conexiones y generador de instrucciones DSP.

### Paso 2: Capa de Infraestructura / Datos (Servicio de Enrutamiento In-Memory)
- [ ] Implementar `lib/core/channels/data/studio_patchbay_routing_service.dart`:
  - Registro dinámico de herramientas y sus plugs.
  - Conexión y desconexión determinista de plugs a canales A, B, C, D.
  - Despacho de búferes de audio `Float32List` entre herramientas con latencia <5 ms.

### Paso 3: Capa de Presentación (Plugs Vectoriales y Barra de Canales)
- [ ] Implementar `lib/core/channels/presentation/studio_modular_plug_widget.dart`:
  - Gráfico vectorial de conector Jack con aro iluminado según el canal (Cian para A, Ámbar para B, Esmeralda para C, Púrpura para D).
  - Diálogo o menú radial rápido al hacer clic para conmutar canal con 1 clic.
- [ ] Implementar `lib/core/channels/presentation/studio_channel_patchbay_bar_widget.dart`:
  - Barra compacta superior con la vista de los 4 canales A, B, C, D, faders, mute y conteo de plugs activos.
- [ ] Integrar los plugs modulares en:
  - `DjStudioWorkstationView`: Deck A `[IN A]`, Deck B `[IN B]`, Master `[OUT MASTER]`.
  - Acciones de partituras/melodías: `[OUT MELODÍA]` conectable al Canal A para sonar directo en el Deck DJ.

### Paso 4: Pruebas, Verificación y Build Nativo
- [ ] Pruebas unitarias de enrutamiento y conexión en `test/core/channels/studio_patchbay_test.dart`.
- [ ] Pruebas de widgets para interacción de plugs y cambio de canales.
- [ ] `flutter analyze` con 0 errores y 0 advertencias.
- [ ] Compilación Linux nativa y lanzamiento en `DISPLAY=:0`.

---

## 4. Criterios de Aceptación (Definition of Done)
1. Cada herramienta principal expone plugs de entrada o salida visibles.
2. Al conectar el plug de una melodía/partitura al `CANAL A` y el plug de entrada de Deck A al `CANAL A`, la melodía se transfiere y reproduce en Deck A con BPM y tono sincronizados.
3. Los plugs reflejan el color del canal conectado y titilan con el flujo de audio.
4. Cero dependencias de red, 60 FPS estables y cero fugas de memoria.
