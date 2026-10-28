# ADR 0026: Exportador Canónico de Partituras en PDF Vectorial Puro

---

## Estado
Aprobado

## Contexto
Tras la implementación de la Fase 9 (reconocimiento óptico de partituras PDF mediante `VectorOmrEngine` y `PdfScoreParser`), Tunner requería una vía simétrica de salida para generar partituras en formato PDF estándar.

Las alternativas evaluadas fueron:
1. **Librería de Terceros (e.g. `pdf` en pub.dev):**
   - *Ventajas:* Simplifica la creación de documentos de texto.
   - *Desventajas:* Introduce dependencia pesada no nativa al dominio de notación musical de Tunner, incrementa el árbol de dependencias, y restringe el control milimétrico sobre las primitivas vectoriales de pentagramas, cabezas de nota y plicas.
2. **Generador Canónico en Pure Dart ISO 32000-1 (Seleccionada):**
   - *Ventajas:* Cero dependencias adicionales (reutiliza `package:archive` para compresión opcional FlateDecode), 100% offline, determinista, acoplado directamente al modelo `HierarchicalScore`, permite simetría exacta con `PdfScoreParser` y garantiza portabilidad absoluta en cualquier plataforma sin dependencias nativas.
   - *Desventajas:* Requiere ensamblar la especificación básica de objetos PDF (Catálogo, Páginas, Streams de contenido, xref, trailer).

## Decisión
Se decide implementar `CanonicalPdfExporter` como una clase pura en `lib/features/universal_importer/domain/canonical_pdf_exporter.dart`, generando la estructura de objetos ISO 32000-1 directamente en memoria.

El documento PDF generado incluye:
- Hoja estándar A4 ($595.28 \times 841.89\text{ pt}$).
- Encabezado con título de la obra, compositor y tempo base en BPM.
- Sistemas de pentagrama de 5 líneas paralelas con clave de Sol, compás métrico y barras divisorias de compás.
- Representación vectorial de cabezas de nota (sólidas/huecas), plicas direccionales estándar según altura de línea media, líneas adicionales superiores/inferiores y silencios.
- Paginación dinámica en caso de obras extensas.
- Integración en `TunerViewModel` y en `ScoreEditorModal`.

## Consecuencias
- **Positivas:**
  - El ecosistema de partituras de Tunner alcanza simetría bidireccional completa para PDF: Importar (OMR) $\longleftrightarrow$ Exportar (PDF Vectorial).
  - Cero costo de red, cero llamadas a microservicios remotos, total soberanía de datos del usuario.
  - Compatibilidad universal con cualquier visor de PDF, impresoras y tablets de música.
- **Negativas / Mitigaciones:**
  - La maquetación de partituras muy densas (polifonía compleja con múltiples voces simultáneas) requiere ajustes progresivos de espaciado horizontal, lo cual se mitiga parametrizando anchos mínimos de compás.
