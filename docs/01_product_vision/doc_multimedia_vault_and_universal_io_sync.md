# Especificación Técnica: Bóveda Multimedia, Línea de Tiempo Drag & Drop y Suite Universal de Importación/Exportación

## Metadatos del Documento

- **ID del Documento:** `DOC-MEDIA-2026-070`
- **Título Oficial:** `Bóveda Multimedia Centralizada, Línea de Tiempo Drag & Drop y Motor Universal de Importación/Exportación`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-11-14`
- **Última Modificación:** `2026-11-14`
- **Fase Asociada:** `Fase 2 - Sinergia Modular y Workstation`
- **Autor / Revisor Principal:** `Equipo Tunner`

---

## 1. Resumen Ejecutivo (Executive Summary)

La **Bóveda Multimedia (Media Vault)** y el **Espacio de Línea de Tiempo Sincronizada (Timeline Arrangement Canvas)** unifican la gestión, organización, importación y exportación de todos los activos musicales de **Tunner** (canciones, stems, partituras MusicXML/MXL/ABC/PDF, archivos MIDI, grabaciones de práctica y presets DJ) en un único espacio 100% offline.

Desde una ventana dedicada, el usuario puede importar archivos locales con detección automática de formato y metadatos acústicos (BPM, tonalidad Camelot, duración, forma de onda espectral), arrastrar y soltar (`Drag & Drop`) cualquier activo hacia pistas de una línea de tiempo cuantizada al beatgrid o directamente hacia las herramientas activas (`DJ Console Deck A/B`, `Club Sampler`, `Mixer`, `Score Editor`), y exportar mezclas, stems o proyectos completos en formatos estándar de la industria (`WAV PCM 16/24-bit`, `MIDI`, `MusicXML`, `ABC`, `PDF`, `.cue` y `JSON Bundle`).

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Actualmente, Tunner cuenta con herramientas potentes pero con flujos de archivos fragmentados:
- `universal_importer` procesa partituras (`MusicXML`, `MXL`, `ABC`, `MIDI`, `PDF`).
- `song_library` gestiona paquetes de canciones y stems `Minus-One`.
- `practice_recorder` almacena sesiones grabadas.
- `dj_console` ejecuta mezcla en vivo, stems, loops, sampler y beatgrid.

Sin una bóveda centralizada ni un lienzo de línea de tiempo con `Drag & Drop`, el músico o DJ no tiene un espacio visual único donde almacenar su catálogo, previsualizar sus activos, organizarlos en el tiempo y sincronizarlos entre herramientas o exportarlos en un solo clic.

### 2.2 Fundamento Teórico / Físico / Musical
- **Cuantización Temporal en Línea de Tiempo:** Todo clip arrastrado a la línea de tiempo se alinea opcionalmente al beatgrid maestro mediante:
  $$\text{beatIndex} = \text{round}\left(\frac{t_{\text{drop\_ms}} \cdot \text{BPM}}{60000}\right), \quad t_{\text{snap\_ms}} = \frac{\text{beatIndex} \cdot 60000}{\text{BPM}}$$
- **Codificación PCM RIFF/WAV Estándar:** La exportación de audio sin pérdida genera encabezados RIFF/WAVE de 44 bytes (PCM lineal IEEE/Int16 o Int24, Little-Endian) garantizando compatibilidad universal con DAWs (`Ableton`, `FL Studio`, `Reaper`, `Audacity`) y reproductores hardware sin dependencias externas.
- **Compatibilidad Armónica Cruzada:** Cada activo de audio o partitura indexado en la bóveda conserva su tonalidad cromática y código Camelot (`1A`–`12B`) para filtrar compatibilidad armónica antes de arrastrarlo a un Deck o pista.

---

## 3. Especificación Funcional Detallada

### 3.1 Comportamiento del Sistema y Requerimientos
- **REQ-01 (Bóveda Multimedia Universal):** Almacenamiento y catalogación unificada de 6 tipos de activos: `audioTrack`, `stem`, `sheetMusic`, `midiSequence`, `practiceRecording`, y `djSessionPreset`.
- **REQ-02 (Búsqueda, Etiquetado y Filtrado Inteligente):** Filtrado instantáneo por tipo de activo, rango de BPM, tonalidad Camelot compatible o etiqueta personalizada.
- **REQ-03 (Importación Universal Multi-Formato):** Pipeline unificado capaz de ingerir `.wav`, `.mid`/`.midi`, `.musicxml`/`.xml`, `.mxl`, `.abc`, `.pdf` y paquetes `.tunner.json` mediante `file_picker` o registro programático, extrayendo metadatos y validando integridad.
- **REQ-04 (Línea de Tiempo Multi-Pista Drag & Drop):** Lienzo temporal con pistas tipadas (`Deck A / Audio`, `Deck B / Stems`, `Partitura / MIDI`, `Sampler / SFX`) que acepta `Drag & Drop` desde la Bóveda, permite mover clips horizontalmente, ajustar ganancia/mute/solo por pista, hacer zoom temporal y activar/desactivar `Snap to Beatgrid`.
- **REQ-05 (Sincronización Directa con Herramientas):** Arrastrar o enviar un activo desde la Bóveda o Línea de Tiempo hacia `DJ Console (Deck A / Deck B / Sampler Pad)`, `Score Editor`, `Mixer` o `Practice Recorder` sin acoplamiento directo entre features.
- **REQ-06 (Exportación Universal Top-Tier):** Exportación offline en:
  - Audio PCM `.wav` (mezcla de línea de tiempo o clip individual).
  - Partitura `.musicxml`, `.abc`, `.mid`, `.pdf` (delegando en los exportadores canónicos existentes).
  - Setlist / Marcadores `.cue` para sesiones DJ.
  - Paquete portátil `.tunner.json` con metadatos completos de bóveda, línea de tiempo y cues.

### 3.2 Casos de Borde y Condiciones de Error
- **Archivo corrupto o extensión no soportada:** El pipeline de importación rechaza el archivo de forma segura devolviendo un `MediaImportResult` con diagnóstico explícito sin cerrar la sesión ni corromper la bóveda.
- **Colisión de clips en la misma pista:** Al soltar un clip sobre un rango ocupado en la línea de tiempo, el motor de dominio resuelve el desplazamiento o recorte no destructivo manteniendo determinismo.
- **Exportación de línea de tiempo vacía:** Se bloquea la exportación WAV/MIDI vacía con mensaje descriptivo al usuario.

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (`lib/features/media_vault/domain/`)
100% Pure Dart, cero dependencias de Flutter UI o plugins de plataforma:
- `media_asset_entity.dart`: Entidad inmutable `MediaAssetEntity` y enum `MediaAssetKind` (`audioTrack`, `stem`, `sheetMusic`, `midiSequence`, `practiceRecording`, `djSessionPreset`).
- `timeline_project_entity.dart`: Entidades inmutables `TimelineClipEntity`, `TimelineTrackEntity`, `TimelineProjectEntity` y motor puro de cuantización/snap, detección de colisiones y desplazamiento de clips.
- `media_synergy_target.dart`: Contratos puros para enrutar activos hacia destinos de Tunner (`djDeckA`, `djDeckB`, `djSamplerPad`, `scoreEditor`, `mixerChannel`, `timelineTrack`).
- `i_media_io_port.dart`: Puertos abstractos `IMediaImporterPort`, `IMediaExporterPort` y `IMediaVaultRepository`.

### 4.2 Capa de Infraestructura / Datos (`lib/features/media_vault/data/`)
- `wav_pcm_codec.dart`: Codificador y decodificador RIFF/WAV PCM puro en Dart (soporta lectura de encabezados WAV 16/24/32-bit y renderizado de mezcla de clips en línea de tiempo a bytes WAV listos para disco).
- `universal_media_io_service.dart`: Orquestador de importación y exportación que integra:
  - `UniversalScoreImporterService` y exportadores canónicos (`MIDI`, `MusicXML`, `ABC`, `PDF`) de `universal_importer`.
  - Generador de archivos `.cue` y paquetes `.tunner.json`.
  - Codificador `WavPcmCodec` para entradas y salidas de audio sin pérdida.
- `in_memory_media_vault_repository.dart`: Repositorio reactivo desacoplado con persistencia JSON serializable para tests y ejecución local offline.

### 4.3 Capa de Presentación (`lib/features/media_vault/presentation/`)
- `media_vault_viewmodel.dart`: `ChangeNotifier` que coordina la Bóveda, la Línea de Tiempo, el estado de importación/exportación, la reproducción/playhead y el callback desacoplado hacia otras herramientas (`onDispatchToTool`).
- `timeline_arrangement_painter.dart`: `CustomPainter` de alto rendimiento (60/120 FPS) que dibuja la regla de compases/beats, grid cuantizado, formas de onda en miniatura por clip y playhead.
- `media_vault_workspace_modal.dart`: Vista/ventana completa dividida en:
  - **Barra superior:** Importar archivo, Exportar (`WAV Mixdown`, `JSON Bundle`, `CUE`, `MIDI/MusicXML`), filtros y controles de transporte de la línea de tiempo (`Play/Stop`, `BPM`, `Snap to Grid`, `Zoom`).
  - **Panel izquierdo (Bóveda Multimedia):** Lista y tarjetas arrastrables (`Draggable<MediaAssetEntity>`) con búsqueda, filtros por tipo y acciones rápidas (`Enviar a Deck A/B`, `Enviar a Timeline`).
  - **Panel derecho (Línea de Tiempo Multi-Pista + Zonas de Soltado):** Pistas receptoras (`DragTarget<MediaAssetEntity>`) para arrastrar música, stems, partituras y grabaciones, mover clips en el tiempo, ajustar volumen/mute/solo y zonas rápidas de soltado hacia herramientas (`Deck A`, `Deck B`, `Score Editor`, `Mixer`).

---

## 5. Criterios de Rendimiento y Benchmarking

- **Renderizado Timeline:** `CustomPainter` con `shouldRepaint` estricto por cambios en clips, zoom o `playheadMs`, manteniendo fluidez 60/120 FPS.
- **Sin Busy-Waiting:** El reloj de reproducción del timeline usa `Ticker` / temporización por delta sin bucles activos.
- **Memoria Determinista:** Buffers PCM asignados con tamaño exacto precalculado al exportar (`Float64List` / `Uint8List`).

---

## 6. Plan de Pruebas y Validación (QA)

- [ ] Pruebas unitarias de dominio (`media_vault_domain_test.dart`): cuantización a beatgrid, resolución de colisiones, CRUD inmutable de bóveda/clips, filtrado por Camelot/tipo y serialización JSON.
- [ ] Pruebas de I/O y codec (`media_vault_io_test.dart`): codificación/decodificación WAV PCM roundtrip, exportación `.cue`, exportación `.tunner.json` y manejo de archivos inválidos.
- [ ] Pruebas de widget y Drag & Drop (`media_vault_ui_test.dart`): renderizado de la ventana Multimedia, filtrado, arrastre/envío de activos a pistas de línea de tiempo, exportación y cero overflow.

---

## 7. Referencias Técnicas y Bibliografía

1. *Microsoft RIFF/WAVE Audio File Format Specification.*
2. *W3C MusicXML 4.0 & Standard MIDI File (SMF) Specification 1.0.*
3. *CDRWIN CUE Sheet Syntax Specification.*
