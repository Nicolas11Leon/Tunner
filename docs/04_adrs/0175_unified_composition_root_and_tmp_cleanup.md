# ADR-0175: Completitud del Composition Root, Persistencia de Tema OLED y Limpieza de Archivos Temporales

- **Estado:** Aceptado
- **Fecha:** 2026-11-23
- **Historia de Usuario:** US-8.3 (Issue #182)
- **Caso de Uso:** [UC-183](../02_use_cases/183_uc_composition_root_completion_and_oled_persistence.md)

---

## Contexto

Tras la consolidación inicial de `StudioCompositionRoot` y la migración al sistema de diseño OLED Monochrome, una auditoría arquitectónica identificó cuatro brechas de calidad, memoria y acoplamiento:

1. **Duplicación de infraestructura y fugas de ciclo de vida en `StudioCompositionRoot`:**
   - `createDjConsoleViewModel()` instanciaba un segundo `LocalDiskStudioFileSystemRepository` en lugar de reutilizar `fileSystemService.fileSystemRepository`.
   - `createTunerViewModel()`, `createDjConsoleViewModel()` y `createMediaVaultViewModel()` creaban tres instancias independientes de `AudioSynthesizerService`, duplicando buffers PCM precalculados y referencias de canales.
   - `StudioCompositionRoot.dispose()` no liberaba `themeCatalogService` (cuando era instanciado en modo aislado por el root) ni liberaba los buffers scratch de `masterDspChain`.
2. **Acumulación de archivos temporales con timestamp en `JsonLocalPersistenceService`:**
   - `saveSettings()` escribe atómicamente en `${targetFile.path}.<microseconds>.tmp`, pero `clearSettings()` solo borraba `${targetFile.path}.tmp`, dejando archivos huérfanos tras cierres abruptos o fallos de renombrado.
3. **Pérdida del tema OLED/DAW entre sesiones:**
   - `AppUserSettingsEntity` ya definía `activeStudioThemeId`, pero `TunerViewModel` no lo restauraba en `loadPersistedState()` ni lo serializaba en `_triggerAutoSave()`, provocando que el tema OLED/Studio Light seleccionado volviera al valor por defecto al reiniciar.
4. **Acoplamiento directo a `FilePicker` en `InstrumentSoundFontSelectorModal`:**
   - El modal invocaba `FilePicker.pickFiles(...)` directamente desde el widget, impidiendo inyectar dobles de prueba mediante `IPlatformFileGateway` y rompiendo la simetría con `TunerViewModel.platformFileGateway`.

---

## Decisión

1. **Instancias Compartidas y Ciclo de Vida Completo en `StudioCompositionRoot`:**
   - Mantener una sola instancia `audioSynthesizerService` en `StudioCompositionRoot`, reutilizada por `createTunerViewModel()`, `createDjConsoleViewModel()` y `createMediaVaultViewModel()`.
   - Inyectar `fileSystemService.fileSystemRepository` en `createDjConsoleViewModel()`, eliminando la segunda instancia de `LocalDiskStudioFileSystemRepository`.
   - Incorporar `dispose()` en `StudioMasterDspChain` para liberar su buffer scratch (`_scratchBuffer = Float32List(0)`).
   - Registrar propiedad `_ownsThemeCatalogService = isolatedServices` y guardia idempotente `_isDisposed` en `StudioCompositionRoot.dispose()`, liberando `audioSynthesizerService`, `themeCatalogService` (cuando corresponde) y `masterDspChain`.

2. **Limpieza Exhaustiva de Temporales Huérfanos en `JsonLocalPersistenceService.clearSettings()`:**
   - Mantener la eliminación de `targetFile` y `${targetFile.path}.tmp`, y añadir un escaneo no recursivo del directorio padre que elimine cualquier archivo cuyo nombre comience por `${targetBaseName}.` y termine en `.tmp`.

3. **Persistencia y Sincronización Bidireccional de `activeStudioThemeId`:**
   - Añadir `_activeStudioThemeId`, getter `activeStudioThemeId`, método `setActiveStudioThemeId(String id)` y callback opcional `onStudioThemeIdChanged` en `TunerViewModel`.
   - Restaurar y persistir `activeStudioThemeId` en `loadPersistedState()` y `_triggerAutoSave()`.
   - Sincronizar desde `StudioCompositionRoot.createTunerViewModel()` hacia `themeCatalogService` / `themeController` al restaurar o cambiar tema, y desde `TunnerApp` y `MainAppShell` hacia `TunerViewModel.setActiveStudioThemeId(...)` cuando el usuario cambia de skin desde la UI o el CLI.

4. **Inyección de `IPlatformFileGateway` en `InstrumentSoundFontSelectorModal`:**
   - Reemplazar el acoplamiento directo a `FilePicker.pickFiles` por `final IPlatformFileGateway? fileGateway` (con fallback `const PlatformFileGateway()`), leyendo bytes desde `PlatformPickedFile.bytes` o `PlatformPickedFile.path`.
   - Propagar `viewModel.platformFileGateway` desde `TunerScreen` y `ToolSearchModal`.

---

## Consecuencias

### Positivas
- Eliminación total de instancias duplicadas de repositorio de disco y sintetizador PCM en el grafo principal.
- Cierre determinista de recursos de catálogo de temas y buffers DSP sin fugas de memoria en pruebas ni en producción.
- El directorio de persistencia permanece libre de archivos `.tmp` huérfanos tras `clearSettings()`.
- La preferencia de tema OLED/DAW persiste de manera transparente entre reinicios y se sincroniza con `StudioThemeController`.
- `InstrumentSoundFontSelectorModal` es completamente testeable sin dependencias nativas de `file_picker`.

### Negativas / Compromisos
- `StudioCompositionRoot` mantiene un `AudioSynthesizerService` durante toda la vida del root; al cerrar un ViewModel secundario que llame `dispose()` sobre el sintetizador inyectado, `AudioSynthesizerService.dispose()` únicamente detiene canales (sin destruir el `StudioAudioEngine` compartido), preservando la operatividad de los demás ViewModels.

---

## Verificación

- Suite dedicada `test/app/us_8_3_composition_root_and_persistence_test.dart` cubriendo reutilización de instancias, cierre de `themeCatalogService` y `masterDspChain`, limpieza de `*.<timestamp>.tmp`, persistencia/restauración de `activeStudioThemeId` e inyección de `IPlatformFileGateway` en `InstrumentSoundFontSelectorModal`.
- `flutter analyze --no-fatal-infos` sin errores.
- `flutter test --no-pub --timeout 45s` verde sobre `test/app/`, `test/features/persistence/` y `test/features/audio_synthesizer/`.
