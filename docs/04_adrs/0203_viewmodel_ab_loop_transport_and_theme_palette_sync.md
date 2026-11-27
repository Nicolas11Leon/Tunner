# ADR 0203: Transporte Unificado de Bucle A-B en ViewModel y Sincronia de Paletas

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-211](../02_use_cases/211_uc_viewmodel_ab_loop_transport_and_theme_palette_sync.md)

---

## 1. Contexto

En `TunerViewModel` (`lib/features/tuner/presentation/tuner_viewmodel.dart`), el bucle automatico de reproduccion respeta `scorePlaybackCoordinator.isMeasureLoopActive`, pero `nextMeasure()` y `previousMeasure()` aplican aritmetica modular sobre `totalMeasures` ignorando los limites `[loopStartMeasureIndex, loopEndMeasureIndex]`. Ademas, `CompositionNotationWorkspaceView` (`lib/features/workspaces/presentation/composition_notation_workspace_view.dart`) mantiene copias locales (`_loopMeasureA`, `_loopMeasureB`, `_isAbLoopActive`) que pueden quedar desincronizadas al cambiar o reiniciar la partitura. En paralelo, `StudioThemeSwitcher` (`lib/core/design_system/atoms/studio_theme_switcher.dart`) actualiza `StudioThemeController` sin propagar el cambio a `TunerViewModel.currentPalette`, generando discordancia cromatica entre los tokens del shell y `RealSheetMusicPainter` / `TunerScreen`.

---

## 2. Decision

1. **Fuente Unica de Verdad para Transporte A-B en `TunerViewModel`:**
   - Exponer `isAbLoopActive`, `abLoopStartMeasureIndex`, `abLoopEndMeasureIndex`, `setAbLoopRange(int startMeasureIndex, int endMeasureIndex)` y `clearAbLoop()` en `TunerViewModel`, delegando el almacenamiento y validacion de limites a `ScorePlaybackCoordinator` (`lib/features/sheet_music/domain/score_playback_coordinator.dart`) y notificando a los suscriptores.
   - Hacer que `nextMeasure()` y `previousMeasure()` naveguen ciclicamente dentro de `[M_A, M_B]` cuando `isAbLoopActive` es `true`, y limpiar o recortar el rango deterministicamente en `loadSongPackage()` y `resetSongState()`.
   - Eliminar el estado paralelo duplicado en `CompositionNotationWorkspaceView` para consumir directamente `viewModel`.
2. **Sincronia Bidireccional de Paletas y Skins:**
   - Enlazar `StudioThemeController` (`lib/core/design_system/studio_theme_provider.dart`) y `TunerViewModel` (`setPalette`, `setPaletteById`, `setActiveStudioThemeId`) mediante escucha desacoplada con guarda anti-reentrancia en `MainAppShell` (`lib/features/navigation/presentation/main_app_shell.dart`), asegurando que el selector `studio_theme_switcher_dropdown` y `ThemeCustomizationModal` mantengan sincronizados `StudioDesignTokens` y `TunnerThemePalette`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Coherencia Determinista en Practica:** Avanzar o retroceder compases manualmente o desde atajos de teclado respeta exactamente la seccion de estudio A-B.
- **Unificacion Visual Instantanea:** Cambiar de skin desde cualquier barra del estudio actualiza simultaneamente el shell, el pentagrama SMuFL y el afinador estroboscopico.

### 3.2 Compromisos y Mitigaciones
- **Ciclos de Notificacion entre Controladores:** Se utiliza una bandera booleana local de sincronizacion (`_isSyncingTheme`) para evitar bucles infinitos al propagar cambios entre `StudioThemeController` y `TunerViewModel`.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/tuner/us_ux_11_ab_loop_transport_and_theme_sync_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
