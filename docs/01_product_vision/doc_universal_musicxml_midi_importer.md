# Especificación Técnica: Importador Universal de Partituras MusicXML y Archivos MIDI Estándar

---

## Metadatos del Documento

- **ID del Documento:** `DOC-IMPORTER-2026-001`
- **Título Oficial:** `Especificación de Arquitectura de Ingesta, Decodificación y Normalización Jerárquica de Partituras MusicXML y MIDI Offline`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-10-27`
- **Última Modificación:** `2026-10-27`
- **Fase Asociada:** `Fase 4 (Estudio de Práctica & Integración Universal - Componente 4.1)`
- **Autor / Revisor Principal:** `Equipo de Ingeniería Acústica & Antigravity Lead Architect`

---

## 1. Resumen Ejecutivo (Executive Summary)

El presente documento define la arquitectura para dotar a **Tunner** de un motor universal de ingesta offline para partituras y composiciones en formatos estándar de la industria musical: **MusicXML** (`.musicxml`, `.xml`) y **MIDI Estándar** (`.mid`, `.midi`). 

El subsistema decodifica la representación simbólica o temporal del archivo binario/texto directamente en la estructura canónica del dominio `HierarchicalScore`, discretizando las duraciones temporales a la cuadrícula de 16 semicorcheas por compás de $4/4$ (y sus equivalentes en otros compases), deduciendo automáticamente la signatura de compás, armadura, tempo base y derivando pistas para la consola de stems multicanal.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Hasta el momento, las obras de la biblioteca residían como estructuras de datos ensambladas manualmente en Dart (`SongDecomposerService`). Para que los estudiantes y músicos de conservatorio utilicen Tunner con su propio repertorio de estudio, es imprescindible poder cargar cualquier archivo exportado desde editores como MuseScore, Sibelius, Finale, Guitar Pro o estaciones de trabajo digital (DAW).

### 2.2 Fundamento Teórico y Formatos Musicales

#### 2.2.1 Especificación MusicXML (W3C Music Notation Community Group)
MusicXML modela la partitura mediante elementos `<measure>`, `<attributes>` (`<divisions>`, `<time>`, `<key>`), y `<note>` (`<pitch>`, `<step>`, `<octave>`, `<duration>`, `<rest>`).
- **Mapeo de Duraciones:** Una medida de $4/4$ en Tunner posee 16 sub-ticks de semicorchea.
  Sea $\Delta_{\text{div}}$ las divisiones por negra especificadas en la cabecera. La duración en ticks de Tunner $D_{\text{ticks}}$ para una nota de duración XML $d_{\text{xml}}$ se calcula como:

  $$D_{\text{ticks}} = \text{round}\left(d_{\text{xml}} \cdot \frac{4}{\Delta_{\text{div}}}\right)$$

- **Nomenclatura Tonal:** El nombre de la nota física se normaliza al sistema silábico/anglosajón de Tunner (`Do`, `Do#`, `Re`, etc.) concatenando la octava correspondiente (ej. `Step: C, Octave: 4` $\to$ `"Do4"`).

#### 2.2.2 Especificación Estándar MIDI 1.0 (SMF Type 0 y Type 1)
Los archivos MIDI se estructuran en bloques *chunks*:
- **Header Chunk (`MThd`):** Define el formato (0 = pista única, 1 = pistas paralelas síncronas), número de pistas $N$, y la división de tiempo $PPQ$ (*Pulses Per Quarter Note*).
- **Track Chunk (`MTrk`):** Contiene secuencias de delta-time variables seguidas de eventos de canal (`NoteOn`, `NoteOff`, `SetTempo`).
- **Cuantización a Cuadrícula:**
  Dado un evento con tiempo acumulado $t_{\text{midi}}$, su posición en sub-ticks de Tunner $T_{\text{tick}}$ viene dada por:

  $$T_{\text{tick}} = \text{round}\left(\frac{t_{\text{midi}}}{PPQ} \cdot 4\right)$$

---

## 3. Especificación Funcional Detallada

### 3.1 Requerimientos Funcionales
- **REQ-01 (Detección y Carga de Archivos):** El usuario podrá seleccionar archivos locales con extensiones `.musicxml`, `.xml`, `.mid` o `.midi` a través del explorador nativo del dispositivo.
- **REQ-02 (Parseo Offline en Dart Puro):** Toda la decodificación se realizará 100% en memoria local sin transferir datos a la red ni requerir servidores externos.
- **REQ-03 (Construcción de Partitura Jerárquica):** El parser producirá una instancia válida e inmutable de `SongPackage` que contiene:
  - Título y autor extraídos de los metadatos o del nombre del archivo.
  - BPM base (extraído del evento tempo o default 100 BPM).
  - Medidas secuenciales con notas y silencios sin solapamientos irregulares.
  - Pistas de stem asociadas si el archivo contiene múltiples canales/instrumentos.
- **REQ-04 (Resistencia y Fallback):** Si un compás contiene notas incompletas o errores de sintaxis XML/MIDI, el parser debe autocorregir los ticks faltantes insertando silencios o truncando excesos sin lanzar excepciones no controladas.

---

## 4. Diseño Técnico y Arquitectura de la Solución

```
lib/features/universal_importer/
├── domain/
│   ├── i_score_parser_service.dart
│   └── parsed_score_result_entity.dart
├── data/
│   ├── musicxml_score_parser.dart
│   ├── midi_score_parser.dart
│   └── universal_score_importer_service.dart
└── presentation/
    └── score_file_import_card.dart
```

### 4.1 Capa de Dominio (Domain Layer)
- `IScoreParserService`: Contrato abstracto con método:
  `Future<ParsedScoreResult> parseScoreData({required Uint8List bytes, required String fileName});`
- `ParsedScoreResult`: Objeto que encapsula el `SongPackage` generado, advertencias de cuantización si existieran, y el formato detectado.

### 4.2 Capa de Infraestructura (Data Layer)
- `MusicXmlScoreParser`: Lee nodos XML (`<score-partwise>`), procesa divisiones, compases, notas, alteraciones accidentales (`<alter>`) y silencios.
- `MidiScoreParser`: Lee bytes binarios con `ByteData`, extrae eventos `NoteOn` y genera compases de acuerdo al tiempo acumulado.
- `UniversalScoreImporterService`: Orquesta la detección por extensión/firma binaria (`MThd` o `<?xml`) y delega al parser especializado.
