# ADR 0207: Modulos Vivos en RackUnitCard y Tokenizacion de StudioRotaryKnob

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-215](../02_use_cases/215_uc_live_rack_unit_modules_and_tokenized_rotary_knob.md)

---

## 1. Contexto

En `lib/core/design_system/atoms/studio_rotary_knob.dart`, `StudioRotaryKnob` emplea colores hardcodeados (`Color(0xFF00E5FF)`, `Colors.white70`, `Colors.white38`, `Colors.white12`) en lugar de resolver `StudioDesignTokens` mediante `StudioThemeScope.of(context)`. De forma similar, `RackUnitCard` (`lib/features/modular_rack/presentation/rack_unit_card.dart`) usa paletas fijas (`Color(0xFF161F30)`, `Color(0xFF0F172A)`), muestra `'Clave de Sol'` estatico en `_buildScoreNotationContent` y reduce los modulos `RackModuleType.djConsole` y `RackModuleType.stemMixer` a un texto pasivo (`_buildStudioAudioModuleSummary`) sin ningun control interactivo.

---

## 2. Decision

1. **Tokenizacion Integral de `StudioRotaryKnob`:**
   - Leer `final tokens = StudioThemeScope.of(context);` dentro de `StudioRotaryKnob.build` para derivar `activeColor ?? tokens.accentPrimary`, colores de pista inactiva (`tokens.borderHairline`), etiqueta (`tokens.textSecondary`) y lectura numerica (`tokens.textMuted` / `activeColor`), respetando el skin activo en `StudioThemeScope`.
2. **Tokenizacion y Sub-vistas Vivas en `RackUnitCard`:**
   - Migrar los contenedores y cabeceras de `RackUnitCard` (`Key('rack_unit_card_header')`) a `StudioThemeScope.of(context)`.
   - Reemplazar `'Clave de Sol'` estatico en `_buildScoreNotationContent` por `tuner.activeInstrument.clef.displayName`.
   - Reemplazar `_buildStudioAudioModuleSummary` por dos paneles interactivos reales:
     - `RackModuleType.stemMixer` (`Key('rack_stem_mixer_live_panel')`): Controles de ganancia (`StudioRotaryKnob` / sliders) y botones de mute/solo conectados a `tuner.mixerConsole`.
     - `RackModuleType.djConsole` (`Key('rack_dj_console_live_panel')`): Lectura en vivo de BPM de Decks A/B, selector de crossfader y botones de Play/Sync conectados a `DjConsoleViewModel` (opcional en el contexto con fallback seguro si no esta montado).

---

## 3. Consecuencias

### 3.1 Positivas
- **Consistencia de Skins:** Al cambiar de tema (`studioOledMonochrome`, `studioDark`, `studioWarmParchment`), todas las perillas rotatorias y tarjetas del rack adaptan su contraste automaticamente.
- **Zero Módulos Muertos:** Ningun modulo del Rack Modular queda como marcador de posicion estatico.

### 3.2 Compromisos y Mitigaciones
- **Uso Aislado en Tests sin `DjConsoleViewModel`:** Si `RackUnitCard` con `RackModuleType.djConsole` se monta sin `DjConsoleViewModel` en el arbol `Provider`, el panel vivo muestra estado de espera local y controles deshabilitados de forma segura sin lanzar `ProviderNotFoundException`.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/modular_rack/us_ux_15_live_rack_modules_and_tokenized_knob_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
