# Plan de Implementación: Refactorización Atómica de Sinergias Inter-Herramientas y Motor de Políticas

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE5-SYNERGY-REFACTOR-2026-056`
- **Título de la Implementación:** Refactorización Atómica de la Red de Sinergias Inter-Herramientas, Validación de Políticas Acústicas y Desacoplamiento Modular
- **Fase del Proyecto:** Fase 5 (Modular Studio & Clean Architecture Refactor)
- **Estado:** En Progreso
- **ADR Relacionado:** [`0052_global_inter_tool_synergy_and_policy_engine.md`](../04_adrs/0052_global_inter_tool_synergy_and_policy_engine.md)
- **Documento Funcional Base:** [`doc_deep_inter_tool_synergy_and_refactor_roadmap.md`](../01_product_vision/doc_deep_inter_tool_synergy_and_refactor_roadmap.md)

---

## 1. Alcance y Objetivos

### 1.1 Objetivo Primario
Implementar en la capa de dominio puro el motor de validación de políticas de sinergia (`SynergyPolicyEngine`) y formalizar la interoperabilidad entre herramientas del ecosistema Tunner, garantizando que los enlaces entre puertos sean acústica y pedagógicamente coherentes, y preparando la arquitectura para la refactorización integral.

### 1.2 Límites del Alcance
- **In-Scope:**
  - Creación del Value Object `SynergyConnectionValidation` y del servicio de dominio `SynergyPolicyEngine`.
  - Definición explícita de reglas de compatibilidad de puertos e incompatibilidad pedagógica (ej. Autotune vs. Oído a Ciegas, Polifonía vs. MPM).
  - Pruebas unitarias exhaustivas del motor de políticas y validación de enlaces.
  - Actualización del `SignalBus` para integrar la validación de políticas antes de autorizar enlaces.
- **Out-of-Scope:**
  - Microservicios o llamadas gRPC (estrictamente prohibido por la regla Offline-First de AGENTS.md).
  - Modificación de pantallas de UI existentes que no utilicen el `SignalBus`.

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Pure Dart)
- [ ] Crear `lib/features/modular_rack/domain/synergy_policy_engine.dart` con validación estricta de puertos y políticas pedagógicas.
- [ ] Extender `SignalBus` para invocar opcionalmente `SynergyPolicyEngine.validateConnection` al establecer enlaces.
- [ ] Pruebas unitarias de dominio para validar las 6 hiper-sinergias y verificar el rechazo de los cruces forzados.

### Paso 2: Verificación de Calidad
- [ ] Ejecutar `flutter analyze` y asegurar 0 advertencias y 0 errores.
- [ ] Ejecutar toda la suite de pruebas del proyecto con 100% de aprobación.

### Paso 3: Git, Pull Request y Documentación
- [ ] Crear rama de feature `feature/deep-inter-tool-synergy-and-policy-engine`.
- [ ] Commit convencional y push a origin.
- [ ] Crear PR formal y fusionar con squash merge en `main`.
