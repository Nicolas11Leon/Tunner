# Implementation Plan: Manual Testing Framework, Use Case Audit Checklists, and Master QA Runbook

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-QA-MANUAL-TESTING-2026-042`
- **Título de la Implementación:** `Marco Canónico de Pruebas Manuales, Bitácora de Validación Acústico-Funcional y Checklists de Casos de Uso`
- **Fase del Proyecto:** `Fase 1 / Fase 2 / Fase 3 / Fase 4 (Cross-Cutting QA & Verification)`
- **Estado:** `Completado`
- **ADR Relacionado:** `N/A (Metodología de Aseguramiento de Calidad y Verificación de Usuario)`
- **Documento Funcional Base:** `docs/02_use_cases/01_uc_...` a `docs/02_use_cases/41_uc_...`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Proveer al creador del proyecto y a los evaluadores de calidad un sistema integral y estandarizado de **Pruebas Manuales y Bitácora de Auditoría en Vivo** que permita:
1. Validar experimentalmente en dispositivo físico (smartphone, tablet, desktop) cada una de las funcionalidades acústicas, pedagógicas, de notación, síntesis y calibración desarrolladas.
2. Identificar qué aspectos funcionan con precisión absoluta, cuáles presentan observaciones ergonómicas o acústicas y qué detalles o casos de borde restan por pulir.
3. Incorporar en la totalidad de los 41 Casos de Uso Canónicos (`01_uc_...` a `41_uc_...`) una sección unificada y detallada de **"Pruebas Manuales por Hacer (Manual Testing Runbook)"** con pasos de ejecución humana, precondiciones, resultados esperados auditivos/visuales, checklists interactivos `[ ]` y tabla de bitácora de ejecución.
4. Crear la **Bitácora Maestra de Pruebas Manuales** (`docs/06_qa_and_manual_testing/bitacora_maestra_pruebas_manuales.md`) como centro de mando unificado para el seguimiento del progreso global de pruebas manuales.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación del directorio canónico `docs/06_qa_and_manual_testing/`.
  - Redacción del Manual Metodológico de Pruebas Manuales `docs/06_qa_and_manual_testing/00_manual_testing_methodology.md`.
  - Redacción de la Bitácora Maestra de Pruebas Manuales `docs/06_qa_and_manual_testing/bitacora_maestra_pruebas_manuales.md` con matriz de seguimiento de los 41 casos de uso.
  - Actualización exhaustiva de cada uno de los 41 Casos de Uso en `docs/02_use_cases/` añadiendo los pasos de prueba manual específicos de cada funcionalidad.
- **Excluido (Out-of-Scope):**
  - Modificación de algoritmos DSP o componentes de UI en esta fase documental/QA (se registrarán como observaciones si se descubren fallas durante las pruebas manuales).

---

## 2. Análisis de Dependencias y Tecnologías

- **Formato:** Markdown GitHub-Flavored con tablas estructuradas, enlaces canónicos relativos `file://` y casillas de verificación interactivas `[ ]`.
- **Riesgo Tecnológico:** **Nulo**. Mejora la trazabilidad, calidad y preparación para lanzamientos de producción sin alterar la estabilidad del código base.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Marco Metodológico y Plantilla de Prueba Manual
- [x] Crear `docs/06_qa_and_manual_testing/00_manual_testing_methodology.md` con los lineamientos formales de prueba:
  - Protocolo acústico (entorno de silencio, pruebas con instrumentos reales y con generadores de tonos de referencia).
  - Protocolo de renderizado visual (inspección de 60/120 FPS, ausencia de jank).
  - Taxonomía de estados de prueba: `[ ] Pendiente`, `[x] Superado con Éxito`, `[!] Con Observaciones/Defectos`, `[-] Bloqueado`.

### Paso 2: Bitácora Maestra de Pruebas Manuales
- [x] Crear `docs/06_qa_and_manual_testing/bitacora_maestra_pruebas_manuales.md`:
  - Matriz resumen de los 41 Casos de Uso (UC-01 al UC-41).
  - Indicadores globales de avance manual (% completado, total pruebas por caso de uso).
  - Plantilla de reporte de incidencias y mejoras sugeridas.

### Paso 3: Actualización Sistemática de los 41 Casos de Uso
Incorporar en cada archivo la sección `## N. Guía de Pruebas Manuales y Bitácora de Validación`:
- [x] Grupo 1: Detección Acústica, Pitch y Hardware (UC-01, UC-02, UC-04, UC-05, UC-13, UC-15, UC-16, UC-20, UC-26, UC-29, UC-41).
- [x] Grupo 2: Afinación Histórica, Sintetizadores y Audio Engine (UC-23, UC-24, UC-25, UC-36, UC-37, UC-39, UC-40).
- [x] Grupo 3: Partituras, Notación SMuFL, Transcripción y Editores (UC-03, UC-06, UC-08, UC-14, UC-17, UC-18, UC-19, UC-27, UC-28, UC-30, UC-31).
- [x] Grupo 4: Grabación, Pistas y Análisis Espectral (UC-07, UC-12, UC-32).
- [x] Grupo 5: Pedagogía, Métricas, Espacios de Trabajo y Personalización (UC-09, UC-10, UC-11, UC-21, UC-22, UC-33, UC-34, UC-35, UC-38).

### Paso 4: Verificación y Consistencia Documental
- [x] Validar que todos los enlaces cruzados funcionen y no existan referencias rotas.
- [x] Sincronizar cambios en el repositorio Git (`main`).

---

## 4. Estrategia de Rollback
- Revertir los cambios en documentación con `git checkout docs/` si existiese inconsistencia de numeración.

---

## 5. Criterios de Aceptación (Definition of Done)
- [x] Los 41 Casos de Uso contienen una sección estructurada de pruebas manuales por hacer.
- [x] Existe la Bitácora Maestra consolidada para el seguimiento del creador.
- [x] Cero impacto negativo en el código de producción ni en los 389 tests unitarios.
