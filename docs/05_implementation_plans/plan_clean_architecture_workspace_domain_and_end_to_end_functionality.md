# Template: Implementation Plan (Plantilla Plan de Implementación)

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-CLEAN-ARCH-WORKSPACE-2026-0076`
- **Título de la Implementación:** Erradicación de Mocks y Hardcoding en Workspace Assets: Dominio Puro, Persistencia Local Offline y Pipelines Funcionales de Creación/Importación
- **Fase del Proyecto:** Fase 2 (Afinación Acústica, Notación Jerárquica y Workspace Studio)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0066](../04_adrs/0066_clean_architecture_workspace_domain_and_end_to_end_functionality.md)
- **Documento Funcional Base:** [Caso de Uso 76](../02_use_cases/76_uc_clean_architecture_workspace_domain_and_end_to_end_functionality.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Erradicar por completo el estado simulado en memoria (`_userCustomScores` y `_userCustomPresets` en `_MainAppShellState`), reemplazándolo por una arquitectura limpia (Clean Architecture) donde:
1. **Partituras de Trabajo (`workspaceScores`):** Sean entidades puras de dominio (`SongPackage`), gestionadas reactivamente por el `TunerViewModel`, persistidas localmente en disco offline, e importables directamente desde el explorador del sistema de archivos (`FilePicker`) mediante el motor universal de importación (`.musicxml`, `.mxl`, `.mid`, `.midi`, `.abc`, `.pdf`, `.wav`).
2. **Presets de Afinación (`tuningPresets`):** Se formalicen en la entidad de dominio `TuningPresetEntity` (Hz, temperamento histórico, nota tónica, metadatos), con persistencia no volátil en `AppUserSettingsEntity` y `JsonLocalPersistenceService`.
3. **Tomas de Audio WAV (`recordingHistory`):** Operen de forma confiable en plataformas de escritorio (Linux/macOS/Windows) y móviles, permitiendo iniciar tomas reales, almacenarlas en almacenamiento local, visualizarlas en el árbol jerárquico y reproducirlas/eliminarlas sin bloqueos.
4. **Navegación e Integración de Vistas:** Eliminar stubs vacíos en la vista de composición (`CompositionNotationWorkspaceView`), conectando la biblioteca y el mezclador a sus respectivos diálogos modales.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación de entidad pura de dominio `TuningPresetEntity`.
  - Serialización y deserialización de `tuningPresets` y `workspaceScores` en `AppUserSettingsEntity`.
  - Métodos mutadores en `TunerViewModel`: `createWorkspaceScore`, `deleteWorkspaceScore`, `importScoreFromFilePicker`, `saveTuningPreset`, `deleteTuningPreset`, `deletePracticeRecording`.
  - Integración nativa de `FilePicker` en `_StudioImportScoreDialog` para abrir archivos locales reales.
  - Limpieza de `MainAppShell`: eliminación de listas privadas en el State y enlace 100% reactivo con el ViewModel.
  - Robustez de códec de grabación en `PracticeRecorderService` (soporte universal WAV/AAC).
  - Pruebas unitarias de dominio y pruebas de widgets.
- **Excluido (Out-of-Scope):**
  - Servicios de sincronización en la nube o backend remoto (regla estricta: 100% Offline-First Monolithic Modular).
  - Modificación de los algoritmos de detección MPM/YIN en C/Dart.

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.5`
  - Flutter SDK: Canal oficial estable
  - `file_picker: ^13.3.0` (Ya presente en `pubspec.yaml`, compatible con Linux, macOS, Windows, Android e iOS).
  - `record: ^6.2.1` (Utilizado para grabación de audio).
- **Riesgo Tecnológico:**
  - ¿Introduce dependencias nativas o FFI adicionales? No, reutiliza las dependencias ya aprobadas y aisladas en infraestructura.
  - ¿Afecta el rendimiento del bucle principal de Flutter? No, la persistencia se realiza asíncronamente en background mediante JSON I/O y no bloquea el hilo principal.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Puros y Contratos)
- [x] Crear `TuningPresetEntity` en `lib/features/tuner/domain/tuning_preset_entity.dart`.
- [x] Actualizar `AppUserSettingsEntity` en `lib/features/persistence/domain/app_user_settings_entity.dart` para incluir colecciones persistibles de `tuningPresets` y `workspaceScores`.

### Paso 2: Capa de Infraestructura / Datos (Persistencia y Grabador)
- [x] Asegurar soporte en `JsonLocalPersistenceService` para guardar y cargar las nuevas listas de entidades.
- [x] Ajustar la configuración de `PracticeRecorderService` para admitir grabación robusta en Linux y escritorio (formato WAV/AAC).

### Paso 3: Capa de Presentación (ViewModel, Modales y AppShell)
- [x] Extender `TunerViewModel` con colecciones reactivas `workspaceScores` y `tuningPresets` y sus métodos mutadores.
- [x] Conectar `StudioAssetsModals`:
  - `_StudioNewScoreDialog`: invoca `viewModel.createWorkspaceScore`.
  - `_StudioImportScoreDialog`: integra `FilePicker` para examinar archivos locales en disco.
  - `_StudioNewTuningPresetDialog`: invoca `viewModel.saveTuningPreset`.
- [x] Refactorizar `MainAppShell`: erradicar listas en `State` y consumir directamente `viewModel.workspaceScores`, `viewModel.tuningPresets`, `viewModel.recordingHistory`.
- [x] Conectar callbacks de `CompositionNotationWorkspaceView` (`onOpenLibraryModal`, `onOpenMixerModal`).

### Paso 4: Pruebas, Verificación y Documentación
- [x] Escribir pruebas unitarias en `test/features/tuner/tuning_preset_entity_test.dart` y pruebas de integración en `test/features/navigation/studio_workspace_assets_functional_test.dart`.
- [x] Ejecutar `flutter analyze lib/ test/` asegurando 0 advertencias.
- [x] Ejecutar la suite completa de pruebas unitarias.
- [x] Compilar el binario Linux de depuración y reiniciar la instancia de la aplicación.
- [x] Registrar ADR 0066 y Caso de Uso 76.
- [x] Confirmar y sincronizar cambios con Git (commit y push).
