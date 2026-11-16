# ADR 0077: Matriz Universal de Canales de Estudio y Enrutamiento Inter-Herramientas (Score-to-DJ-to-DSP)

## Estado
Aprobado

## Contexto
El usuario requiere un ecosistema integrado donde las herramientas individuales de la plataforma (reproductor de partituras/notación, consola DJ profesional, sintetizador Soundfont, afinador de precisión y bóveda de audio) no funcionen como silos aislados, sino que puedan conectarse entre sí a través de un **sistema canónico de canales de audio y eventos**.

El desafío de diseño radica en dos factores críticos:
1. **Velocidad y Rendimiento Técnico:** La interconexión debe operar con latencia imperceptible (<10ms) en memoria local, sin dependencias de red ni sobrecarga en el hilo principal de Flutter.
2. **Ergonomía Cognitiva y Facilidad de Uso:** Las matrices de enrutamiento convencionales de DAWs de escritorio abruman al estudiante con cientos de opciones de buses y ruteos pre/post. Se requiere un modelo basado en **Divulgación Progresiva (Progressive Disclosure)** y **Reducción de Carga Cognitiva Extraña (Cognitive Load Theory)** que permita asignar fuentes a destinos con un solo clic o arrastrar-y-soltar.

## Decisión
Se implementa una arquitectura desacoplada basada en Clean Architecture e In-Process Event Bus:
1. **Capa de Dominio (`lib/core/channels/domain`):**
   - `StudioChannelEntity`: Entidad inmutable que representa un canal de audio/evento con identificador único, nombre, color temático, fuente asignada (`ChannelSourceType`: Partitura, MIDI, WAV, Micrófono, Sintetizador SF2), destino de enrutamiento (`ChannelDestinationType`: Master, DjDeckA, DjDeckB, StrobeTuner, Autotune, StemProcessor), ganancia, balance estéreo, mute y solo.
   - `StudioChannelMatrixState`: Colección inmutable de canales y topología de conexiones activas.
2. **Capa de Datos / Infraestructura (`lib/core/channels/data`):**
   - `StudioChannelRoutingBus`: Bus de orquestación en memoria local (offline-first). Convierte y transfiere búferes de audio o eventos sintetizados de partituras directamente hacia los reproductores de la Consola DJ (`DjConsoleViewModel`), sincronizando automáticamente metadatos de BPM y clave armónica Camelot.
3. **Capa de Presentación (`lib/core/channels/presentation`):**
   - Controles atómicos de canal: `StudioChannelStripWidget` con faders verticales, medidores de nivel estéreo, botones de silencio/solo y menús de asignación rápida ("1-Click Routing").
   - Integración directa en la Consola DJ y el Visor de Partituras para permitir cargar cualquier composición musical directamente en Deck A o Deck B como una pista de reproducción en vivo.

## Consecuencias

### Positivas
- Interoperabilidad total entre el mundo de la notación musical tradicional (partituras) y el mundo de la producción moderna/DJ.
- Experiencia de usuario limpia y pedagógica: el usuario solo interactúa con el canal que le interesa sin navegar laberintos de configuración.
- Máximo rendimiento: cero serializaciones pesadas sobre la red, uso de búferes `Float32List` nativos y 60 FPS estables.
- Cero microservicios y funcionamiento 100% desconectado (Offline-First).

### Negativas / Mitigaciones
- Gestión del ciclo de vida de los búferes de sintetizador: se mitiga liberando automáticamente la memoria de pistas inactivas y utilizando referencias eficientes en Dart.
