# Auditoria Forense MCP-Readiness: Core DSL y Terminal OS Kernel (`lib/core/dsl/`, `lib/core/terminal/`)

**Fecha:** 2026-11-23  
**Alcance:** `lib/core/dsl/` (11 archivos `.dart`) y `lib/core/terminal/` (10 archivos `.dart`) — **Total: 21 archivos `.dart`**  
**Objetivo:** Evaluar la preparacion Headless Pure Dart del compilador/interprete Tunner DSL, el micro-kernel de audio y el despachador de comandos Tunner OS (`TunnerOsKernel`), y especificar su exposicion mediante Model Context Protocol (MCP).

---

## 1. Inventario Archivo por Archivo

### 1.1 `lib/core/dsl/` (11 archivos)

| Archivo | Clases / Enums Principales | Metodos / Responsabilidades Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- |
| `domain/i_synth_voice_pool_port.dart` | `DslSynthWaveform`, `ISynthVoicePoolPort` | Puerto Pure Dart para sintesis polifonica (`setDslWaveform()`, `noteOn()`, `noteOff()`, `allNotesOff()`, ADSR `attackSeconds`/`decaySeconds`/`sustainLevel`/`releaseSeconds`) | UC-105, UC-108, UC-141 |
| `domain/studio_os_audio_event.dart` | `StudioOsAudioEvent`, `StudioOsTempoEvent`, `StudioOsChannelDeclaredEvent`, `StudioOsConnectionEvent`, `StudioOsParameterEvent`, `StudioOsNoteEvent`, `StudioOsChordEvent`, `StudioOsRestEvent`, `StudioOsTransportEvent` | Jerarquia inmutable de eventos acusticos tipados con `timestampMicroseconds`, `scheduledOffsetMs` y `durationMs` | UC-108, UC-177 |
| `domain/studio_os_audio_kernel.dart` | `StudioOsAudioKernel` | Bus de eventos en proceso (`eventStream`, `eventHistory` acotado por `maxHistoryLength`) y despachadores `dispatchTempo()`, `dispatchDeclareChannel()`, `dispatchConnect()`, `dispatchSetParameter()`, `dispatchNote()`, `dispatchChord()`, `dispatchRest()`, `dispatchTransport()` | UC-108, UC-177 |
| `domain/tunner_ast_node.dart` | `TunnerAstNode`, `TunnerStatementNode`, `ProgramNode`, `TempoStatementNode`, `ChannelDeclNode`, `ConnectStatementNode`, `SetParamStatementNode`, `NoteStatementNode`, `ChordStatementNode`, `RestStatementNode`, `TransportStatementNode`, `LoopStatementNode`, `TunnerAstVisitor` | Arbol de Sintaxis Abstracta (AST) completo con patron Visitor | UC-107 |
| `domain/tunner_dsl_diagnostic.dart` | `TunnerDslDiagnosticSeverity`, `TunnerDslDiagnostic` | Diagnosticos de analisis lexico/sintactico con linea, columna y severidad (`info`, `warning`, `error`) | UC-107, UC-129 |
| `domain/tunner_dsl_interpreter.dart` | `TunnerDslExecutionContext`, `TunnerDslExecutionReport`, `TunnerDslInterpreter` | Evaluador AST Visitor no bloqueante (`interpret()` con `isDryRun`, `initialBpm`), utilidades puras `pitchToMidi()`, `midiToFrequency()`, `parseFraction()`, `calculateDurationMs()` | UC-108, UC-177 |
| `domain/tunner_dsl_lexer.dart` | `TunnerDslLexer` | Analizador lexico determinista (`tokenize()`) para notas, acordes, fracciones, unidades (`dB`, `ms`, `Hz`), identificadores `@target` y bloques `loop` | UC-107, UC-129 |
| `domain/tunner_dsl_parser.dart` | `TunnerDslParseResult`, `TunnerDslParser` | Parser recursivo descendente (`parse()`) que produce `ProgramNode` y lista de `TunnerDslDiagnostic` | UC-107, UC-129 |
| `domain/tunner_dsl_template_catalog.dart` | `TunnerDslTemplate`, `TunnerDslTemplateCatalog` | Catalogo canonico de scripts DSL (escalas, progresiones, pruebas de masterizacion, reverb y paneo binaural) | UC-115 |
| `domain/tunner_dsl_token.dart` | `TunnerDslTokenType`, `TunnerDslToken` | Definicion de tokens lexicos con posicion (linea/columna) | UC-107 |
| `infrastructure/studio_os_audio_kernel_bridge.dart` | `StudioOsAudioKernelBridge` | Enlaza callbacks del `StudioOsAudioKernel` con matriz master, reloj, sintetizador polifonico, reverb y panner binaural; gestiona temporizadores programados (`_activeNoteTimers`) y `dispose()` | UC-108, UC-177 |

### 1.2 `lib/core/terminal/` (10 archivos)

| Archivo | Clases / Contratos Principales | Metodos / Dominios Clave | Casos de Uso Asociados |
| :--- | :--- | :--- | :--- |
| `domain/i_terminal_command_handler.dart` | `ITerminalCommandHandler` | Contrato `supportedDomains` y `execute(domain, args, rawCommandLine)` | UC-124, UC-180 |
| `domain/i_terminal_feature_ports.dart` | `ITerminalScorePort`, `ITerminalProjectPort`, `TerminalEarTrainingItemSnapshot`, `TerminalEarTrainingSubmitSnapshot`, `ITerminalEarTrainingPort`, `TerminalVocalEvalSnapshot`, `ITerminalVocalPedagogyPort`, `terminalNoteNameToMidi()` | Puertos Pure Dart que desacoplan el kernel de terminal de `lib/features/` (Score, Project, Ear Training Ebbinghaus, Evaluacion Vocal + PDF) | UC-112, UC-113, UC-141, UC-180 |
| `domain/tunner_os_command_entity.dart` | `TunnerOsCommandResult`, `TunnerOsCommandHistoryItem` | Resultado inmutable (`isSuccess`, `output`, `clearConsole`) e historial de comandos | UC-101, UC-109 |
| `application/tunner_os_kernel.dart` | `TunnerOsKernel` | Despachador $O(1)$ de comandos CLI por dominio (`execute()`, `registerHandler()`, `registeredDomains`, `dispose()`), integra `TunnerDslParser`, `TunnerDslInterpreter`, `StudioOsAudioKernel` y `StudioOsAudioKernelBridge` | UC-101, UC-109, UC-124, UC-180 |
| `application/handlers/audio_dsp_command_handler.dart` | `AudioDspCommandHandler` | Dominios: `io`, `dsp`, `master`, `eq`, `comp`, `route`, `clock`, `reverb`, `spatial` | UC-102, UC-103, UC-104, UC-110, UC-111, UC-119, UC-180 |
| `application/handlers/dj_media_command_handler.dart` | `DjMediaCommandHandler` | Dominios: `dj`, `synth`, `score` | UC-083, UC-105, UC-180 |
| `application/handlers/fs_workspace_command_handler.dart` | `FsWorkspaceCommandHandler` | Dominios: `fs`, `project`, `train`, `vocal`, `dsl`, `eval` | UC-101, UC-106, UC-108, UC-112, UC-113, UC-115, UC-180 |
| `application/handlers/nav_theme_command_handler.dart` | `NavThemeCommandHandler` | Dominios: `help`, `tuner`, `theme`, `clear` | UC-101, UC-109, UC-137 |
| `presentation/studio_dsl_terminal_panel_widget.dart` | `StudioDslTerminalPanelWidget` | Panel REPL interactivo Flutter para edicion y ejecucion de Tunner DSL | UC-109 |
| `presentation/tunner_os_terminal_drawer.dart` | `TunnerOsTerminalDrawer` | Drawer inferior Flutter de la terminal Tunner OS con historial y autocompletado | UC-101, UC-109 |

---

## 2. Auditoria de Brechas (Gaps) y Preparacion Headless (MCP-Readiness)

### 2.1 Acoplamientos Transitivos con `package:flutter/` (Violaciones de DIP)

Aunque ningun archivo de `lib/core/dsl/domain/`, `lib/core/terminal/domain/` ni `lib/core/terminal/application/` importa `package:flutter/` directamente, **la ejecucion en Pure Dart CLI esta BLOQUEADA transitivamente** por 4 archivos que dependen de clases concretas de infraestructura de audio en lugar de sus interfaces de dominio:

1. **`lib/core/dsl/infrastructure/studio_os_audio_kernel_bridge.dart` (CRITICO):**
   - Importa los concretos `StudioAudioDeviceMatrixService` y `StudioMasterClockService` (ambos extienden `ChangeNotifier` de `package:flutter/foundation.dart`).
   - **Solucion:** Cambiar los tipos de campo/constructor a `IStudioAudioDeviceMatrixService?` e `IStudioMasterClockService?`.
2. **`lib/core/terminal/application/tunner_os_kernel.dart` (CRITICO):**
   - Importa los concretos `StudioAudioDeviceMatrixService`, `StudioMasterClockService` y `NativeDspFfiBridge` (que actualmente importa `kIsWeb` de `package:flutter/foundation.dart`).
   - Ademas, en el constructor instancia por defecto `NativeDspFfiBridge()` si no se inyecta `nativeDspBridge`.
3. **`lib/core/terminal/application/handlers/audio_dsp_command_handler.dart` (CRITICO):**
   - Importa los concretos `StudioAudioDeviceMatrixService` y `StudioMasterClockService`.
4. **`lib/core/terminal/application/handlers/fs_workspace_command_handler.dart` (CRITICO):**
   - Importa el concreto `StudioAudioDeviceMatrixService`.

### 2.2 Brechas Funcionales, Seguridad de Ejecucion IA y Concurrencia

1. **Riesgo de explosion exponencial de sentencias/timers en bucles DSL anidados (SEGURIDAD / DoS):**
   - En `TunnerDslInterpreter.visitLoop()`, cada `loop` individual limita `node.count.clamp(1, 1000)`, pero **no existe un presupuesto global maximo de sentencias (`maxStatements`) ni profundidad maxima de anidamiento (`maxLoopDepth`)**.
   - Un agente IA que genere `loop 500 { loop 500 { note C4 1/16 } }` intentara despachar 250,000 eventos y crear 250,000 `Timer` en `StudioOsAudioKernelBridge._activeNoteTimers`, degradando o colgando el proceso del servidor MCP.
2. **Falta de serializacion JSON nativa en el AST, diagnosticos y eventos del Kernel:**
   - `TunnerDslDiagnostic`, `TunnerDslExecutionReport`, `StudioOsAudioEvent` (y sus 8 subclases) y `TunnerDslTemplate` no implementan `toJson()`. Para exponer reportes estructurados a clientes MCP sin parsear texto plano, se requiere serializacion JSON canonica.
3. **Salida de `TunnerOsKernel.execute()` orientada a texto humano (`String output`):**
   - `TunnerOsCommandResult` solo expone `bool isSuccess`, `String output` y `bool clearConsole`. Los agentes IA se benefician significativamente de un campo opcional `Map<String, dynamic>? data` junto al texto legible para evitar parsing fragil con regex.
4. **Temporizadores activos en `StudioOsAudioKernelBridge` sin cancelacion por comando MCP:**
   - `StudioOsAudioKernelBridge` mantiene `_activeNoteTimers`, pero aunque `dispose()` los cancela, no existe un metodo publico `cancelAllScheduledTimers()` / `panicStop()` para detener la reproduccion de un script DSL en curso sin destruir el bridge completo.
5. **Validacion de rutas y comandos de UI en modo Headless:**
   - En `NavThemeCommandHandler`, los comandos `tuner` (navegacion de pestanas) y `theme` invocan callbacks `onNavigateTab` / `onSetTheme`. En modo Headless puro sin cliente Flutter conectado, estos callbacks son `null` y deben emitir eventos IPC o informar claramente si no hay cliente grafico adjunto.

---

## 3. Especificacion de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripcion | Estructura JSON |
| :--- | :--- | :--- |
| `tunner://dsl/templates` | Catalogo completo de scripts canonicos de Tunner DSL listos para ejecutar o usar como referencia sintactica. | `{ "templates": [ { "id": "...", "name": "...", "category": "...", "description": "...", "sourceCode": "..." } ] }` |
| `tunner://dsl/grammar` | Resumen estructurado de la gramatica Tunner DSL soportada por `TunnerDslLexer` y `TunnerDslParser` (palabras clave, formatos de nota/solfeo, fracciones, objetivos `@master`, `@eq`, `@comp`, `@synth`, `@reverb`, `@spatial`). | `{ "statements": ["tempo", "channel", "connect", "set", "note", "chord", "rest", "play|pause|stop", "loop"], "targets": [...], "pitchFormats": ["C4", "F#5", "Do4", "Sol#4"] }` |
| `tunner://kernel/events` | Ultimos eventos acusticos despachados por `StudioOsAudioKernel.eventHistory` (hasta `maxHistoryLength`). | `{ "count": 42, "events": [ { "type": "note|chord|tempo|param|connect|channel|rest|transport", "timestampMicroseconds": 0, "payload": { ... } } ] }` |
| `tunner://terminal/domains` | Lista de dominios de comandos registrados dinamicamente en `TunnerOsKernel.registeredDomains` y estado de puertos conectados. | `{ "domains": ["io", "dsp", "master", "eq", "comp", "route", "clock", "reverb", "spatial", "fs", "project", "train", "vocal", "dsl", "eval", "dj", "synth", "score", "help", "tuner", "theme", "clear"], "attachedPorts": { "fileSystem": true, "matrix": true, "clock": true, "synth": false, "score": false } }` |

### 3.2 Tools (`tunner_*`)

| Tool Name | Parametros (JSON Schema Resumido) | Salida | Mapeo Exacto en Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_dsl_validate` | `{ sourceCode: string }` | `{ isValid: boolean, statementCount: int, diagnostics: [ { severity, message, line, column } ] }` | `TunnerDslParser.parse(sourceCode)` |
| `tunner_dsl_execute` | `{ sourceCode: string, dryRun?: boolean (default false), initialBpm?: number (20..300) }` | `{ isSuccess, totalStatementsExecuted, executionTimeMicroseconds, totalScheduledDurationMs, warnings, diagnostics, generatedEventsCount, activeScheduledTimers }` | `TunnerDslParser.parse()` + `TunnerDslInterpreter.interpret(program, isDryRun, initialBpm)` |
| `tunner_dsl_stop_scheduled` | `{}` | `{ cancelledTimers: int, status: "stopped" }` | `StudioOsAudioKernelBridge.cancelAllScheduled()` (a implementar) + `StudioOsAudioKernel.dispatchTransport('stop')` |
| `tunner_dsl_pitch_math` | `{ pitch?: string, midiNote?: int (0..127), referencePitchHz?: number (default 440.0), fraction?: string, bpm?: number (default 120.0) }` | `{ midiNote, frequencyHz, durationMs? }` | `TunnerDslInterpreter.pitchToMidi()`, `midiToFrequency()`, `calculateDurationMs()` |
| `tunner_os_execute` | `{ commandLine: string }` | `{ isSuccess: boolean, output: string, clearConsole: boolean, data?: object }` | `TunnerOsKernel.execute(commandLine)` |
| `tunner_kernel_clear_history` | `{}` | `{ cleared: true }` | `StudioOsAudioKernel.clearHistory()` |

### 3.3 Prompts Guiados para Agentes IA

1. **`tunner_dsl_compose_and_verify`**: Instruye al agente a leer `tunner://dsl/grammar` y `tunner://dsl/templates`, redactar un script Tunner DSL musicalmente valido, validarlo primero con `tunner_dsl_validate`, simularlo con `tunner_dsl_execute(dryRun: true)` para verificar duracion total y cero advertencias, y solo entonces ejecutarlo en vivo.
2. **`tunner_os_cli_workflow`**: Guia al agente a inspeccionar `tunner://terminal/domains` y encadenar comandos de `TunnerOsKernel` (`master`, `eq`, `reverb`, `clock`, `fs`, `project`) con verificacion post-ejecucion.

---

## 4. Plan de Ajustes Tecnicos Previos (Pre-MCP Hardening)

1. **Corregir inversion de dependencias (DIP) hacia interfaces Pure Dart (Prioridad S0):**
   - En `StudioOsAudioKernelBridge`, `TunnerOsKernel`, `AudioDspCommandHandler` y `FsWorkspaceCommandHandler`: reemplazar toda referencia a los concretos `StudioAudioDeviceMatrixService` y `StudioMasterClockService` por `IStudioAudioDeviceMatrixService` e `IStudioMasterClockService`.
   - En `TunnerOsKernel`: desacoplar la instanciacion directa de `NativeDspFfiBridge` una vez limpiado el import de `kIsWeb`, o aceptar fabrica inyectada con fallback `NativeDspBridgeFallback()`.
2. **Guardias anti-DoS en `TunnerDslInterpreter` (Prioridad S0):**
   - Incorporar `maxStatements` (ej. default `10000`) y `maxLoopDepth` (ej. default `8`) en `TunnerDslExecutionContext`. Si un script generado por IA supera el limite, abortar deterministicamente con diagnostico/warning claro sin bloquear el event loop ni saturar memoria.
3. **Control de ciclo de vida de timers programados en `StudioOsAudioKernelBridge` (Prioridad S1):**
   - Exponer metodo `int cancelAllScheduledTimers()` que cancele `_activeNoteTimers` y llame `synthVoicePool?.allNotesOff()` sin marcar `_isDisposed = true`, habilitando el tool `tunner_dsl_stop_scheduled`.
4. **Serializacion JSON canonica (Prioridad S1):**
   - Agregar `Map<String, dynamic> toJson()` a `TunnerDslDiagnostic`, `TunnerDslExecutionReport`, `StudioOsAudioEvent` (y subclases) y `TunnerDslTemplate`.
   - Extender `TunnerOsCommandResult` con campo opcional `final Map<String, dynamic>? structuredData` manteniendo retrocompatibilidad total con la terminal UI actual.
5. **Puente IPC para comandos UI (`nav`/`theme`) en modo Headless (Prioridad S2):**
   - Conectar los callbacks `onNavigateTab` y `onSetTheme` de `TunnerOsKernel` a un emisor de eventos IPC (`ui.navigation.tab_changed`, `ui.theme.changed`) cuando el servidor MCP corra en paralelo con la aplicacion Flutter de escritorio.
