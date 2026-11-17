# Plan de Implementación: Suite Modular de Plugs Interactivos, Canales Nombrables Personalizados y Sincronización Bidireccional de Parámetros (Full-Duplex Bus)

Este documento formaliza el plan de ingeniería para dotar a cada herramienta de **Tunner** de **Plugs Modulares Interactivos (Entrada/Salida)** interconectados mediante **Buses de Canales Nombrables Personalizados**, con simulación tangible, intercambio reactivo bidireccional de parámetros (BPM, Tonalidad Camelot, Reproducción, Título de Pista y Flujo PCM) y preparación para compilación en un futuro lenguaje DSL/DSP de bajo nivel.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-MODULAR-PLUGS-CHANNELS-2026-0087`
- **Título:** Plugs Modulares Interactivos por Herramienta, Canales Nombrables Personalizados, Sincronización Bidireccional de Parámetros y Motor de Parcheo Escalable a Bajo Nivel
- **Fase del Proyecto:** Fase 2 (Instrumentación, Consola DJ y Estaciones de Trabajo)
- **Estado:** Aprobado para Implementación
- **ADR Relacionado:** [ADR 0077: Suite Modular de Plugs Interactivos y Buses de Canales](../04_adrs/0077_universal_studio_channel_matrix_and_inter_tool_audio_routing_suite.md)
- **Documento Funcional Base:** [Caso de Uso 87: Plugs Modulares Interactivos y Matriz de Canales](../02_use_cases/87_uc_universal_studio_channel_matrix_and_inter_tool_audio_routing_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Transformar la plataforma en un **estudio modular tangible**, donde cada herramienta dispone de puertos físicos virtuales (**Plugs** de entrada y salida de Audio, MIDI y Clock Sync). El usuario puede interconectar herramientas seleccionando o conectando plugs a **Canales Nombrables y Personalizados** (ej. "Canal A: Melodía Violín", "Canal B: Batería Rock", "Voz Principal", "Master DJ"), permitiendo:
1. **Canales Nombrables y Dinámicos:**
   - Creación ilimitada de canales por el usuario mediante un botón interactivo `[+] NUEVO CANAL`.
   - Renombrado rápido de canales existentes con sincronización inmediata.
   - Asignación de paleta de color e icono por canal.
2. **Intercambio Bidireccional de Parámetros de Reproducción (Full-Duplex Parameter Bus):**
   - Cuando una herramienta conecta su plug (de entrada o salida) a un canal, **hereda y adopta inmediatamente los parámetros de lo que se esté reproduciendo en ese canal**:
     - Título activo (`activeTrackTitle`).
     - Tempo (`activeBpm`).
     - Tonalidad armónica (`activeCamelotKey`).
     - Estado de transporte (`isPlaying` - reproduciendo / en pausa).
     - Posición de reproducción (`positionMs`).
     - Flujo de audio en tiempo real (`livePcmBuffer`).
   - Si una herramienta emisora (ej. Consola DJ Deck A o Visor de Partituras) modifica el BPM, inicia la reproducción o cambia de tema en ese canal, **todas las herramientas receptoras conectadas actualizan reactivamente sus parámetros** sin latencia perceptible (<5 ms).
3. **Interactividad Visual Inmediata (LEDs y Pulso de Señal):**
   - Cada plug cuenta con un bisel metálico industrial y un anillo LED neón que adopta el color del canal y titila al transmitir audio o eventos musicales.
   - Selector emergente directo en cada plug que lista todos los canales existentes y permite crear nuevos canales al instante.
4. **Escalabilidad a Lenguaje de Bajo Nivel (DSL/DSP Ready):**
   - La arquitectura de parches se estructura mediante opcodes e instrucciones desacopladas (`StudioPatchbayOpcode`: `CONNECT_PLUG`, `SET_GAIN`, `DISCONNECT_BUS`, `SYNC_PARAMS`), garantizando compilación nativa en C/Rust (`dart:ffi`) o una máquina virtual de audio en tiempo real.
5. **Ergonomía de Ventanas y Consola DJ Profesional:**
   - La consola DJ se renderiza en alta fidelidad responsive y completa, evitando vistas cortadas o controles sobrepuestos, e integrando la barra de canales y plugs modulares tanto en la vista modal como en el espacio de trabajo de pantalla completa.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades de dominio: `StudioChannelBus` ampliado con estado de reproducción, `StudioModularPlug`, `StudioPatchbayMatrixEntity`.
  - Capa de datos: `StudioPatchbayRoutingService` con publicación/suscripción reactiva de parámetros e inyección de audio.
  - Componentes de UI: `StudioModularPlugWidget`, `StudioChannelPatchbayBarWidget`, modales de creación y renombrado de canales (`StudioCreateChannelModal`, `StudioRenameChannelModal`).
  - Integración en `DjStudioWorkstationView` y `DjConsoleModal` con sincronización de Decks A y B.
  - Pruebas unitarias y de widgets con 100% de éxito.
- **Excluido (Out-of-Scope):**
  - Conexiones a través de red o internet (respeto estricto a Offline-First y Cero Microservicios).

---

## 2. Fundamentos de Interacción Humano-Computadora (HCI) y Ergonomía

1. **Metáfora Física Tangible (Skeuomorphic Affordance):**
   - El concepto de un cable o conector Jack enchufado a un canal es natural e intuitivo.
   - Nombrar un canal (ej. "Guitarra Acústica") permite que cualquier herramienta que se conecte a él comprenda contextualmente qué señal está procesando.
2. **Divulgación Progresiva:**
   - Nivel 1: Conexión inmediata a 1 clic desde el plug Jack con selector de canal.
   - Nivel 2: Monitoreo visual de BPM, tonalidad y transporte en la barra superior `StudioChannelPatchbayBarWidget`.
   - Nivel 3: Creación y renombrado avanzado de buses y ruteo a pedales de efectos.
3. **Retroalimentación Sensorial Continua:**
   - Si un canal está reproduciendo, su medidor VU y anillo de plug se iluminan reactivamente.
   - Las herramientas conectadas reflejan el cambio de tempo al instante sin interrupción del audio.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Ampliar `lib/core/channels/domain/studio_channel_bus.dart`:
  - Campos: `activeTrackTitle`, `activeBpm`, `activeCamelotKey`, `isPlaying`, `positionMs`, `livePcmBuffer`.
  - Métodos inmutables `copyWith`, `withPlaybackState(...)`, `withName(...)`.
- [x] Actualizar `lib/core/channels/domain/studio_patchbay_matrix_entity.dart`:
  - Soporte para agregar canales personalizados, renombrar canales y actualizar parámetros de canal.
  - Generación de opcodes DSP con soporte para sincronización de reloj y transporte.

### Paso 2: Capa de Infraestructura / Datos (Servicio de Enrutamiento In-Memory)
- [x] Actualizar `lib/core/channels/data/studio_patchbay_routing_service.dart`:
  - `createCustomChannel({required String name, int? colorHex})`.
  - `renameChannel(String channelId, String newName)`.
  - `removeCustomChannel(String channelId)`.
  - `publishChannelParameters(String channelId, {...})`: difusión inmediata a todos los plugs y herramientas conectadas.
  - Auto-sincronización: al enchufar un plug a un canal, se envían automáticamente los parámetros actuales del canal al plug receptor.

### Paso 3: Capa de Presentación (Plugs Vectoriales, Barra de Canales y Modales)
- [x] Actualizar `lib/core/channels/presentation/studio_channel_patchbay_bar_widget.dart`:
  - Botón interactivo `[+] NUEVO CANAL` con diálogo de creación.
  - Botón de renombrar canal en cada chip.
  - Píldora de estado con BPM, tonalidad y estado de reproducción.
- [x] Actualizar `lib/core/channels/presentation/studio_modular_plug_widget.dart`:
  - Listado dinámico de todos los canales (troncales y personalizados).
  - Acceso directo a `[+] Crear nuevo canal...` desde el menú del plug.
- [x] Refactorizar la experiencia de la Consola DJ (`DjStudioWorkstationView` y `DjConsoleModal`):
  - Integrar la barra de canales y los plugs modulares con publicación bidireccional de parámetros en Decks A y B.
  - Garantizar resolución adecuada sin cortes de interfaz ni botones inoperantes.

### Paso 4: Pruebas, Verificación y Build Nativo
- [x] Pruebas unitarias de creación de canales, renombrado y sincronización de parámetros en `test/core/channels/studio_patchbay_test.dart`.
- [x] `flutter analyze` con 0 errores y 0 advertencias.
- [x] Compilación y ejecución nativa en Linux (`DISPLAY=:0`).

---

## 4. Criterios de Aceptación (Definition of Done)
1. El usuario puede crear nuevos canales con nombres y colores personalizados y renombrarlos a voluntad.
2. Al conectar cualquier herramienta a un canal, esta recibe de inmediato el título, BPM, tonalidad Camelot y estado de reproducción actual de dicho canal.
3. Si la herramienta emisora modifica el tempo o estado de transporte, todas las herramientas conectadas a ese canal se actualizan en tiempo real.
4. Cero dependencias de red, 60 FPS estables y cero fugas de memoria.
