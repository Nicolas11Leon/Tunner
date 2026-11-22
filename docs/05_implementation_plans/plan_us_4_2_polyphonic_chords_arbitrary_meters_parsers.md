# Plan de Implementacion: US-4.2 Preservacion Polifonica de Acordes, Compases Arbitrarios y Rango 0..8 en Parsers y Exportadores

## Metadatos del Plan
- **ID del Plan:** `PLAN-US-4.2-2026-01`
- **Titulo de la Implementacion:** Soporte Polifonico, Compases Arbitrarios, 15 Armaduras y Rango 0..8 en MusicXML, MIDI y ABC
- **Fase del Proyecto:** Fase 4 / Parsers Polifonicos y Transcripcion
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0151](../04_adrs/0151_polyphonic_chords_arbitrary_meters_parsers.md)
- **Documento Funcional Base:** [Caso de Uso 159](../02_use_cases/159_uc_polyphonic_chords_arbitrary_meters_parsers.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Actualizar los parsers y exportadores canonicos de MusicXML, MIDI y ABC en `lib/features/universal_importer/` para garantizar la preservacion exacta de acordes polifonicos simultaneos, compases arbitrarios `TimeSignature(num, den)`, las 15 armaduras estandar (`-7..+7`) y el rango completo de octavas `0..8`.

### 1.2 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `lib/features/universal_importer/data/musicxml_score_parser.dart`
  - `lib/features/universal_importer/domain/canonical_musicxml_exporter.dart`
  - `lib/features/universal_importer/data/midi_score_parser.dart`
  - `lib/features/universal_importer/data/abc_score_parser.dart`
  - `lib/features/universal_importer/domain/canonical_abc_exporter.dart`
  - `test/features/universal_importer/us_4_2_polyphonic_parsers_test.dart`
  - Actualizacion de la asercion obsoleta sobre `<chord/>` en `test/features/notation/wave_c_notation_parsers_pedagogy_shell_test.dart`.
- **Excluido (Out-of-Scope):**
  - Cambios en `PdfScoreParser`, `VectorOmrEngine`, `CanonicalPdfExporter` o en el modelo `ScoreTree`.
  - Cambios en widgets de presentacion o en el motor FFI C99.

---

## 2. Analisis de Dependencias y Tecnologias

- **Versiones de Librerias / SDKs:**
  - Dart SDK / Flutter SDK estable del proyecto.
  - Paquete `xml` existente para recorrido DOM de MusicXML; sin nuevas dependencias externas.
- **Riesgo Tecnologico:**
  - Introduce dependencias nativas o FFI: No (100% Pure Dart offline).
  - Afecta el rendimiento del bucle principal: No; todos los parsers operan bajo demanda y con complejidad lineal $O(N)$ respecto al numero de notas.

---

## 3. Plan Paso a Paso de Ejecucion (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (`CanonicalMusicXmlExporter` y `CanonicalAbcExporter`)
- [x] En `CanonicalMusicXmlExporter`, ordenar las notas de cada compas por `startTick`, emitir `<chord/>` en las voces simultaneas que comparten el `startTick` de la nota base, emitir `<attributes><time>` en cambios de metrica inter-compas y acotar octavas al rango `0..8`.
- [x] En `CanonicalAbcExporter`, agrupar notas simultaneas por `startTick` para serializar acordes como `[CEG]` (o `[C2E]` cuando difieran duraciones), soportar cambios de compas `[M:num/den]`, emitir duraciones proporcionales arbitrarias y garantizar el mapeo de octavas `0..8`.

### Paso 2: Capa de Infraestructura / Datos (`MusicXmlScoreParser`, `MidiScoreParser`, `AbcScoreParser`)
- [x] En `MusicXmlScoreParser`, conservar el `startTick` de la nota base para los elementos `<chord/>` sin avanzar el cursor de tiempo, soportar compases arbitrarios en `_parseTimeSignature` y validar el rango de octavas `0..8`.
- [x] En `MidiScoreParser._quantizeToMeasures`, agrupar eventos MIDI por `startTick` cuantizado dentro del compas, preservar acordes polifonicos, calcular silencios intermedios mediante `timelineCursor` y validar denominadores de compas MIDI.
- [x] En `AbcScoreParser`, implementar parseo polifonico de acordes entre corchetes `[...]`, soporte de compases arbitrarios `M:` (incluyendo inline `[M:...]`), resolucion de las 15 armaduras estandar (`-7..+7`) y rango de octavas `0..8`.

### Paso 3: Pruebas, Verificacion y Limpieza
- [x] Crear suite exhaustiva `test/features/universal_importer/us_4_2_polyphonic_parsers_test.dart` cubriendo MusicXML (`<chord/>`, compases arbitrarios, `0..8`, round-trip), MIDI (acordes simultaneos, silencios intermedios, compases arbitrarios, `0..8`) y ABC (`[CEG]`, compases arbitrarios, 15 armaduras `-7..+7`, octavas `0..8`, round-trip).
- [x] Actualizar la asercion heredada de Ola C en `test/features/notation/wave_c_notation_parsers_pedagogy_shell_test.dart`.
- [x] Ejecutar `flutter analyze --no-fatal-infos` verificando cero problemas.
- [x] Ejecutar `flutter test` sobre `us_4_2_polyphonic_parsers_test.dart` y la suite completa del proyecto verificando 100% de aprobacion.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauracion Git:** Commit base de `origin/qa` previo al despliegue de la rama `feature/us-4.2-polyphonic-chords-arbitrary-meters-parsers`.
- **Mitigacion Inmediata:** Reversion atomica mediante `git revert` o cierre del PR sin afectar la rama `qa`.

---

## 5. Criterios de Aceptacion (Definition of Done)

- [x] Documentacion canonica (Caso de Uso 159 con 2 diagramas Mermaid, ADR 0151 y Plan US-4.2) redactada sin emojis.
- [x] Clean Architecture respetada (puro Dart en dominio, cero dependencias de UI).
- [x] `flutter analyze --no-fatal-infos` finalizado con 0 issues.
- [x] Pruebas unitarias pasando al 100%.
- [ ] PR abierto hacia `qa` vinculando el Issue correspondiente (`Closes #141`).
