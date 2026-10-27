# ADR 0010: Arquitectura de Ingesta y Decodificación Universal de Partituras MusicXML y MIDI en Memoria Offline

---

## Estado
**Aprobado (Approved)**

## Fecha
2026-10-27

## Contexto y Planteamiento del Problema
1. **Dependencia de Repertorio Estático:** Hasta ahora, el repertorio de canciones de Tunner residía en plantillas estáticas dentro de `SongDecomposerService`. Para alcanzar la visión de producto de democratización musical, los usuarios deben poder importar cualquier obra desde sus herramientas de notación favoritas (MuseScore, Sibelius, Finale) o bancos de archivos MIDI.
2. **Requisitos de Rendimiento y Offline:**
   - La decodificación debe completarse en tiempos sub-segundo ($< 200\text{ ms}$) para archivos de tamaño medio (10 a 100 compases).
   - Zero dependencias en la nube: ningún archivo debe enviarse a APIs externas.
   - Zero dependencias en plugins con inicializaciones de canal prematuras que puedan romper el aislamiento de tests unitarios en la máquina virtual de Dart.

---

## Decisión Arquitectónica

1. **Parser de Dart Puro sin Dependencias Nativas:**
   - Para **MusicXML**, se utiliza el paquete oficial de Dart `xml: ^6.5.0` (Dart team LTS, puro y sin dependencias de plataforma), permitiendo recorrer el árbol DOM de forma determinista y segura.
   - Para **MIDI**, se implementa un decodificador binario en Dart puro utilizando `ByteData` para procesar cabeceras `MThd` y eventos de pistas `MTrk` con decodificación de enteros de longitud variable (*variable-length quantity*).

2. **Capa de Dominio (`lib/features/universal_importer/domain/`):**
   - Se crea el contrato `IScoreParserService` desacoplado de la UI y del sistema de archivos, aceptando `Uint8List bytes` y el nombre del archivo.
   - Se estandariza la salida en `ParsedScoreResult` que entrega directamente una entidad `SongPackage` lista para ser consumida por el `TunerViewModel`, el `RealSheetMusicPainter` (SMuFL) y la consola de stems.

3. **Cuantización y Tolerancia a Fallos:**
   - Los parsers normalizan el tiempo de compás a la cuadrícula de 16 semicorcheas por compás de $4/4$ (o equivalente en otros compases).
   - Se implementa auto-relleno de compases incompletos mediante silencios (`HierarchicalNote.rest`) para asegurar que la invariant de compases válidos se preserve siempre.

4. **Integración en la UI:**
   - Se agrega una tarjeta de acción en `SongDecomposerModal` para importar archivos.
   - La selección de archivos se desacopla mediante un proveedor de bytes (`Future<ScoreFileData?> Function() filePicker`) permitiendo tests unitarios puros con mocks deterministas.

---

## Consecuencias

### Positivas
- **Independencia Total de Repertorio:** El músico puede cargar miles de partituras existentes en formato MusicXML y MIDI.
- **Portabilidad y Testabilidad Máxima:** Al operar sobre bytes en Dart puro, los parsers pueden probarse exhaustivamente en pruebas unitarias del Dart VM con cero llamadas a canales de plataforma.
- **Alineación con SMuFL:** Las notas y silencios decodificados se renderizan con la tipografía SMuFL estandarizada del proyecto.

### Negativas / Mitigaciones
- Archivos MIDI polifónicos densos (e.g. obras completas para piano con acordes de 8 notas) pueden requerir simplificación a la voz superior para el pentagrama monofónico del afinador.  
  *Mitigación:* El parser MIDI extrae la nota melódica más aguda de cada intervalo de tiempo para el pentagrama del estudiante, manteniendo las demás voces en los stems de la mezcladora.
