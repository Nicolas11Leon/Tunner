# Plan de Implementación: Tareas Conjuntas Multi-Herramienta y Orquestación Atómica de Señales

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE5-MULTI-TOOL-TASKS-2026-055`
- **Título de la Implementación:** Integración de Tareas Conjuntas ($\ge 3$ Herramientas), Topologías de Conexión en Dominio e Interfaz Atómica Multi-Herramienta
- **Fase del Proyecto:** Fase 5 (Modular Studio & Advanced Pedagogy)
- **Estado:** En Progreso
- **ADR Relacionado:** [`0051_multi_tool_joint_tasks_and_orchestration_architecture.md`](../04_adrs/0051_multi_tool_joint_tasks_and_orchestration_architecture.md)
- **Documento Funcional Base:** [`doc_multi_tool_joint_tasks_and_orchestration.md`](../01_product_vision/doc_multi_tool_joint_tasks_and_orchestration.md)

---

## 1. Alcance y Objetivos

### 1.1 Objetivo Primario
Permitir que las tareas pedagógicas y técnicas de Tunner puedan orquestar sincrónicamente tres o más herramientas del sistema, conectándolas mediante topologías declarativas sobre `SignalBus` y exponiendo indicadores visuales atómicos de sinergia en la UI.

### 1.2 Límites del Alcance
- **In-Scope:**
  - Extensión de `PedagogicalTaskEntity` y `StandardPedagogicalTask` con `requiredToolIds` e `isMultiTool`.
  - Definición de Value Object `TaskInterconnectionLink` para topologías declarativas entre puertos.
  - Registro de las 5 tareas conjuntas canónicas en `TaskCatalogIndex`.
  - Creación del átomo visual `MultiToolBadgeList` / `ToolIconAtom` en `task_badge_atom.dart`.
  - Integración en `TaskCardBase` y en el modal de salto rápido `TaskQuickJumpModal`.
  - Pruebas unitarias de dominio y pruebas de widgets.
- **Out-of-Scope:**
  - Microservicios de red (prohibidos por la regla Offline-First de AGENTS.md).
  - Protocolos de streaming de audio por red (todo opera in-process en memoria).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Pure Dart)
- [x] Actualizar `pedagogical_task_contract.dart`: agregar `requiredToolIds`, `interconnectionLinks`, y getter `isMultiTool`.
- [x] Actualizar `StandardPedagogicalTask` con soporte completo de copia inmutable (`copyWith`) y valores por defecto.
- [x] Actualizar `TaskCatalogIndex`: incorporar las 5 tareas conjuntas canónicas con sus herramientas requeridas y tags de búsqueda.

### Paso 2: Capa de Presentación Atómica (Atomic UI & UX)
- [x] Crear átomo visual `MultiToolBadgeList` en `task_badge_atom.dart` que dibuje iconos representativos de cada herramienta requerida.
- [x] Integrar indicador multi-herramienta en `task_card_base.dart` y en `task_quick_jump_modal.dart`.

### Paso 3: Pruebas y Control de Calidad
- [x] Crear y ejecutar pruebas unitarias para `isMultiTool`, topologías y tareas conjuntas.
- [x] Validar pruebas de widgets para renderizado de insignias multi-herramienta.
- [x] Ejecutar `flutter analyze` y asegurar 0 advertencias y 0 errores.
- [x] Ejecutar suite de pruebas completa.

### Paso 4: Git, Pull Request y Merge
- [x] Push a rama remota `origin/feature/multi-tool-joint-tasks-orchestration`.
- [x] Crear PR formal con `gh pr create`.
- [x] Fusión limpia con squash merge a `main`.
