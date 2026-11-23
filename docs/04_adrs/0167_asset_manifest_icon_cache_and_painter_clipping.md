# ADR-0167: Caché Determinista de `AssetManifest` en `StudioIcon`, Igualdad Estructural en `StudioDesignTokens` y Blindaje Geométrico de `CustomPainter`

- **Estado:** `Accepted`
- **Fecha:** `2026-11-23`
- **Fase:** `Fase 6 — Hardening Estético v1.0 (US-7.1 / US-7.4)`

---

## 1. Contexto

Tras la introducción del sistema progresivo de iconografía (`StudioIcon`) y el tema por defecto `StudioDesignTokens.studioOledMonochrome` en el ADR-0166, la auditoría forense identificó cinco puntos de fragilidad técnica:
1. **Excepciones asíncronas en `Image.asset`:** De los 44 `StudioIconId` definidos en `StudioIconCatalog`, 38 cuentan actualmente con archivo PNG físico en `assets/icons/png/`, mientras que 6 (`module_piano_roll`, `module_score_editor`, `module_spectrogram`, `module_chord_analyzer`, `module_autotune`, `module_pedagogy`) dependen del fallback vectorial. Delegar la detección de ausencia exclusivamente al `errorBuilder` de `Image.asset` provoca que el pipeline de imágenes de Flutter intente cargar el byte stream de forma asíncrona y registre excepciones de asset faltante en tests y consola antes de montar el fallback.
2. **Desincronización de tema inicial y bloqueo en `setTokens`:** `StudioThemeCatalogService` inicializaba `_activeSkin` en `obsidianPro` en lugar de `studioOledMonochrome`, y `StudioThemeController.setTokens()` abortaba la actualización si `next.id == _tokens.id`, impidiendo aplicar ediciones en vivo sobre un mismo identificador de preset.
3. **Colores cian hardcoded y re-exportación legacy:** `StudioDesktopAppShell` conservaba colores hardcoded (`0xFF00E5FF`, `0xFF0F121C`, `0xFF1E283C`) en el conmutador de barra lateral, y `lib/core/design_system/tunner_theme.dart` re-exportaba el sistema legacy dentro del paquete del nuevo Design System.
4. **Vulnerabilidad geométrica en `CustomPainter`:** En tamaños de ventana muy reducidos (`< 48px`) o ante muestras DSP con `NaN`/`Infinity`, painters como `_ChordRadarPainter`, `_StrobePainter`, `_JogWheelPainter`, `DjParallelWaveformPainter` y `_ClipWaveformPainter` podían calcular radios negativos, desbordar los límites de su widget sin `clipRect` o fallar en `double.clamp()`. Asimismo, `RealSheetMusicPainter` compilaba expresiones regulares en cada llamada de `getNoteStep()` / `paint()` y omitía `timeSignature` y `totalMeasures` en `shouldRepaint`.
5. **Desbordamientos `RenderFlex` en pantallas compactas:** Filas rígidas sin `Flexible`/`Expanded` o scroll horizontal en `GuidedLessonsModal`, `ExerciseGeneratorModal`, `PracticeReportModal` y `DrumPadsTactileWidget` producían overflows en anchos de `360px`.

---

## 2. Decisión

1. **Caché Estática y Precarga de `AssetManifest` en `StudioIcon`:**
   - Mantener en `StudioIcon` un conjunto estático `_availablePngAssets` inicializado con los 38 PNGs verificados en `assets/icons/png/`, complementado con el método asíncrono `StudioIcon.preloadManifest([AssetBundle? bundle])` (que consulta `AssetManifest.loadFromAssetBundle`) y helpers de registro dinámico (`registerAvailablePngAssets`, `resetManifestCache`) para soporte extensible y pruebas.
   - Si `hasBundledPng(spec.pngAssetPath)` es `false`, `StudioIcon.build()` retorna directamente `SizedBox(width: size, height: size, child: fallback)` sin instanciar `Image.asset`.
2. **Igualdad por Valor en `StudioDesignTokens` y Skin OLED por Defecto:**
   - Implementar `operator ==` y `hashCode` completos en `StudioDesignTokens` y `StudioThemeSkinEntity`, y actualizar `StudioThemeController.setTokens()` para comparar `if (identical(next, _tokens) || next == _tokens) return;`.
   - Incorporar `StudioThemeSkinEntity.studioOledMonochrome` (`id: 'studio_oled_monochrome'`) como primer elemento de `StudioThemeSkinEntity.defaultCatalog` y como `_activeSkin` inicial en `StudioThemeCatalogService`.
   - Eliminar `lib/core/design_system/tunner_theme.dart` y sustituir los colores hardcoded del switcher de barra lateral en `StudioDesktopAppShell` por tokens de `StudioDesignTokens`.
3. **Blindaje de `CustomPainter` y Layouts Responsivos:**
   - Aplicar `canvas.clipRect(Offset.zero & size)`, guardas de tamaño (`size.width <= 0 || size.height <= 0`), validación `.isFinite` y clamping no negativo (`math.max(0.0, ...)`) en `ChordRadarWidget`, `StrobeTunerWidget`, `VectorJogWheel`, `DjParallelWaveformPainter` y `_ClipWaveformPainter`.
   - Extraer las expresiones regulares de `RealSheetMusicPainter` a constantes `static final RegExp` y añadir `timeSignature` y `totalMeasures` a `shouldRepaint`.
   - Envolver con `SingleChildScrollView(scrollDirection: Axis.horizontal)`, `Expanded` o `Flexible` los encabezados, steppers y controles horizontales en `GuidedLessonsModal`, `ExerciseGeneratorModal`, `PracticeReportModal` y `DrumPadsTactileWidget`.

---

## 3. Consecuencias

- **Positivas:**
  - Cero intentos fallidos de lectura de assets para iconos en fase de fallback; resolución en $O(1)$ y tests de widget limpios sin excepciones de `AssetBundle`.
  - Coherencia 100% entre `StudioThemeController` y `StudioThemeCatalogService` arrancando en `studio_oled_monochrome`.
  - Resiliencia matemática garantizada en los `CustomPainter` ante redimensionamientos extremos (`10x10`) o telemetría `NaN`.
  - Compatibilidad responsiva verificada en resoluciones móviles y paneles flotantes estrechos (`360x640`).
- **Negativas / Trade-offs:**
  - Cuando se agreguen los 6 PNGs restantes al directorio `assets/icons/png/`, deberán añadirse al conjunto por defecto o cargarse mediante `StudioIcon.preloadManifest()` al inicio de la aplicación.
