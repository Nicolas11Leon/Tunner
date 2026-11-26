# ADR 0208: Lanzador de Boveda, Presets de Stems y Snap de Crossfader en Consola DJ

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-216](../02_use_cases/216_uc_dj_workstation_vault_launcher_stem_presets_and_crossfader_snap.md)

---

## 1. Contexto

En `DjStudioWorkstationView` (`lib/features/dj_console/presentation/dj_studio_workstation_view.dart`), el usuario puede abrir `DjTrackLoaderModal`, pero no dispone de un acceso directo en la cabecera hacia la Boveda Multimedia (`MediaVaultWorkspaceModal`) para inspeccionar activos o arrastrar/enviar tomas. Ademas, la tira de aislamiento de 4 stems (`_buildStemStrip`) solo ofrece conmutadores individuales (`VOCAL`, `MELODY`, `BASS`, `DRUMS`), obligando a pulsar multiples botones para lograr una acapella o una pista instrumental; y el `Slider` del crossfader central carece de iman magnetico hacia `0.0` y de boton directo de centrado rapido.

---

## 2. Decision

1. **Lanzador Directo de Boveda Multimedia en `DjStudioWorkstationView`:**
   - Anadir el boton `Key('dj_open_media_vault_launcher_btn')` en la barra superior de la estacion DJ (junto a los controles de mezcla/exportacion) para abrir `MediaVaultWorkspaceModal` con el `MediaVaultViewModel` activo o callback inyectado.
2. **Presets de 4 Stems en 1 Clic (`DjStemPreset`):**
   - Definir en `lib/features/dj_console/domain/dj_stem_isolation_entity.dart` los presets puros `acapella` (solo vocal activa), `instrumental` (vocal silenciada; melodia, bajo y bateria activos), `drumsOnly` (solo bateria activa) y `fullMix` (todos activos).
   - Implementar `applyStemPreset(String deckId, DjStemPreset preset)` en `DjConsoleViewModel` y exponer chips en `_buildStemStrip` (`Key('dj_stem_preset_${deckId}_acapella')`, `instrumental`, `drums_only`, `reset`).
3. **Snap Magnetico Central y Boton `0.0` en Crossfader:**
   - Implementar `snapCrossfaderWithMagneticDeadzone(double rawPosition, {double deadzone = 0.04})` y `centerCrossfader()` en `DjConsoleViewModel`.
   - Conectar el `Slider` del crossfader al snap magnetico en `onChanged` y anadir `Key('dj_crossfader_center_snap_btn')` (y soporte `onDoubleTap`) para centrar instantaneamente en `0.0`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Transiciones Limpias en Vivo:** El DJ ejecuta cortes Acapella/Instrumental en 1 clic y centra el crossfader sin quedar atascado en `+0.02` o `-0.03`.
- **Flujo Continuo con Boveda:** Acceso inmediato a grabaciones y stems locales sin cerrar la estacion DJ.

### 3.2 Compromisos y Mitigaciones
- **Ajuste Fino Cerca del Centro:** La zona muerta se limita a `|rawPosition| <= 0.04` (4% del recorrido total), manteniendo resolucion continua fuera de ese umbral.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/dj_console/us_ux_16_dj_vault_launcher_stem_presets_and_crossfader_snap_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
