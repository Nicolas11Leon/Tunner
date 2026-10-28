# Especificación Técnica: Motor de Importación de Partituras en PDF & Reconocimiento Óptico Musical (OMR)

Este documento define la arquitectura técnica, fundamentos geométricos y especificaciones del motor de reconocimiento óptico de partituras (Optical Music Recognition, OMR) para documentos PDF en **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-PDF-OMR-2026-001`
- **Título Oficial:** Motor de Ingesta de Partituras en PDF y Reconocimiento Óptico Musical Vectorial
- **Estado:** `Approved`
- **Fecha de Creación:** 2026-10-27
- **Fase Asociada:** `Fase 9 (Importador de Partituras en PDF & OMR Vectorial)`
- **Autor / Revisor Principal:** Nicolas Leon / Antigravity Engine

---

## 1. Resumen Ejecutivo (Executive Summary)

El formato PDF es el contenedor más común de distribución de partituras para músicos en todo el mundo, pero históricamente ha sido un "callejón sin salida" gráfico no reproducible ni interactivo. Tunner incorpora un motor nativo y 100% offline de Reconocimiento Óptico de Partituras Vectoriales (**Vector OMR Engine**). 

Este componente analiza el flujo de operadores gráficos del estándar PDF (líneas, rectángulos, curvas de Bézier y caracteres tipográficos musicales), reconstruye la geometría del pentagrama de 5 líneas, detecta cabezas de nota y plicas, cuantiza las duraciones en compases estructurados y genera un `HierarchicalScore` directamente navegable, reproducible y editable en la interfaz SMuFL.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 La Naturaleza Gráfica de un Documento PDF
A diferencia de MusicXML o MIDI, un archivo PDF no contiene conceptos musicales semánticos; contiene instrucciones de dibujo para el motor de renderizado PostScript/PDF:
- `m` / `l`: Mover a coordenadas $(x, y)$ y trazar línea a $(x', y')$.
- `re`: Trazar rectángulo con origen $(x, y)$, ancho $w$ y alto $h$.
- `c`: Trazar curva cúbica de Bézier con puntos de control.
- `Tj` / `TJ`: Mostrar cadenas de texto o glifos de fuentes incrustadas.

### 2.2 Fundamento Geométrico del OMR Vectorial
Para reconstruir la partitura sin pérdida de calidad y con determinismo matemático:
1. **Detección de Pentagramas (Staff Lines Clustering):**
   Un pentagrama estándar está formado por 5 segmentos de línea horizontales coplanares con una longitud similar $L \approx W_{\text{system}}$ y una separación vertical constante:
   $$\Delta y = y_{i+1} - y_i = \text{staffSpace}$$
   Se agrupan las líneas que cumplen $|y_{i+1} - y_i - \Delta y| \le \epsilon$. La altura del pentagrama es $H_{\text{staff}} = 4 \cdot \Delta y$.
2. **Detección de Barras de Compás (Barlines):**
   Las líneas verticales con longitud $h \approx H_{\text{staff}}$ que intersectan las 5 líneas delimitan los compases $M_0, M_1 \dots M_k$.
3. **Mapeo de Altura Tonal (Pitch Mapping):**
   En clave de Sol (G clef), la posición relativa vertical $\delta = \frac{y_{\text{note}} - y_{\text{line1}}}{\Delta y / 2}$ mapea directamente a los grados diatónicos de la escala:
   - $\delta = 0$: Primera línea inferior $\to \text{Mi}_4$ ($E_4$).
   - $\delta = 1$: Primer espacio $\to \text{Fa}_4$ ($F_4$).
   - $\delta = 2$: Segunda línea $\to \text{Sol}_4$ ($G_4$).
   - $\delta = 3$: Segundo espacio $\to \text{La}_4$ ($A_4$).
   - $\delta = 4$: Tercera línea $\to \text{Si}_4$ ($B_4$).
   - $\delta = 5$: Tercer espacio $\to \text{Do}_5$ ($C_5$).
   - $\delta = 6$: Cuarta línea $\to \text{Re}_5$ ($D_5$).
   - $\delta = 7$: Cuarto espacio $\to \text{Mi}_5$ ($E_5$).
   - $\delta = 8$: Quinta línea superior $\to \text{Fa}_5$ ($F_5$).
   - $\delta = -2$: Línea adicional inferior $\to \text{Do}_4$ ($C_4$).
4. **Morfología Rítmica (Notehead & Stem Topology):**
   - Cabeza rellena sin plica / con plica vertical: duración calculada según proporción métrica.
   - Plicas unidas por barras horizontales (beams): notas en subdivisión de corcheas o semicorcheas.

---

## 3. Especificación Funcional

1. **`PdfScoreParser`:**
   - Detecta cabecera mágica `%PDF-` (`[0x25, 0x50, 0x44, 0x46]`) o extensión `.pdf`.
   - Extrae el contenido de los flujos de dibujo de las páginas del documento.
   - Filtra operaciones gráficas de líneas, rectángulos y curvas.
2. **`VectorOmrEngine`:**
   - Agrupa líneas horizontales en pentagramas de 5 líneas.
   - Detecta barras verticales de compás.
   - Identifica cabezas de notas mediante correlación posicional.
   - Genera compases de 4/4 o métrica detectada con notas `HierarchicalNote`.
3. **Integración con `UniversalScoreImporterService`:**
   - Habilita la selección de archivos `.pdf` en el selector nativo y en el importador universal.
4. **Respaldo Heurístico y Diagnóstico:**
   - Si el PDF contiene una partitura digital estándar, se genera la partitura y se reporta el número de compases y notas reconocidas.
   - Si el PDF es un escaneo de imagen degradada sin vectores, informa al usuario con un diagnóstico claro.

---

## 4. Criterios de Aceptación (DoD)

- 100% de pruebas unitarias y de widgets pasando.
- Cero dependencias externas en la nube (100% offline).
- Cero lints en `flutter analyze`.
- Cero emojis en código fuente, comentarios o commits.
