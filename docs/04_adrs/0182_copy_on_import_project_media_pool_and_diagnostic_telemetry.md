# ADR 0182: Patrón Copy-on-Import Project Media Pool y Telemetría Diagnóstica de Ingesta

- **Estado:** Aprobado
- **Fecha:** 2026-11-23
- **Autor:** Nicolás León
- **Caso de Uso Relacionado:** [UC-190](../02_use_cases/190_uc_copy_on_import_project_media_pool_and_diagnostic_telemetry.md)

---

## 1. Contexto

Antes de esta decisión, la importación de archivos externos mediante `TunerViewModel.importScoreFromFilePicker` e `importScoreFromBytes` (`lib/features/tuner/presentation/tuner_viewmodel.dart`) sufría dos deficiencias operativas frente a estaciones de trabajo de audio digital (DAWs) estándar como Ableton Live 12 y Reaper:

1. **Volatilidad de Recursos Importados:** Los archivos de audio o partituras elegidos desde carpetas externas del sistema operativo (p. ej. `Descargas` o `Música`) se decodificaban únicamente en memoria volátil (`_workspaceScores`). No existía copia física hacia el proyecto activo del estudio (`IStudioWorkspaceFileSystem`), por lo que el Explorador de Proyecto estilo VS Code permanecía desincronizado y los archivos desaparecían al reiniciar o trasladar el proyecto.
2. **Opacidad Diagnóstica de Fallos vs. Cancelación:** Cuando `importScoreFromFilePicker` o `importScoreFromBytes` retornaban `null`, la interfaz no disponía de estado observable para distinguir si el usuario había cancelado voluntariamente el diálogo nativo o si había ocurrido un error real (archivo vacío, falla de transcodificación en `FFmpeg` o formato corrupto), ni de un indicador reactivo de carga (`isImportingFile`).

---

## 2. Decisión

Se adopta el patrón **Copy-on-Import Project Media Pool** junto con telemetría diagnóstica reactiva en `TunerViewModel` e `IStudioWorkspaceFileSystem`:

1. **Copia Determinista al Pool del Proyecto (`importScoreFromBytes`):**
   - Tras transcodificar (si aplica) y validar la decodificación vía `_scoreImporterService.parseScoreData`, si `_workspaceFileSystem != null`, el archivo se persiste automáticamente en una de dos carpetas canónicas en la raíz del proyecto:
     - `/Tomas de Audio & WAV/` (`StudioFileType.audioWav`) cuando el formato original es audio comprimido soportado por `_audioTranscoder.isSupportedCompressedExtension(ext)` o PCM/AIFF/WAV (`wav`, `pcm`, `aif`, `aiff`). Si fue transcodificado desde formato comprimido, la copia almacenada en el pool se normaliza con extensión `.wav` (`$baseTitle.wav`) y sus bytes PCM 16-bit resultantes (`effectiveBytes`).
     - `/Partituras & Notación/` (`StudioFileType.score`) para partituras (`musicxml`, `mxl`, `xml`, `mid`, `midi`, `abc`, `pdf`).
   - Si la carpeta destino no existe en `rootFolder.children`, `TunerViewModel` la crea automáticamente con `_workspaceFileSystem.createFolder(...)` antes de invocar `_workspaceFileSystem.createFile(..., initialBytes: effectiveBytes)`.
   - Un fallo en la persistencia en el pool emite advertencia vía `_logger.warning` sin abortar la sesión de análisis ya cargada en memoria.

2. **Máquina de Estados de Telemetría Diagnóstica (`lastImportError` e `isImportingFile`):**
   - `bool get isImportingFile`: transiciona a `true` al iniciar `importScoreFromBytes` (notificando listeners) y regresa a `false` en bloque `finally`.
   - `String? get lastImportError`:
     - Permanece estrictamente en `null` cuando `pickFile()` retorna `null` (cancelación voluntaria del usuario).
     - Registra mensaje descriptivo con el nombre del archivo cuando:
       1. El archivo seleccionado tiene `bytes == null || bytes!.isEmpty`.
       2. `IAudioTranscoderPort.transcodeToWav16BitPcm` retorna `null` o vacío para audio comprimido.
       3. `_scoreImporterService.parseScoreData` o `pickFile` lanzan una excepción.

---

## 3. Consecuencias

### 3.1 Positivas
- **Autocontención de Proyectos (Offline-First):** Todo proyecto Tunner conserva físicamente en su árbol local las copias de audio WAV y partituras importadas, replicando el flujo *Collect All and Save / Copy Media to Project Directory* de Ableton Live 12 y Reaper.
- **Feedback UX Preciso:** `StudioAssetsModals.showImportScoreDialog` consulta `lastImportError` para mostrar un `SnackBar` diagnóstico solo ante fallos reales, manteniendo silencio elegante cuando el usuario presiona "Cancelar" en el selector nativo.
- **Inyección Limpia para Pruebas:** Al depender exclusivamente de abstracciones (`IStudioWorkspaceFileSystem`, `IAudioTranscoderPort`, `IPlatformFileGateway`), la lógica completa es verificable sin disco real ni UI mediante `MemoryStudioFileSystemRepository`.

### 3.2 Compromisos
- Al persistir la copia WAV decodificada en lugar del MP3 original cuando hay transcodificación, el pool del proyecto ocupa mayor espacio en disco a cambio de garantizar reproducción instantánea de latencia cero sin re-decodificar `FFmpeg` en cada apertura futura.

---

## 4. Verificación

Validado en [us_fs_03_copy_on_import_project_pool_test.dart](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/test/features/universal_importer/us_fs_03_copy_on_import_project_pool_test.dart):
- Persistencia automática de `.musicxml` en `/Partituras & Notación/obra_prueba.musicxml` y validación de transición `[true, ..., false]` de `isImportingFile`.
- Transcodificación y persistencia de audio `.mp3` en `/Tomas de Audio & WAV/pista_ensayo.wav`.
- Verificación de los 4 escenarios de telemetría: fallo de transcodificación (`lastImportError` contiene nombre de archivo), cancelación de usuario (`lastImportError == null`), archivo vacío (`lastImportError` contiene nombre) y payload corrupto.
