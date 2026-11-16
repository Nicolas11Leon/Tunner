# ADR 0077: Suite Modular de Plugs Interactivos, Canales de Parcheo (A, B, C, D) y Enrutamiento Inter-Herramientas

## Estado
Aprobado

## Contexto
El usuario ha definido una visión clara y tangible para la interconexión de herramientas en **Tunner**:
1. En lugar de tablas de configuración abstractas, cada herramienta (Consola DJ, Partituras, Sintetizador Soundfont, Afinador, Grabador de tomas) debe exponer **Plugs modulares interactivos** (como conectores Jack 1/4" físicos virtuales).
2. Los plugs se interconectan mediante un sistema troncal de canales (**Canal A, Canal B, Canal C, Canal D**), simulando una verdadera consola de audio modular con sincronización reactiva en tiempo real.
3. El diseño debe ser atomizado, visualmente responsivo (LEDs neón por canal) y **arquitectónicamente escalable para permitir en el futuro la ejecución mediante un lenguaje de bajo nivel o máquina virtual DSP nativa (`dart:ffi` en C/Rust)** sin reescribir la interfaz de usuario.

## Decisión
Se implementa una arquitectura modular limpia e in-process:
1. **Capa de Dominio (`lib/core/channels/domain`):**
   - `StudioPlugType`: Enumeración de tipos de puerto (`audioInput`, `audioOutput`, `midiInput`, `midiOutput`, `clockSyncInput`, `clockSyncOutput`).
   - `StudioModularPlug`: Entidad inmutable que representa un puerto Jack interactivo con identificación única, herramienta propietaria, dirección de flujo, canal asignado y estado de señal activa.
   - `StudioChannelBus`: Modelo de canal troncal (Canales A, B, C, D) con color hexadecimal, nombre, ganancia, mute y listas de plugs emisores y receptores.
   - `StudioPatchbayMatrixEntity`: Matriz global inmutable de parcheo. Incluye el método `toDspOpcodeSequence()` que genera un flujo de instrucciones de bajo nivel (`StudioDspInstruction`), garantizando que la topología de ruteo pueda ser compilada y ejecutada en un futuro motor C++/Rust o compilador JIT/AOT.
2. **Capa de Datos e Infraestructura (`lib/core/channels/data`):**
   - `StudioPatchbayRoutingService`: Orquestador de parcheo in-memory offline-first. Despacha búferes de audio `Float32List` y eventos MIDI entre plugs conectados al mismo canal con latencia sub-5ms y cero duplicación innecesaria en memoria.
3. **Capa de Presentación (`lib/core/channels/presentation`):**
   - `StudioModularPlugWidget`: Componente visual táctil con bisel metálico skeuomórfico, aro LED reactivo al color del canal (Cian, Ámbar, Esmeralda, Púrpura) y menú de 1 clic para conmutar canal o desconectar.
   - `StudioChannelPatchbayBarWidget`: Barra superior horizontal que expone los faders, vúmetros y estados de los 4 canales A, B, C, D.
   - Integración nativa en `DjStudioWorkstationView` (plugs `[IN A]`, `[IN B]`, `[OUT MASTER]`) y en el visor de partituras/melodías (`[OUT MELODÍA]`).

## Consecuencias

### Positivas
- Facilidad de uso e intuitividad instantánea: la metáfora física de enchufar un plug a un canal es universalmente entendida por cualquier músico o aficionado.
- Totalmente preparado para escalar a un lenguaje de bajo nivel (DSL/DSP) gracias a la separación estricta mediante opcodes en la entidad de dominio.
- Latencia sub-5ms en memoria local, respetando el principio Offline-First y la regla de Cero Microservicios de Tunner.
- Renderizado desacoplado a 60/120 FPS con microanimaciones e iluminación neón reactiva.

### Negativas / Mitigaciones
- Necesidad de coordinar el ciclo de vida de los búferes de audio entre herramientas: se mitiga mediante buffers de anillo circulares (ring buffers) inmutables y recolección de memoria determinista.
