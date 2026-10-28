# ADR 0024: Motor de Importación de Partituras en PDF & Reconocimiento Óptico Vectorial (OMR)

- **Estado:** Approved
- **Fecha:** 2026-10-27
- **Fase:** Fase 9

---

## 1. Contexto

El formato PDF es el estándar indiscutible para la distribución gráfica e impresión de partituras (e.g. descargas de IMSLP, bibliotecas de conservatorio, exportaciones de Sibelius y MuseScore). Sin embargo, un archivo PDF no posee estructura semántica musical nativa (carece de notas legibles, compases o eventos temporales).

La integración de conversión de PDF a partitura estructurada plantea dos rutas técnicas:
1. *Servicios en la Nube (Cloud OMR):* Viola los principios cardinales de Tunner (privacidad, latencia cero, 100% offline).
2. *OMR Neuronal Pesado para Escaneos Sucios:* Requiere modelos de deep learning de cientos de megabytes que penalizan el arranque y la batería en dispositivos móviles.
3. *OMR Vectorial Determinista en Memoria (Vector OMR):* La inmensa mayoría de PDFs modernos exportados desde software de notación son vectoriales puros. Contienen líneas exactas de pentagrama, barras de compás y cabezas de nota en coordenadas geométricas predecibles.

---

## 2. Decisión Arquitectónica

1. **Parser de Sintaxis de Flujo PDF en Pure Dart:**
   Construir `PdfScoreParser` capaz de extraer los objetos de contenido (*content streams*) del archivo PDF, descomprimiendo filtros `FlateDecode` en memoria y tokenizando operadores gráficos de trazado (`m`, `l`, `c`, `re`).
2. **Motor Geométrico de Reconocimiento Óptico (`VectorOmrEngine`):**
   - Agrupar líneas horizontales en conjuntos de 5 con separación equidistante $\Delta y$ para formar pentagramas.
   - Detectar segmentos verticales que conectan la línea 1 y la línea 5 como barras divisorias de compás.
   - Analizar las cabezas de nota geométricas / glifos y proyectar su coordenada vertical $y$ a la escala diatónica en clave de Sol.
   - Construir notas `HierarchicalNote` y compases `MeasureEntity`.
3. **Integración con `UniversalScoreImporterService`:**
   El orquestador universal incorpora `PdfScoreParser` reconociendo la extensión `.pdf` y la firma mágica `%PDF-`.

---

## 3. Consecuencias

### Positivas
- Capacidad revolucionaria en una aplicación móvil de código abierto: cargar directamente partituras en PDF y transformarlas en música interactiva.
- Procesamiento 100% local, instantáneo y sin consumir datos de red.
- Integración directa con el reproductor, el editor interactivo y los exportadores MusicXML/MIDI/ABC.

### Negativas / Mitigaciones
- Un PDF que consista en una fotografía escaneada de baja resolución sin trazados vectoriales no podrá ser resuelto por el OMR geométrico puro. Mitigación: se emite un diagnóstico claro al usuario informando la ausencia de vectores legibles.
