# Auditoría Forense MCP: Pedagogía (Ebbinghaus y Estabilidad Vocal), Perfiles Adaptativos, Reportes PDF y Evaluador de Práctica

**Módulos Auditados:** `lib/features/pedagogy/` (5 archivos), `lib/features/pedagogy_profiles/` (4 archivos), `lib/features/pedagogy_report/` (3 archivos) y `lib/features/practice_evaluator/` (6 archivos)  
**Total de Archivos `.dart` Inspeccionados:** 18  
**Casos de Uso Canónicos Asociados:** `UC-009`, `UC-010`, `UC-033`, `UC-034`, `UC-112`, `UC-113`, `UC-129`, `UC-135`, `UC-169`, `UC-170`, `UC-178`  
**Alcance:** Preparación para ejecución Headless Pure Dart y exposición de capacidades mediante Model Context Protocol (MCP).

---

## 1. Inventario Archivo por Archivo

### 1.1 Módulo `lib/features/pedagogy/`

| Archivo `.dart` | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso |
| :--- | :--- | :--- | :--- | :--- |
| `domain/ear_training_item_entity.dart` | Domain (Pure Dart) | `EarTrainingCategory`, `EarTrainingItemEntity` | `retentionAt(DateTime)`, `isDue(DateTime)`, `copyWith()`, `toJson()`, `fromJson()` (Curva de Ebbinghaus `R(t) = exp(-t / S)`) | `UC-112`, `UC-170` |
| `domain/ebbinghaus_spaced_repetition_engine.dart` | Domain (Pure Dart) | `EarTrainingEvaluationResult`, `EbbinghausSpacedRepetitionEngine` | `getDueItems()`, `calculateQualityGrade()`, `submitAnswer()`, `overallRetentionAverage()`, `exportItemsJson()`, `restoreFromItemsJson()`, `reset()` (banco canónico de 17 ítems: 13 intervalos, 2 microtonos, 2 tríadas) | `UC-112`, `UC-170` |
| `domain/vocal_evaluation_result.dart` | Domain (Pure Dart) | `VocalEvaluationResult` | Constructor con cálculo automático de sello criptográfico `payloadHashSha256` vía `package:crypto` | `UC-113`, `UC-178` |
| `domain/vocal_stability_evaluator.dart` | Domain (Pure Dart) | `VocalStabilityEvaluator` | `evaluate()`, `_computeJitter()`, `_computeShimmer()`, `_analyzeVibrato()`, `_computeOverallScore()` | `UC-113`, `UC-178` |
| `infrastructure/pedagogical_certificate_pdf_generator.dart` | Infrastructure (Pure Dart) | `PedagogicalCertificatePdfGenerator` | `generateCertificatePdf()`, `sanitizePdfText()` (generador binario PDF 1.4 ISO 32000-1 sin dependencias externas) | `UC-113` |

### 1.2 Módulo `lib/features/pedagogy_profiles/`

| Archivo `.dart` | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso |
| :--- | :--- | :--- | :--- | :--- |
| `domain/learner_profile_entity.dart` | Domain (Pure Dart) | `LearnerProfileType`, `FeedbackStyle`, `VisualDensityLevel`, `LearnerProfileEntity` | Presets `child()`, `adult()`, `conservatory()`, `copyWith()`, `toJson()`, `fromJson()` | `UC-034` |
| `domain/i_adaptive_scaffolding_engine.dart` | Domain (Pure Dart) | `IAdaptiveScaffoldingEngine` | `computeEffectiveTolerance()`, `isNoteInTune()`, `evaluateNote()` | `UC-034` |
| `domain/adaptive_scaffolding_engine.dart` | Domain (Pure Dart) | `PedagogicalDiagnosticResult`, `AdaptiveScaffoldingEngine` | `computeEffectiveTolerance()` (scaffolding fade-out cada 3 aciertos), `isNoteInTune()`, `evaluateNote()` (diagnóstico lúdico, biomecánico o microtonal + ajuste sugerido de BPM) | `UC-034` |
| `presentation/learner_profile_selector_modal.dart` | Presentation (Flutter) | `LearnerProfileSelectorModal` | `show()`, `build()` (selector visual de presets y calibración en `TunerViewModel`) | `UC-034` |

### 1.3 Módulo `lib/features/pedagogy_report/`

| Archivo `.dart` | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso |
| :--- | :--- | :--- | :--- | :--- |
| `domain/pedagogical_report_models.dart` | Domain (Pure Dart) | `TimedCentsSample`, `PedagogicalSessionData`, `PedagogicalReportConfig` | `PedagogicalSessionData.sample()`, `toJson()`, `fromJson()`, `copyWith()` | `UC-033`, `UC-169` |
| `domain/pedagogical_report_pdf_generator.dart` | Domain (Pure Dart) | `PedagogicalReportPdfGenerator` | `generateReportPdf()` (PDF 1.4 de 2 páginas: informe analítico con curva de cents, histograma H1-H8, diagnóstico con word-wrap + certificado con sello SHA-256 `TN-...`) | `UC-033`, `UC-169` |
| `presentation/pedagogical_report_modal.dart` | Presentation (Flutter) | `PedagogicalReportModal`, `_PedagogicalReportModalState` | `show()`, `build()` (formulario de configuración y exportación de PDF conectado a `TunerViewModel.currentPedagogicalSessionData`) | `UC-033` |

### 1.4 Módulo `lib/features/practice_evaluator/`

| Archivo `.dart` | Capa | Clases / Enums Principales | Métodos / Funciones Clave | Casos de Uso |
| :--- | :--- | :--- | :--- | :--- |
| `domain/note_evaluation_entity.dart` | Domain (Pure Dart) | `NoteTimingCategory`, `NoteEvaluationEntity` | `isHit` (métricas de pitch 45%, rhythm 30%, sustain 25%, transposición `soundingExpectedNoteName`) | `UC-009`, `UC-010`, `UC-169` |
| `domain/practice_report_entity.dart` | Domain (Pure Dart) | `RhythmTendency`, `PerformanceGrade`, `PracticeReportEntity` | `PerformanceGrade.fromScore()`, `toMap()`, `fromMap()` (desglose `noteAccuracyMap`, `criticalNotes`, `masteredNotes`, tendencia vs sesión previa) | `UC-009`, `UC-010`, `UC-169` |
| `domain/i_practice_evaluator_service.dart` | Domain (Pure Dart) | `IPracticeEvaluatorService` | `evaluateNote()`, `generateReport()` | `UC-009`, `UC-010` |
| `domain/practice_evaluator_service.dart` | Domain (Pure Dart) | `PracticeEvaluatorService` | `evaluateNote()` (normalización enarmónica por frecuencia MIDI, ventana rítmica +/-80 ms), `generateReport()` (detección de rushing/dragging +/-25 ms y tendencia) | `UC-009`, `UC-010`, `UC-169` |
| `data/practice_evaluator_service.dart` | Data (Re-export) | Re-export de `../domain/practice_evaluator_service.dart` | Compatibilidad hacia atrás | `UC-009` |
| `presentation/practice_report_modal.dart` | Presentation (Flutter) | `PracticeReportModal` | `show()`, `build()` (diálogo de calificación S/A/B/C/D, métricas multidimensionales y reproducción de grabación) | `UC-009`, `UC-010` |

---

## 2. Auditoría de Brechas (Gaps) y Preparación Headless (MCP-Readiness)

### 2.1 Acoplamientos con `package:flutter/` y `dart:ui`

| Archivo | Import Bloqueante | Impacto en CLI Pure Dart | Severidad |
| :--- | :--- | :--- | :--- |
| `pedagogy/domain/*` e `infrastructure/*` (5 archivos) | Ninguno (solo `dart:math`, `dart:convert`, `dart:typed_data`, `package:crypto/crypto.dart`) | 100% ejecutable en CLI Pure Dart | Baja (Listo) |
| `pedagogy_profiles/domain/*` (3 archivos) | Ninguno (0 imports Flutter/UI) | 100% ejecutable en CLI Pure Dart | Baja (Listo) |
| `pedagogy_report/domain/*` (2 archivos) | Ninguno (solo `dart:convert`, `dart:math`, `dart:typed_data`, `package:crypto/crypto.dart`) | 100% ejecutable en CLI Pure Dart | Baja (Listo) |
| `practice_evaluator/domain/*` y `data/*` (5 archivos) | Ninguno (dependencias `score_tree.dart`, `note_entity.dart`, `practice_recording_entity.dart` verificadas con 0 imports Flutter/UI) | 100% ejecutable en CLI Pure Dart | Baja (Listo) |
| `pedagogy_profiles/presentation/*`, `pedagogy_report/presentation/*`, `practice_evaluator/presentation/*` (3 archivos) | `package:flutter/material.dart`, `provider` | Exclusivos de UI; no se importan en MCP | Informativa |

**Conclusión de Pureza:** Este bloque de 4 módulos es el más maduro arquitectónicamente para ejecución Headless Pure Dart: 15 de 18 archivos (100% de la lógica de negocio, DSP vocal, Ebbinghaus, scaffolding, evaluación multidimensional y compilación binaria PDF ISO 32000-1) corren sin ningún cambio en Dart CLI puro.

### 2.2 Brechas Funcionales, de Serialización y de Orquestación IA

1. **Serialización JSON Incompleta en Entidades Clave:**
   - `VocalEvaluationResult` (en `pedagogy/domain/`) no tiene `toJson()`/`fromJson()`.
   - `EarTrainingEvaluationResult` (en `ebbinghaus_spaced_repetition_engine.dart`) no tiene `toJson()`.
   - `PedagogicalDiagnosticResult` (en `adaptive_scaffolding_engine.dart`) no tiene `toJson()`.
   - `NoteEvaluationEntity` no tiene `toMap()`/`toJson()`, y `PracticeReportEntity.toMap()` omite deliberadamente la lista `evaluations` (en `fromMap` la restaura siempre como `const []`), perdiendo la granularidad nota por nota al persistir o enviar a un agente IA.

2. **Colisión Nominal de Enums `PerformanceGrade`:**
   - Existe `PerformanceGrade` en `lib/features/ear_training/domain/ear_training_exercise.dart` (`sGrade`, `aGrade`, `bGrade`, `cGrade`, `fGrade`) y otro `PerformanceGrade` distinto en `lib/features/practice_evaluator/domain/practice_report_entity.dart` (`s`, `a`, `b`, `c`, `d`). Al ensamblar un servidor MCP que importe ambos dominios habrá colisión de nombres si no se usan aliases o se renombran explícitamente.

3. **Sin Persistencia Headless para `EbbinghausSpacedRepetitionEngine` ni Historial de `PracticeReportEntity`:**
   - Aunque `EbbinghausSpacedRepetitionEngine` ya cuenta con `exportItemsJson()` y `restoreFromItemsJson()`, la persistencia a disco depende actualmente del ciclo de autosave de `TunerViewModel` (Flutter). En un servidor MCP Pure Dart se necesita un repositorio JSON local (archivo en el directorio de proyecto/perfil) para que la curva de olvido persista entre sesiones del agente IA.

4. **Construcción de `PedagogicalSessionData` Acoplada a `TunerViewModel` / `_scoreEditorController`:**
   - `PedagogicalReportPdfGenerator` es 100% Pure Dart, pero la agregación de métricas reales hacia `PedagogicalSessionData` (combinando `PracticeReportEntity`, timbre H1-H8, centroide espectral, THD y jitter rítmico) se dispara desde `TunerViewModel.currentPedagogicalSessionData`. Hace falta un ensamblador Pure Dart (`PedagogicalSessionDataBuilder`) que convierta directamente un `PracticeReportEntity` + `VocalEvaluationResult` / telemetría en `PedagogicalSessionData`.

5. **Limitaciones de `VocalStabilityEvaluator` y `PedagogicalCertificatePdfGenerator`:**
   - `VocalStabilityEvaluator.evaluate()` recibe arrays ya extraídos de `frequenciesHz` y `amplitudes` a tasa fija `analysisFrameRateHz` (default 50 Hz). Para que un agente MCP evalúe directamente un archivo WAV o buffer PCM real, necesita una fachada que conecte el detector de pitch (`YIN`/autocorrelación) + RMS frame-by-frame hacia `VocalStabilityEvaluator`.
   - `PedagogicalReportPdfGenerator` y `PedagogicalCertificatePdfGenerator` devuelven `Uint8List` en memoria; el servidor MCP deberá escribirlos a un archivo `.pdf` en ruta autorizada del workspace o devolver ruta + hash SHA-256 verificable (evitando saturar el contexto del LLM con PDFs en base64 gigantes).

6. **Desconexión entre `PracticeEvaluatorService` y `AdaptiveScaffoldingEngine`:**
   - `PracticeEvaluatorService.evaluateNote()` recibe un `toleranceCents` estático (default `15.0`) y no consume `LearnerProfileEntity` ni genera el diagnóstico formativo (`biomechanicalCue`, `suggestedBpmAdjustment`) de `AdaptiveScaffoldingEngine`, ni alimenta notas críticas (`criticalNotes`) hacia el generador de ejercicios o Ebbinghaus.

---

## 3. Especificación de Primitivos MCP

### 3.1 Resources (`tunner://...`)

| URI | Descripción | Estructura JSON |
| :--- | :--- | :--- |
| `tunner://pedagogy/ebbinghaus/bank` | Estado completo del banco de ítems de repetición espaciada (17 ítems canónicos + personalizados) con retención actual `R(t)`. | `{ "overallRetention": number, "evaluatedAt": "ISO-8601", "items": [{ "id": "interval_M3", "name": "Tercera Mayor", "category": "interval", "stabilityDays": number, "easeFactor": number, "repetitions": int, "lapses": int, "retention": number, "isDue": bool, "nextReviewDate": "ISO-8601" }] }` |
| `tunner://pedagogy/ebbinghaus/due` | Cola priorizada de ítems vencidos ordenados de menor a mayor retención cognitiva (mayor urgencia pedagógica primero). | `{ "dueCount": int, "targetRetention": 0.90, "items": EarTrainingItemJson[] }` |
| `tunner://pedagogy/profiles/presets` | Presets oficiales de perfiles de aprendizaje (`childPlayful`, `adultDeliberate`, `conservatoryMastery`) y sus parámetros de andamiaje. | `{ "presets": [LearnerProfileEntityJson] }` |
| `tunner://pedagogy/profiles/active` | Perfil pedagógico actualmente activo en el workspace/sesión del estudiante. | `LearnerProfileEntityJson` (`type`, `centsTolerance`, `feedbackStyle`, `visualDensity`, `enableSmartWait`, `enableScaffoldingFadeOut`) |
| `tunner://practice/reports/latest` | Último `PracticeReportEntity` generado en el workspace con notas críticas, tendencia y calificación. | `PracticeReportEntity.toMap()` + `evaluations[]` |

### 3.2 Tools (`tunner_*`)

| Tool MCP | Parámetros (JSON Schema Resumido) | Salida JSON | Mapeo Exacto a Tunner |
| :--- | :--- | :--- | :--- |
| `tunner_ebbinghaus_submit_answer` | `{ "itemId": string, "isCorrect": bool, "centsError": number, "responseTimeSeconds": number, "timestamp"?: "ISO-8601" }` | `{ "qualityGrade": int (0..5), "previousRetention": number, "nextRetentionProjected": number, "cognitiveFeedback": string, "updatedItem": EarTrainingItemJson }` | `EbbinghausSpacedRepetitionEngine.submitAnswer()` |
| `tunner_ebbinghaus_add_item` | `{ "id": string, "name": string, "category": "interval"|"chord"|"microtone"|"pitch", "semitones": number, "centsDeviation": number }` | `{ "added": true, "item": EarTrainingItemJson }` | `EbbinghausSpacedRepetitionEngine.addItem()` |
| `tunner_evaluate_vocal_stability` | `{ "frequenciesHz": number[], "amplitudes": number[], "targetFrequencyHz": number, "analysisFrameRateHz"?: number (50.0), "evaluationId"?: string }` | `{ "evaluationId": string, "measuredMeanFrequencyHz": number, "centsDeviation": number, "jitterPercent": number, "shimmerPercent": number, "vibratoRateHz": number, "vibratoDepthCents": number, "overallScore": number, "classificationLabel": string, "payloadHashSha256": string }` | `VocalStabilityEvaluator.evaluate()` |
| `tunner_scaffolding_evaluate_note` | `{ "centsDeviation": number, "profile": "child"|"adult"|"conservatory"|LearnerProfileJson, "consecutiveSuccesses"?: int (0), "consecutiveErrors"?: int (0) }` | `{ "isInTune": bool, "effectiveToleranceCents": number, "primaryFeedback": string, "biomechanicalCue": string?, "motivationalCue": string, "suggestedBpmAdjustment": int?, "scaffoldingLevel": int (1..5) }` | `AdaptiveScaffoldingEngine.evaluateNote()` |
| `tunner_practice_evaluate_session` | `{ "songTitle": string, "instrumentName"?: string, "toleranceCents"?: number (15.0), "notes": [{ "expectedNoteName": string, "soundingExpectedNoteName"?: string, "isRest"?: bool, "detectedNoteName": string, "detectedFrequency": number, "detectedCents": number, "timingDeltaMs": int, "sustainRatio"?: number }], "previousSession"?: PracticeReportJson }` | `PracticeReportEntity` JSON (`overallScore`, `grade`, `pitchAccuracyPercentage`, `rhythmAccuracyPercentage`, `rhythmTendency`, `sustainAccuracyPercentage`, `criticalNotes`, `masteredNotes`, `trendAnalysisText`, `evaluations`) | `PracticeEvaluatorService.evaluateNote()` + `PracticeEvaluatorService.generateReport()` |
| `tunner_export_vocal_certificate_pdf` | `{ "studentName": string, "evaluation": VocalEvaluationResultJson, "outputPath": string }` | `{ "outputPath": string, "byteLength": int, "payloadHashSha256": string }` | `PedagogicalCertificatePdfGenerator.generateCertificatePdf()` |
| `tunner_export_pedagogical_report_pdf` | `{ "session": PedagogicalSessionDataJson, "config": PedagogicalReportConfigJson, "outputPath": string }` | `{ "outputPath": string, "byteLength": int, "pages": int, "masteryLevel": string }` | `PedagogicalReportPdfGenerator.generateReportPdf()` |

### 3.3 Prompts (Flujos Guiados para Agentes IA)

1. **`conservatory_vocal_exam_and_certification`**:
   - **Objetivo:** Realizar un examen formal de estabilidad vocal (nota tenida), emitir dictamen clínico-acústico y generar el certificado PDF con sello SHA-256.
   - **Flujo:** Extrae serie de pitch/amplitud -> ejecuta `tunner_evaluate_vocal_stability` -> contrasta jitter (`<= 1.0%`), shimmer (`<= 3.5%`) y vibrato (`4.5-7.0 Hz`, `25-75 cents`) -> si `overallScore >= 65.0`, genera el certificado con `tunner_export_vocal_certificate_pdf` -> si detecta fallos, diagnostica pautas biomecánicas con `tunner_scaffolding_evaluate_note`.
2. **`deliberate_practice_post_mortem`**:
   - **Objetivo:** Analizar una sesión completa de práctica de partitura, detectar tendencias de pulso (*rushing*/*dragging*) y prescribir ejercicios correctivos.
   - **Flujo:** Ejecuta `tunner_practice_evaluate_session` -> identifica `criticalNotes` y `rhythmTendency` -> ajusta tolerancia/BPM con `tunner_scaffolding_evaluate_note` -> recomienda ejercicios específicos (con `tunner_generate_exercise`) y genera reporte oficial con `tunner_export_pedagogical_report_pdf`.
3. **`ebbinghaus_daily_review_planner`**:
   - **Objetivo:** Planificar la sesión diaria de estudio auditivo basada en retención cognitiva.
   - **Flujo:** Lee `tunner://pedagogy/ebbinghaus/due` -> prioriza los 5 ítems con menor `retention` -> registra cada intento con `tunner_ebbinghaus_submit_answer` -> reporta ganancia de retención global (`overallRetention`).

---

## 4. Plan de Ajustes Técnicos Previos (Pre-MCP)

1. **Completar Serialización JSON Canónica en los 4 Módulos:**
   - Añadir `toJson()` / `fromJson()` a `VocalEvaluationResult`, `EarTrainingEvaluationResult`, `PedagogicalDiagnosticResult` y `NoteEvaluationEntity`.
   - Incluir `evaluations` (opcional mediante flag `includeEvaluations: true`) en `PracticeReportEntity.toMap()` y restaurarlo en `fromMap()`.
2. **Resolver Colisión Nominal de `PerformanceGrade`:**
   - Renombrar o exponer aliases explícitos en la capa de barrido/exportación (`EarTrainingPerformanceGrade` vs `PracticePerformanceGrade`) para evitar conflictos de símbolos en el paquete del servidor MCP.
3. **Crear Repositorio Headless de Persistencia Pedagógica (`IPedagogyStateStore`):**
   - Implementar un adaptador en Pure Dart (`dart:io` JSON atómico en el workspace) para persistir `EbbinghausSpacedRepetitionEngine.exportItemsJson()`, el `LearnerProfileEntity` activo y el historial de `PracticeReportEntity` sin depender de `TunerViewModel` ni `SharedPreferences` de Flutter.
4. **Extraer `PedagogicalSessionDataBuilder` Pure Dart:**
   - Desacoplar la construcción de `PedagogicalSessionData` desde `TunerViewModel.currentPedagogicalSessionData` hacia una clase pura de dominio en `lib/features/pedagogy_report/domain/` que reciba `PracticeReportEntity`, métricas espectrales y muestras de cents directamente.
5. **Añadir Fachada PCM -> `VocalStabilityEvaluator`:**
   - Crear un método de conveniencia en infraestructura/dominio que reciba PCM crudo (`Float32List` + `sampleRate`), ejecute el detector de pitch frame-a-frame (ventana de 20 ms / 50 Hz) y alimente directamente a `VocalStabilityEvaluator.evaluate()`.
6. **Integrar `LearnerProfileEntity` en `PracticeEvaluatorService`:**
   - Permitir que `PracticeEvaluatorService.evaluateNote()` acepte opcionalmente un `LearnerProfileEntity` + `IAdaptiveScaffoldingEngine` para aplicar tolerancia adaptativa (`scaffolding fade-out`) y adjuntar pautas biomecánicas y sugerencias de BPM directamente en el reporte.
