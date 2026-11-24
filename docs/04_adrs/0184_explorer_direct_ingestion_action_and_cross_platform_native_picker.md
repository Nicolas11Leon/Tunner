# ADR 0184: Acción Directa de Ingesta en el Explorador, Selector Nativo Multiplataforma y Resolución de Binario FFmpeg

- **Estado:** Aprobado
- **Fecha:** 2026-11-23
- **Autor:** Nicolás León
- **Caso de Uso Relacionado:** [UC-192](../02_use_cases/192_uc_explorer_direct_ingestion_action_and_cross_platform_native_picker.md)

---

## 1. Contexto

El flujo de importación de archivos externos desde la interfaz de escritorio presentaba tres fricciones críticas de usabilidad y portabilidad entre Windows y Linux:

1. **Ausencia de punto de entrada directo en el Explorador VS Code:** Aunque el botón `[+] Archivo` (`btn_new_file`) creaba archivos vacíos en el proyecto, el usuario no disponía de un botón explícito en la barra de cabecera `StudioExplorerActionHeader` para importar canciones MP3/WAV o partituras desde el disco del computador sin salir del panel lateral. Al mismo tiempo, `lib/core/file_system/presentation/` no debía acoplarse directamente a `TunerViewModel` ni a `StudioAssetsModals` para respetar la separación estricta de capas.
2. **Bloqueo de filtros en selectores nativos Linux vs. Windows:** En Linux (`zenity`, `kdialog`, `xdg-desktop-portal`), pasar una lista heterogénea de 14 extensiones (`mp3`, `wav`, `flac`, `musicxml`, `mid`, `pdf`, etc.) con `FileType.custom` en `file_picker` provoca en varios entornos de escritorio que el diálogo nativo filtre únicamente por el último o primer tipo (p. ej., mostrando solo archivos `.pdf` y ocultando los `.mp3`). En cambio, en Windows (`IFileOpenDialog`), `FileType.custom` con extensiones en minúsculas sin duplicados es insensible a mayúsculas y funciona de forma óptima.
3. **Resolución frágil de `ffmpeg` / `ffmpeg.exe`:** Invocar `'ffmpeg'` asumiendo únicamente su presencia en el `PATH` global fallaba en paquetes portables de escritorio Windows o instalaciones Linux con rutas explícitas cuando el binario estaba junto al ejecutable o en ubicaciones estándar del sistema.

---

## 2. Decisión

Se implementan tres resoluciones coordinadas en presentación e infraestructura:

1. **Botón `btn_import_external_file` Desacoplado por Callback en el Explorador:**
   - `StudioExplorerActionHeader` y `StudioVsCodeExplorerWidget` exponen `final VoidCallback? onImportExternalFile`.
   - La barra de acciones incorpora un `IconButton` identificado con `Key('btn_import_external_file')` y tooltip `'Importar Audio o Partitura del Computador...'` que ejecuta `widget.onImportExternalFile?.call()`.
   - El shell principal (`MainAppShell`) inyecta el callback invocando `StudioAssetsModals.showImportScoreDialog`, el cual consume `viewModel.importScoreFromFilePicker()` y reporta éxito o `viewModel.lastImportError` mediante `SnackBar`. De este modo `lib/core/file_system/` permanece 100% agnóstico de `features/tuner` y `features/song_library`.

2. **Estrategia Dual de Selector Nativo en `PlatformFileGateway.pickFile`:**
   - Normaliza `allowedExtensions` a minúsculas únicas (`toSet().toList()`).
   - **Windows / Otros OS:** Emplea `FileType.custom` con `allowedExtensions: lowerExts`, aprovechando el filtro nativo insensible a mayúsculas de `IFileOpenDialog`.
   - **Linux (`Platform.isLinux`):** Cuando `lowerExts.length > 1` (selector multi-formato de audio y partituras), utiliza `FileType.any` para evitar que `zenity`/portales bloqueen archivos `.mp3` o `.musicxml`; cuando `lowerExts.length <= 1`, usa `FileType.custom` expandiendo minúsculas y mayúsculas (`[ext.toLowerCase(), ext.toUpperCase()]`) porque los filtros POSIX distinguen capitalización.
   - Si `picked.readAsBytes()` retorna vacío pero existe `picked.path`, lee directamente desde `File(picked.path!)` como respaldo en disco.

3. **Resolución Multiplataforma de `ffmpeg` en `FfmpegAudioTranscoderService._resolveExecutable`:**
   - Si se configuró una ruta explícita distinta de `'ffmpeg'`, la retorna directamente.
   - Determina `binaryName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg'`.
   - Inspecciona en orden de prioridad:
     1. Binario empaquetado junto al ejecutable (`<exeDir>/<binaryName>` y `<exeDir>/bin/<binaryName>`).
     2. Rutas estándar de Windows (`C:\ffmpeg\bin\ffmpeg.exe`, `C:\Program Files\ffmpeg\bin\ffmpeg.exe`) o Linux (`/usr/bin/ffmpeg`, `/usr/local/bin/ffmpeg`).
     3. Respaldo al `PATH` del sistema (`runInShell: Platform.isWindows && executable == 'ffmpeg'`).

---

## 3. Consecuencias

### 3.1 Positivas
- **Descubribilidad Inmediata sin Romper Clean Architecture:** El usuario dispone de importación directa en un clic desde el Explorador VS Code mientras `core/file_system` mantiene cero dependencias hacia `features/`.
- **Paridad Real Windows / Linux:** Tanto usuarios de Windows (`IFileOpenDialog`) como de Linux (`zenity`/portales) pueden seleccionar archivos `.mp3`, `.flac`, `.wav`, `.mid`, `.musicxml` y `.pdf` con mayúsculas o minúsculas sin filtros rotos.
- **Portabilidad de Empaquetado:** Los instaladores portables con `ffmpeg.exe` o `ffmpeg` embebido en `bin/` funcionan sin requerir que el usuario configure variables de entorno `PATH`.

### 3.2 Compromisos
- En Linux multi-formato (`FileType.any`), el usuario puede visualizar archivos no musicales en el diálogo nativo; cualquier extensión no soportada es validada y reportada de manera segura y controlada por `UniversalScoreImporterService` y `TunerViewModel.lastImportError`.

---

## 4. Verificación

Validado en [us_fs_05_explorer_import_button_ui_test.dart](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/test/core/file_system/us_fs_05_explorer_import_button_ui_test.dart):
- Renderizado de `Key('btn_import_external_file')` dentro de `StudioVsCodeExplorerWidget` y disparo exacto del callback `onImportExternalFile`.
- Flujo completo de `StudioAssetsModals.showImportScoreDialog` mostrando `SnackBar` con título, compases y pistas en éxito (`Importado: "Sonata en Do" (16 compases, 2 pistas).`).
- Presentación de `SnackBar` diagnóstico leyendo `viewModel.lastImportError` en fallo de decodificación (`No se pudo importar o decodificar el archivo: ...`).
