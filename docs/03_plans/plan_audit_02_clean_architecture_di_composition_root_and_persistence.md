# Plan de Implementación 02: Clean Architecture, Composition Root Completo, DI y Persistencia Pura

## Metadatos del Plan

- **ID del Plan:** `PLAN-AUDIT-02-CLEAN-DI-2026`
- **Título de la Implementación:** `Saneamiento Estricto de Capas Clean Architecture, Eliminación de Singletons Ocultos y Composition Root Único`
- **Fase del Proyecto:** `Fase 6 — Hardening Arquitectónico v1.0`
- **Estado:** `Propuesto`
- **ADR Relacionado:** `Por crear (ADR-0167: Pure Domain Persistence & Strict Composition Root)`
- **Documento Funcional Base:** [Auditoría Forense Integral](../05_audits/2026-11-23_master_tool_by_tool_forensic_audit.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Restaurar el cumplimiento estricto de la regla `AGENTS.md 3.2` (Domain 100% Pure Dart sin Flutter/terceros, Presentation sin acceso directo a infraestructura/I-O/singletons) y consolidar el 100% del ensamblaje de dependencias en `StudioCompositionRoot`.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Limpieza de `domain/`: retirar `tunner_theme.dart` de `app_user_settings_entity.dart`, mover generadores binarios PDF y `package:crypto` de `pedagogy/domain` y `pedagogy_report/domain` a `infrastructure/`, retirar colores hex de `studio_patchbay_routing_service.dart`, retirar literales UI de `mixer_track_entity.dart`, eliminar shims vacíos en `data/`.
  - `StudioCompositionRoot` completo: registrar `TunnerOsKernel`, `StudioOsAudioKernel`, `StudioOsAudioKernelBridge`, `TunnerDslInterpreter`, `EbbinghausSpacedRepetitionEngine`, `VocalStabilityEvaluator`, `IStudioLogger` y reutilizar una sola instancia de `LocalDiskStudioFileSystemRepository` y `AudioSynthesizerService`.
  - Eliminación de singletons ocultos (`StudioPatchbayRoutingService()`, `StudioThemeCatalogService()`, `StudioDebugLogger.instance`, `StudioWorkspaceFileSystemService()`).
  - Retiro de I/O de plataforma directo en widgets (`instrument_soundfont_selector_modal.dart`, `pedagogical_report_modal.dart`, `score_editor_modal.dart`) y retiro de imports de `studio_composition_root.dart` desde `presentation/`.
  - Persistencia del tema activo de `StudioThemeController` (`studio_oled_monochrome`) y limpieza correcta de archivos `.tmp` con timestamp en `json_local_persistence_service.dart`.
- **Excluido (Out-of-Scope):**
  - Cambios estéticos de layout (cubiertos en Plan 01).

---

## 2. Análisis de Dependencias y Tecnologías

- **SDKs:** Dart `^3.11.x` / Flutter estable. `package:crypto` permanece en `pubspec.yaml` pero movido exclusivamente a `infrastructure/` detrás de una interfaz `ICryptographicHashService`.
- **Riesgo Tecnológico:** Medio (requiere actualizar constructores de tests que omitían dependencias y confiaban en singletons).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Purificación de la Capa de Dominio (`lib/**/domain/`)
- [ ] Reemplazar `List<TunnerThemePalette> customPalettes` en `app_user_settings_entity.dart` por entidades puras `StudioThemeSkinEntity` y añadir persistencia de `activeStudioThemeId` (default `'studio_oled_monochrome'`).
- [ ] Mover `pedagogical_report_pdf_generator.dart` y `pedagogical_certificate_pdf_generator.dart` a `infrastructure/` (consolidando el compilador PDF-1.4 duplicado en un único motor con codificación WinAnsi real) detrás de interfaces en `domain/`.
- [ ] Desacoplar `vocal_evaluation_result.dart` de `package:crypto` inyectando el hash desde un servicio de infraestructura.
- [ ] Retirar colores hex de `studio_patchbay_routing_service.dart` y literales/iconos de UI de `mixer_track_entity.dart`.

### Paso 2: Interfaces y Eliminación de Singletons Ocultos
- [ ] Definir contratos faltantes: `IStudioMasterClockService`, `IStudioAudioDeviceMatrixService`, `IHarmonicReferenceSynth`, `IEarTrainerEngine`, `ITaskCatalogIndex`, `IExerciseGenerator`, `IAdaptiveScaffoldingEngine`, `ITunnerBinaryCodec`.
- [ ] Eliminar factories singleton ocultos en `StudioPatchbayRoutingService`, `StudioThemeCatalogService`, `StudioWorkspaceFileSystemService` y reemplazar los usos directos de `StudioDebugLogger.instance` por `IStudioLogger` inyectado.
- [ ] Eliminar ramificaciones `Platform.environment.containsKey('FLUTTER_TEST')` en `audio_playback_service.dart` y `dj_deck_audio_service.dart` usando inyección de `IStudioAudioEngine`.

### Paso 3: `StudioCompositionRoot` Único y Limpieza de Presentación
- [ ] Completar `lib/app/studio_composition_root.dart` para ensamblar y liberar (`dispose()`) todos los motores, kernel, bridge, `themeCatalogService` y `masterDspChain`, sin duplicar repositorios ni sintetizadores.
- [ ] Retirar instanciaciones directas de infraestructura en `main_app_shell.dart:185-247`, `dj_console_modal.dart`, `dj_studio_workstation_view.dart` y `modular_studio_rack_view.dart`.
- [ ] Canalizar `FilePicker` (`instrument_soundfont_selector_modal.dart`) y `saveExportedBytes` (`pedagogical_report_modal.dart`, `score_editor_modal.dart`) a través de casos de uso / controladores que usen `IPlatformFileGateway`.
- [ ] Corregir limpieza de `.tmp` con timestamp en `json_local_persistence_service.dart:149`.

### Paso 4: Pruebas y Verificación
- [ ] Añadir test de arquitectura automatizado que falle si cualquier archivo en `**/domain/**` importa `package:flutter`, `dart:io` o `package:crypto`.
- [ ] Ejecutar `flutter analyze --no-fatal-infos` y `flutter test` completo.

---

## 4. Estrategia de Rollback
- **Punto de Restauración Git:** Commit previo a la rama `refactor/audit-02-clean-di`.
- **Mitigación Inmediata:** Reversión atómica de cada sub-paso si falla alguna prueba de integración.

---

## 5. Criterios de Aceptación (Definition of Done)
- [ ] `0` imports de `package:flutter` o infraestructura en `**/domain/**`.
- [ ] `0` imports de `studio_composition_root.dart` en `**/presentation/**`.
- [ ] `0` singletons globales activos en servicios de estado.
- [ ] Persistencia real del tema `studioOledMonochrome` entre reinicios.
- [ ] `flutter analyze` y `flutter test` al 100%.
