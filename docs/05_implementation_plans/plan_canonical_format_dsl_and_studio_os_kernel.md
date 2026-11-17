# Plan de Implementación: Formato Canónico (.tunner), DSL Musical y Kernel Studio OS

Este documento formaliza la arquitectura mayor, el diseño de especificación y el cronograma técnico para transformar a **Tunner** en un Entorno Operativo Musical Integral (Studio OS) dotado de un Formato Canónico Universal de Paquete (`.tunner`), un Lenguaje Específico de Dominio (Tunner DSL) y un Micro-Kernel de Audio en Proceso.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-HORIZON-STUDIO-OS-DSL-2026-094`
- **Título de la Implementación:** Formato Canónico (.tunner), Lenguaje de Dominio Específico (DSL) y Micro-Kernel Studio OS
- **Fase del Proyecto:** Fase 4 (Horizonte de Escalabilidad y Ecosistema de Plataforma)
- **Estado:** Propuesto
- **ADR Relacionado:** [ADR 0084: docs/04_adrs/0084_canonical_format_dsl_and_studio_os_kernel.md](docs/04_adrs/0084_canonical_format_dsl_and_studio_os_kernel.md)
- **Documento Funcional Base:** [Caso de Uso 94: docs/02_use_cases/94_uc_canonical_format_dsl_and_studio_os_kernel.md](docs/02_use_cases/94_uc_canonical_format_dsl_and_studio_os_kernel.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Evolucionar la base modular de Tunner hacia una plataforma autónoma y unificada capaz de:
1. Empaquetar y desempaquetar proyectos completos en un contenedor canónico binario/comprimido (`.tunner`), garantizando portabilidad multiplataforma 100% *Offline First* sin pérdida de fidelidad.
2. Interpretar y ejecutar código musical declarativo y procedural mediante un motor DSL (Tunner DSL) con soporte de programación en vivo (Live Coding), macros y automatización de parámetros.
3. Orquestar herramientas, plugins internos y streams de audio a través de un Micro-Kernel en proceso con distribución de ticks y paso de buffers por referencia en memoria compartida.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - **Especificación y Compresor del Contenedor `.tunner`:** Motor de serialización jerárquica (manifiesto, matriz de parcheo, partituras MusicXML, stems WAV, parches de instrumentos y blueprints DJ).
  - **Motor de Léxico, Parser y AST del Tunner DSL:** Gramática formal para definición de canales, pistas, notas polifónicas, envolventes y enrutamiento acústico.
  - **Micro-Kernel de Audio Scheduler:** Planificador de eventos acústicos en tiempo real con latencia determinista $\le 10\text{ ms}$.
  - **Terminal / Consola de Scripting Interactiva:** Ventana de consola interactiva integrada en el dock para ingresar comandos DSL y evaluar expresiones en tiempo real.
- **Excluido (Out-of-Scope):**
  - Protocolos de red remota o almacenamiento en nube pública (se preserva la soberanía local y privacidad del usuario).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.x` con uso de `dart:typed_data`, `dart:io` y soporte de FFI nativo (`dart:ffi`) para llamadas de memoria compartida si se requiere enlace C/Rust.
- **Formato Contenedor:** Algoritmo de compresión estándar `archive` (DEFLATE / ZIP 64-bit) libre de dependencias propietarias, asegurando que cualquier descompresor del sistema operativo pueda auditar el contenido.
- **Parser de DSL:** Arquitectura de análisis léxico (Lexer) y sintáctico descendente recursivo (Recursive Descent Parser) implementado en Dart puro sin librerías externas para máxima velocidad y determinismo.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Especificación y Capa de Dominio del Formato `.tunner`
- [ ] Definición del manifiesto canónico (`TunnerProjectManifestEntity`) y su esquema JSON formal (versión semántica, autor, tempo, firmas de tiempo, hashes de integridad).
- [ ] Especificación de la estructura de directorios interna del paquete (`/notation`, `/audio_vault`, `/instruments`, `/dj_workstation`, `/routing_matrix`).
- [ ] Implementación de interfaces abstractas `ITunnerPackageCodec` para empaquetado y lectura de streams.

### Paso 2: Capa de Infraestructura del Contenedor Canónico
- [ ] Implementación de `LocalDiskTunnerPackageService` para escribir y descomprimir archivos `.tunner` en disco de forma atómica.
- [ ] Verificación criptográfica SHA-256 de cada archivo dentro del paquete para prevenir corrupción acústica.
- [ ] Integración con el explorador de archivos estilo VS Code para abrir archivos `.tunner` con un solo clic.

### Paso 3: Diseño e Implementación del Lenguaje Musical (Tunner DSL)
- [ ] Definición de la gramática formal (EBNF) del Tunner DSL (canales, instrumentos, secuencias, envolventes, enrutamiento).
- [ ] Implementación del Lexer (generador de tokens) y Parser para construir el Árbol de Sintaxis Abstracta (`TunnerAstNode`).
- [ ] Implementación del evaluador / intérprete de eventos (`TunnerDslInterpreter`) que traduce el AST en comandos directos para el `StudioPatchbayRoutingService` y `DjPerformanceOrchestrator`.

### Paso 4: Capa de Micro-Kernel y Planificador de Eventos (Studio OS)
- [ ] Implementación de `StudioOsAudioKernel`: bus de eventos de control de ultra-baja latencia y despacho de búferes de audio PCM compartidos.
- [ ] Conexión del planificador con el reloj de alta resolución (`HighResAudioClockService`).

### Paso 5: Capa de Presentación (Terminal de Scripting y UI Integrada)
- [ ] Creación del panel acoplable `StudioDslTerminalPanelWidget` con resaltado de sintaxis, autocompletado y ejecución interactiva en vivo (REPL).
- [ ] Botones de importación/exportación rápida a formato `.tunner` en el menú principal del sistema.

### Paso 6: Pruebas, Verificación y Documentación
- [ ] Suite de pruebas unitarias para empaquetado/desempaquetado lossless del contenedor `.tunner`.
- [ ] Suite de pruebas del Lexer, Parser y evaluador DSL con validación de errores sintácticos y tipado estricto.
- [ ] Ejecución de `flutter analyze` y suite completa de regresión.
- [ ] Compilación del binario nativo Linux release.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Aislamiento Modular:** El formato `.tunner` y el motor DSL se implementan como módulos desacoplados sobre la arquitectura existente. Si el intérprete DSL sufre un error de ejecución en tiempo real, el Micro-Kernel aísla la falla y no interrumpe la reproducción del motor de audio principal ni corrompe el estado del proyecto en memoria.
- **Punto de Restauración Git:** Commit base verificado en `feature/multimedia-vault-timeline-universal-io`.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Cero emojis en código, comentarios y documentación técnica.
- [ ] Proyectos completos guardados en un único archivo `.tunner` y restaurados con 100% de paridad acústica y visual.
- [ ] El Tunner DSL analiza, valida y ejecuta scripts de música y enrutamiento en menos de 5 ms.
- [ ] Terminal interactiva REPL operativa con historial y autocompletado.
- [ ] 100% de pruebas unitarias aprobadas sin advertencias en `flutter analyze`.
