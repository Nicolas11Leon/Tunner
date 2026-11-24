# ADR 0180: Taxonomía Universal de Tipos de Archivo y Preservación de Extensión Física en Disco

- **Estado:** Aprobado
- **Fecha:** 2026-11-23
- **Autor:** Nicolás León
- **Caso de Uso Relacionado:** [UC-188](../02_use_cases/188_uc_universal_studio_file_type_taxonomy_and_extension_preservation.md)

---

## 1. Contexto

El sistema de archivos interno de **Tunner** (`lib/core/file_system/`) nació modelando un conjunto reducido de extensiones canónicas de un único sufijo por categoría: `.tunner` para proyectos, `.musicxml` para partituras, `.wav` para audio, `.tnt` para módulos del Rack, `.tpreset` para calibraciones de afinación y `.djblueprint` para mapas de consola DJ.

Al habilitar la ingesta universal de música y notación desde el equipo local del usuario, emergieron dos fallas estructurales:

1. **Clasificación errónea a `StudioFileType.genericFile`:** El método `StudioFileType.fromFileName` únicamente evaluaba un sufijo exacto por variante (por ejemplo, solo `.wav` y `.musicxml`/`.mxl`). Cualquier archivo de audio comprimido o sin pérdida moderno (`.mp3`, `.flac`, `.ogg`, `.m4a`, `.aac`, `.opus`, `.wma`, `.webm`, `.pcm`, `.aif`, `.aiff`) o partitura estándar (`.xml`, `.mid`, `.midi`, `.abc`, `.pdf`) era clasificado como `StudioFileType.genericFile` (`.bin`), perdiendo su icono, color semántico y capacidad de enrutamiento hacia el Editor de Partituras o la Consola DJ.
2. **Pérdida de extensión física al escanear disco:** `LocalDiskStudioFileSystemRepository._scanDirectoryRecursively` asignaba a cada `StudioFileEntity` la propiedad `extension: fileType.extension` (por ejemplo, forzando `.wav` sobre un archivo físico llamado `pista.mp3` o `.musicxml` sobre `obra.mid`), lo cual impedía al pipeline posterior de transcodificación (`IAudioTranscoderPort`) y a los parsers polimórficos distinguir el formato real del recurso.

---

## 2. Decisión

Se establece una taxonomía universal en `StudioFileType` (`lib/core/file_system/domain/studio_file_type.dart`) y preservación estricta de extensión física en el repositorio de disco:

1. **Conjuntos Canónicos de Clasificación en `StudioFileType`:**
   - `_audioExtensions`: `{'.wav', '.pcm', '.aif', '.aiff', '.mp3', '.flac', '.ogg', '.m4a', '.aac', '.opus', '.wma', '.webm'}` mapeados de forma insensible a mayúsculas (`toLowerCase()`) a `StudioFileType.audioWav`.
   - `_scoreExtensions`: `{'.musicxml', '.mxl', '.xml', '.mid', '.midi', '.abc', '.pdf'}` mapeados a `StudioFileType.score`.
   - Se preservan sin regresión `.tunner` (`project`), `.tnt` (`rackTool`), `.tpreset` (`tuningPreset`), `.djblueprint`/`.djkeymap` (`djBlueprint`) y el respaldo `genericFile` (`.bin`).
2. **Extractor Determinista `StudioFileType.extractExtension(String fileName, StudioFileType fallbackType)`:**
   - Normaliza el nombre con `trim()`, localiza el último punto (`lastIndexOf('.')`) con `dotIndex > 0` y `dotIndex < trimmed.length - 1` (excluyendo archivos ocultos tipo `.oculto` o nombres terminados en punto como `archivo.`).
   - Verifica que el sufijo no contenga separadores de ruta (`/`, `\`) ni espacios; si la validación falla, retorna `fallbackType.extension`. En caso válido, retorna la extensión real en minúsculas con punto inicial (por ejemplo, `.mp3`, `.flac`, `.mid`, `.pdf`).
3. **Preservación en `LocalDiskStudioFileSystemRepository`:**
   - Al escanear archivos en `_scanDirectoryRecursively`, `StudioFileEntity.extension` se inicializa con `StudioFileType.extractExtension(fileName, fileType)` en lugar de `fileType.extension`, manteniendo el nombre y la extensión real intactos para su resolución perezosa posterior.

### Modelo Formal de Clasificación

Sea $\Sigma^*$ el conjunto de nombres de archivo válidos y $\text{ext}: \Sigma^* \to \Sigma^*$ el operador de extracción en minúsculas:

$$\text{ext}(f) = \begin{cases} \text{lower}(f[i_{\text{dot}}..|f|-1]) & \text{si } 0 < i_{\text{dot}} < |f|-1 \land \text{valid}(f[i_{\text{dot}}..]) \\ \tau_{\text{fallback}}(f).\text{extension} & \text{en caso contrario} \end{cases}$$

La función de taxonomía $\mathcal{T}(f)$ define una partición determinista y disjunta sobre las extensiones soportadas:

$$\mathcal{T}(f) = \begin{cases} \text{audioWav} & \text{si } \text{ext}(f) \in \mathcal{E}_{\text{audio}} \\ \text{score} & \text{si } \text{ext}(f) \in \mathcal{E}_{\text{score}} \\ \text{project} | \text{rackTool} | \text{tuningPreset} | \text{djBlueprint} & \text{si } \text{ext}(f) \in \mathcal{E}_{\text{studio}} \\ \text{genericFile} & \text{en caso contrario} \end{cases}$$

---

## 3. Consecuencias

### 3.1 Positivas
- **Integridad de Identidad de Archivo:** Un archivo `.mp3`, `.flac` o `.mid` en el workspace conserva su extensión real en memoria y disco, habilitando decisiones de transcodificación (`FFmpeg`) y selección de parser sin inspección heurística redundante.
- **Compatibilidad Retroactiva:** Los archivos `.wav` y `.musicxml` existentes continúan operando sin migración de esquemas ni ruptura de contratos en `lib/core/file_system/domain/`.
- **Pureza de Dominio:** `StudioFileType` permanece 100% Pure Dart, sin dependencias de `dart:io` ni Flutter UI.

### 3.2 Riesgos y Mitigaciones
- **Archivos sin extensión o con múltiples puntos (`mi.obra.maestra.flac`):** `lastIndexOf('.')` resuelve correctamente el último segmento (`.flac`) y el guardia `dotIndex <= 0` previene que archivos ocultos (`.gitignore`, `.oculto`) sean tratados como extensiones vacías.

---

## 4. Verificación

Validado mediante la suite unitaria y de integración en disco [us_fs_01_studio_file_type_test.dart](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/test/core/file_system/us_fs_01_studio_file_type_test.dart):
- Clasificación insensible a mayúsculas de las 12 extensiones de audio y 7 extensiones de partitura/notación.
- Preservación de extensiones nativas (`.tunner`, `.tnt`, `.tpreset`, `.djblueprint`, `.djkeymap`) y fallback `genericFile`.
- Casos borde de `extractExtension` (`sin_extension`, `archivo.`, `.oculto`, `mi.obra.maestra.flac`).
- Escaneo físico real en directorio temporal mediante `LocalDiskStudioFileSystemRepository.loadRootWorkspace()`.
