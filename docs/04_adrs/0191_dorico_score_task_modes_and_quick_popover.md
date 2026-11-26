# ADR 0191: Modos de Flujo Musical estilo Steinberg Dorico y Popover Rapido de Tempo y Compas en Partitura

- **Estado:** Aprobado
- **Fecha:** 2026-11-25
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-199](../02_use_cases/199_uc_dorico_score_task_modes_and_quick_popover.md)

---

## 1. Contexto

En `CompositionNotationWorkspaceView`, apilar simultaneamente la barra de navegacion de obra, la paleta de 15 herramientas de escritura de notas, la barra de transcripcion, la consola de 4 Stems y la barra inferior de exportacion reducia la altura vertical disponible para el pentagrama SMuFL. Los referentes comerciales de notacion (**Steinberg Dorico 5** con sus modos *Write / Play / Print* y sus *Popovers* `Shift+T` / `Shift+M`) resuelven este problema mostrando unicamente las barras correspondientes a la intencion cognitiva actual del musico.

---

## 2. Decision

1. **Modos de Flujo Musical (`ScoreWorkflowTaskMode`):** Incorporar en `CompositionNotationWorkspaceView` (`lib/features/workspaces/presentation/composition_notation_workspace_view.dart`) el selector segmentado `Key('dorico_score_task_mode_selector')` con cuatro modos:
   - `all` (`Key('dorico_mode_all_chip')` - `'Todo'`): Modo por defecto retrocompatible.
   - `write` (`Key('dorico_mode_write_chip')` - `'Escribir (Write)'`): Muestra la paleta de escritura de figuras y alteraciones sobre el pentagrama.
   - `mixStems` (`Key('dorico_mode_mix_chip')` - `'Mezclar Stems (Mix)'`): Oculta la barra de escritura de notas y prioriza la consola en linea de 4 Stems y Minus-One.
   - `practice` (`Key('dorico_mode_practice_chip')` - `'Practicar (Practice)'`): Oculta la barra de edicion para maximizar el pentagrama y despliega la barra de **Bucle A-B de Compases** (`Key('score_ab_measure_loop_bar')`).
2. **Popover Rapido de Comando Musical (`Key('dorico_quick_command_popover')`):** Anadir el disparador `Key('btn_open_dorico_quick_popover')` que despliega un campo de entrada rapida (`Key('dorico_popover_input_field')`) capaz de interpretar valores de tempo (`144`, `120 bpm`) o saltos directos de compas (`m3`, `compas 2`).

---

## 3. Consecuencias

### 3.1 Positivas
- **Despeje Vertical del Pentagrama SMuFL:** Al cambiar a los modos `Mezclar Stems` o `Practicar`, se oculta la paleta de dibujo de notas, recuperando espacio vertical critico para la lectura musical.
- **Entrada de Parametros sin Navegacion de Menus:** El Popover Rapido permite ajustar el tempo o saltar a un compas con el teclado en menos de 1,5 segundos.

### 3.2 Compromisos y Mitigaciones
- **Retrocompatibilidad Garantizada:** El estado inicial `ScoreWorkflowTaskMode.all` mantiene visibles todos los controles para flujos y pruebas preexistentes.

---

## 4. Verificacion

- Suite automatizada: `test/features/workspaces/us_ux_07_dorico_task_modes_and_popover_test.dart`.
- Analisis estatico: `flutter analyze --no-fatal-infos` con `0 issues`.
