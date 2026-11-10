# ADR 0051: Arquitectura de Tareas Conjuntas Multi-Herramienta y Orquestación Atómica de Señales

## Estado
Aprobado (Approved) - 2026-11-09

## Contexto
Tunner dispone de potentes herramientas individuales (afinador MPM, metrónomo en Isolate, pentagrama SMuFL, grabador, dron, analizador de acordes, espectrograma). Sin embargo, los ejercicios musicales del mundo real requieren la interacción sincronizada de múltiples herramientas simultáneamente. La integración debe respetar Clean Architecture, mantener la capa de dominio libre de Flutter, garantizar una latencia de comunicación entre herramientas $< 1\text{ ms}$ y permitir la orquestación declarativa mediante el código de taxonomía canónico TTC.

## Decisión
1. **Extensión del Contrato de Dominio:** Se extiende `PedagogicalTaskEntity` para incluir `requiredToolIds: List<String>` y un getter booleano `isMultiTool => requiredToolIds.length >= 3`.
2. **Entidad de Topología de Conexión Declarativa:** Se modela `TaskInterconnectionTopology` en el dominio puro, especificando los puertos de origen y destino en `SignalBus` requeridos para la tarea.
3. **Catálogo Semilla Canónico Multi-Herramienta:** Se incorporan al índice `TaskCatalogIndex` las 5 tareas conjuntas canónicas que combinan tres o más herramientas (Lectura en Vuelo, Afinación por Batimento, Dictado Inverso, Diagnóstico Tímbrico, Exploración Polifónica).
4. **Componente Visual Atómico (`MultiToolDockPill`):** Se introduce un átomo de interfaz en `task_badge_atom.dart` y `task_card_base.dart` que visualiza las herramientas participantes y permite lanzar la orquestación conjunta.

## Consecuencias

### Positivas
- **Máxima Reutilización:** No se crean herramientas ad-hoc ni monolíticas; se orquestan las existentes a través de contratos desacoplados.
- **Rendimiento Determinista:** El ruteo de señales a través de `SignalBus` opera con despacho reactivo en memoria con latencia $< 1\text{ ms}$ sin garbage collection innecesario.
- **Pedagogía Integral:** Los estudiantes reciben evaluaciones que cruzan ritmo, afinación, articulación y pureza espectral en una sola sesión.

### Negativas / Mitigaciones
- **Complejidad de UI:** Mostrar tres o más herramientas en pantallas móviles pequeñas puede causar saturación visual. *Mitigación:* Se implementa colapso dinámico (`ModuleViewMode.compact`) en el Rack de Estudio y tabs sincronizados con indicador de estado compartido.
