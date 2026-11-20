# Plan de Implementacion: UX Wave 1 - Atajos de Teclado, Foco, Command Palette y Prompt Bar

## Metadatos
- **ID:** `PLAN-UX-WAVE-1-2026-001`
- **Titulo:** Remediacion Quirurgica de Usabilidad de Teclado, Paleta de Comandos y Prompt Bar
- **Fase:** Fase 4 - Hardening Pre-v1.0.0
- **Estado:** Aprobado
- **ADR Relacionado:** [ADR 0126](../04_adrs/0126_ux_wave_1_keyboard_shortcuts_and_prompt.md)
- **Documento Funcional Base:** [Caso de Uso 137](../02_use_cases/137_uc_ux_wave_1_keyboard_shortcuts_and_prompt.md)

---

## 1. Alcance y Objetivos

### 1.1 Objetivo Primario
Optimizar la ergonomia de control por teclado fisico en Tunner Desktop y Web, garantizando soporte completo de atajos globales, navegacion Spotlight en la Command Palette, entrada de teclado en modales clave y procesamiento limpio de comandos con argumentos en el prompt bar.

### 1.2 Limites del Alcance
- **Incluido:**
  - `pro_command_palette_modal.dart`: Manejo de flechas, enter, seleccion activa y catalogo completo.
  - `main_app_shell.dart`: Atajos globales (`Ctrl+S`, `Ctrl+O`, `Ctrl+N`, `Ctrl+B`, `Ctrl+Shift+D`, `F1..F6`, `Alt+1..6`, `F12`, `?`), intenciones, acciones y descarte de apertura accidental de terminal.
  - `studio_command_prompt_bar.dart`: Tokenizacion de comandos con argumentos (`/bpm 140`, `/calibrar 442`).
  - `tap_tempo_modal.dart`: Entrada de teclado (`T`, `Space`, `Enter`).
  - `universal_master_keyboard_widget.dart`: Mapeo QWERTY a notas musicales.
  - `score_editor_modal.dart`: Atajos de teclado para navegacion e insercion de notas.
- **Excluido:**
  - Redisenos estructurales de vistas DAW (alcance de Ola UX-2).
  - Reescritura de motores de renderizado de lienzo o DSP de consola DJ (alcances de Ola UX-3 y UX-4).

---

## 2. Plan Paso a Paso de Ejecucion

### Paso 1: Refactorizacion de `ProCommandPaletteModal`
1. Incorporar `Focus` con `onKeyEvent` que intercepte `arrowDown`, `arrowUp` y `enter`.
2. Mantener `_selectedIndex` limitado a `[0, _filteredCommands.length - 1]`.
3. Anadir estilo visual de elemento seleccionado (`border` o fondo resaltado con `palette.primaryAccent`).
4. Al pulsar `enter`, ejecutar el comando seleccionado y cerrar el modal.

### Paso 2: Ampliacion de Comandos y Registro de Atajos en `MainAppShell`
1. Agregar atajos globales a `activeShortcuts`:
   - `SingleActivator(LogicalKeyboardKey.keyS, control: true)` -> `SaveSessionIntent`
   - `SingleActivator(LogicalKeyboardKey.keyO, control: true)` -> `OpenFileIntent`
   - `SingleActivator(LogicalKeyboardKey.keyN, control: true)` -> `NewProjectIntent`
   - `SingleActivator(LogicalKeyboardKey.keyB, control: true)` -> `ToggleSidebarIntent`
   - `SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true)` -> `ToggleDualSplitIntent`
   - `F1..F6` y `Alt+1..Alt+6` -> `SwitchTabIntent(0..5)`
   - `F12` y `Ctrl+backquote` -> `ToggleTerminalIntent`
   - `slash` con shift o `F1` -> `OpenShortcutsGuideIntent`
2. Ampliar la lista `commands` en `_openCommandPalette` para cubrir todas las funciones principales.

### Paso 3: Correccion de Sintaxis en `StudioCommandPromptBar`
1. En `_applySuggestionFilter`: comparar contra el primer token para que comandos como `/bpm 140` mantengan visible y seleccionable la sugerencia de `/bpm`.
2. En `_submitCurrentText`: si el comando comienza por `/` o `@`, buscar coincidencia por prefijo del comando y ejecutar `_executeSuggestion` sin disparar apertura obligatoria del terminal.

### Paso 4: Entrada de Teclado en `TapTempoModal`, `UniversalMasterKeyboardWidget` y `ScoreEditorModal`
1. `TapTempoModal`: Responder a `T`, `Space` y `Enter` para llamar a `_onTap()`.
2. `UniversalMasterKeyboardWidget`: Escuchar eventos de teclado fisico mapeando teclas QWERTY a notas MIDI (`A`=Do, `W`=Do#, `S`=Re, `E`=Re#, `D`=Mi, `F`=Fa, `T`=Fa#, `G`=Sol, `Y`=Sol#, `H`=La, `U`=La#, `J`=Si, `K`=Do+1).
3. `ScoreEditorModal`: Permitir navegacion de compases/ticks con flechas y confirmacion con Enter.

### Paso 5: Suite de Pruebas de Regresion y Verificacion
1. Crear `test/features/navigation/ux_wave_1_keyboard_shortcuts_test.dart` verificando:
   - Atajos de navegacion de pestañas por `Alt+1..6` y `F1..F6`.
   - Paleta de comandos: navegacion por flechas y ejecucion con Enter.
   - Prompt bar: ejecucion de `/bpm 120` y `/calibrar 442` sin invocar terminal.
   - Tap tempo: registro de taps con teclado fisico.
2. Ejecutar `flutter analyze --no-fatal-infos` (0 advertencias).
3. Ejecutar suite completa de pruebas con `flutter test --no-pub`.
