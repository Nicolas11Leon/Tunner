# UC-186: Orquestación Inteligente Headless Mediante Servidor MCP (Model Context Protocol)

## Metadatos del Documento

- **ID del Documento:** `DOC-USECASE-2026-186`
- **Título Oficial:** Orquestación y Conexión de Agentes de Inteligencia Artificial mediante Servidor Nativo MCP
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-11-23`
- **Última Modificación:** `2026-11-23`
- **Fase Asociada:** `Fase 5 / Épica 13`
- **Issue Relacionado:** `#186`
- **ADR Relacionado:** [ADR-0178](../04_adrs/0178_dart_native_mcp_server_and_headless_engine.md)
- **Documento de Arquitectura:** [DOC-ARCH-2026-186](../01_architecture/186_tunner_mcp_server_architecture.md)

---

## 1. Resumen Ejecutivo

Este caso de uso define la especificación operacional completa para la interacción entre clientes de Inteligencia Artificial (Antigravity, Claude Desktop, Cursor) y el motor musical Tunner a través del protocolo abierto **Model Context Protocol (MCP)** implementado en un proceso autónomo de Dart (`bin/tunner_mcp_server.dart`).

Permite a cualquier modelo de lenguaje actuar como asistente de composición, arreglista orquestal, ingeniero de mezcla y tutor de pedagogía musical, invocando herramientas de alta fidelidad acústica sin requerir que la interfaz gráfica esté en ejecución, pero sincronizándose visualmente con ella si se encuentra activa mediante sockets IPC locales.

---

## 2. Diagrama de Casos de Uso

```mermaid
flowchart TD
    subgraph Actors ["Actores del Sistema"]
        USER["Usuario / Creador Musical"]
        AI_AGENT["Agente de IA (Antigravity / Claude)"]
    end

    subgraph MCP_Boundary ["Tunner MCP Server Engine"]
        UC_INIT["UC-186.1: Inicialización y Negociación de Capacidades (initialize)"]
        UC_RES["UC-186.2: Inspección de Recursos (resources/read)"]
        UC_COMPOSE["UC-186.3: Composición y Cuantización (tools/call: compose_progression)"]
        UC_RENDER["UC-186.4: Síntesis y Render WAV/Stems (tools/call: render_score_to_wav)"]
        UC_ANALYSIS["UC-186.5: Detección Acústica y Autotune (tools/call: detect_pitch_file)"]
        UC_IO["UC-186.6: Importación y Exportación Canónica (tools/call: export_project)"]
        UC_PROMPT["UC-186.7: Ejecución de Prompts Guiados (prompts/get)"]
        UC_IPC["UC-186.8: Sincronización Opcional con Tunner Desktop (IPC Socket)"]
    end

    subgraph Tunner_Core ["Dominio Puro de Tunner"]
        SCORE_ENG["Motor de Notación SMuFL"]
        SYNTH_ENG["Síntesis SoundFont2 / Additive"]
        DSP_ENG["Algoritmos MPM / Autotune"]
        CONTAINER_ENG["Serializador Lossless .tunner"]
        GUI["Tunner Desktop GUI (OLED Shell)"]
    end

    USER -->|Instrucción en Lenguaje Natural| AI_AGENT
    AI_AGENT --> UC_INIT
    AI_AGENT --> UC_RES
    AI_AGENT --> UC_COMPOSE
    AI_AGENT --> UC_RENDER
    AI_AGENT --> UC_ANALYSIS
    AI_AGENT --> UC_IO
    AI_AGENT --> UC_PROMPT

    UC_COMPOSE --> SCORE_ENG
    UC_RENDER --> SYNTH_ENG
    UC_ANALYSIS --> DSP_ENG
    UC_IO --> CONTAINER_ENG

    UC_COMPOSE -.->|Notificación IPC| UC_IPC
    UC_IPC -.->|Refresco Visual| GUI
```

---

## 3. Diagrama de Secuencia Detallado

```mermaid
sequenceDiagram
    autonumber
    actor Usuario
    participant AgenteIA as Agente IA (Antigravity)
    participant Stdio as MCP Server (stdio)
    participant Dispatcher as Request Dispatcher
    participant Facade as TunnerHeadlessFacade
    participant Domain as Capa de Dominio (Pure Dart)
    participant GUI as Tunner Desktop (OLED UI)

    Usuario->>AgenteIA: "Crea una progresión armónica en 3/4 para piano en Do Mayor y expórtala a WAV"
    
    Note over AgenteIA, Stdio: Paso 1: Handshake e Inspección
    AgenteIA->>Stdio: JSON-RPC "initialize"
    Stdio-->>AgenteIA: Capacidades (Resources, Tools, Prompts)
    
    AgenteIA->>Stdio: JSON-RPC "resources/read" { uri: "tunner://catalog/instruments" }
    Stdio->>Dispatcher: Consultar catálogo
    Dispatcher->>Facade: getInstrumentsCatalog()
    Facade-->>Dispatcher: Lista de 40 instrumentos con tesituras
    Dispatcher-->>AgenteIA: Catálogo JSON
    
    Note over AgenteIA, Stdio: Paso 2: Ejecución de Composición Musical
    AgenteIA->>Stdio: JSON-RPC "tools/call" { name: "tunner_compose_progression", args: { key: "C_MAJOR", meter: "3/4", progression: ["I", "IV", "V", "I"], instrument: "acoustic_grand_piano" } }
    Stdio->>Dispatcher: Validar argumentos contra JSON Schema
    Dispatcher->>Facade: composeProgression(...)
    Facade->>Domain: Construir ScoreTree, compases 3/4 y notas
    Domain-->>Facade: ScoreTree generado y verificado (sub-ticks = 2880 por compás)
    Facade-->>Dispatcher: Progresión en memoria + Tunner DSL generado
    Dispatcher-->>AgenteIA: Resultado exitoso con métricas de compases y notas
    
    opt Aplicación Tunner Desktop Abierta
        Facade->>GUI: Evento IPC: "ui/refreshScore" (recargar lienzo SMuFL)
        GUI-->>Usuario: Muestra en pantalla los nuevos compases pintados a 60 FPS
    end

    Note over AgenteIA, Stdio: Paso 3: Renderizado a Audio WAV
    AgenteIA->>Stdio: JSON-RPC "tools/call" { name: "tunner_render_score_to_wav", args: { output_path: "exports/piano_progression.wav", sample_rate: 44100 } }
    Stdio->>Dispatcher: Despachar a motor de síntesis
    Dispatcher->>Facade: renderScoreToWav(...)
    Facade->>Domain: Isolate.run() -> Renderizado SoundFont2/PCM estéreo
    Domain-->>Facade: Archivo WAV generado en disco (PCM 16-bit)
    Facade-->>Dispatcher: Metadata del audio (duración, samples, tamaño bytes)
    Dispatcher-->>AgenteIA: JSON-RPC Response con confirmación
    
    AgenteIA-->>Usuario: "He compuesto la progresión en 3/4, actualizado la partitura y exportado el archivo WAV a 'exports/piano_progression.wav'."
```

---

## 4. Precondiciones, Flujos y Postcondiciones

### 4.1 Precondiciones
1. El ejecutable del servidor `tunner_mcp_server` está compilado o se ejecuta mediante el comando `dart run bin/tunner_mcp_server.dart`.
2. El cliente de IA tiene configurado el servidor en su manifiesto de configuración local (`mcpServers`).
3. El entorno de ejecución dispone de permisos de lectura y escritura en el sistema de archivos del espacio de trabajo.

### 4.2 Flujo Principal (Composición y Renderizado Headless)
1. **Inicialización:** El cliente IA abre el proceso hijo y envía el mensaje JSON-RPC `initialize`. El servidor responde con su versión y manifiesto de capacidades.
2. **Consulta de Contexto:** El cliente lee `tunner://project/active` para conocer la tonalidad, tempo y pistas actuales.
3. **Invocación de Herramientas:** El cliente solicita la ejecución de `tunner_compose_progression` pasando parámetros musicales válidos.
4. **Validación de Dominio:** El servidor valida la teoría musical (armadura válida, conducción de voces, compatibilidad métrica).
5. **Generación Determinista:** Se genera la estructura de partitura inmutable y se almacena en el estado headless activo.
6. **Sincronización IPC:** Si el socket IPC local está conectado, se emite una notificación de refresco a la GUI.
7. **Respuesta Estructurada:** El servidor retorna el resumen en texto estructurado y datos JSON con el AST musical y su representación en Tunner DSL.

### 4.3 Flujos Alternativos y Manejo de Errores
- **Argumento Acústico Inválido (Código de Error -32602):** Si la IA solicita una nota fuera del rango físico del instrumento (ejemplo: $C_1$ en un violín soprano con tesitura $G_3 - C_7$), el servidor intercepta el error, rechaza la operación sin romper el proceso y retorna un mensaje explicativo con la tesitura en Hz soportada.
- **Archivo Corrupto o No Encontrado (Código de Error -32001):** Si se solicita importar un archivo MusicXML o WAV inexistente o mal formado, el servidor responde con el código de error y detalle de la línea de parsing que falló.
- **GUI No Disponible (Comportamiento Silencioso):** Si Tunner Desktop no está encendido, el intento de conexión por socket local falla silenciosamente sin detener el servidor MCP; todo el flujo continúa en modo headless.

### 4.4 Postcondiciones
1. El estado del proyecto en memoria refleja fielmente las operaciones ejecutadas.
2. Los archivos de salida (WAV, MusicXML, PDF, contenedor `.tunner`) quedan persistidos en disco de forma atómica.
3. El proceso MCP se mantiene listo para la siguiente petición sin fugas de memoria y con cero consumo de CPU residual.
