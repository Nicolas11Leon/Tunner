# ADR 0077: Suite Modular de Plugs Interactivos, Canales Nombrables Personalizados y Sincronización Bidireccional de Parámetros (Full-Duplex Bus)

## Estado
Aprobado

## Contexto
El usuario ha definido una visión clara y tangible para la interconexión de herramientas en **Tunner**:
1. En lugar de tablas de configuración abstractas, cada herramienta (Consola DJ, Partituras, Sintetizador Soundfont, Afinador, Grabador de tomas) debe exponer **Plugs modulares interactivos** (como conectores Jack 1/4" físicos virtuales).
2. Los plugs se interconectan mediante un sistema troncal de **Canales Nombrables y Dinámicos**, donde el usuario puede no solo utilizar los canales predeterminados (Canal A, Canal B, Canal C, Canal D) sino también **crear canales ilimitados con nombres semánticos personalizados** (ej. "Voz Principal", "Batería Rock", "Melodía Violín", "Master DJ"), con código corto y paleta de color propia.
3. El canal actúa como un **Bus Full-Duplex de Parámetros y Flujo de Audio**: cualquier herramienta conectada (ya sea como entrada o salida) **recibe e intercambia en tiempo real los parámetros de reproducción del canal**:
   - Título de la pista o fragmento sonando.
   - Tempo en BPM.
   - Tonalidad armónica (Camelot Key / Notación musical).
   - Estado de transporte (`isPlaying` - reproduciendo / pausado).
   - Posición de reproducción (`positionMs`).
   - Ganancia y búfer de audio PCM en tiempo real.
4. El diseño debe ser atomizado, visualmente responsivo (LEDs neón por canal) y **arquitectónicamente escalable para permitir en el futuro la ejecución mediante un lenguaje de bajo nivel o máquina virtual DSP nativa (`dart:ffi` en C/Rust)** sin reescribir la interfaz de usuario.

## Decisión
Se implementa una arquitectura modular limpia e in-process:
1. **Capa de Dominio (`lib/core/channels/domain`):**
   - `StudioPlugType`: Enumeración de tipos de puerto (`audioInput`, `audioOutput`, `midiInput`, `midiOutput`, `clockSyncInput`, `clockSyncOutput`).
   - `StudioModularPlug`: Entidad inmutable que representa un puerto Jack interactivo con identificación única, herramienta propietaria, dirección de flujo, canal asignado y estado de señal activa.
   - `StudioChannelBus`: Modelo de canal dinámico y nombrable. Almacena metadatos (nombre, código corto, color) y estado reactivo de reproducción (`activeTrackTitle`, `activeBpm`, `activeCamelotKey`, `isPlaying`, `positionMs`, `gain`, `livePcmBuffer`).
   - `StudioPatchbayMatrixEntity`: Matriz global inmutable de parcheo con soporte para alta, baja y renombrado dinámico de canales. Incluye `toDspOpcodeSequence()` que genera un flujo de instrucciones de bajo nivel (`StudioDspInstruction`), garantizando que la topología de ruteo pueda ser compilada y ejecutada en un futuro motor C++/Rust o compilador JIT/AOT.
2. **Capa de Datos e Infraestructura (`lib/core/channels/data`):**
   - `StudioPatchbayRoutingService`: Orquestador de parcheo in-memory offline-first. Gestiona suscripciones de plugs y canales, despacha búferes de audio `Float32List`, eventos MIDI y cambios de parámetros en tiempo real (<5ms de latencia) a todos los nodos conectados.
   - Auto-sincronización instantánea: en el momento exacto en que un plug se conecta a un canal, el servicio le entrega inmediatamente el estado de reproducción completo del canal.
3. **Capa de Presentación (`lib/core/channels/presentation`):**
   - `StudioModularPlugWidget`: Componente visual táctil con bisel metálico skeuomórfico, aro LED reactivo al color del canal y selector emergente para elegir entre todos los canales o crear uno nuevo.
   - `StudioChannelPatchbayBarWidget`: Barra superior horizontal que expone todos los canales (faders, vúmetros, BPM en vivo, estado de reproducción), botón `[+] NUEVO CANAL` y diálogo para renombrar.
   - Integración nativa en `DjStudioWorkstationView` y `DjConsoleModal` (plugs `[IN A]`, `[IN B]`, `[OUT MASTER]`) con sincronización bidireccional de parámetros y renderizado completo sin recortes.

## Consecuencias

### Positivas
- Facilidad de uso e intuitividad instantánea: nombrar canales y conectar plugs replica fielmente un entorno de estudio físico profesional.
- Sincronización transparente de parámetros: cualquier cambio de tempo o pista se propaga de forma reactiva e inmediata a todas las herramientas interconectadas.
- Totalmente preparado para escalar a un lenguaje de bajo nivel (DSL/DSP) gracias a la separación estricta mediante opcodes en la entidad de dominio.
- Latencia sub-5ms en memoria local, respetando el principio Offline-First y la regla de Cero Microservicios de Tunner.

### Negativas / Mitigaciones
- Necesidad de coordinar el ciclo de vida de los búferes de audio entre herramientas: se mitiga mediante buffers de anillo circulares (ring buffers) inmutables y recolección de memoria determinista.
