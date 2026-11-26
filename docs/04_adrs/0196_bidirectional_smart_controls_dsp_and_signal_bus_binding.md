# ADR 0196: Vinculacion Bidireccional de Smart Controls con DSP y SignalBus

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-204](../02_use_cases/204_uc_bidirectional_smart_controls_dsp_and_signal_bus_binding.md)

---

## 1. Contexto

En la Ola 5 ([ADR 0193](0193_logic_pro_smart_controls_macro_bar_in_rack.md)), `StudioSmartControlsMacroBar` (`lib/features/modular_rack/presentation/studio_smart_controls_macro_bar.dart`) expuso 6 macro-perillas (`A4 PITCH`, `MASTER TEMPO`, `NOISE GATE`, `DRONE MIX`, `RETUNE SPEED`, `ROOM REVERB`) y 3 chips de preset. Al inspeccionar la implementacion real, `_updateA4Pitch` y `_updateMasterTempo` propagan valores hacia `TunerViewModel` y `ModularRackViewModel`, pero `_updateNoiseGate`, `_updateDroneMix`, `_updateRetuneSpeed` y `_updateRoomReverb` solo mutan campos locales de `_StudioSmartControlsMacroBarState` e invocan callbacks opcionales de widget, sin sincronizarse bidireccionalmente con los motores DSP de `TunerViewModel` ni emitir o escuchar eventos en `ModularRackViewModel.signalBus`.

---

## 2. Decision

1. **Contrato de Parametros Macro en Dominio (`SmartControlDspBindingSpec`):** Definir en `lib/features/modular_rack/domain/` las ecuaciones puras de normalizacion/desnormalizacion y mapeo de los 6 parametros (`A4 PITCH` $[415, 466]\text{ Hz}$, `MASTER TEMPO` $[40, 240]\text{ BPM}$, `NOISE GATE` $[-70, -10]\text{ dBFS}$ a amplitud lineal $10^{L/20}$, `DRONE MIX` $[0, 100]\%$, `RETUNE SPEED` $[0, 100]\text{ ms}$, `ROOM REVERB` $[0, 100]\%$).
2. **Enlace Bidireccional con `TunerViewModel` y `ModularRackViewModel.signalBus`:** Conectar las 6 perillas (`smart_control_noise_gate_knob`, `smart_control_drone_mix_knob`, `smart_control_retune_speed_knob`, `smart_control_room_reverb_knob`, junto con `A4` y `Tempo`) bidireccionalmente con los setters de `TunerViewModel` (umbral de Noise Gate, volumen de `HarmonicDroneConfig`, velocidad de `AutotuneConfigEntity` y ambiente en `PolyphonicVoicePool`) y publicar eventos en `SignalBus`.
3. **Proteccion Anti-Reentrancia:** Implementar una guarda `_isSyncingFromBus` en `StudioSmartControlsMacroBar` y un origen explicito en `ModularRackViewModel` para evitar bucles de retroalimentacion entre listeners.

---

## 3. Consecuencias

### 3.1 Positivas
- **Control Real de la Cadena Acustica:** Todas las macro-perillas del Rack Modular modifican parametros DSP efectivos en tiempo real y reflejan cambios originados desde otras vistas o presets.
- **Consistencia de Sesion:** Los ajustes de `Noise Gate`, `Drone Mix`, `Retune Speed` y `Room Reverb` sobreviven al desmontaje y remontaje de `ModularStudioRackView`.

### 3.2 Compromisos y Mitigaciones
- **Desacoplamiento de Pruebas Aisladas:** Si `StudioSmartControlsMacroBar` se monta en un arbol de prueba sin `TunerViewModel` ni `ModularRackViewModel` en el `Provider`, conserva el comportamiento local de respaldo junto con sus callbacks directos.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/modular_rack/us_hc_02_bidirectional_smart_controls_dsp_binding_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
