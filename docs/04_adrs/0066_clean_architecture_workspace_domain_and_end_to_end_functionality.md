# ADR 0066: Arquitectura Limpia para Gestión de Assets de Espacio de Trabajo, Dominio Puro y Persistencia Offline

## Estado
Aprobado

## Contexto
Durante la implementación del explorador jerárquico de archivos estilo IDE/DAW profesional, las carpetas de assets (`Partituras & Notación`, `Tomas de Audio & WAV` y `Presets de Afinación`) presentaban variables de estado en memoria efímeras dentro de la clase de presentación `_MainAppShellState` (`_userCustomScores` y `_userCustomPresets`). Además, los presets de afinación se modelaban mediante mapas no tipados (`Map<String, dynamic>`), y el diálogo de importación de partituras carecía de conexión directa con el explorador nativo de archivos del sistema operativo a pesar de que el motor universal de importación (`UniversalScoreImporterService`) y el plugin `file_picker` ya formaban parte del proyecto.

Esto contravenía los principios cardinales de `AGENTS.md`:
1. **Disciplina de Arquitectura Limpia (Clean Architecture):** El dominio debe contener entidades inmutables y puras de Dart libres de dependencias de UI. La capa de presentación nunca debe retener estado de negocio ni modelar entidades mediante estructuras genéricas o no tipadas.
2. **Offline-First y Persistencia Determinista:** Los documentos y configuraciones creados por el usuario deben persistirse localmente en disco sin depender de servicios en la nube ni perderse ante el reinicio del software.
3. **Plena Funcionalidad End-to-End:** Todo control de interfaz (crear, importar, grabar, eliminar) debe ejecutar una operación real en el ViewModel y los servicios de infraestructura.

## Decisión
Se toma la decisión arquitectónica de:
1. **Crear la Entidad de Dominio `TuningPresetEntity`:**
   Ubicada en `lib/features/tuner/domain/tuning_preset_entity.dart`. Modela formalmente la calibración de frecuencia en Hz ($f \in [380.0, 480.0]$), el temperamento musical histórico asociado (`equal`, `just`, `pythagorean`, `meantone`), la nota tónica, el nombre descriptivo y la marca de tiempo de creación.
2. **Actualizar la Entidad Agregada de Persistencia `AppUserSettingsEntity`:**
   Incorporar campos tipados `List<TuningPresetEntity> tuningPresets` y `List<SongPackage> workspaceScores`, con serialización/deserialización JSON completa en `JsonLocalPersistenceService`.
3. **Mudar la Gestión de Assets al `TunerViewModel`:**
   Erradicar las variables privadas en `_MainAppShellState`. `TunerViewModel` es la única fuente de la verdad para:
   - `workspaceScores`: Inicia vacía o con las obras persistidas por el usuario.
   - `tuningPresets`: Inicia vacía o con los presets guardados.
   - `recordingHistory`: Tomas reales registradas.
   - Métodos: `createWorkspaceScore`, `deleteWorkspaceScore`, `importScoreFromFilePicker`, `saveTuningPreset`, `deleteTuningPreset`, `deletePracticeRecording`.
4. **Integrar `FilePicker` en `_StudioImportScoreDialog`:**
   Conectar el diálogo directamente con el explorador de archivos nativo de la plataforma para permitir la importación de partituras en formatos MusicXML, MIDI, ABC, PDF y WAV.
5. **Universalizar Códec de Grabación en `PracticeRecorderService`:**
   Garantizar compatibilidad con WAV / PCM sin compresión o AAC según la plataforma, asegurando funcionamiento sin bloqueos en Linux, Windows y macOS.

## Consecuencias

### Positivas
- **Alineación 100% con Clean Architecture:** Eliminación total de mocks y estructuras de datos crudas en la capa de presentación.
- **Persistencia No Volátil Garantizada:** Toda partitura creada o importada y todo preset de afinación se mantiene intacto entre sesiones de la aplicación.
- **Experiencia de Usuario Profesional:** Las carpetas del explorador son completamente dinámicas, reactivas y funcionales con soporte de importación real de archivos en disco.

### Negativas / Mitigaciones
- **Tamaño de Carga Inicial:** La serialización de múltiples partituras en JSON podría incrementar el archivo de configuración.  
  *Mitigación:* Se almacena la jerarquía esencial de notas y compases, y las tomas de audio se referencian por su ruta en disco local (`filePath`), sin duplicar binarios en memoria.
