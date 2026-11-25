# ADR 0193: Barra de Macro-Perillas Smart Controls estilo Apple Logic Pro en el Rack Modular

- **Estado:** Aprobado
- **Fecha:** 2026-11-25
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-201](../02_use_cases/201_uc_logic_pro_smart_controls_macro_bar_in_rack.md)

---

## 1. Contexto

En estaciones de produccion como **Apple Logic Pro (*Smart Controls*)** y **Ableton Live (*Macro Controls*)**, una cadena compleja de modulos DSP se sintetiza en una fila superior de 4 a 8 macro-perillas rotatorias que gobiernan los parametros acusticos mas frecuentes sin obligar al usuario a abrir ventanas individuales por cada procesador. En `ModularStudioRackView`, ajustar parametros globales del estudio requeria desplazarse por la lista de tarjetas `RackUnitCard` o abrir modales secundarios.

---

## 2. Decision

1. **Organismo `StudioSmartControlsMacroBar` (`lib/features/modular_rack/presentation/studio_smart_controls_macro_bar.dart`):** Construir un panel de macro-control (`Key('studio_smart_controls_macro_bar')`) utilizando el atomo `StudioRotaryKnob` y `StudioDesignTokens` con **6 Macro-Perillas en tiempo real**:
   - `A4 PITCH` (`Key('smart_knob_a4_pitch')`, $415.0 .. 466.0	ext{ Hz}$).
   - `MASTER TEMPO` (`Key('smart_knob_master_tempo')`, $40.0 .. 240.0	ext{ BPM}$).
   - `NOISE GATE` (`Key('smart_knob_noise_gate')`, $-70.0 .. -10.0	ext{ dB}$).
   - `DRONE MIX` (`Key('smart_knob_drone_mix')`, $0.0 .. 100.0\%$).
   - `RETUNE SPEED` (`Key('smart_knob_retune_speed')`, $0.0 .. 100.0	ext{ ms}$).
   - `ROOM REVERB` (`Key('smart_knob_room_reverb')`, $0.0 .. 100.0\%$).
2. **Perfiles Macro Instantaneos e Integracion en `ModularStudioRackView`:** Incluir 3 presets de un clic (`Estudio Limpio`, `Sala de Concierto`, `Barroco 415 Hz`), boton de restauracion (`Key('smart_controls_reset_defaults_btn')`) y el conmutador `Key('btn_toggle_smart_controls_bar')` en la cabecera de `ModularStudioRackView`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Control Tactil y Directo a 60 FPS:** Los 6 parametros cardinales del estudio se gobiernan desde una unica consola superior con retroalimentacion numerica instantanea.
- **Cambio de Escenario Acustico en 1 Clic:** El musico puede pasar de afinacion estandar de estudio ($440	ext{ Hz}$) a orquesta sinfonica ($442	ext{ Hz}$) o ensamble barroco ($415	ext{ Hz}$) mediante un solo chip de preset macro.

### 3.2 Compromisos y Mitigaciones
- **Colapsabilidad en Pantallas Compactas:** El boton `btn_toggle_smart_controls_bar` permite ocultar la barra de macro-perillas cuando el usuario desea dedicar toda la altura vertical al patchbay de tarjetas.

---

## 4. Verificacion

- Suite automatizada: `test/features/modular_rack/us_ux_09_smart_controls_macro_bar_test.dart`.
- Analisis estatico: `flutter analyze --no-fatal-infos` con `0 issues`.
