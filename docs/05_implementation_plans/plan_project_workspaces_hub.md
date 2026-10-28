# Implementation Plan: Project Workspaces Hub & Mode Division

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-WORKSPACES-HUB-2026-0031`
- **Título de la Implementación:** Hub de Espacios de Trabajo Especializados (Aprender, Componer, Producir)
- **Fase del Proyecto:** Fase 3
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0031](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/04_adrs/0031_project_workspaces_hub_and_mode_division.md)
- **Documento Funcional Base:** [Caso de Uso 35](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/02_use_cases/35_uc_project_workspaces_hub.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Modularizar y desacoplar la interfaz de usuario monolítica en tres espacios de trabajo independientes, especializados y optimizados para la carga cognitiva del usuario: *Aprender*, *Componer* y *Producir*, con conmutación en un toque y persistencia local sin conexión.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad de dominio puro `WorkspaceType` y `WorkspaceConfigurationEntity`.
  - Persistencia en `AppUserSettingsEntity` y `JsonLocalPersistenceService`.
  - Integración en `TunerViewModel`.
  - Vistas especializadas: `LearningPracticeWorkspaceView`, `CompositionNotationWorkspaceView`, `ProductionAcousticLabWorkspaceView`.
  - Conmutador visual `WorkspaceSwitchBar`.
  - Pruebas unitarias de dominio y pruebas de integración de widgets.
- **Excluido (Out-of-Scope):**
  - Modificación de algoritmos DSP de bajo nivel (MPM, FFT, supresión acústica).
  - Cambios en formatos de archivo MusicXML o SMuFL.

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `>=3.0.0 <4.0.0`
  - Flutter SDK: Stable channel
- **Riesgo Tecnológico:**
  - Cero dependencias nativas adicionales.
  - Cero busy-waiting loops.
  - Preservación del 100% de los tests existentes (311 tests pasando).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Crear `lib/features/workspaces/domain/workspace_type.dart` con `WorkspaceType` y `WorkspaceConfigurationEntity`.
- [x] Crear pruebas unitarias en `test/features/workspaces/workspace_domain_test.dart`.

### Paso 2: Capa de Infraestructura / Persistencia
- [x] Actualizar `AppUserSettingsEntity` para incluir `activeWorkspace`.
- [x] Actualizar serialización y deserialización JSON para conservar compatibilidad.

### Paso 3: Orquestación en ViewModel
- [x] Integrar `activeWorkspace` en `TunerViewModel`.
- [x] Crear método `setWorkspace(WorkspaceType)`.
- [x] Persistencia reactiva automática sin bloqueos de hilo.

### Paso 4: Capa de Presentación (Vistas y Switcher)
- [x] Crear `WorkspaceSwitchBar` (componente reutilizable y estilizado).
- [x] Implementar `LearningPracticeWorkspaceView`.
- [x] Implementar `CompositionNotationWorkspaceView`.
- [x] Implementar `ProductionAcousticLabWorkspaceView`.
- [x] Conectar en `TunerScreen` preservando todas las claves semánticas existentes.

### Paso 5: Pruebas, Verificación y Limpieza
- [x] Crear pruebas de interfaz en `test/features/workspaces/workspace_ui_test.dart`.
- [x] Ejecutar `flutter analyze` (0 linter warnings).
- [x] Ejecutar `flutter test` (100% pass rate - 311/311 tests).

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- Si surge alguna inconsistencia o regresión en pruebas, volver al commit anterior en la rama de trabajo.
- Mantener retrocompatibilidad de modo que si `activeWorkspace` es nulo, el sistema utilice por defecto `WorkspaceType.learning`.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Código adherido estrictamente a las reglas de [AGENTS.md](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/AGENTS.md).
- [x] Cero busy-waiting loops.
- [x] 100% de pruebas unitarias y de integración pasando sin excepciones.
- [x] Documentación técnica, caso de uso y ADR redactados en `docs/`.
