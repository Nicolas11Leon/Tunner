# ADR 0195: Inspector Contextual Vivo en MainAppShell y Enrutamiento por Canal desde Boveda Multimedia

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-203](../02_use_cases/203_uc_live_contextual_inspector_and_vault_channel_routing.md)

---

## 1. Contexto

En la Ola 5 ([ADR 0189](0189_contextual_right_inspector_and_hover_info_view.md)), `StudioDesktopAppShell` (`lib/core/design_system/organisms/studio_desktop_app_shell.dart`) incorporo el parametro `rightInspectorContent` dentro del Nivel 1 del Inspector Contextual Derecho (`inspector_level_1_essential_section`). Sin embargo, `MainAppShell` (`lib/features/navigation/presentation/main_app_shell.dart`) no estaba proveyendo dicho widget segun la pestana activa, dejando el inspector reducido a cuatro propiedades estaticas globales. Adicionalmente, el callback `onDispatchToTool` de `MediaVaultViewModel` en `MainAppShell` resolvia `MediaSynergyTarget.mixerChannel` enviando el activo directamente a `_djConsoleViewModel.loadTrackWithBeatTracking('A', ...)` en lugar de publicarlo en `StudioPatchbayRoutingService` (`lib/core/channels/domain/studio_patchbay_routing_service.dart`), impidiendo el enrutamiento real hacia los canales nombrables del estudio (`canal_a`..`canal_d` y canales personalizados).

---

## 2. Decision

1. **Inyeccion Contextual de `rightInspectorContent` en `MainAppShell`:** Construir un generador contextual por pestana (`StudioWorkspaceTabSpec`) que inyecte `Key('live_contextual_inspector_content')` en `StudioDesktopAppShell`, mostrando telemetria acustica en vivo y estado de bus para cada espacio (Tuner, Practica, Rack Modular, Partituras, Consola DJ) junto con el acceso directo `Key('inspector_quick_route_patchbay_btn')`.
2. **Enrutamiento Explicito por Canal desde `MediaVaultViewModel`:** Ampliar `MediaSynergyTarget` (`lib/features/media_vault/domain/media_synergy_target.dart`) y `MediaVaultViewModel` (`lib/features/media_vault/presentation/media_vault_viewmodel.dart`) con un selector de canal destino (`Key('vault_channel_routing_selector')`) que despache metadatos (`title`, `bpm`, `key`, `isPlaying`) y flujo PCM hacia `StudioPatchbayRoutingService.publishChannelParameters(...)` e `injectAudioToChannel(...)` en `MainAppShell`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Inspector Derecho Realmente Vivo:** Cada espacio de trabajo expone controles y telemetria pertinentes al contexto activo sin abrir dialogos modales bloqueantes.
- **Boveda Multimedia Integrada al Bus Full-Duplex:** Cualquier toma, stem o pista en `MediaVaultViewModel` alimenta simultaneamente a todas las herramientas conectadas al `StudioChannelBus` seleccionado.

### 3.2 Compromisos y Mitigaciones
- **Aislamiento de Reconstrucciones en el Shell:** El widget `rightInspectorContent` se encapsula con `ListenableBuilder` acotado al subestado pertinente para evitar reconstrucciones completas de `StudioDesktopAppShell` a 60 FPS.

---

## 4. Verificacion

- Suite automatizada planificada: `test/core/navigation/us_hc_01_live_contextual_inspector_and_vault_routing_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
