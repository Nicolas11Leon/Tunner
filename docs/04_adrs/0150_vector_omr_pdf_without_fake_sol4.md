# ADR-0150: Saneamiento del Motor Vector OMR PDF sin Notas Sol4 Falsas ni Marcadores Artificiales

- **Estado:** Aprobado
- **Fecha:** 2026-11-22
- **Issue:** #142 (US-4.1)
- **Relacionado:** [UC-158](../02_use_cases/158_uc_vector_omr_pdf_without_fake_sol4.md)

## Contexto

La auditoría técnica sobre el subsistema de exportación e importación PDF vectorial (`CanonicalPdfExporter`, `PdfScoreParser` y `VectorOmrEngine`) reveló cuatro deficiencias críticas incompatibles con la filosofía de cero simulación y precisión musical de Tunner:

1. **`CanonicalPdfExporter._renderNotehead`** inyectaba un rectángulo artificial `${x - 3.5} ${y - 3.0} 7.0 6.0 re f` encima de cada cabeza de nota rellena para facilitar la detección simplificada del parser, ensuciando la geometría PDF canónica y omitiendo el reconocimiento real de las curvas Bezier ovaladas.
2. **`PdfScoreParser._parseGraphicOperators`** ignoraba por completo la pila de matrices de transformación (`q`, `Q`, `cm`), evaluaba cada operador `c` de forma aislada usando únicamente la distancia entre `currentPoint` y `(x3, y3)` (produciendo altura `0` en óvalos horizontales de 2 curvas), no limpiaba la pila numérica ante operadores gráficos/textuales de 1 o 2 caracteres (como `Tm`, `Tj`, `w`, `rg`), y no diferenciaba subpaths cerrados trazados con contorno hueco (`S`, `s`) frente a rellenos (`f`, `F`, `f*`, `B`, `b`).
3. **`VectorOmrEngine.processGeometricElements`** invocaba `_buildFallbackScore` cuando no encontraba pentagramas válidos, fabricando notas `'Sol4'` artificiales en lugar de rechazar documentos PDF no musicales o rasterizados.
4. **`VectorOmrEngine._findNotesInStaffRegion`** repartía los ticks del compás uniformemente entre todas las cabezas sin distinguir blancas/redondas huecas de negras/corcheas/semicorcheas con plica y corchetes/barras, y `_mapYToSolfegeNote` limitaba la escala diatónica a un arreglo fijo de 13 notas (`Do4` a `La5`).

## Decisión

1. **Pureza Vectorial en `CanonicalPdfExporter`:**
   - Eliminar el rectángulo artificial `7.0 6.0 re f` de `_renderNotehead`. Las cabezas huecas (`durationTicks >= 8`) se emiten exclusivamente mediante dos curvas Bezier cúbicas cerradas con operador `s` (`closepath + stroke`), y las cabezas rellenas mediante las mismas curvas Bezier cerradas con operador `f` (`fill`).

2. **Pila CTM, Extremos Bezier y Estado Hueco/Relleno en `PdfScoreParser`:**
   - Implementar una matriz afín 2D inmutable (`[a, b, c, d, e, f]`) con pila explícita para `q` (push), `Q` (pop) y `cm` (pre-multiplicación conforme a ISO 32000-1).
   - Tokenizar el flujo respetando literales de texto `(...)`, comentarios `%...` y bloques `BT ... ET`, limpiando la pila numérica tras cualquier operador no numérico para evitar contaminación de operandos.
   - Acumular subpaths (`m`, `l`, `c`, `v`, `y`, `re`, `h`) en coordenadas transformadas y resolver la caja delimitadora exacta en `X` y `Y` calculando los extremos analíticos de cada segmento Bezier cúbico (raíces de la derivada cuadrática $B'(t) = 0$) en los operadores de pintado (`S`, `s`, `f`, `F`, `f*`, `B`, `B*`, `b`, `b*`), propagando `isFilled` en `OmrRect` (`false` para `S`/`s`, `true` para `f`/`F`/`B`/`b`). Descartar subpaths terminados con `n` (clipping paths).

3. **Eliminación de Fallback Falso e Inferencia Real en `VectorOmrEngine`:**
   - Extender `OmrRect` con `final bool isFilled` (valor por defecto `true` para compatibilidad con constructores existentes).
   - Eliminar por completo `_buildFallbackScore`. Cuando no se detecten sistemas de pentagramas de 5 líneas equidistantes y alineadas (`staves.isEmpty`), lanzar `FormatException`. Igualmente, en `PdfScoreParser.parseScoreData`, lanzar `FormatException` si tras evaluar todas las páginas no se consolidó ningún compás válido.
   - Asegurar que `_detectBarlinesForStaff` valide la cobertura completa `[bottomY, topY]` del pentagrama y descarte plicas de notas adyacentes.
   - En `_findNotesInStaffRegion`, cruzar cada `OmrRect` con los `OmrLine` del flujo para detectar presencia de plica vertical adyacente (hacia arriba o abajo) y agrupar corchetes/barras conectados a la punta de la plica, infiriendo:
     - `!isFilled && !hasStem` -> `16` ticks (redonda).
     - `!isFilled && hasStem` -> `8` ticks (blanca).
     - `isFilled` sin plica o con plica y `0` corchetes/barras -> `4` ticks (negra).
     - `isFilled` con plica y `1` corchete/barra -> `2` ticks (corchea).
     - `isFilled` con plica y `>= 2` corchetes/barras -> `1` tick (semicorchea).
   - Reemplazar la tabla fija de 13 notas en `_mapYToSolfegeNote` por cálculo aritmético de grado diatónico y octava relativa a `Mi4` (`absStep = 30 + deltaHalfSpaces`), soportando líneas adicionales superiores e inferiores sin tope fijo.

## Consecuencias

- **Positivas:**
  - Compatibilidad real round-trip entre `CanonicalPdfExporter` y `PdfScoreParser` para redondas, blancas, negras, corcheas y semicorcheas sin marcadores ocultos.
  - Rechazo explícito y honesto (`FormatException`) de PDFs sin pentagramas vectoriales (documentos de texto, escaneos rasterizados, gráficos arbitrarios).
  - Soporte fiel para PDFs generados con transformaciones de coordenadas (`q`/`Q`/`cm`), como flips verticales Y o escalados de página.
  - Lectura de notas extendidas en líneas adicionales por debajo de `Do4` y por encima de `La5`.
- **Negativas / Trade-offs:**
  - Las pruebas heredadas que validaban explícitamente la existencia del marcador `re f` o del comportamiento fallback `Sol4` requieren actualización para reflejar la nueva especificación canónica libre de simulaciones.
  - Los PDFs puramente rasterizados (imágenes escaneadas sin primitivas vectoriales) ahora fallan explícitamente con `FormatException` en lugar de devolver un compás inventado de `'Sol4'`, lo cual es el comportamiento correcto hasta implementar un futuro motor OMR rasterizado.
