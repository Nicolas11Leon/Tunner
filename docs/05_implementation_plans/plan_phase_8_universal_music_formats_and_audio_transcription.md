# Plan de Implementación: Fase 8 - Centro Universal de Formatos Musicales & Transcripción de Audio a Partitura

Este plan formaliza las tareas y pasos secuenciales para implementar la ingesta de Compressed MusicXML (`.mxl`), ABC Notation (`.abc`), exportación a ABC, el motor de transcripción offline de audio (WAV) a partitura SMuFL y su integración en el ViewModel y la UI.

---

## 1. Objetivos

1. Implementar `CompressedMusicXmlParser` para soportar archivos `.mxl` (ZIP) desempaquetando en memoria.
2. Implementar `AbcScoreParser` para decodificar partituras escritas en formato de texto plano ABC Notation (`.abc`).
3. Implementar `CanonicalAbcExporter` para exportar cualquier partitura `HierarchicalScore` a sintaxis ABC estándar.
4. Desarrollar `AudioToScoreTranscriptionEngine` en `lib/features/transcription/domain/` para transcribir archivos de audio PCM/WAV a partituras estructuradas mediante ventana deslizante MPM.
5. Actualizar `UniversalScoreImporterService` para soportar `.mxl`, `.abc`, `.musicxml`, `.xml`, `.mid`, `.midi` y audios `.wav` de forma unificada.
6. Integrar en `TunerViewModel` y en la UI de importación y visor de partituras.
7. Crear suites de pruebas unitarias y de widgets con 100% de cobertura.

---

## 2. Tareas por Capa Arquitectónica

### Capa 1: Dominio y Parsers de Notación
- [x] Crear `lib/features/universal_importer/data/compressed_musicxml_parser.dart`:
  - Detección de firma ZIP `[0x50, 0x4B, 0x03, 0x04]` y extensión `.mxl`.
  - Descompresión en memoria con `archive`.
  - Extracción de archivo raíz desde `META-INF/container.xml`.
  - Delegación a `MusicXmlScoreParser`.
- [x] Crear `lib/features/universal_importer/data/abc_score_parser.dart`:
  - Detección de cabeceras ABC (`X:`, `T:`, `M:`, `K:`, etc.) o extensión `.abc`.
  - Análisis léxico de compases, figuras, notas musicales y silencios.
  - Conversión a `HierarchicalScore`.
- [x] Crear `lib/features/universal_importer/domain/canonical_abc_exporter.dart`:
  - Conversión de `HierarchicalScore` a cadena de texto ABC válida.
- [x] Pruebas unitarias de parsers y exportadores de partitura en `test/features/universal_importer/`.

### Capa 2: Motor de Transcripción de Audio a Partitura (Audio-to-Score)
- [x] Crear `lib/features/transcription/domain/audio_to_score_transcription_engine.dart`:
  - Decodificación de encabezado RIFF/WAVE PCM 16-bit (mono o estéreo).
  - Normalización a `List<double>`.
  - Análisis por ventana deslizante (2048 muestras, hop 512 muestras) con `McleodPitchMethod`.
  - Agrupación por continuidad temporal e interválica ($\le 40\text{ cents}$).
  - Cuantización rítmica en compases de 4/4 con `RhythmicQuantizer`.
- [x] Pruebas unitarias del motor de transcripción en `test/features/transcription/audio_to_score_transcription_engine_test.dart`.

### Capa 3: Orquestación, Aplicación y UI
- [x] Actualizar `UniversalScoreImporterService`:
  - Integrar `CompressedMusicXmlParser` y `AbcScoreParser`.
  - Exponer método `transcribeAudioToScoreResult({required Uint8List bytes, required String fileName, int bpm = 120})`.
- [x] Actualizar `TunerViewModel`:
  - Métodos `exportActiveScoreToAbc()`, `importScoreFromBytes()`, y `transcribeAudioFileToScore()`.
  - Exportación a MusicXML, MIDI y ABC desde `ScoreEditorModal`.
- [x] Pruebas de integración y UI en `test/features/universal_importer/universal_importer_formats_ui_test.dart`.

---

## 3. Criterios de Aceptación (DoD)
- 100% de pruebas unitarias y de integración pasando.
- Cero issues en `flutter analyze`.
- Cero emojis en código fuente, comentarios y commits.
