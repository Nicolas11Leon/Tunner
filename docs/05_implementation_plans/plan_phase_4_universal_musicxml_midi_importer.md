# Plan de Implementación: Importador Universal de Partituras MusicXML y MIDI Offline

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE4-IMPORTER-2026-001`
- **Título de la Implementación:** Motor Universal de Ingesta y Cuantización de Partituras MusicXML y Secuencias MIDI Offline
- **Fase del Proyecto:** Fase 4 (Estudio de Práctica & Integración Universal - Componente 4.1)
- **Estado:** En Progreso
- **ADR Relacionado:** [0010_universal_musicxml_midi_score_importer.md](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/04_adrs/0010_universal_musicxml_midi_score_importer.md)
- **Documento Funcional Base:** [doc_universal_musicxml_midi_importer.md](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/01_product_vision/doc_universal_musicxml_midi_importer.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Construir el subsistema de ingesta universal capaz de procesar bytes de archivos MusicXML y MIDI estándar, normalizando sus eventos musicales al modelo `HierarchicalScore` con compases, notas, armaduras y pistas para la consola de stems.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Paquete `xml: ^6.5.0` añadido a `pubspec.yaml`.
  - Contrato `IScoreParserService` y entidad `ParsedScoreResult` en `lib/features/universal_importer/domain/`.
  - Parser MusicXML (`MusicXmlScoreParser`) con soporte para divisiones, notas, alteraciones y silencios.
  - Parser MIDI binario (`MidiScoreParser`) con decodificación de chunks `MThd`/`MTrk` y eventos de nota.
  - Servicio orquestador `UniversalScoreImporterService`.
  - Integración en `TunerViewModel.importScoreFromBytes(bytes, fileName)`.
  - Tarjeta de importación en `SongDecomposerModal`.
  - Pruebas unitarias completas de MusicXML, MIDI y ViewModel.
- **Excluido (Out-of-Scope):**
  - OCR de partituras escaneadas por cámara (fase posterior avanzada).
  - Grabación directa de archivos MIDI de salida.

---

## 2. Análisis de Dependencias y Tecnologías

- **Paquete `xml`:** Versión estable `^6.5.0` (mantenida oficialmente por el equipo de Dart, Dart puro, sin dependencias nativas).
- **Decodificador MIDI:** Implementado en Dart puro sobre `ByteData` para máxima velocidad sin dependencias externas.
- **Riesgo Tecnológico:** Cero. Al no utilizar plugins nativos para el parseo, los tests unitarios corren instantáneamente en Dart VM sin advertencias ni dependencias rotas.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Configuración de Dependencias & Dominio
- [ ] Añadir `xml: ^6.5.0` a `pubspec.yaml` y ejecutar `flutter pub get`.
- [ ] Crear interfaces y entidades en `lib/features/universal_importer/domain/`.

### Paso 2: Infraestructura y Parsers
- [ ] Implementar `MusicXmlScoreParser` en `lib/features/universal_importer/data/`.
- [ ] Implementar `MidiScoreParser` en `lib/features/universal_importer/data/`.
- [ ] Implementar `UniversalScoreImporterService` que coordina ambos decodificadores.

### Paso 3: Integración en TunerViewModel
- [ ] Inyectar `UniversalScoreImporterService` en `TunerViewModel`.
- [ ] Añadir método `Future<bool> importScoreFromBytes(Uint8List bytes, String fileName)`.
- [ ] Agregar el nuevo paquete a `_curatedLibrary` y cargarlo automáticamente.

### Paso 4: Capa de Presentación (UI)
- [ ] Añadir tarjeta interactiva "Importar Partitura Externa" en `SongDecomposerModal`.
- [ ] Diseñar previsualización modal y feedback visual tras la carga.

### Paso 5: Suite de Pruebas & Validación
- [ ] Pruebas unitarias de MusicXML con partituras de prueba XML.
- [ ] Pruebas unitarias de MIDI con binarios de prueba generados programáticamente.
- [ ] Pruebas de integración en `TunerViewModel`.
- [ ] Verificar `flutter analyze` (0 issues) y `flutter test` (100% passing).
