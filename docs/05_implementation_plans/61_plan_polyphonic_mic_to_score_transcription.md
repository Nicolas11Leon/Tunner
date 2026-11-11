# Plan de Implementacion: Transcripcion Polifonica Mic-to-Score en Tiempo Real

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-POLY-TRANS-2026-061`
- **Título de la Implementación:** Implementación del Motor de Transcripción Polifónica en Tiempo Real con Soporte de Acordes en ScoreTree
- **Fase del Proyecto:** Fase 2 (Suites Sinérgicas Multi-Herramienta)
- **Estado:** Aprobado
- **ADR Relacionado:** [ADR 0057: Arquitectura de Transcripción Polifónica Mic-to-Score en Tiempo Real](../04_adrs/0057_polyphonic_mic_to_score_transcription.md)
- **Documento Funcional Base:** [DOC-ARCH-2026-063](../01_product_vision/doc_polyphonic_mic_to_score_transcription.md) y [UC-63](../02_use_cases/63_uc_polyphonic_mic_to_score_transcription.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Extender las capacidades de notación musical y DSP de Tunner para permitir la transcripción acústica directa de acordes polifónicos y pasajes armónicos complejos desde el micrófono hacia el pentagrama vectorial SMuFL, garantizando consistencia métrica en `MeasureEntity`.

### 1.2 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Actualización de `MeasureEntity.isValidMeasure` en `lib/features/sheet_music/domain/score_tree.dart` para soportar notas simultáneas (acordes).
  - Creación de `PolyphonicTranscriptionEngine` y `PolyphonicChordCandidate` en `lib/features/transcription/domain/polyphonic_transcription_engine.dart`.
  - Integración en `TunerViewModel`: métodos `togglePolyphonicLiveTranscription()`, `isPolyphonicTranscriptionActive`, y procesamiento de frames multitono.
  - Pruebas unitarias de dominio (`test/features/transcription/polyphonic_transcription_engine_test.dart`).
- **Excluido (Out-of-Scope):**
  - Detección polifónica de más de 6 voces simultáneas (acorde de orquesta completa) en esta iteración.

---

## 2. Analisis de Dependencias y Tecnologias

- **Dart SDK:** `^3.11.5` puro en la capa de dominio.
- **Riesgo Tecnológico:** Cero. Reutiliza el tamiz armónico de `PolyphonicMultiToneDetector` y la estructura inmutable de `HierarchicalScore`.

---

## 3. Plan Paso a Paso de Ejecucion (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (ScoreTree y Motor Polifónico)
- [ ] Actualizar `MeasureEntity.isValidMeasure` para calcular la unión de ticks ocupados.
- [ ] Implementar `PolyphonicTranscriptionEngine` con:
  - `start({required SongPackage initialPackage, ...})`
  - `processMultiToneFrame({required List<String> activeNoteNames, int currentSubTick, double rms})`
  - `flushPendingChord()`
  - `stop()`

### Paso 2: Orquestacion en TunnerViewModel
- [ ] Incorporar `final PolyphonicTranscriptionEngine _polyphonicTranscriptionEngine`.
- [ ] Exponer getter `bool get isPolyphonicTranscriptionActive`.
- [ ] Agregar método reactivo `togglePolyphonicLiveTranscription()`.
- [ ] Enlazar el procesamiento de frames PCM multitono con el motor polifónico.

### Paso 3: Pruebas Automatizadas y Verificacion
- [ ] Escribir `test/features/transcription/polyphonic_transcription_engine_test.dart` verificando:
  - Transcripción de tríada de Do Mayor (Do4, Mi4, Sol4).
  - Transcripción secuencial de acordes en compás cuaternario.
  - Transcripción mixta de silencios y notas sostenidas.
- [ ] Ejecutar `flutter analyze` (0 issues).
- [ ] Ejecutar `flutter test` (100% passing).

---

## 4. Criterios de Aceptacion y Definition of Done (DoD)

1. Cero imports de Flutter o plugins en las entidades de dominio.
2. Cero emojis en código y comentarios.
3. 100% de la suite de pruebas automatizadas aprobada sin regresiones.
4. Documentación referenciada en `README.md`.
