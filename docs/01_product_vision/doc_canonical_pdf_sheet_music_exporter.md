# Especificación Técnica: Exportador Canónico de Partituras en PDF Vectorial

Este documento define la arquitectura integral, especificaciones funcionales y fundamentos algorítmicos para la generación y exportación de partituras en formato PDF vectorial estándar (ISO 32000-1) en **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-PDF-EXPORTER-2026-001`
- **Título Oficial:** Generador Vectorial Canónico de Partituras en Formato PDF Imprimible (ISO 32000-1)
- **Estado:** `Approved`
- **Fecha de Creación:** 2026-10-28
- **Fase Asociada:** `Fase 9.1 (Exportación Simétrica de Partituras PDF)`
- **Autor / Revisor Principal:** Nicolas Leon / Antigravity Engine

---

## 1. Resumen Ejecutivo (Executive Summary)

Tunner cuenta con un motor de reconocimiento óptico vectorial (Vector OMR) capaz de importar partituras desde archivos PDF. Para cerrar el ciclo simétrico de interoperabilidad universal de partituras, este módulo introduce el componente puro `CanonicalPdfExporter`.

El generador traduce cualquier estructura de partitura `HierarchicalScore` en un documento PDF vectorial binario puro (formato ISO 32000-1), estructurado en sistemas de pentagramas de 5 líneas, claves, métricas de compás, cabezas de nota según duración, plicas direccionales estándar, líneas adicionales automáticas, silencios y metadatos de título, compositor y tempo. Todo el proceso es 100% offline, opera en Pure Dart sin enlaces C/C++ ni dependencias externas propietarias, produciendo documentos listos para su impresión física en papel o visualización en cualquier visor PDF de escritorio o móvil.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 El Ecosistema de Publicación de Partituras
El estándar universal para distribución impresa y visualización de partituras para músicos de conservatorio, directores de orquesta y profesores es el formato Portable Document Format (PDF). Aunque MusicXML y MIDI son ideales para intercambio de datos de software, los intérpretes requieren documentos maquetados con proporciones exactas de espaciado musical para su atril.

### 2.2 Fundamentos Geométricos y Tipográficos de Notación
La generación de partituras en PDF se fundamenta en el sistema de coordenadas cartesianas de PostScript/PDF (donde el origen $(0,0)$ reside en la esquina inferior izquierda):
1. **Espacio de Pentagrama (Staff Space $sp$):**
   Se establece $sp = 8.0\text{ pt}$. La altura total del pentagrama de 5 líneas es:
   $$H_{\text{staff}} = 4 \cdot sp = 32.0\text{ pt}$$
2. **Proyección de Alturas Tonal a Coordenada Vertical $y$:**
   Para una línea base inferior del pentagrama en $y_{\text{base}}$ ($E_4$ en clave de Sol):
   $$y(\text{step}, \text{octave}) = y_{\text{base}} + \Delta_{\text{diatonic}} \cdot \left(\frac{sp}{2}\right)$$
   Donde cada grado diatónico asciende medio espacio ($4.0\text{ pt}$):
   - $C_4$ (Do central): $y_{\text{base}} - 8.0\text{ pt}$ (con línea adicional).
   - $D_4$: $y_{\text{base}} - 4.0\text{ pt}$.
   - $E_4$: $y_{\text{base}}$ (primera línea inferior).
   - $G_4$: $y_{\text{base}} + 8.0\text{ pt}$ (segunda línea).
   - $B_4$: $y_{\text{base}} + 16.0\text{ pt}$ (tercera línea o línea media).
   - $F_5$: $y_{\text{base}} + 32.0\text{ pt}$ (quinta línea o línea superior).
   - $A_5$: $y_{\text{base}} + 40.0\text{ pt}$ (con línea adicional superior).
3. **Regla de Dirección de Plicas (Stem Direction Rule):**
   - Notas con $y < y_{\text{line3}}$ ($B_4$): Plica hacia arriba en el lado derecho de la cabeza de nota ($x + w$), ascendiendo $3.5 \cdot sp = 28.0\text{ pt}$.
   - Notas con $y \ge y_{\text{line3}}$: Plica hacia abajo en el lado izquierdo de la cabeza de nota ($x$), descendiendo $28.0\text{ pt}$.
   - Redondas (Whole notes): Sin plica.
4. **Paginación Dinámica y Sistemas:**
   - Hoja A4 estándar: $595.28 \times 841.89\text{ pt}$.
   - Márgenes: $40\text{ pt}$ laterales, $50\text{ pt}$ superior e inferior.
   - Ancho útil del pentagrama: $W_{\text{staff}} = 595.28 - 2 \cdot 40 = 515.28\text{ pt}$.
   - Agrupamiento de compases: 4 compases por sistema. Cuando un sistema se completa, se desciende verticalmente con un espaciado inter-sistema $\Delta y = 70.0\text{ pt}$.
   - Salto de página automático si el siguiente sistema excede el margen inferior.

---

## 3. Especificación Funcional

### 3.1 Requisitos del Sistema
- **REQ-PDF-01:** Generar archivos binarios válidos compatibles con ISO 32000-1 (PDF 1.4).
- **REQ-PDF-02:** Renderizar encabezado con título centrado, compositor y marca de tempo (BPM).
- **REQ-PDF-03:** Dibujar pentagramas de 5 líneas paralelas continuas con clave de Sol y armadura.
- **REQ-PDF-04:** Dibujar barras de compás delimitadoras y barra doble final.
- **REQ-PDF-05:** Renderizar cabezas de nota proporcionales: rellenas para negras/corcheas, huecas para blancas/redondas.
- **REQ-PDF-06:** Trazar líneas adicionales (ledger lines) para notas fuera de los límites del pentagrama ($C_4, A_5$, etc.).
- **REQ-PDF-07:** Renderizar plicas orientadas y banderas para corcheas/semicorcheas.
- **REQ-PDF-08:** Renderizar silencios (rests) proporcionados según la figura rítmica.
- **REQ-PDF-09:** Soportar compresión de flujos `FlateDecode` (ZLib) en memoria para optimizar el tamaño de archivo sin requerir paquetes externos.

---

## 4. Diseño Técnico y Arquitectura

### 4.1 Capa de Dominio (`lib/features/universal_importer/domain/canonical_pdf_exporter.dart`)
- Clase pura `CanonicalPdfExporter`.
- Métodos:
  - `Uint8List exportToPdf(SongPackage package)`
  - `Uint8List exportScore({required HierarchicalScore score, String title, String composer})`
- Ensamblado de objetos PDF:
  - Objeto 1: Catálogo (`/Type /Catalog /Pages 2 0 R`).
  - Objeto 2: Árbol de Páginas (`/Type /Pages /Kids [...] /Count N`).
  - Objeto 3: Página individual (`/Type /Page /Parent 2 0 R /MediaBox [...] /Contents 4 0 R /Resources ...`).
  - Objeto 4: Flujo de Contenido Gráfico (`stream ... endstream`).
  - Objeto 5: Fuentes estándar Type 1 (Helvetica y Helvetica-Bold para tipografía legible).
  - Tabla de referencias cruzadas (`xref`) y trailer con cálculo determinista de offsets de bytes.

### 4.2 Capa de Presentación y Orquestación
- Incorporación de `exportActiveScoreToPdf()` en `TunerViewModel`.
- Integración en `ScoreEditorModal` con botón "PDF" (`export_pdf_btn`) con icono `Icons.picture_as_pdf`.

---

## 5. Criterios de Aceptación (Definition of Done)

- 100% de pruebas unitarias pasando.
- Verificación de decodificación simétrica mediante `PdfScoreParser`.
- Cero issues en `flutter analyze`.
- Cero dependencias nativas o externas propietarias.
- Cero emojis en código, comentarios y commits.
