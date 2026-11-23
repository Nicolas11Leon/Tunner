# Registro de Decisión de Arquitectura (ADR) 0097: Micro-Kernel Studio OS: Bus de Eventos en Tiempo Real y Evaluador DSL

---

## Metadatos

- **ID del ADR:** `ADR-0097`
- **Título:** Micro-Kernel de Audio en Proceso y Evaluador de Sintaxis Abstracta (AST) para Ejecución en Tiempo Real de Tunner DSL
- **Estado:** `Approved`
- **Fecha:** `2026-11-18`
- **Fase Asociada:** `Fase 6`
- **Autor Principal:** `Nicolas Leon (Mantenedor Principal) / Antigravity Engine`
- **Caso de Uso Relacionado:** [Caso de Uso 108](../02_use_cases/108_uc_studio_os_audio_kernel_and_dsl_evaluator.md)
- **Plan Relacionado:** [Plan Épica 6.3](../05_implementation_plans/plan_studio_os_audio_kernel_and_dsl_evaluator.md)
- **Issue Asociado:** [#35](https://github.com/Nicolas11Leon/Tunner/issues/35)

---

## 1. Contexto

La introducción de Tunner DSL (ADR-0096) provee un árbol sintáctico formal (AST) para modelar orquestaciones musicales y parametrización de estudio. Para aplicar estas instrucciones en caliente a los osciladores, buses de enrutamiento y cadenas DSP, se requiere una capa ejecutora que cumpla con los siguientes principios no negociables:

1. **Sub-10ms Latency Target:** La evaluación y aplicación de parámetros debe realizarse de inmediato sin demoras acumuladas que desincronicen el audio.
2. **Cero Microservicios / Monolito Local:** El despacho debe ser en proceso (*in-process*) mediante llamadas directas y un bus reactivo de eventos en memoria local, sin WebSockets ni HTTP.
3. **Clean Architecture Disciplinada:** El intérprete del lenguaje debe operar sobre contratos abstractos de dominio (`IStudioOsAudioSink` / `StudioOsAudioKernel`), desacoplado de plugins específicos de plataforma o widgets de Flutter.

---

## 2. Decisión

Se adopta una arquitectura desacoplada basada en el **Patrón Visitor Evaluador** e **In-Process Micro-Kernel Event Bus**:

1. **Micro-Kernel de Audio (`lib/core/dsl/domain/studio_os_audio_kernel.dart`):**
   - Entidad centralizadora en Dart puro que gestiona el despacho de eventos de audio (`StudioOsAudioEvent`).
   - Mantiene un flujo reactivo asíncrono (`Stream<StudioOsAudioEvent>`) para permitir que cualquier componente del sistema observe las mutaciones en tiempo real.
   - Provee métodos atómicos de despacho: `setTempo`, `declareChannel`, `connect`, `setParameter`, `playNote`, `playChord`, `rest`, `transport`.

2. **Evaluador del DSL (`lib/core/dsl/domain/tunner_dsl_interpreter.dart`):**
   - Implementa `TunnerAstVisitor<Future<void>, TunnerDslExecutionContext>` para recorrer la jerarquía del AST de forma determinista y tipada.
   - Convierte nombres de notas tonales científicas (ej. `'C4'`, `'F#5'`, `'Bb3'`) a frecuencias exactas en Hz mediante cálculo logarítmico canónico ($440 \cdot 2^{(midi - 69)/12}$).
   - Calcula duraciones fraccionarias en milisegundos basadas en el tempo actual ($60000 / BPM \cdot \text{pulsos}$).
   - Genera reportes de ejecución inmutables (`TunnerDslExecutionReport`) con conteo de eventos, diagnósticos y tiempos de evaluación.

3. **Puente de Infraestructura (`lib/core/dsl/infrastructure/studio_os_audio_kernel_bridge.dart`):**
   - Implementa los manejadores conectando `StudioOsAudioKernel` con `StudioAudioDeviceMatrixService`, `PolyphonicVoicePool`, `StudioMasterClockService` y `TunerViewModel`.
   - Garantiza que las llamadas mutadoras respeten el rango seguro de parámetros (*clamping*) y manejen de forma no bloqueante las emisiones de síntesis polifónica.

---

## 3. Consecuencias

### Positivas
- **Aislamiento y Testabilidad Total:** El intérprete y el kernel pueden probarse exhaustivamente con mocks o en memoria sin necesidad de hardware de audio real.
- **Observabilidad en Tiempo Real:** Todos los eventos emitidos por scripts DSL pueden visualizarse en consolas interactivas o vúmetros.
- **Extensibilidad:** Nuevos tipos de sentencias en el AST pueden soportarse simplemente añadiendo métodos al Visitor y al Kernel sin alterar el código existente.

### Consideraciones
- La temporización de notas secuenciales complejas en scripts interactivos requiere respetar el reloj del sistema sin bucles de espera activa (*busy-waiting*).
