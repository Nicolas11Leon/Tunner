# Plan de Implementación: Generador de Reportes y Certificados Pedagógicos en PDF

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-PEDAGOGY-2026-033`
- **Título de la Implementación:** Generador de Reportes de Progreso Acústico y Certificados de Logro en PDF Vectorial (ISO 32000-1)
- **Fase del Proyecto:** Fase 13 (Analítica Pedagógica y Certificación Formal)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0029](../04_adrs/0029_pedagogical_progress_and_certificate_pdf_report.md)
- **Documento Funcional Base:** [doc_pedagogical_progress_and_certificate_pdf_report.md](../01_product_vision/doc_pedagogical_progress_and_certificate_pdf_report.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Implementar un motor de exportación de documentos PDF vectoriales (ISO 32000-1) 100% offline y en Dart puro, capaz de compilar un informe analítico de práctica musical (curvas de entonación en cents, distribución armónica de 8 parciales, jitter de metrónomo y diagnósticos formativos) y un Certificado de Logro de Conservatorio con orla ornamental geométrica y código de validación.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades de dominio puras: `PedagogicalReportConfig`, `PedagogicalSessionData`, `TimedCentsSample`.
  - Generador vectorial Pure Dart: `PedagogicalReportPdfGenerator`.
  - Interfaz gráfica: `PedagogicalReportModal` con formulario de metadatos, selector de opciones y previsualización.
  - Orquestación en `TunerViewModel` para sintetizar los datos de la sesión activa y permitir exportación a `Uint8List`.
  - Chips y botones de acceso en `TunerScreen` y en la barra de práctica.
  - Pruebas unitarias de dominio y pruebas de widgets/UI.
- **Excluido (Out-of-Scope):**
  - Envío automático de correos electrónicos o sincronización en la nube (la plataforma preserva su política 100% offline y privada).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`.
  - Flutter SDK: Canal estable oficial.
- **Riesgo Tecnológico:**
  - Cero dependencias nativas adicionales; reutiliza la infraestructura de compilación de sintaxis PDF vectorial pura ya probada en el proyecto.
  - Cero bucles de espera activa (no busy-waiting).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Entidades Puras y Generador Vectorial PDF)
- [x] Crear `lib/features/pedagogy_report/domain/pedagogical_report_models.dart`:
  - `TimedCentsSample`: Muestra de tiempo y desviación en cents.
  - `PedagogicalSessionData`: Agregado de métricas acústicas, armónicos, jitter y recomendaciones formativas.
  - `PedagogicalReportConfig`: Configuración del estudiante, instrumento, institución y banderas de inclusión.
- [x] Crear `lib/features/pedagogy_report/domain/pedagogical_report_pdf_generator.dart`:
  - Compilador de bajo nivel de sintaxis ISO 32000-1 (PDF-1.4).
  - Página 1: Membrete, tarjetas KPI, curva continua de entonación con bandas de tolerancia ($\pm 5$ cents), barras de armónicos y caja de diagnóstico.
  - Página 2 (opcional): Orla ornamental vectorial, certificado formal y sello de validación.
  - Tabla de referencias cruzadas (`xref`), objeto `Catalog` y marca `%%EOF`.
- [x] Pruebas unitarias de dominio en `test/features/pedagogy_report/pedagogical_report_pdf_generator_test.dart`.

### Paso 2: Capa de Presentación (Modal y Controles Interactivos)
- [x] Crear `lib/features/pedagogy_report/presentation/pedagogical_report_modal.dart`:
  - Formulario con campos de texto para estudiante, instrumento e institución.
  - Selectores para incluir curva de afinación, histograma de armónicos, análisis de jitter y Certificado de Logro.
  - Botón de exportación con confirmación de tamaño generado en kilobytes.
- [x] Extender `TunerViewModel`:
  - Getter `currentPedagogicalSessionData` consolidando los datos vivos del afinador, analizador de armónicos, grabadora de práctica y metrónomo.
  - Método `exportPedagogicalReportPdf(PedagogicalReportConfig config)`.
- [x] Integrar botón / chip en `TunerScreen` y dock de práctica.

### Paso 3: Pruebas, Verificación y Aprobación
- [x] Pruebas de integración UI en `test/features/pedagogy_report/pedagogical_report_ui_test.dart`.
- [x] Verificar 100% de la suite de pruebas pasando (`flutter test`).
- [x] Verificar `flutter analyze` limpio sin advertencias ni errores.
- [x] Merge a `main` con `--no-ff`.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- Si surge alguna regresión o conflicto de renderizado, se revierte al commit base de `main` mediante Git sin alterar los módulos de audio o partituras.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md) (cero emojis, nombres rigurosos, Clean Architecture).
- [x] Generación de PDF válida y reproducible en cualquier visor estándar.
- [x] Cobertura de pruebas unitarias y de interfaz superando el 90%.
- [x] Documentación canónica completa en `docs/`.
