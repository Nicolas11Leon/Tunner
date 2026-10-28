# Plan de Implementación: Exportador Canónico de Partituras en PDF Vectorial

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-PDF-EXPORTER-2026-001`
- **Título de la Implementación:** Exportador Canónico de Partituras a PDF Imprimible (ISO 32000-1)
- **Fase del Proyecto:** Fase 9.1 (Exportación Simétrica de Partituras PDF)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0026](../04_adrs/0026_canonical_pdf_sheet_music_vector_exporter.md)
- **Documento Funcional Base:** [doc_canonical_pdf_sheet_music_exporter.md](../01_product_vision/doc_canonical_pdf_sheet_music_exporter.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Desarrollar un serializador canónico de partituras en Pure Dart capaz de compilar cualquier estructura `HierarchicalScore` en un archivo binario PDF imprimible (ISO 32000-1), estructurado en sistemas de pentagramas de 5 líneas, claves, métricas, notas con plicas direccionales y silencios, permitiendo al usuario exportar e imprimir sus partituras desde Tunner.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido:**
  - Creación de `lib/features/universal_importer/domain/canonical_pdf_exporter.dart`.
  - Geometría de pentagramas de 5 líneas, barras de compás, cabezas de nota según duración, plicas estándar, líneas adicionales y silencios.
  - Distribución de 4 compases por sistema en página A4 ($595.28 \times 841.89\text{ pt}$) con paginación automática.
  - Estructuración de objetos PDF (Catálogo, Páginas, Contenido vectorial, Fuentes Type 1, xref, trailer).
  - Integración en `TunerViewModel.exportActiveScoreToPdf()`.
  - Integración en `ScoreEditorModal` con botón "PDF" (`export_pdf_btn`).
  - Pruebas unitarias completas de exportación, validez de bytes y prueba de integración de ida y vuelta (*round-trip*) con `PdfScoreParser`.
- **Excluido:**
  - Edición WYSIWYG de maquetación de página (márgenes personalizados por usuario), reservado para fases editoriales posteriores.

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.5`
- **Flutter SDK:** Canal oficial estable.
- **Dependencias:** `archive: ^4.5.2` (ya presente en pubspec.yaml para compresión ZLib si se requiere).
- **Riesgo Tecnológico:** Ninguno. 100% código Dart estándar, sin FFI, sin enlaces de red, determinista y seguro.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Serializador PDF Canónico)
- [x] Crear `lib/features/universal_importer/domain/canonical_pdf_exporter.dart`:
  - Definición de constantes geométricas A4 ($595.28 \times 841.89\text{ pt}$), espacio de pentagrama $sp = 8.0\text{ pt}$, márgenes.
  - Generación de comandos de flujo gráfico PDF (`m`, `l`, `re`, `c`, `S`, `f`, `BT`, `ET`, `Tf`, `Tj`).
  - Mapeo de grados diatónicos ($C_4$ a $B_5$) a coordenadas verticales $y$.
  - Generación de cabezas de nota (huecas/sólidas), plicas direccionales, líneas adicionales y silencios.
  - Paginación dinámica en páginas de 4 sistemas por página.
  - Ensamblado de tabla `xref` y trailer con offsets de bytes exactos.
- [x] Pruebas unitarias de dominio en `test/features/universal_importer/canonical_pdf_exporter_test.dart`:
  - Cabecera `%PDF-`.
  - Estructura de catálogo, páginas y objetos.
  - Validación de pentagramas, notas y silencios.
  - Integración de ida y vuelta con `PdfScoreParser`.

### Paso 2: Capa de Orquestación y ViewModel
- [x] Actualizar `lib/features/tuner_viewmodel.dart`:
  - Inyectar `CanonicalPdfExporter`.
  - Añadir método `Uint8List exportActiveScoreToPdf()`.

### Paso 3: Capa de Presentación e Interfaz
- [x] Actualizar `lib/features/score_editor/presentation/score_editor_modal.dart`:
  - Añadir botón de exportación "PDF" con icono `Icons.picture_as_pdf` y key `export_pdf_btn`.
  - Notificación SnackBar con tamaño en KB generado.
- [x] Pruebas de UI/Widgets en `test/features/universal_importer/pdf_export_ui_test.dart`.

### Paso 4: Verificación, Compilación y Aprobación
- [x] 100% de pruebas pasando.
- [x] `flutter analyze` / `dart analyze` sin errores de compilación ni advertencias.
- [x] Cero emojis en código, comentarios y commits.

---

## 4. Criterios de Aceptación (Definition of Done)

- [x] Archivos PDF generados conformes con el estándar ISO 32000-1 (%PDF-1.4).
- [x] Validación de lectura mediante `PdfScoreParser` de las partituras exportadas.
- [x] Suite completa de pruebas pasando.
- [x] Documentación técnica, caso de uso y ADR completos.
