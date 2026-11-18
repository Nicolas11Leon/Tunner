# Plan de Implementación: Micro-Kernel Studio OS: Bus de Eventos en Tiempo Real y Evaluador DSL

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE6-STUDIO-KERNEL-2026-0097`
- **Título de la Implementación:** Micro-Kernel Studio OS: Bus de Eventos en Tiempo Real, Evaluador de Árbol AST y Enrutamiento Acústico
- **Fase del Proyecto:** Fase 6 (Ecosistema de Plataforma Autónoma y Lenguaje DSL)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0097](../04_adrs/0097_studio_os_audio_kernel_and_dsl_evaluator.md)
- **Documento Funcional Base:** [Caso de Uso 108](../02_use_cases/108_uc_studio_os_audio_kernel_and_dsl_evaluator.md)
- **Issue Asociado:** [#35](https://github.com/Nicolas11Leon/Tunner/issues/35)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Construir el evaluador de sentencias DSL (`TunnerDslInterpreter`) y el micro-kernel de audio reactivo (`StudioOsAudioKernel`), permitiendo traducir instrucciones del AST en eventos acústicos atómicos despachados en tiempo real hacia la matriz de dispositivos de hardware, sintetizadores polifónicos y reloj maestro.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Eventos de audio tipados e inmutables en `lib/core/dsl/domain/studio_os_audio_event.dart`.
  - Micro-Kernel en proceso y bus de eventos reactivo en `lib/core/dsl/domain/studio_os_audio_kernel.dart`.
  - Intérprete Visitor del AST en `lib/core/dsl/domain/tunner_dsl_interpreter.dart` con soporte para tempo, canales, conexiones, parámetros (`set`), notas, acordes, silencios y bucles.
  - Puente de integración de infraestructura en `lib/core/dsl/infrastructure/studio_os_audio_kernel_bridge.dart`.
  - Comando `dsl` / `eval` integrado en `TunnerOsKernel` para ejecución directa desde scripts o terminal.
  - Pruebas unitarias de evaluador, eventos y despacho de kernel con 100% de éxito.
- **Excluido (Out-of-Scope):**
  - Terminal gráfica interactiva y consola visual REPL con autocompletado (asignado a Épica 6.4 e Issue #36).
  - Algoritmos de reverberación física (asignado a Fase 7 e Issue #37).

---

## 2. Análisis de Dependencias y Tecnologías

- **Lenguaje:** Dart Puro (Domain Layer), Flutter Foundation / Services (Infrastructure Layer).
- **Latencia:** Despacho de eventos sub-10ms mediante flujos reactivos en memoria sin llamadas bloqueantes ni bucles de espera activa.
- **Acoplamiento:** Totalmente desacoplado mediante interfaces canónicas (`IStudioOsAudioSink`, `StudioOsAudioKernel`).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Jerarquía de Eventos Acústicos (`lib/core/dsl/domain/studio_os_audio_event.dart`)
- Definir la clase base sellada/abstracta `StudioOsAudioEvent` con marca temporal en microsegundos.
- Subclases inmutables:
  - `StudioOsTempoEvent`
  - `StudioOsChannelDeclaredEvent`
  - `StudioOsConnectionEvent`
  - `StudioOsParameterEvent`
  - `StudioOsNoteEvent`
  - `StudioOsChordEvent`
  - `StudioOsRestEvent`
  - `StudioOsTransportEvent`

### Paso 2: Micro-Kernel Studio OS (`lib/core/dsl/domain/studio_os_audio_kernel.dart`)
- Implementar el bus de eventos basado en `StreamController<StudioOsAudioEvent>.broadcast()`.
- Definir manejadores configurables o callbacks para mutación de hardware.
- Suministrar métodos atómicos deterministas para cada acción acústica.

### Paso 3: Evaluador AST (`lib/core/dsl/domain/tunner_dsl_interpreter.dart`)
- Implementar `TunnerAstVisitor<Future<void>, TunnerDslExecutionContext>`.
- Mapeo de notas a frecuencias ($440 \cdot 2^{(m-69)/12}$) y duraciones en milisegundos.
- Emisión de `TunnerDslExecutionReport`.

### Paso 4: Puente de Infraestructura y Comando de Kernel (`lib/core/dsl/infrastructure/`)
- Conectar el kernel con `StudioAudioDeviceMatrixService`, `PolyphonicVoicePool`, y `StudioMasterClockService`.
- Integrar el comando `dsl` / `eval` en `TunnerOsKernel`.

### Paso 5: Pruebas Unitarias y de Regresión (`test/core/dsl/`)
- `test/core/dsl/tunner_dsl_interpreter_test.dart`
- `test/core/dsl/studio_os_audio_kernel_test.dart`
- Verificación estática con `flutter analyze` y suites de regresión.

---

## 4. Criterios de Aceptación (Definition of Done)

1. Evaluador AST procesa scripts válidos y despacha eventos a `StudioOsAudioKernel`.
2. Bus de eventos emite notificaciones a través de `eventStream` sin fugas de memoria.
3. Comando `eval`/`dsl` en `TunnerOsKernel` ejecuta scripts en vivo y reporta estado de forma legible.
4. Cobertura de pruebas unitarias al 100% en componentes nuevos con cero fallos.
5. `flutter analyze --no-fatal-infos` sin advertencias ni errores.
