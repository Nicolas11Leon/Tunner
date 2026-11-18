# Plan de Implementación: Asistente de Evaluación Vocal y Certificados PDF Canónicos

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE8-VOCAL-PDF-2026-0102`
- **Título de la Implementación:** Asistente de Evaluación de Afinación y Emisión Vocal con Certificados PDF Canónicos
- **Fase del Proyecto:** Fase 8 (Suite Pedagógica y Analítica Cognitiva)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0102](../04_adrs/0102_vocal_evaluation_and_pdf_certificates.md)
- **Documento Funcional Base:** [Caso de Uso 113](../02_use_cases/113_uc_vocal_evaluation_and_pdf_certificates.md)
- **Issue Asociado:** [#40](https://github.com/Nicolas11Leon/Tunner/issues/40)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Construir en Dart puro dentro de `lib/features/pedagogy/domain/` el evaluador acústico fonatorio `VocalStabilityEvaluator` y el generador vectorial autónomo de documentos PDF-1.4 `PedagogicalCertificatePdfGenerator` con sellado criptográfico SHA-256, integrándolo en `TunnerOsKernel` para emisión y certificación interactiva de desempeño vocal.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad `VocalEvaluationResult` con métricas de afinación, Jitter %, Shimmer %, tasa de vibrato Hz, extensión de vibrato cents y puntuación global.
  - Clase `VocalStabilityEvaluator` que analiza secuencias de tonos y amplitudes.
  - Clase `PedagogicalCertificatePdfGenerator` que emite documentos binarios PDF-1.4 con estructura válida, tablas y firma SHA-256.
  - Comando `vocal` en `TunnerOsKernel` (`vocal eval`, `vocal cert`).
  - Pruebas unitarias de cálculo de jitter/shimmer y validación estructural de la sintaxis binaria PDF.
- **Excluido (Out-of-Scope):**
  - Ninguno. Completa la totalidad de la Fase 8 del proyecto.

---

## 2. Análisis de Dependencias y Tecnologías

- **Lenguaje:** Dart puro (Domain Layer).
- **Criptografía:** `package:crypto` para cálculo SHA-256.
- **Formato:** ISO 32000-1 / PDF-1.4 nativo en Dart puro sin dependencias externas.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Entidad de Métricas Vocales (`vocal_evaluation_result.dart`)
- Modelo inmutable con `targetFrequencyHz`, `measuredMeanFrequencyHz`, `centsDeviation`, `jitterPercent`, `shimmerPercent`, `vibratoRateHz`, `vibratoDepthCents`, `overallScore`, `classificationLabel`.

### Paso 2: Evaluador de Estabilidad Fonatoria (`vocal_stability_evaluator.dart`)
- Algoritmo de cálculo de periodos fundamentales $T_i = 1 / f_i$.
- Algoritmo de cálculo de jitter local y relativo ciclo a ciclo.
- Algoritmo de cálculo de shimmer local ciclo a ciclo sobre amplitudes.
- Algoritmo de extracción de envolvente de vibrato (frecuencia de modulación y excursión en cents).
- Fórmula de puntuación integral sobre 100.

### Paso 3: Generador Vectorial de Certificados PDF (`pedagogical_certificate_pdf_generator.dart`)
- Ensamblaje de sintaxis binaria PDF-1.4:
  - Header `%PDF-1.4`
  - Objetos indirectos: `Catalog`, `Pages`, `Page`, `Font` (Helvetica), `Contents` stream.
  - Flujo de contenido con comandos gráficos PDF (`BT`, `ET`, `Tf`, `Tm`, `Tj`, `re`, `f`, `m`, `l`, `S`).
  - Tabla de referencias cruzadas `xref` con offsets de bytes precisos.
  - Trailer con `Root` y `Size`.
  - Firma digital SHA-256 estampada en el documento.

### Paso 4: Integración en `TunnerOsKernel` CLI
- Registrar comando `vocal`:
  - `vocal eval <target_hz>`: Ejecuta una evaluación simulada o con datos acústicos y muestra telemetría.
  - `vocal cert <nombre_estudiante> [target_hz]`: Genera y exporta el certificado PDF oficial en bytes.

### Paso 5: Pruebas Unitarias y de Regresión (`test/features/pedagogy/`)
- Crear `test/features/pedagogy/vocal_stability_and_pdf_test.dart`:
  - Pruebas matemáticas de jitter y shimmer en tonos sintéticos controlados.
  - Pruebas de extracción de vibrato sinusoidal.
  - Pruebas de estructura y validez de la sintaxis PDF generada (header, xref, trailer, hash SHA-256).
  - Pruebas de comandos CLI en `TunnerOsKernel`.

---

## 4. Criterios de Aceptación (Definition of Done)

1. Cálculo cuantitativo preciso de Jitter %, Shimmer % y parámetros de vibrato.
2. Generación de archivo PDF estructuralmente válido conforme a la especificación PDF-1.4 con cabecera, tabla xref y trailer.
3. Sello digital SHA-256 verificado criptográficamente.
4. Cobertura de pruebas unitarias al 100% pasando sin fallos.
5. `flutter analyze` sin advertencias.
