# Implementation Plan: Phase 2 Continuous Horizontal Scrolling and Multi-Measure Score Navigation

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-MULTI-MEASURE-SCROLL-2026-006`
- **Título de la Implementación:** `Navegación Multi-Compás con Scroll Horizontal Continuo y Playhead Inter-Compases`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `Completado`
- **ADR Relacionado:** `docs/04_adrs/0002_hierarchical_score_tree_domain_model.md`
- **Documento Funcional Base:** `docs/02_use_cases/03_uc_interactive_score_playhead.md` y `docs/02_use_cases/06_uc_smufl_sheet_music_engine.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Evolucionar la visualización del estudio musical de un único compás estático en bucle a un **sistema de compases múltiples encadenados con transición y scroll horizontal**.
1. Permitir que `HierarchicalScore` contenga $M \ge 1$ compases (`MeasureEntity`).
2. Sincronizar el avance del `MetronomeService` y `TunerViewModel`: al superar el último sub-tick del compás actual, avanzar al siguiente compás de forma continua.
3. Permitir que el usuario visualice el compás activo (con barra divisoria de compás vertical y numeración de compás) e indicador de progreso global del estudio.
4. Mantener la suite de tests unitarios y de widgets al 100% verde sin desbordes de UI ni degradación de FPS.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Soporte de múltiples compases en `TunerViewModel` (`currentMeasureIndex`, `totalMeasures`, `isScoreFinished`).
  - Renderizado de barra divisoria de compás (`BarLine`) y número de compás en `RealSheetMusicPainter`.
  - Estudios canónicos de prueba con más de 1 compás (e.g. Estudio diatónico de 2 o 4 compases).
  - Pruebas unitarias de navegación inter-compás en `test/domain/score_tree_test.dart` y `test/presentation/`.
- **Excluido (Out-of-Scope):**
  - Carga dinámica de partituras MusicXML desde archivos ZIP en disco (Fase 4).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.5`.
- **Flutter Framework:** `CustomPainter`, `AnimationController` / Reactividad pura vía `ChangeNotifier`.
- **Riesgo Tecnológico:** **Bajo**. Cálculo puramente vectorial y de estado reactivo en memoria local. Cero dependencias externas.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Ampliación de Estudios Canónicos Multi-Compás)
- [x] Incorporar obras multi-compás en `lib/domain/score_entity.dart` y `lib/domain/score_tree.dart` (ejemplo: "Escala Mayor Extendida" con 2 o más compases con su correspondiente barra final de doble línea).
- [x] Pruebas unitarias en `test/domain/score_tree_test.dart` validando longitud total de ticks de la obra completa y navegación ordinal de compases.

### Paso 2: Capa de Infraestructura / ViewModel
- [x] Actualizar `TunerViewModel` para trackear `currentMeasureIndex` y `currentMeasure`.
- [x] Al recibir cada `tick` del `MetronomeService`, calcular el compás activo:
  - Cuando `tick >= currentMeasure.timeSignature.totalTicks`, transicionar a `currentMeasureIndex + 1`.
  - Si es el último compás, permitir reinicio cíclico o pausa de finalización de estudio.
- [x] Limpiar o preservar el historial de afinación por compás de forma organizada.

### Paso 3: Capa de Presentación (Renderizado Vectorial en CustomPainter)
- [x] Dibujar la barra de compás inicial y final (`|` y `||` para final de obra).
- [x] Mostrar etiqueta del compás actual en el pentagrama (e.g., "Compás 1/2", "Compás 2/2").
- [x] Controles en la barra superior o en el lienzo para navegar manualmente entre compases si el metrónomo está pausado.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Ejecutar `flutter test` asegurando que todos los tests pasen (17/17 tests pasando).
- [x] Comprobar ausencia de regresiones de memoria o CPU.
- [x] Registrar commit formal en `main`.

---

## 4. Estrategia de Rollback

- Revertir al commit `40438b4` en caso de fallo en la reactividad del metrónomo.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Soporte completo de estudios con múltiples compases sin saltos temporales bruscos.
- [x] Barra de compás (`BarLine`) y numeración visual renderizadas vectorialmente.
- [x] Todos los tests de Flutter pasando al 100%.
- [x] Sincronizado en `main`.
