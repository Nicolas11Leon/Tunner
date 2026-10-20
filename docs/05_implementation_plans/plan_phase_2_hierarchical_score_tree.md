# Implementation Plan: Phase 2 Hierarchical Score Tree and Variable Time Signatures

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-SCORE-TREE-2026-005`
- **Título de la Implementación:** `Árbol de Notación Musical Jerárquico en Dominio Puro y Métricas Variables (3/4, 4/4, 6/8)`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `Completado`
- **ADR Relacionado:** `docs/04_adrs/0002_hierarchical_score_tree_domain_model.md`
- **Documento Funcional Base:** `docs/02_use_cases/03_uc_interactive_score_playhead.md` y `docs/02_use_cases/06_uc_smufl_sheet_music_engine.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Superar el modelo preliminar de partitura rígida (fijado a 16 ticks en 4/4) implementando un **árbol de dominio jerárquico inmutable en Dart puro** (`lib/domain/score_tree.dart`) que soporte:
1. Métricas de compás configurables (`TimeSignature`: $2/4, 3/4, 4/4, 6/8$).
2. Compases encadenados (`MeasureEntity`) que permiten canciones y estudios de longitud arbitraria.
3. Figuras rítmicas estándar con duraciones relativas (Redondas, Blancas, Negras, Corcheas, Semicorcheas, Tresillos y sus silencios correspondientes).
4. Pruebas unitarias completas de la matemática de tiempos y compases.
5. Adaptación del motor gráfico (`RealSheetMusicPainter`) para renderizar el árbol de notas dinámico manteniendo el tracking del *playhead* sincronizado con el reloj de audio.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades en `lib/domain/`: `TimeSignature`, `ScoreMeasure`, `ScorePart`, `HierarchicalScore`.
  - Migración limpia de `lib/domain/score_entity.dart` para mantener retrocompatibilidad.
  - Suite de pruebas en `test/domain/score_tree_test.dart`.
  - Integración en `TunerViewModel` y `TunerScreen`.
- **Excluido (Out-of-Scope):**
  - Parser de archivos MusicXML en disco (Fase 4).
  - Polifonía de múltiples pentagramas simultáneos (pianoforte a dos manos).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.5`.
- **Cero dependencias externas:** El árbol de dominio es **Dart puro**, cumpliendo el principio no negociable de Clean Architecture ([AGENTS.md](AGENTS.md)).
- **Riesgo Tecnológico:** **Bajo**. Estructura de datos inmutable basada en colecciones estándar de Dart (`List<T>`).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Crear `lib/domain/score_tree.dart` con:
  - `TimeSignature`: Numerador, denominador y total de ticks por compás.
  - `NoteFigure`: Enumeración de duraciones relativas.
  - `HierarchicalNote`: Posición en compás, duración en sub-ticks, tono/frecuencia y bandera de silencio.
  - `MeasureEntity`: Índice de compás, métrica y lista de notas/silencios.
  - `HierarchicalScore`: Título, tempo base en BPM y lista de compases.
- [x] Crear suite de pruebas en `test/domain/score_tree_test.dart` verificando la suma de ticks por compás (e.g. 3/4 = 12 ticks, 4/4 = 16 ticks, 6/8 = 12 ticks en semicorcheas).

### Paso 2: Capa de Infraestructura / Datos y ViewModel
- [x] Actualizar `TunerViewModel` para admitir compases dinámicos con métricas distintas a 4/4.
- [x] Garantizar que el cambio de compás o estudio no resetee abruptamente los hilos de audio.

### Paso 3: Capa de Presentación (Renderizado Vectorial en CustomPainter)
- [x] Ajustar `RealSheetMusicPainter` en `tuner_screen.dart` para leer las propiedades de compás y pintar la armadura de tiempo correspondiente (e.g., "3/4", "4/4") al inicio del pentagrama.
- [x] Ajustar el espaciado dinámico de las figuras según la duración del compás.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Ejecutar `flutter test` verificando 100% de pruebas pasando.
- [x] Redactar ADR-0002 para documentar el modelo de dominio jerárquico.
- [x] Sincronizar en la rama `main` de GitHub.

---

## 4. Estrategia de Rollback

- Revertir al commit previo `4eab7dc` en caso de incompatibilidad con el playhead existente.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Árbol de notación 100% desacoplado en Dart puro (cero imports de Flutter en `lib/domain/score_tree.dart`).
- [x] Soporte probado para compases de 4/4, 3/4 y 6/8.
- [x] Pruebas unitarias de dominio con cobertura superior al 95%.
- [x] ADR formal redactado en `docs/04_adrs/`.
- [x] Commit y push a `main`.
