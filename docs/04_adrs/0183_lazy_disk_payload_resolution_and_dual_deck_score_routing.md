# ADR 0183: Resolución Perezosa de Payload desde Disco, Transcodificación Comprimida y Enrutamiento Dual Deck A / Partitura

- **Estado:** Aprobado
- **Fecha:** 2026-11-23
- **Autor:** Nicolás León
- **Caso de Uso Relacionado:** [UC-191](../02_use_cases/191_uc_lazy_disk_payload_resolution_and_dual_deck_score_routing.md)

---

## 1. Contexto

Al escanear el directorio físico del proyecto con `LocalDiskStudioFileSystemRepository._scanDirectoryRecursively`, los nodos `StudioFileEntity` se construyen de forma ligera con `payload: null` para evitar cargar en RAM gigabytes de grabaciones WAV/MP3 o partituras al arrancar el estudio.

Sin embargo, el manejador de apertura `MainAppShell._handleOpenFile(StudioFileEntity file)` (`lib/features/navigation/presentation/main_app_shell.dart`) asumía originalmente que `file.payload` ya venía precargado en memoria (`file.payload is Uint8List`, `String` o `SongPackage`). Como consecuencia:

1. Al hacer doble clic o abrir cualquier archivo persistido en disco (partitura, audio, preset de afinación o proyecto `.tunner`), `file.payload` era `null` y la apertura se convertía en una operación silenciosamente vacía.
2. Si un usuario depositaba un archivo comprimido (`.mp3`, `.flac`, `.ogg`, `.m4a`, `.aac`, `.opus`, `.wma`, `.webm`, `.aiff`) directamente en la carpeta del proyecto, la Consola DJ y el transcriptor necesitaban bytes WAV PCM decodificados mediante `IAudioTranscoderPort` (`FfmpegAudioTranscoderService`).
3. Abrir un archivo de audio desde el Explorador solo debía enrutar al `Deck A` o también permitir transcripción/descomposición en Stems según el flujo del usuario, manteniendo coherencia entre la Consola DJ y el Editor de Partituras / Mezclador de Stems.

---

## 2. Decisión

Se establece una arquitectura de **Resolución Perezosa de Payload desde Disco (Lazy Disk Payload Resolution)** y **Enrutamiento Dual Inteligente** en `MainAppShell._handleOpenFile`:

1. **Resolución Asíncrona Bajo Demanda (`payload == null`):**
   - `_handleOpenFile` evoluciona a un flujo asíncrono que verifica si `file.payload` es `null`.
   - Cuando `file.payload == null`, resuelve los bytes físicos desde disco invocando el puerto del repositorio (`_fileSystemService.fileSystemRepository.readFile(file.relativePath)` / adaptador `readFileBytes`), verificando `mounted` tras cada `await` para prevenir uso de `BuildContext` desmontado.
   - Si los bytes leídos están vacíos o el archivo no existe en disco, se informa al usuario mediante `SnackBar` diagnóstico sin lanzar excepciones no controladas en UI.

2. **Transcodificación Transparente de Audio Comprimido:**
   - Para nodos `StudioFileType.audioWav` cuya extensión normalizada (`StudioFileType.extractExtension(file.name, file.fileType)`) pertenezca a `IAudioTranscoderPort.compressedAudioExtensions`, los bytes crudos se transcodifican a PCM WAV 16-bit mediante `IAudioTranscoderPort` (`FfmpegAudioTranscoderService` en `StudioCompositionRoot`).

3. **Enrutamiento Dual Inteligente (Consola DJ Deck A + Pentagrama / Mezclador de Stems):**
   - **`StudioFileType.score`:** Navega al tab del Editor de Partituras (`_navigateToTab(4)`) e inyecta los bytes resueltos en `vm.importScoreFromBytes(resolvedBytes, file.name)`.
   - **`StudioFileType.audioWav`:**
     - Carga el audio WAV resuelto en el `Deck A` de `_djConsoleViewModel.loadDeckTrack(deckId: 'A', filePath: file.relativePath, wavBytes: effectiveWavBytes, title: file.name, ...)` y navega a la Consola DJ (`_navigateToTab(5)`).
     - En paralelo (o mediante sincronización con `TunerViewModel.importScoreFromBytes`), mantiene disponible la partitura transcrita y sus 4 Stems (`lead_stem`, `harmony_stem`, `bass_stem`, `rhythm_stem`) en el Pentagrama / Mezclador de Stems, ofreciendo acceso directo o notificación con acción rápida hacia el Editor de Partituras.
   - **`StudioFileType.tuningPreset`, `djBlueprint`, `project`:** Decodifican el JSON o paquete binario `.tunner` a partir de los bytes leídos del disco cuando `payload == null`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Consumo de Memoria O(1) en Reposo:** El árbol del Explorador VS Code no retiene buffers binarios en RAM durante el escaneo inicial; los bytes se leen únicamente del archivo seleccionado por el usuario.
- **Soporte Real de Archivos Externos Copiados al Disco:** Cualquier `.mp3`, `.flac`, `.mid`, `.pdf`, `.musicxml` o `.tunner` colocado en `~/Documents/TunnerProjects` es completamente operable desde el Explorador.
- **Sinergia DJ / Pedagogía:** Un mismo archivo de audio alimenta tanto la mezcla en vivo en `Deck A` como el análisis armónico y de 4 Stems en el estudio.

### 3.2 Riesgos y Mitigaciones
- **Disponibilidad de `ffmpeg` en el sistema:** Si `FfmpegAudioTranscoderService` retorna `null` por ausencia del binario o archivo corrupto, el flujo captura la condición y notifica un mensaje claro sin bloquear la Consola DJ ni dejar el shell en estado inconsistente.

---

## 4. Verificación

Validado mediante las pruebas de integración de apertura de archivos, transcodificación y enrutamiento:
- Suite de repositorio en disco: [local_disk_file_system_repository_test.dart](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/test/core/file_system/local_disk_file_system_repository_test.dart).
- Suite de transcodificación MP3 y puerto `IAudioTranscoderPort`: [mp3_import_and_didactic_browser_test.dart](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/test/features/universal_importer/mp3_import_and_didactic_browser_test.dart).
- Suite de integración de `MainAppShell` y apertura perezosa desde disco (`us_fs_04`): [main_app_shell_test.dart](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/test/features/navigation/main_app_shell_test.dart) y pruebas específicas `us_fs_04_*` asociadas a la historia `US-FS-04`.
