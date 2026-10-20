# Project Constitution & Non-Negotiables: Tunner

This document defines the foundational engineering rules, operating philosophy, and non-negotiable principles for collaborating on the **Tunner** project. 

Whenever an AI agent or engineer works within this codebase, this document is the primary authority governing design, architecture, documentation, and implementation decisions.

---

## 1. Reglas Cardinales de Operación (Mandatory Operational Rules)

1. **Lectura Completa Previa Obligatoria:**  
   Siempre se debe leer este archivo en su totalidad como primera instancia antes de iniciar o planificar cualquier tarea, sin excepción.
2. **Alineación Continua con el Creador:**  
   Ante cualquier ambigüedad, decisión de diseño o encrucijada arquitectónica, se deben formular preguntas claras y directas para asegurar que cada acción esté 100% alineada con la visión y beneficio del creador del proyecto.
3. **Estado del Arte y Versiones Estables:**  
   Se debe investigar y aplicar siempre lo último en tecnología de la industria del audio digital y desarrollo de software, priorizando siempre versiones estables, confiables y con soporte a largo plazo (LTS).
4. **Planificación Previa y Plantillas Canónicas:**  
   Antes de modificar o generar código fuente, es estrictamente obligatorio redactar un Plan de Implementación formal y la Documentación Técnica correspondiente utilizando las plantillas maestras del proyecto:
   - [Plantilla de Documentación](docs/templates/plantilla_documentacion.md)
   - [Plantilla de Plan de Implementación](docs/templates/plantilla_plan_implementacion.md)
   Ambos documentos deben ser leídos y respetados en cada ciclo de trabajo.
5. **Libro Canónico de Casos de Uso y Diagramas de Flujo:**  
   Cada funcionalidad nueva propuesta debe formalizarse en un documento individual clasificado del `00` al `N` dentro de `docs/02_use_cases/`. Cada caso de uso debe incluir obligatoriamente:
   - Diagrama de Casos de Uso formal (Mermaid).
   - Diagrama de Flujo / Secuencia detallado (Mermaid).
   - Precondiciones, postcondiciones, flujo principal y flujos alternativos / de error.

---

## 2. Core Operating Philosophy

### 2.1 Product vs. Project Mindset
- **Project Scope:** Structured in strictly bounded, sequential phases with well-defined deliverables and milestones.
- **Product Vision:** Continuous, long-term commitment to democratizing music education. The user experience, pedagogical value, and acoustic precision always take precedence over convenience.

### 2.2 The Phase-Gate Model
- Development progresses in strict **Fases (Phases)**.
- **Phase Completion Rule:** No phase is considered complete, and no subsequent phase may be started, until the current phase meets its formal **Definition of Done (DoD)**:
  1. Complete functional coverage of the target components.
  2. Maximum optimization (zero busy-waiting loops, minimal CPU/battery overhead, deterministic memory usage).
  3. Formal ADRs (Architecture Decision Records) written for all architectural choices.
  4. Unit and regression test suites passing with high coverage.
  5. Exhaustive technical documentation updated in `docs/`.

---

## 3. Architectural Non-Negotiables

### 3.1 Monolithic Modular Architecture over Microservices
- **Zero Microservices Rule:** Real-time audio processing and educational feedback strictly forbid network latency, server dependencies, and distributed network overhead. 
- **Offline First:** All core capabilities (pitch detection, metronome, score rendering, analysis, synthesis) must run 100% locally on the user's device without requiring an active internet connection.
- **In-Process Modular Extensibility:** The architecture is a clean, modular monolith. If performance limits are encountered in Dart:
  - Do NOT extract services over HTTP/gRPC.
  - DO use **In-Process Native Bindings (`dart:ffi` with C, C++, or Rust)** to achieve bare-metal performance within the same local binary.

### 3.2 Clean Architecture Discipline
- **Domain Layer (`lib/domain`):** Pure Dart. Zero dependencies on Flutter UI, third-party frameworks, or platform plugins. Contains musical primitives (notes, intervals, frequencies, meters, score trees, pitch algorithms).
- **Data / Infrastructure Layer (`lib/data`):** Audio streams, microphone ingestion, hardware clocks, file I/O, platform channels. Implements interfaces defined in the domain layer.
- **Presentation Layer (`lib/presentation`):** Flutter widgets, view models, reactive state, custom painters, rendering canvases. Presentation never interacts with raw hardware or data sources directly; it communicates solely through domain entities and view models.

---

## 4. Engineering & Performance Non-Negotiables

### 4.1 Audio & Hardware Discipline
- **No Busy-Waiting (100% CPU loops):** Threads and Isolates must yield CPU time to the operating system. Polling or high-frequency loops must use compensated sleeping or high-resolution OS timers.
- **Sub-10ms Latency Target:** Pitch estimation and audio clocks must minimize buffer latency to preserve real-time visual-auditory coherence.
- **No Arbitrary Hardcoding:** Musical ranges must support all human vocal registers (bass to soprano, ~60 Hz to ~1500 Hz) and orchestral/contemporary instruments (~27.5 Hz $A_0$ to ~4186 Hz $C_8$).

### 4.2 Visual & Rendering Discipline
- **Vector & Standard Musical Typography:** Sheet music notation must adhere to standardized musical typography rules (SMuFL standards) rather than arbitrary ad-hoc geometric sketches.
- **60/120 FPS Fluidity:** Canvas painting and playhead tracking must maintain smooth frame rates without UI jank. Heavy math must live in background Isolates or native FFI.

---

## 5. Documentation Non-Negotiables

Every structural evolution must be documented before or alongside code implementation:
1. **Architecture Decision Records (ADRs):** Any change in architecture, dependency selection, or state management strategy must be documented as an ADR in `docs/04_adrs/` following the standard format (Status, Context, Decision, Consequences).
2. **Spikes & Research (`docs/spikes/`):** Novel algorithms or performance experiments must have written findings and benchmark logs before graduating into production code.
3. **No Undocumented Magic Numbers:** Every DSP constant (window sizes, overlap ratios, cents formulas, FFT sizes) must include accompanying mathematical documentation explaining its derivation.
4. **Professional Technical Tone:** Documentation must be rigorous, precise, objective, and free of unnecessary fluff or emojis.
