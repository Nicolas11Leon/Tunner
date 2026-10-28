# Plan de Implementación: Fase 9 - Motor de Importación de Partituras en PDF & OMR Vectorial

Este plan formaliza las tareas y pasos secuenciales para implementar la decodificación de documentos PDF de partituras, el reconocimiento óptico vectorial geométrico (Vector OMR), y su integración en Tunner.

---

## 1. Objetivos

1. Implementar `VectorOmrEngine` en `lib/features/universal_importer/domain/` para el análisis geométrico determinista de pentagramas, compases y alturas tonales a partir de primitivas vectoriales.
2. Implementar `PdfScoreParser` en `lib/features/universal_importer/data/` para la extracción de flujos de dibujo de documentos PDF.
3. Integrar `PdfScoreParser` en `UniversalScoreImporterService` con autodetección de firma `%PDF-` y extensión `.pdf`.
4. Actualizar `ScoreImportTabView` permitiendo la selección de archivos PDF e incorporando una muestra de partitura PDF canónica.
5. Crear suite de pruebas unitarias y de widgets con 100% de cobertura.

---

## 2. Tareas por Capa Arquitectónica

### Capa 1: Dominio Puro y Algoritmo OMR
- [x] Crear `lib/features/universal_importer/domain/vector_omr_engine.dart`:
  - Primitivas geométricas: `VectorLine`, `VectorRect`, `VectorPoint`.
  - Agrupamiento de 5 líneas paralelas equidistantes en `StaffSystem`.
  - Detección de barras de compás verticales divisorias.
  - Proyección de posición vertical $y$ a grados diatónicos de clave de Sol ($E_4$ a $F_5$, líneas adicionales para $C_4$ y $A_5$).
  - Cuantización rítmica en compases de 4/4 con notas `HierarchicalNote`.
  - Creación de `HierarchicalScore`.
- [x] Suite de pruebas de dominio en `test/features/universal_importer/vector_omr_engine_test.dart`.

### Capa 2: Parser de Archivos PDF y Flujos de Dibujo
- [x] Crear `lib/features/universal_importer/data/pdf_score_parser.dart`:
  - Detección de firma mágica `%PDF-` (`0x25, 0x50, 0x44, 0x46`) y extensión `.pdf`.
  - Descompresión de streams `FlateDecode` mediante paquete `archive` (`ZLibDecoder`).
  - Extracción y tokenización de operadores gráficos `re`, `m`, `l`, `c`.
  - Delegación a `VectorOmrEngine`.
  - Empaquetado en `ParsedScoreResult`.
- [x] Suite de pruebas del parser en `test/features/universal_importer/pdf_score_parser_test.dart`.

### Capa 3: Orquestación e Interfaz de Usuario
- [x] Actualizar `UniversalScoreImporterService` para incluir `PdfScoreParser`.
- [x] Actualizar `ScoreImportTabView` con selector `.pdf` y botón de prueba rápida de partitura PDF.
- [x] Suite de pruebas de UI en `test/features/universal_importer/pdf_import_ui_test.dart`.

---

## 3. Criterios de Aceptación (DoD)
- 100% de pruebas unitarias y de integración pasando.
- Cero issues en `flutter analyze`.
- Cero emojis en código fuente, comentarios y commits.
