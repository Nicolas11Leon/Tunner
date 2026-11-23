# Registro de Decisión de Arquitectura (ADR) 0095: Formato Canónico (.tunner), Contenedor Universal de Proyecto y Serialización Criptográfica Lossless

---

## Metadatos

- **ID del ADR:** `ADR-0095`
- **Título:** Especificación del Contenedor Canónico (.tunner), Manifiesto con Integridad Criptográfica SHA-256 y Motor de Empaquetado en Memoria
- **Estado:** `Approved`
- **Fecha:** `2026-11-18`
- **Fase Asociada:** `Fase 6`
- **Autor Principal:** `Nicolas Leon (Mantenedor Principal) / Antigravity Engine`
- **Caso de Uso Relacionado:** [Caso de Uso 106](../02_use_cases/106_uc_canonical_tunner_project_container_and_lossless_serialization.md)
- **Plan Relacionado:** [Plan Épica 6.1](../05_implementation_plans/plan_canonical_tunner_project_container_and_lossless_serialization.md)
- **Issue Asociado:** [#33](https://github.com/Nicolas11Leon/Tunner/issues/33)

---

## 1. Contexto

Hasta la Fase 5, el estado del proyecto Tunner (partituras, matriz de hardware, configuraciones tímbricas y grabaciones) se almacenaba de forma fragmentada en diferentes entidades de configuración (`JsonLocalPersistenceService`, matrices inmutables en memoria y exportadores específicos de MusicXML/MIDI). 

Para permitir la portabilidad completa de proyectos entre músicos, educadores y estaciones de trabajo de conservatorio sin dependencias de servicios en la nube ni formatos propietarios cerrados, es imperativo establecer un formato canónico universal de intercambio:
1. **Autocontenido y 100% Offline:** Debe encapsular todo lo necesario para reproducir fielmente la sesión (manifiesto, partituras, presets de síntesis, enrutamiento y pistas de audio).
2. **Lossless y Criptográficamente Seguro:** Debe garantizar que ningún archivo haya sufrido alteraciones o corrupción bit a bit mediante validación por hash SHA-256.
3. **Clean Architecture Estricta:** La capa de dominio (`lib/core/packaging/domain/`) debe ser Dart puro, libre de dependencias de Flutter UI o widgets.

---

## 2. Decisión

Se adopta la especificación del contenedor canónico `.tunner`:

1. **Taxonomía Interna del Contenedor:**
   El formato `.tunner` se estructura como un archivo de compresión estándar DEFLATE (ZIP) con la siguiente estructura interna de directorios:
   ```
   [nombre].tunner
   ├── manifest.json              # Metadatos del proyecto, versión del formato, hashes SHA-256
   ├── routing_matrix.json        # Estado de canales, ganancias, EQ biquad y compresor
   ├── notation/
   │   └── score.json             # Árbol serializado de la partitura
   ├── instruments/
   │   └── synth_preset.json      # Preset del sintetizador polifónico (forma de onda, ADSR)
   ├── dj_workstation/
   │   └── session.json           # Estado de decks DJ, tempos y cues
   └── audio_vault/
       └── stems/                 # Archivos WAV PCM de audio
   ```

2. **Capa de Dominio Puro (`lib/core/packaging/domain/`):**
   - `TunnerProjectManifestEntity`: Entidad inmutable con identificador único, título, autor, versión de formato, marcas de tiempo, metadatos y un mapa de firmas criptográficas `Map<String, String> fileHashes`.
   - `TunnerProjectPackageEntity`: Representación en memoria de todos los componentes del paquete.
   - `ITunnerPackageCodec`: Interfaz que declara los métodos `encodePackage`, `decodePackage` y `readManifest`.

3. **Capa de Infraestructura (`lib/core/packaging/infrastructure/`):**
   - `TunnerPackageCodecService`: Implementa la compresión y descompresión en memoria utilizando el motor `archive`, calculando y comprobando el hash SHA-256 de cada archivo al vuelo.
   - Si se detecta una discrepancia entre el hash registrado en `manifest.json` y el contenido binario, se arroja `TunnerPackageCorruptedException` inmediatamente, abortando la carga antes de tocar el estado del audio.

---

## 3. Consecuencias

### Positivas
- **Portabilidad Universal:** Un proyecto musical completo puede compartirse mediante un único archivo binario reproducible en cualquier dispositivo con Tunner.
- **Protección contra Corrupción:** El hash SHA-256 previene la carga de archivos dañados o incompletos por fallas de almacenamiento o transferencia.
- **Mantenibilidad:** El código de empaquetado reside en su propio módulo atomizado en `lib/core/packaging/`, respetando Clean Architecture.

### Negativas / Mitigaciones
- **Uso Temporal de Memoria en Exportación:** Comprimir múltiples pistas de audio en memoria puede requerir un buffer de varios megabytes.  
  *Mitigación:* Se procesan los flujos como arreglos `Uint8List` contiguos optimizados y se liberan inmediatamente tras la serialización.
