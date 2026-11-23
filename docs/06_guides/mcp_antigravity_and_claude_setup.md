# Guia de Configuracion del Servidor MCP Nativo de Tunner para Antigravity y Claude Desktop

Este documento detalla la compilacion nativa AOT, la configuracion de clientes compatibles con el **Model Context Protocol (MCP 2024-11-05)** sobre `stdio` (`stdin`/`stdout`), las banderas CLI soportadas, el puente IPC local y ejemplos reales de flujos musicales asistidos por agentes de IA.

---

## 1. Resumen de Capacidades del Servidor (`tunner-mcp-server`)

El servidor `tunner-mcp-server` se ejecuta **100% en local y offline** (Pure Dart sin dependencias de `package:flutter/` ni `dart:ui`), exponiendo la totalidad del nucleo DSP, notacion, sintesis, pedagogia y estudio de Tunner a traves de JSON-RPC 2.0:

| Categoria | Cantidad Exacta | Descripcion |
| :--- | :---: | :--- |
| Modulos de dominio registrados | **17** | Cobertura total de audio, afinador, sintesis, notacion, OMR, armonia, pedagogia, DJ/mixer, rack modular, boveda, proyectos, DSL y persistencia |
| Resources (`tunner://...`) | **71** | Estado de solo lectura del servidor (`tunner://server/status`), partitura activa, motor de audio, temperamentos, catalogo de instrumentos, bancos SF2, consola DJ y progreso pedagogico |
| Tools (`tunner_*`) | **162** | Operaciones ejecutables con validacion de esquema JSON y aislamiento estricto de rutas dentro del `--workspace` |
| Prompts guiados | **41** | Flujos musicales estructurados (composicion Grand Staff, transcripcion OMR/WAV, entrenamiento auditivo, diagnostico acustico, mezcla DJ, etc.) |
| **Total de primitivas MCP** | **274** | Registradas con validacion estricta de cero colisiones mediante `TunnerMcpBootstrap` |

---

## 2. Compilacion del Binario Nativo AOT (`build/tunner_mcp_server`)

### 2.1 Por que compilar a binario AOT

Compilar el servidor a codigo maquina nativo AOT ofrece tres ventajas criticas para clientes MCP:

1. **Arranque instantaneo (~80 ms):** sin penalizacion de compilacion JIT ni resolucion de paquetes al iniciar la sesion del agente.
2. **Canal `stdout` 100% limpio:** garantiza cero mensajes de compilacion o *build hooks* en `stdout` (todo diagnostico interno se dirige exclusivamente a `stderr`).
3. **Ejecutable autocontenido (~11 MB):** binario independiente listo para ser invocado directamente desde Antigravity o Claude Desktop.

### 2.2 Comando de compilacion (Dart SDK 3.11+)

Debido a que el proyecto Flutter padre incluye dependencias con *native build hooks* (`hooks`, `code_assets`, `objective_c`, `jni`), el subcomando clasico `dart compile exe` rechaza compilar el proyecto. Debe utilizarse `dart build cli` desde la raiz del repositorio:

```bash
/home/nicomania11/desarrollo/flutter/bin/dart build cli \
  --target=bin/tunner_mcp_server.dart \
  --output=build/mcp_aot

cp build/mcp_aot/bundle/bin/tunner_mcp_server build/tunner_mcp_server
chmod +x build/tunner_mcp_server
```

> Nota: El directorio `build/` esta excluido en `.gitignore`. El binario compilado no debe ser versionado en Git.

---

## 3. Banderas CLI Disponibles

El binario `build/tunner_mcp_server` (y el punto de entrada `bin/tunner_mcp_server.dart`) acepta las siguientes banderas:

| Bandera | Valor por defecto | Comportamiento |
| :--- | :--- | :--- |
| `--workspace=<ruta>` | Directorio actual (`cwd`) | Define la raiz de trabajo aislada (sandbox de archivos). Todas las lecturas/escrituras de WAV, MIDI, MusicXML, PDF y `.tunner` se validan estrictamente dentro de esta ruta para prevenir *path traversal* (`-32002`). |
| `--headless-only` | `false` | Fuerza operacion 100% autonoma sin intentar conexion TCP al puente IPC local. Ignora cualquier valor de `--ipc-port`. |
| `--ipc-port=<puerto>` | Deshabilitado | Puerto TCP en `127.0.0.1` (rango `1..65535`) donde escucha la interfaz grafica de Tunner Desktop (`TunnerIpcBridge`). Si la GUI no esta abierta, el servidor registra un aviso en `stderr` y degrada de forma silenciosa a modo headless sin interrumpir el servicio MCP. |

---

## 4. Configuracion en Antigravity

Edite el archivo de configuracion MCP de Antigravity (por ejemplo `~/.gemini/antigravity/mcp_config.json` o la configuracion de servidores MCP del espacio de trabajo) y agregue la entrada `tunner`.

### 4.1 Opcion Recomendada: Binario Nativo AOT

```json
{
  "mcpServers": {
    "tunner": {
      "command": "/home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/build/tunner_mcp_server",
      "args": [
        "--headless-only",
        "--workspace=/home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/mcp_workspace"
      ]
    }
  }
}
```

### 4.2 Opcion con Puente IPC en Vivo hacia Tunner Desktop

Si desea que las mutaciones de partitura (`ui.score.updated`) y proyecto (`workspace.project.updated`) se reflejen en tiempo real en Tunner Desktop cuando la GUI este escuchando en `127.0.0.1:49200`:

```json
{
  "mcpServers": {
    "tunner": {
      "command": "/home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/build/tunner_mcp_server",
      "args": [
        "--ipc-port=49200",
        "--workspace=/home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/mcp_workspace"
      ]
    }
  }
}
```

### 4.3 Alternativa de Desarrollo sin Recompilar AOT (VM Directa)

Durante ciclos rapidos de desarrollo de modulos MCP, puede invocar directamente el archivo fuente con el binario `dart`:

```json
{
  "mcpServers": {
    "tunner": {
      "command": "/home/nicomania11/desarrollo/flutter/bin/dart",
      "args": [
        "/home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/bin/tunner_mcp_server.dart",
        "--headless-only",
        "--workspace=/home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/mcp_workspace"
      ]
    }
  }
}
```

> **ADVERTENCIA CRITICA (NO USAR `dart run`):** Nunca configure `"args": ["run", "bin/tunner_mcp_server.dart", ...]`. En proyectos Flutter con *build hooks*, `dart run` imprime mensajes de progreso (`Running build hooks...`) en `stdout` antes de iniciar `main()`, lo cual corrompe el protocolo JSON-RPC 2.0 sobre `stdio` y provoca la desconexion inmediata del cliente MCP. Use siempre el binario AOT (`build/tunner_mcp_server`) o la invocacion directa `dart bin/tunner_mcp_server.dart`.

---

## 5. Configuracion en Claude Desktop

Localice el archivo `claude_desktop_config.json`:

- **Linux:** `~/.config/Claude/claude_desktop_config.json`
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

### 5.1 Opcion Recomendada: Binario Nativo AOT

```json
{
  "mcpServers": {
    "tunner": {
      "command": "/home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/build/tunner_mcp_server",
      "args": [
        "--headless-only",
        "--workspace=/home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/mcp_workspace"
      ]
    }
  }
}
```

### 5.2 Alternativa de Desarrollo (VM Directa)

```json
{
  "mcpServers": {
    "tunner": {
      "command": "/home/nicomania11/desarrollo/flutter/bin/dart",
      "args": [
        "/home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/bin/tunner_mcp_server.dart",
        "--headless-only",
        "--workspace=/home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/mcp_workspace"
      ]
    }
  }
}
```

Tras guardar el archivo, reinicie completamente Claude Desktop para que ejecute el *handshake* `initialize` y descubra los 71 Resources, 162 Tools y 41 Prompts.

---

## 6. Verificacion Rapida (Smoke Test por `stdin`/`stdout`)

Puede validar el binario compilado directamente desde la terminal antes de conectarlo a un cliente IA:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","clientInfo":{"name":"cli-check","version":"1.0.0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"tunner_server_health","arguments":{}}}' \
  | ./build/tunner_mcp_server --headless-only
```

Salida esperada:
- **`stdout`:** exactamente 2 lineas JSON-RPC 2.0 validas (`id: 1` con `protocolVersion: "2024-11-05"` e `id: 2` con `status: "ready"`, `modules: 17`, `resources: 71`, `tools: 162`, `prompts: 41`).
- **`stderr`:** linea informativa `[INFO][TunnerMcpServer] Starting tunner-mcp-server ...`.

---

## 7. Ejemplos de Prompts Musicales Reales

Una vez conectado el servidor MCP en Antigravity o Claude Desktop, puede solicitar flujos completos en lenguaje natural:

### Ejemplo 1: Composicion Grand Staff en 3/4 con Exportacion Completa y Verificacion Acustica
> "Usa Tunner para crear un vals para piano en 3/4 a 116 BPM en La menor (Grand Staff de 2 pentagramas y 8 compases). Compone melodia en la mano derecha y acompanamiento de bajo-acorde en la mano izquierda, valida la integridad metrica de todos los compases, exporta la obra a `vals_la_menor.musicxml`, `vals_la_menor.mid` (MIDI Formato 1) y `vals_la_menor.pdf`, sintetiza el audio a `vals_la_menor.wav` y verifica su contorno de afinacion con `tunner_detect_pitch_wav`."

### Ejemplo 2: Diagnostico Acustico con Temperamentos Historicos y Autotune
> "Analiza la toma vocal en `tomas/aria_barroca.wav` usando referencia A4 = 415 Hz y temperamento Werckmeister III. Genera un reporte de desviacion en cents, aplica correccion de afinacion sutil hacia una escala menor barroca y transcribe la melodia resultante a una partitura editable."

### Ejemplo 3: Preparacion de Sesion de Estudio Pedagogico y Pista Minus-One
> "Transpone la partitura activa para saxofon alto en Eb, genera una pista de acompanamiento Minus-One con metronomo en 3/4 y crea un plan de practica adaptativo basado en repeticion espaciada de Ebbinghaus exportando el informe en PDF."

### Ejemplo 4: Diseno Sonoro en Rack Modular y Mezcla DJ Automix
> "Construye un parche en el rack modular con un sintetizador polifonico conectado a reverb de convolucion y salida maestra verificando que no existan ciclos en el DAG. Carga dos pistas en los decks A y B de la consola DJ, sincroniza el BPM y renderiza una transicion Automix a `mezclas/set_demo.wav`."

---

## 8. Resolucion de Problemas

1. **Error de parseo JSON en el cliente MCP:** verifique que no esta invocando `dart run`. Use `build/tunner_mcp_server` o `dart bin/tunner_mcp_server.dart`.
2. **Error `-32002` (Security Violation):** la ruta solicitada por el agente sale del directorio configurado en `--workspace=<ruta>`. Use rutas relativas dentro del workspace.
3. **Advertencia de IPC en `stderr`:** el mensaje `No Tunner GUI IPC listener reachable on 127.0.0.1:<puerto>; continuing in headless mode` es normal cuando Tunner Desktop no esta ejecutandose y no afecta ninguna herramienta MCP.
