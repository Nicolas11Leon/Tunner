# ADR-0178: Servidor Nativo MCP en Dart y Motor Headless de Orquestación

- **Estado:** Aprobado
- **Fecha:** 2026-11-23
- **Contexto / Issue:** Épica 13 (#186)
- **Caso de Uso Asociado:** [UC-186](../02_use_cases/186_uc_tunner_mcp_server_orchestration.md)
- **Documento de Arquitectura:** [DOC-ARCH-2026-186](../01_architecture/186_tunner_mcp_server_architecture.md)

---

## 1. Contexto

La visión de Tunner incluye transformar la plataforma en un ecosistema profesional de creación musical guiada por Inteligencia Artificial. Se requiere que cualquier agente de IA (como Antigravity, Claude Desktop o Cursor) pueda conectarse a Tunner de forma local, gratuita, ligera y segura para componer canciones, armonizar melodías, transcribir audio, analizar acústica, procesar efectos DSP y renderizar partituras/stems con precisión hiperprofesional.

Para lograr esta integración con LLMs existían tres enfoques arquitectónicos posibles:
1. **Sidecar o Wrapper en Python:** Implementar un servidor FastMCP en Python que invoque un ejecutable o API REST.
2. **Servicio Web / Microservicio REST o gRPC:** Levantar un servidor HTTP dentro o fuera de la aplicación.
3. **Servidor Nativo en Dart sobre `stdio` (JSON-RPC 2.0):** Implementar el servidor MCP directamente en Dart (`bin/tunner_mcp_server.dart`), reutilizando de forma directa e in-process las entidades y motores de la capa de dominio puro (`lib/domain`).

---

## 2. Decisión

Se adopta la **Opción 3: Servidor Nativo en Dart sobre `stdio` con Fachada Headless Unificada (`TunnerHeadlessFacade`)**:

1. **Cumplimiento Estricto de la Constitución (`AGENTS.md`):**
   - **Zero Microservices Rule:** Prohibidos servidores HTTP externos, microservicios distribuidos o llamadas de red innecesarias. El transporte oficial del protocolo MCP es `stdio` mediante streams de entrada/salida estándar (`stdin` y `stdout`).
   - **Clean Architecture Pura:** El servidor en `bin/` consume directamente la lógica de dominio puro (`lib/features/.../domain`), sin arrancar el pipeline de widgets de Flutter ni dependencias gráficas, garantizando tiempos de arranque inferiores a $120\text{ ms}$ y consumo de memoria inferior a $65\text{ MB}$.
   - **No Python Bridge:** Evita dependencias de entorno externo (pip, virtualenvs, versiones de python) en la máquina del usuario final. Un único SDK de Dart o un binario compilado AOT (`dart compile exe`) gestiona todo.

2. **Diseño de Primitivos Canónicos:**
   - **Resources (`tunner://...`):** Exposición de solo lectura del estado musical, árbol de partituras, catálogo de 40 instrumentos, afinaciones históricas y sintaxis de Tunner DSL.
   - **Tools:** Catálogo de 19 herramientas atómicas con esquemas JSON de entrada/salida tipados para composición, transcripción, síntesis SoundFont2, cuantización, DSP, exportación canónica y análisis de DJ.
   - **Prompts:** Plantillas de orquestación pedagógica y compositiva para guiar a la IA en flujos de trabajo multi-paso.

3. **Fachada Headless Unificada (`TunnerHeadlessFacade`):**
   - Se crea una fachada de dominio que encapsula los repositorios, motores de audio/síntesis en Isolates y parsers universales.
   - La fachada ofrece métodos asíncronos y síncronos con validación acústica estricta (rango de Hz, consistencia de compás, duración de notas en sub-ticks).

4. **Puente Opcional de Sockets Locales (`TunnerIpcBridge`):**
   - Si la aplicación de escritorio Tunner (GUI) está abierta, el servidor MCP puede emitir eventos mediante un socket IPC local para que la UI refresque la partitura, el reproductor o la consola en vivo frente a los ojos del usuario.
   - Si la GUI está cerrada, el servidor funciona de forma 100% autónoma procesando directamente archivos de proyecto en disco.

---

## 3. Consecuencias

### Positivas
- **Máximo Rendimiento y Cero Fricción:** Reutilización directa del código existente de Tunner (108.000+ LOC) sin duplicar lógica en otro lenguaje.
- **Portabilidad Absoluta:** Funciona en Linux, macOS y Windows sin requerir dependencias externas de runtime adicionales a Dart.
- **Seguridad y Privacidad:** Todo el procesamiento ocurre de forma local y offline. Ningún dato ni audio viaja a servidores de terceros.
- **Compatibilidad Universal:** Compatible de inmediato con el protocolo MCP soportado nativamente por Antigravity y Claude Desktop.

### Trade-offs y Mitigaciones
- **Desacoplamiento Gráfico:** El servidor MCP no puede invocar widgets de Flutter ni plugins que dependan exclusivamente del binding gráfico (`flutter/services.dart`).
  - *Mitigación:* Se implementan abstracciones de gateway (`IPlatformFileGateway`, `ISoundFontGateway`) para que el servidor use implementaciones basadas en `dart:io` puro mientras la UI usa los plugins de Flutter.
- **Aislamiento de Logs:** Cualquier `print` accidental rompería el protocolo JSON-RPC en `stdout`.
  - *Mitigación:* Se redirige todo el log interno a `stderr` mediante `TunnerMcpLogger`.

---

## 4. Referencias
- *Model Context Protocol Specification (Anthropic / Open Standard).*
- *JSON-RPC 2.0 Specification.*
- *Tunner Architecture Constitution (`AGENTS.md`).*
- [DOC-ARCH-2026-186: Arquitectura de Tunner MCP Server](../01_architecture/186_tunner_mcp_server_architecture.md).
