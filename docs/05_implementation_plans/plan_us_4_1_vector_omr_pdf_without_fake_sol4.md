# Plan de Implementación: US-4.1 Saneamiento del Motor Vector OMR PDF sin Notas Sol4 Falsas ni Marcadores Artificiales

## Metadatos del Plan
- **ID del Plan:** `PLAN-FASE4-VECTOR-OMR-2026-01`
- **Título de la Implementación:** Saneamiento de `CanonicalPdfExporter`, `PdfScoreParser` y `VectorOmrEngine` sin marcadores artificiales ni notas `'Sol4'` falsas
- **Fase del Proyecto:** Fase 4 / Hardening Vector OMR PDF
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR-0150](../04_adrs/0150_vector_omr_pdf_without_fake_sol4.md)
- **Documento Funcional Base:** [Caso de Uso 158](../02_use_cases/158_uc_vector_omr_pdf_without_fake_sol4.md)
- **Issue GitHub:** `#142`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Garantizar que la exportación e importación de partituras PDF vectoriales opere exclusivamente sobre geometría musical auténtica: óvalos Bezier puros sin rectángulos de ayuda, seguimiento completo de matrices de transformación PDF (`q`/`Q`/`cm`), distinción de cabezas huecas vs rellenas, inferencia rítmica real (`16, 8, 4, 2, 1` ticks) mediante plicas y corchetes/barras, cálculo diatónico sin límite de 13 pasos, y rechazo con `FormatException` cuando un PDF carezca de pentagramas vectoriales válidos.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `lib/features/universal_importer/domain/canonical_pdf_exporter.dart`: Eliminación de `7.0 6.0 re f` en `_renderNotehead`.
  - `lib/features/universal_importer/data/pdf_score_parser.dart`: Pila CTM (`q`/`Q`/`cm`), tokenización segura, cálculo exacto de bounding box en subpaths Bezier cerrados (`m`..`c`..`h`), clasificación hueco (`S`/`s`) vs relleno (`f`/`F`/`B`), y validación estricta ante PDFs sin pentagramas válidos.
  - `lib/features/universal_importer/domain/vector_omr_engine.dart`: Propiedad `isFilled` en `OmrRect`, eliminación de `_buildFallbackScore` lanzando `FormatException`, protección de barras de compás frente a plicas, inferencia de duración real (`16, 8, 4, 2, 1` ticks) y mapeo diatónico ilimitado.
  - `test/features/universal_importer/us_4_1_vector_omr_pdf_test.dart`: Suite unitaria dedicada de round-trip, figuras huecas/rellenas, transformaciones `q`/`Q`/`cm`, rango extendido de notas y excepciones ante PDF sin pentagramas.
  - Actualización de pruebas heredadas afectadas por la eliminación del marcador `re f` y del fallback `Sol4`.
- **Excluido (Out-of-Scope):**
  - Reconocimiento OMR basado en visión por computador sobre imágenes rasterizadas (bitmap).
  - Decodificación de fuentes tipográficas musicales incrustadas (SMuFL Type1/TrueType outlines).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.5`
  - Flutter SDK: Canal estable local (`/home/nicomania11/desarrollo/flutter/bin/flutter`)
  - Dependencias utilizadas: únicamente `dart:math`, `dart:convert`, `dart:typed_data` y `archive` (ya existente en `pubspec.yaml` para `FlateDecode`).
- **Riesgo Tecnológico:**
  - No introduce dependencias externas ni nativas FFI.
  - No afecta el hilo principal de audio ni el renderizado a 60/120 FPS.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (`CanonicalPdfExporter` y `VectorOmrEngine`)
- [ ] Eliminar la emisión de `${x - 3.5} ${y - 3.0} 7.0 6.0 re f` en `CanonicalPdfExporter._renderNotehead`.
- [ ] Incorporar `final bool isFilled` (default `true`) en `OmrRect`.
- [ ] Eliminar `_buildFallbackScore` en `VectorOmrEngine` y lanzar `FormatException` cuando `staves.isEmpty`.
- [ ] Refinar `_detectStaffSystems` y `_detectBarlinesForStaff` para exigir alineación de pentagrama y evitar falsos positivos con plicas de notas.
- [ ] Refactorizar `_findNotesInStaffRegion` para recibir `lines`, detectar plica vertical y corchetes/barras adjuntos e inferir `16, 8, 4, 2, 1` ticks reales.
- [ ] Reemplazar la tabla de 13 pasos en `_mapYToSolfegeNote` por cálculo diatónico modular ilimitado y ampliar los márgenes verticales inter-sistema.

### Paso 2: Capa de Infraestructura / Datos (`PdfScoreParser`)
- [ ] Implementar clase auxiliar privada `_PdfMatrix` y pila de estados en `_parseGraphicOperators` (`q`, `Q`, `cm`).
- [ ] Implementar tokenizador seguro para ignorar comentarios `%`, cadenas `(...)` y bloques de texto `BT ... ET`, limpiando `numStack` ante todo operador.
- [ ] Acumular subpaths (`m`, `l`, `c`, `v`, `y`, `re`, `h`) transformados por CTM y calcular extremos analíticos exactos de curvas Bezier cúbicas.
- [ ] Distinguir operadores de trazo hueco (`S`, `s`) vs relleno (`f`, `F`, `f*`, `B`, `B*`, `b`, `b*`) al construir `OmrRect` e ignorar rutas `n`.
- [ ] Garantizar lanzamiento de `FormatException` en `parseScoreData` si no se consolidan compases válidos.

### Paso 3: Pruebas, Verificación y Limpieza
- [ ] Crear `test/features/universal_importer/us_4_1_vector_omr_pdf_test.dart` cubriendo round-trip de figuras `16, 8, 4, 2, 1`, óvalos Bezier huecos/rellenos, transformaciones `q`/`Q`/`cm`, notas fuera del rango `Do4..La5` y `FormatException` en PDF sin pentagrama.
- [ ] Actualizar las aserciones obsoletas de marcador `re f` / fallback `Sol4` en pruebas heredadas.
- [ ] Ejecutar `/home/nicomania11/desarrollo/flutter/bin/flutter analyze --no-fatal-infos` (0 issues).
- [ ] Ejecutar `/home/nicomania11/desarrollo/flutter/bin/flutter test` (100% pass).

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit base `e946b95` en `origin/qa`.
- **Mitigación Inmediata:** Reversión atómica de la rama `feature/us-4.1-vector-omr-pdf-without-fake-sol4` o `git revert` sobre el PR antes de su integración a `main`.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Cumplimiento estricto de `AGENTS.md` (cero emojis, Clean Architecture, documentación canónica).
- [ ] `CanonicalPdfExporter._renderNotehead` libre de rectángulos `7.0 6.0 re f`.
- [ ] `PdfScoreParser._parseGraphicOperators` con soporte CTM (`q`/`Q`/`cm`), bounding box Bezier cerrado exacto y distinción `S`/`s` vs `f`/`F`/`B`.
- [ ] `VectorOmrEngine` sin `_buildFallbackScore`, con `FormatException` ante ausencia de pentagramas, inferencia de duraciones `16/8/4/2/1` y pasos diatónicos ilimitados.
- [ ] `flutter analyze --no-fatal-infos` con 0 issues y 100% de pruebas aprobadas en `flutter test`.
