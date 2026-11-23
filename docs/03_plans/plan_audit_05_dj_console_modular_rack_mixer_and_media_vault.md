# Plan de Implementación 05: Refactorización Profunda de DJ Console, Modular Rack, Mixer, Media Vault y Docking

## Metadatos del Plan

- **ID del Plan:** `PLAN-AUDIT-05-DJ-RACK-VAULT-DOCK-2026`
- **Título de la Implementación:** `Deduplicación de Consola DJ, Descomposición de Modular Rack y Media Vault, Mixer Robusto y Docking Genérico`
- **Fase del Proyecto:** `Fase 6 — Hardening de Producción y Enrutamiento v1.0`
- **Estado:** `Propuesto`
- **ADR Relacionado:** `Por crear (ADR-0170: Unified DJ Surface, Resettable SignalBus & Generic Docking)`
- **Documento Funcional Base:** [Auditoría Forense Integral](../05_audits/2026-11-23_master_tool_by_tool_forensic_audit.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Resolver la duplicación severa y colisión de IDs de Patchbay en `dj_console`, atomizar los God Widgets/ViewModels de `dj_console`, `modular_rack` y `media_vault`, corregir bugs funcionales en `SignalBus`, `MediaVault` y `Docking`, y eliminar acoplamientos cruzados en `core/docking` y `core/channels`.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - **DJ Console:** Unificar lógica compartida entre `dj_studio_workstation_view.dart` (1,764 LOC) y `dj_console_modal.dart` (1,037 LOC) en un único `DjDeckPatchbayBridge` con IDs con scope de instancia (eliminando colisión de `'plug_dj_deck_a_in'`); descomponer `dj_console_view_model.dart` (1,439 LOC) en `DjTransportController`, `DjEffectsAndStemsController` y `DjTelemetryNotifier` (evitando rebuild completo del modal a 30 Hz); cablear `MediaSynergyTarget.scoreEditor`, `djSamplerPad` y `mixerChannel` reales; separar claramente el modo teclado/hardware real del simulador de gamepad (etiquetado como herramienta de pruebas/emulación o removido de producción).
  - **Modular Rack & Channels:** Implementar `SignalBus.reset()`/`clear()` (dejar de llamar `signalBus.dispose()` dentro de `loadPreset`/`loadProjectPackage`); atomizar `modular_rack_viewmodel.dart` (1,224 LOC) y `rack_unit_card.dart` (955 LOC, usando un registro de builders por tipo de módulo en vez de importar 12+ modales); añadir `TextEditingController` en `universal_instrument_search_modal.dart:92` para que `Icons.clear` limpie el texto; corregir `_safeNotify()` y pulsos visuales independientes por sink en `StudioPatchbayRoutingService`.
  - **Media Vault:** Corregir bug de ruta en `exportTimelineToDisk` (`media_vault_viewmodel.dart:111-113`), eliminar llamada redundante en `media_vault_workspace_modal.dart:59,75`, mover generación de demos y estimación BPM/Camelot a `Isolate.run` (sin bloquear constructor), aislar el repaint del playhead del modal de 979 LOC y descomponer el modal en sub-widgets.
  - **Mixer:** Validar `isFinite` + `.clamp(0.0, 1.0)` en `AudioTrack.fromMap`, añadir `==`/`hashCode`, soporte de paneo/escala dB y extraer capa `presentation/` propia desacoplada de `tuner_screen.dart`.
  - **Docking:** Desacoplar `StudioDockLayoutEntity` de IDs hardcoded de `dj_console`, implementar renderizado real de `StudioDockZone.floating` (Overlay/Stack posicionable), añadir `ValueKey(zonePanels.length)` en `DefaultTabController` (`:314`), proteger `widget.panels.first` cuando está vacío (`:146-149`), corregir clamps de altura (`:162,264`) y unificar `studio_splitter_divider.dart` con `studio_splitter.dart`.
- **Excluido (Out-of-Scope):**
  - Drivers nativos USB-HID de controladores DJ propietarios.

---

## 2. Análisis de Dependencias y Tecnologías

- **SDKs:** Flutter/Dart estable (`ValueListenableBuilder` para aislar repaints de 30 FPS en VU/playhead).
- **Riesgo Tecnológico:** Medio en refactorización de `dj_console` y `modular_rack`; mitigar con tests de integración de Patchbay y Docking.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: `SignalBus`, `Channels` y `Docking`
- [ ] Añadir `SignalBus.clearRoutes()` y guarda `_isDisposed` en `signal_bus.dart`, reemplazando los usos erróneos de `signalBus.dispose()` en `modular_rack_viewmodel.dart:991,1078`.
- [ ] Corregir `_safeNotify()` y mapa de timers por `plugId` en `studio_patchbay_routing_service.dart`.
- [ ] Desacoplar `core/docking` de `dj_console`, implementar `StudioDockZone.floating`, fijar `ValueKey(zonePanels.length)` en `DefaultTabController` y eliminar crashes/overflows de splitter.

### Paso 2: `DJ Console` y `Mixer`
- [ ] Extraer controladores atómicos desde `dj_console_view_model.dart` y eliminar la duplicación/colisión de IDs entre `dj_console_modal.dart` y `dj_studio_workstation_view.dart`.
- [ ] Aislar telemetría VU/playhead en `ValueNotifier` para no reconstruir el árbol de 1,764 LOC a 30 Hz.
- [ ] Cablear sinergias reales (`scoreEditor`, `djSamplerPad`, `mixerChannel`) y endurecer `AudioTrack.fromMap` + igualdad por valor en `mixer_track_entity.dart`.

### Paso 3: `Modular Rack` y `Media Vault`
- [ ] Descomponer `rack_unit_card.dart` (registro de fábricas por `RackModuleType`) y `modular_rack_viewmodel.dart`; corregir `Icons.clear` en `universal_instrument_search_modal.dart`.
- [ ] Corregir `exportTimelineToDisk` (`relativePath`), eliminar síntesis síncrona en constructor de `InMemoryMediaVaultRepository`, delegar BPM/Camelot a `Isolate.run` y descomponer `media_vault_workspace_modal.dart`.

### Paso 4: Verificación
- [ ] Pruebas unitarias de `SignalBus.clearRoutes()`, `StudioDockZone.floating` + drag/drop multi-tab, `exportTimelineToDisk` y `AudioTrack.fromMap(NaN)`.
- [ ] `flutter analyze --no-fatal-infos` y suite completa de pruebas de `dj_console`, `modular_rack`, `media_vault`, `mixer` y `docking`.

---

## 4. Estrategia de Rollback
- **Punto de Restauración Git:** Commit base de la rama `refactor/audit-05-dj-rack-vault-dock`.
- **Mitigación Inmediata:** Reversión modular por feature sin afectar el core de afinación.

---

## 5. Criterios de Aceptación (Definition of Done)
- [ ] Cero colisiones de IDs globales de Patchbay entre `dj_console_modal` y `dj_studio_workstation_view`.
- [ ] `SignalBus` reiniciable limpiamente sin cerrar controllers activos.
- [ ] Zona `floating` de `core/docking` funcional y 0 crashes de `DefaultTabController`.
- [ ] `flutter analyze` y `flutter test` al 100%.
