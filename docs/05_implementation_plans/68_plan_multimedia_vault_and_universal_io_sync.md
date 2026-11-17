# Plan de Implementación: Bóveda Multimedia, Línea de Tiempo Drag & Drop y Suite Universal I/O

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-MEDIA-VAULT-2026-068`
- **Título de la Implementación:** `Bóveda Multimedia Centralizada, Línea de Tiempo Drag & Drop y Motor Universal de Importación/Exportación`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `Aprobado`
- **ADR Relacionado:** [ADR-0064](../04_adrs/0064_multimedia_vault_timeline_drop_and_synergy_io.md)
- **Documento Funcional Base:** [DOC-MEDIA-2026-070](../01_product_vision/doc_multimedia_vault_and_universal_io_sync.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Proveer a **Tunner** de una ventana multimedia unificada donde el usuario pueda importar, almacenar, buscar, arrastrar hacia líneas de tiempo multi-pista, sincronizar con herramientas (`DJ Console`, `Mixer`, `Score Editor`, `Practice Recorder`) y exportar proyectos, partituras y audio WAV sin pérdida 100% offline.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades puras de Dominio en `lib/features/media_vault/domain/`: activos multimedia, pistas/clips de línea de tiempo, motor de cuantización/colisión y contratos de exportación/importación.
  - Capa Data en `lib/features/media_vault/data/`: `WavPcmCodec`, `UniversalMediaIoService` (WAV, MIDI, MusicXML, MXL, ABC, PDF, `.cue`, `.tunner.json`) y repositorio local.
  - Capa Presentation en `lib/features/media_vault/presentation/`: `MediaVaultViewModel`, `TimelineArrangementPainter` y `MediaVaultWorkspaceModal` con `Draggable` / `DragTarget`.
  - Botón de acceso directo desde la cabecera principal de `Tunner` y desde `DjConsoleModal`.
  - Suite completa de pruebas unitarias, I/O y UI.
- **Excluido (Out-of-Scope):**
  - Decodificación FFI nativa en C/Rust de códecs comprimidos (MP3/FLAC/OGG) en esta iteración.

---

## 2. Análisis de Dependencias y Tecnologías

- **SDKs:** Dart `^3.11.5`, Flutter estable.
- **Paquetes existentes reutilizados (cero paquetes nuevos):** `file_picker`, `path_provider`, `archive`, `xml`, `provider`.
- **Riesgo Tecnológico:** Bajo. No se agregan dependencias externas ni llamadas de red.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (`lib/features/media_vault/domain/`)
- [ ] Crear `media_asset_entity.dart` (`MediaAssetKind`, `MediaAssetEntity` con serialización JSON y metadatos musicales).
- [ ] Crear `timeline_project_entity.dart` (`TimelineTrackKind`, `TimelineClipEntity`, `TimelineTrackEntity`, `TimelineProjectEntity` con cuantización al beatgrid y resolución no destructiva de colisiones).
- [ ] Crear `media_synergy_target.dart` (`MediaSynergyTarget`, `MediaExportFormat`, `MediaImportResult`, `MediaExportResult`).
- [ ] Crear `i_media_io_port.dart` (contratos abstractos `IMediaIoService` y `IMediaVaultRepository`).
- [ ] Escribir pruebas unitarias en `test/features/media_vault/domain/media_vault_domain_test.dart`.

### Paso 2: Capa de Infraestructura / Datos (`lib/features/media_vault/data/`)
- [ ] Implementar `wav_pcm_codec.dart` (lectura/escritura de encabezados RIFF/WAVE PCM 16-bit y renderizado de mixdown multi-clip).
- [ ] Implementar `universal_media_io_service.dart` (importación unificada + exportación a `.wav`, `.mid`, `.musicxml`, `.abc`, `.pdf`, `.cue`, `.tunner.json`).
- [ ] Implementar `in_memory_media_vault_repository.dart` (gestión ordenada de activos y serialización completa de bóveda).
- [ ] Escribir pruebas de I/O en `test/features/media_vault/data/media_vault_io_test.dart`.

### Paso 3: Capa de Presentación (`lib/features/media_vault/presentation/`)
- [ ] Implementar `media_vault_viewmodel.dart` con `Ticker`/delta playback, filtros de bóveda, operaciones Drag & Drop en línea de tiempo y despacho hacia herramientas.
- [ ] Implementar `timeline_arrangement_painter.dart` (`CustomPainter` de beatgrid, regla temporal, clips con mini-waveform y playhead).
- [ ] Implementar `media_vault_workspace_modal.dart` con layout responsivo, tarjetas arrastrables, pistas `DragTarget`, zonas rápidas de sincronización (`Deck A`, `Deck B`, `Sampler`, `Score Editor`, `Mixer`) y menú de importación/exportación.
- [ ] Integrar botón de apertura en `DjConsoleModal` y en la vista principal de la aplicación.
- [ ] Escribir pruebas de widget en `test/features/media_vault/presentation/media_vault_ui_test.dart`.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Ejecutar `flutter analyze` (0 issues).
- [ ] Ejecutar `flutter test` completo al 100%.
- [ ] Actualizar documentación si surgieron ajustes de diseño, hacer commit convencional y abrir PR.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit `dd04eb2` en rama `feature/standalone-pro-dj-workstation-suite`.
- **Mitigación Inmediata:** El módulo `lib/features/media_vault/` está completamente aislado; revertir los puntos de entrada en la UI restaura el estado previo sin afectar otras herramientas.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Adherencia estricta a `AGENTS.md` (cero emojis, Clean Architecture 100%, sin números mágicos sin documentar).
- [ ] `flutter analyze` con 0 advertencias/errores.
- [ ] 100% de pruebas pasando en dominio, datos y presentación.
- [ ] Documentación completa (`DOC-MEDIA-2026-070`, `UC-70`, `ADR-0064`, `PLAN-68`) actualizada.
