# Plan de Implementación Maestro: Sistema de Archivos Unificado y Suite de Ingesta Universal (US-FS-01 a US-FS-05)

Este documento formaliza el plan maestro de ingeniería para unificar el sistema de archivos local de **Tunner**, la ingesta universal de formatos de audio y partitura, la transcripción polifónica rápida con descomposición en 4 Stems, el patrón *Copy-on-Import Project Media Pool*, la resolución perezosa desde disco con enrutamiento dual y la ergonomía multiplataforma del selector nativo.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-UNIFIED-FS-INGESTION-2026-0188`
- **Título de la Implementación:** Sistema de Archivos Unificado, Ingesta Universal, Transcripción Acotada a 4 Stems y Enrutamiento Dual
- **Fase del Proyecto:** Fase 2 & Fase 4 (Sistema de Archivos, Ingesta Universal y Motor DSP)
- **Estado:** Aprobado
- **ADRs Relacionados:**
  - [ADR 0180: Taxonomía Universal de Tipos de Archivo y Preservación de Extensión Física](../04_adrs/0180_universal_studio_file_type_taxonomy_and_extension_preservation.md)
  - [ADR 0181: Transcripción Polifónica Acotada por Salto Adaptativo y 4 Stems](../04_adrs/0181_adaptive_hop_polyphonic_audio_transcription_and_four_stem_decomposition.md)
  - [ADR 0182: Patrón Copy-on-Import Project Media Pool y Telemetría Diagnóstica](../04_adrs/0182_copy_on_import_project_media_pool_and_diagnostic_telemetry.md)
  - [ADR 0183: Resolución Perezosa de Payload desde Disco y Enrutamiento Dual](../04_adrs/0183_lazy_disk_payload_resolution_and_dual_deck_score_routing.md)
  - [ADR 0184: Acción Directa de Ingesta en el Explorador y Selector Nativo Multiplataforma](../04_adrs/0184_explorer_direct_ingestion_action_and_cross_platform_native_picker.md)
- **Documentos Funcionales Base:**
  - [UC-188 (US-FS-01)](../02_use_cases/188_uc_universal_studio_file_type_taxonomy_and_extension_preservation.md)
  - [UC-189 (US-FS-02)](../02_use_cases/189_uc_adaptive_hop_polyphonic_audio_transcription_and_four_stem_decomposition.md)
  - [UC-190 (US-FS-03)](../02_use_cases/190_uc_copy_on_import_project_media_pool_and_diagnostic_telemetry.md)
  - [UC-191 (US-FS-04)](../02_use_cases/191_uc_lazy_disk_payload_resolution_and_dual_deck_score_routing.md)
  - [UC-192 (US-FS-05)](../02_use_cases/192_uc_explorer_direct_ingestion_action_and_cross_platform_native_picker.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Eliminar todas las rupturas de extremo a extremo entre el Explorador de Proyecto en disco, el selector nativo de archivos del sistema operativo, el decodificador de audio comprimido, el motor de transcripción polifónica y los módulos consumidores (Consola DJ y Editor de Partituras / Mezclador de 4 Stems), garantizando ejecución 100% offline, determinista y sin bloqueos de interfaz.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `US-FS-01`: Taxonomía universal en `StudioFileType` (12 extensiones de audio, 7 de notación/partitura), `extractExtension` y preservación en `LocalDiskStudioFileSystemRepository`.
  - `US-FS-02`: Optimización de `AudioToScoreTranscriptionEngine` (`maxAnalysisFrames = 480`, `defaultMinClarity = 0.32`, diezmado anti-aliasing y extractor ZCR-RMS pasa-bajos a $880\text{ Hz}$) y descomposición en 4 Stems vía `SongDecomposerService`.
  - `US-FS-03`: Persistencia automática *Copy-on-Import* en `/Tomas de Audio & WAV/` o `/Partituras & Notación/` y telemetría diagnóstica (`lastImportError`, `isImportingFile`) en `TunerViewModel`.
  - `US-FS-04`: Resolución asíncrona de bytes desde disco en `MainAppShell._handleOpenFile` cuando `payload == null`, transcodificación automática vía `IAudioTranscoderPort` y enrutamiento dual hacia `Deck A` y Pentagrama/Stems.
  - `US-FS-05`: Botón `btn_import_external_file` desacoplado por callback en `StudioExplorerActionHeader` / `StudioVsCodeExplorerWidget`, selector multiplataforma Windows/Linux en `PlatformFileGateway.pickFile` y resolución multiplataforma de `ffmpeg.exe`/`ffmpeg` en `FfmpegAudioTranscoderService`.
- **Excluido (Out-of-Scope):**
  - Servicios remotos en la nube para separación de fuentes o transcripción (violación de la regla Offline-First en `AGENTS.md`).
  - Rediseño visual completo de tarjetas del Dashboard fuera del Explorador y modales de importación.

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x` (Null-safety estricto, Pure Dart en `lib/domain` y `lib/core/file_system/domain`).
  - Flutter SDK: Versión estable del canal oficial (Linux y Windows Desktop).
  - Dependencias clave de infraestructura: `file_picker` (encapsulado en `PlatformFileGateway`), `path_provider` y binario local `ffmpeg` / `ffmpeg.exe` (encapsulado en `FfmpegAudioTranscoderService`).
- **Riesgo Tecnológico:**
  - **FFI / Subprocesos nativos:** No introduce nuevos bindings FFI; utiliza `Process.run` encapsulado únicamente en `lib/core/audio/infrastructure/ffmpeg_audio_transcoder_service.dart` sobre directorio temporal aislado con limpieza en bloque `finally`.
  - **Rendimiento del bucle principal de Flutter:** El cálculo de `AudioToScoreTranscriptionEngine` queda estrictamente acotado a `480` ventanas con diezmado ($< 250\text{ ms}$ en pistas comerciales), evitando congelamientos de UI y eliminando cualquier busy-waiting.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos, Taxonomía y Contratos Puros)
- [x] **US-FS-01 (`StudioFileType`):** Ampliar `_audioExtensions` y `_scoreExtensions` en `lib/core/file_system/domain/studio_file_type.dart` e implementar `extractExtension`.
- [x] **US-FS-02 (`AudioToScoreTranscriptionEngine` y `SongDecomposerService`):** Implementar `maxAnalysisFrames = 480`, `defaultMinClarity = 0.32`, diezmado anti-aliasing ($8820\text{ Hz}$), extractor de respaldo ZCR-RMS con filtro IIR pasa-bajos ($f_c = 880\text{ Hz}$) y conexión a `SongDecomposerService.decomposeCustomScore` (4 Stems).
- [x] Contratos puros: `IAudioTranscoderPort`, `IPlatformFileGateway`, `IStudioWorkspaceFileSystem` y `StudioFileSystemRepository`.

### Paso 2: Capa de Infraestructura / Datos (Disco, Picker Nativo y Transcodificador)
- [x] **US-FS-01 (`LocalDiskStudioFileSystemRepository`):** Conservar la extensión física real con `StudioFileType.extractExtension(fileName, fileType)` durante `_scanDirectoryRecursively`, manteniendo intacto el confinamiento `_resolveSafePath`.
- [x] **US-FS-05 (`PlatformFileGateway` y `FfmpegAudioTranscoderService`):** Implementar estrategia dual Linux (`FileType.any` multi-formato) vs Windows (`FileType.custom` en minúsculas) en `pickFile`, lectura de respaldo por `picked.path` y resolución multiplataforma de `ffmpeg.exe` / `ffmpeg`.

### Paso 3: Capa de Aplicación / Presentación (ViewModels, Shell y Explorador VS Code)
- [x] **US-FS-03 (`TunerViewModel`):** Implementar `lastImportError`, `isImportingFile` y copia automática *Copy-on-Import* hacia `/Tomas de Audio & WAV/` o `/Partituras & Notación/` en `importScoreFromBytes` e `importScoreFromFilePicker`.
- [ ] **US-FS-04 (`MainAppShell._handleOpenFile`):** Completar la resolución asíncrona desde disco cuando `file.payload == null` (`fileSystemRepository.readFile`), transcodificación automática vía `IAudioTranscoderPort` y enrutamiento dual hacia `Deck A` (`DjConsoleViewModel.loadDeckTrack`) y Pentagrama/Stems (`TunerViewModel.importScoreFromBytes`), además de conectar `onImportExternalFile` en `StudioVsCodeExplorerWidget` dentro de `main_app_shell.dart`.
- [x] **US-FS-05 (`StudioExplorerActionHeader` y `StudioAssetsModals`):** Renderizar `btn_import_external_file` desacoplado por `onImportExternalFile` y consumir `lastImportError` en `StudioAssetsModals.showImportScoreDialog`.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] `test/core/file_system/us_fs_01_studio_file_type_test.dart`
- [x] `test/features/universal_importer/us_fs_02_fast_polyphonic_song_transcription_test.dart`
- [x] `test/features/universal_importer/us_fs_03_copy_on_import_project_pool_test.dart`
- [ ] Suite de integración `us_fs_04` para apertura perezosa desde disco y enrutamiento dual en `MainAppShell`
- [x] `test/core/file_system/us_fs_05_explorer_import_button_ui_test.dart`
- [ ] Ejecución integral de `flutter analyze` (cero advertencias) y `flutter test` sobre todas las suites tras completar US-FS-04.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

Si alguna iteración introduce regresiones en el parseo de formatos, apertura de archivos o rendimiento de transcripción:

- **Punto de Restauración Git:** Etiqueta o commit previo en la rama `main` anterior a la fusión de cada PR atómico por historia (`US-FS-01` a `US-FS-05`).
- **Mitigación Inmediata:**
  - Dado que cada historia (`US-FS-01`..`US-FS-05`) posee un ADR, Caso de Uso y suite de pruebas independiente y se integra en PRs aislados, puede revertirse puntualmente el commit de la historia afectada sin comprometer el resto del pipeline.
  - En ausencia del binario `ffmpeg`, `FfmpegAudioTranscoderService` degrada de forma segura retornando `null` y exponiendo un mensaje claro en `TunerViewModel.lastImportError` sin afectar la estabilidad de archivos WAV/MusicXML nativos.

---

## 5. Criterios de Aceptación (Definition of Done)

Para considerar completada la suite completa:
- [ ] Código adherido estrictamente a [AGENTS.md](../../AGENTS.md) (Pure Dart en dominio, cero busy-waiting, offline-first, sin números mágicos sin derivación).
- [ ] Todos los 5 ADRs (`0180`–`0184`), 5 Casos de Uso (`188`–`192`) y este Plan Maestro aprobados y actualizados en `docs/`.
- [ ] Las 5 suites de pruebas (`us_fs_01` a `us_fs_05`) más las pruebas de regresión de `file_system`, `universal_importer` y `navigation` pasando al 100%.
- [ ] `flutter analyze` reportando cero errores y cero advertencias.
- [ ] Revisión y aprobación explícita del creador/mantenedor principal.
