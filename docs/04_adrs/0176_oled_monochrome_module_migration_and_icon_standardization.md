# ADR-0176: Migración OLED Monochrome y Estandarización de StudioIcon en Modales de Estudio, Acústica y Pedagogía

- **Estado:** Aceptado
- **Fecha:** 2026-11-23
- **Historia de Usuario:** US-7.3 (Issue #178)
- **Caso de Uso:** [UC-184](../02_use_cases/184_uc_oled_monochrome_and_studio_icon_across_modules.md)

---

## Contexto

Tras consolidar el sistema de diseño Pro OLED Monochrome (`StudioDesignTokens`, `StudioThemeScope`, `StudioIcon`) en ADR-0166 y migrar el Shell, Canales, Terminal y Workspaces en ADR-0174, once componentes modales y de dock distribuidos en los módulos de estudio, acústica, grabación y pedagogía permanecían acoplados a `TunnerThemePalette`, colores neón hardcodeados e iconos dispersos de Material Icons:

1. **Tipado inseguro (`dynamic palette`):** `ExerciseGeneratorModal` resolvía `v.currentPalette` con `context.select<TunerViewModel, dynamic>` y propagaba `dynamic palette` a helpers privados; `HarmonicSpectrogramModal` también declaraba `required dynamic palette` en `_metricCard`.
2. **Colores neón hardcodeados:** `HarmonicTutorModal`, `LearnerProfileSelectorModal`, `SpectralComparatorModal` y `SpectralComparatorPainter` incrustaban literales `Color(0xFF00E5FF)`, `Color(0xFF00E676)` y `Color(0xFFFFD700)`, rompiendo la estética monocromática OLED (negro puro + plata/blanco, reservando color únicamente para telemetría semántica).
3. **Iconografía heterogénea:** Los encabezados, botones de cierre, controles de transporte, micrófono, exportación PDF y comparación usaban `Icon(Icons.*)` directamente en lugar de `StudioIcon`.
4. **Restricción de aislamiento paralelo:** La migración debía ejecutarse sin modificar `tuner_screen.dart` ni `tuner_viewmodel.dart` para evitar conflictos con US-9.3 en desarrollo paralelo, y sin romper pruebas existentes que montan modales sin envolverlos en `StudioThemeScope`.

---

## Decisión

1. **Adopción uniforme de `StudioThemeScope.of(context)`:**
   - Migrar los 12 archivos objetivo (`exercise_generator_modal.dart`, `harmonic_drone_modal.dart`, `tap_tempo_modal.dart`, `harmonic_spectrogram_modal.dart`, `chord_analyzer_modal.dart`, `blind_ear_trainer_modal.dart`, `harmonic_tutor_modal.dart`, `learner_profile_selector_modal.dart`, `pedagogical_report_modal.dart`, `spectral_comparator_modal.dart`, `spectral_comparator_painter.dart` y `practice_recorder_dock.dart`) para consumir `StudioDesignTokens` vía `StudioThemeScope.of(context)`.
   - Aprovechar el fallback automático de `StudioThemeScope.of(context)` hacia `StudioDesignTokens.studioOledMonochrome` para garantizar compatibilidad total con pruebas heredadas que no monten un `StudioThemeScope` explícito.

2. **Eliminación de `dynamic palette` y literales neón:**
   - Eliminar todos los casts `dynamic` de paleta en `ExerciseGeneratorModal` y `HarmonicSpectrogramModal`, tipando los helpers estrictamente con `StudioDesignTokens`.
   - Reemplazar `0xFF00E5FF`, `0xFF00E676`, `0xFFFFD700` y colores de estado hardcodeados por `tokens.accentPrimary`, `tokens.accentSecondary`, `tokens.accentSuccess`, `tokens.accentWarning`, `tokens.accentDanger` y `tokens.textOnAccent`.

3. **Estandarización sobre `StudioIcon`:**
   - Sustituir iconos de encabezado, cierre, transporte, micrófono, volumen, exportación y herramientas por `StudioIcon(StudioIconId.*, tintCustomAsset: true, ...)` usando los identificadores canónicos de `StudioIconCatalog` (y `fallbackOverride` únicamente cuando un glifo auxiliar no tenga equivalente dedicado en los 44 IDs canónicos).

4. **Retrocompatibilidad binaria de firmas públicas:**
   - En `HarmonicTutorModal` y `SpectralComparatorPainter`, conservar el parámetro opcional `palette` para no alterar llamadores existentes en `tuner_screen.dart` ni pruebas heredadas, utilizando `StudioDesignTokens` como fuente principal de renderizado.
   - En `ChordAnalyzerModal` y `BlindEarTrainerModal`, mantener la delegación de `viewModel.currentPalette` exclusivamente hacia subwidgets fuera del alcance (`MultiToneVoicingWidget`, `ChordRadarWidget`, `ContextualHelpBadge`).

---

## Consecuencias

### Positivas
- Coherencia visual Pro-DAW OLED Monochrome en todos los modales de estudio, acústica, grabación y pedagogía.
- Tipado estático completo (`StudioDesignTokens`) sin casts `dynamic` en la capa de presentación migrada.
- Cambio de skin en caliente propagado automáticamente a modales abiertos mediante `StudioThemeScope`.
- Cero conflictos con `tuner_screen.dart` y `tuner_viewmodel.dart`.

### Negativas / Compromisos
- `HarmonicTutorModal` y `SpectralComparatorPainter` conservan temporalmente un parámetro opcional `palette` por retrocompatibilidad hasta que todos los consumidores externos migren completamente a `StudioDesignTokens`.

---

## Verificación

- Suite dedicada `test/core/design_system/us_7_3_modules_oled_and_studio_icon_test.dart` verificando renderizado OLED Monochrome, presencia de `StudioIcon` y ausencia de errores en todos los modales migrados.
- `flutter analyze --no-fatal-infos` sin errores.
- `flutter test --no-pub --timeout 45s` verde en `test/core/design_system/us_7_3_*`, `test/features/ear_training/`, `test/features/harmonic_tutor/`, `test/features/exercise_generator/`, `test/features/pedagogy_report/` y `test/features/practice_recorder/`.
