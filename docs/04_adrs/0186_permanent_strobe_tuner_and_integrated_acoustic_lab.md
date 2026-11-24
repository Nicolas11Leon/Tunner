# ADR 0186: Afinador Estroboscópico Permanente y Acceso Integrado al Laboratorio Acústico en Modo Pro

- **Estado:** Aprobado
- **Fecha:** 2026-11-24
- **Autor:** Nicolás León
- **Caso de Uso Relacionado:** [UC-194](../02_use_cases/194_uc_permanent_strobe_tuner_and_integrated_acoustic_lab.md)

---

## 1. Contexto

En `TunerScreen` (`lib/features/tuner/presentation/tuner_screen.dart`), el usuario alterna entre el Modo Esencial (`AppDisplayMode.essential`, que renderiza `EssentialTunerPanel` con el afinador estroboscópico central) y el Modo Conservatorio Pro (`AppDisplayMode.conservatoryPro`, que activa `WorkspaceSwitchBar` con los espacios `WorkspaceType.learning`, `WorkspaceType.composition` y `WorkspaceType.production`).

Esta transición presentaba una ruptura grave de continuidad funcional:

1. **Desaparición del Afinador al Entrar al Modo Conservatorio Pro:** Cuando el usuario cambiaba a `WorkspaceType.composition` (Editor de Partitura), el afinador en vivo y el botón de control del micrófono desaparecían por completo de la vista, obligando a regresar al Modo Esencial o al espacio `learning` solo para verificar si el instrumento seguía afinado o activar la captura de audio.
2. **Desconexión entre Lectura Rápida, Estroboscopio y Laboratorio Acústico:** El ingeniero de sonido o estudiante avanzado que necesitaba saltar desde cualquier espacio Pro hacia el Estroboscopio completo (`WorkspaceType.learning`) o hacia el Laboratorio Acústico (`WorkspaceType.production` en `ProductionAcousticLabWorkspaceView`) carecía de accesos directos persistentes de 1 clic junto a la telemetría de afinación en tiempo real.
3. **Restricción de Latencia y Fluidez (60/120 FPS):** De acuerdo con `AGENTS.md`, la telemetría acústica debe actualizarse de forma reactiva sin reconstruir todo el árbol de widgets de `TunerScreen` en cada frame DSP.

---

## 2. Decisión

Se introduce una arquitectura de **Barra Persistente de Telemetría del Afinador y Navegación Rápida al Laboratorio Acústico** en `TunerScreen` cuando `AppDisplayMode.conservatoryPro` está activo:

1. **Barra Persistente de Lectura y Micrófono (`pro_persistent_tuner_readout_bar`):**
   - Debajo de `WorkspaceSwitchBar` (o integrada en la cabecera fija del modo Pro en `TunerScreen`), se renderiza de forma permanente la barra `Key('pro_persistent_tuner_readout_bar')` en los tres espacios de trabajo (`learning`, `composition`, `production`).
   - La barra escucha exclusivamente `viewModel.telemetryListenable` mediante `ValueListenableBuilder<TunerAcousticTelemetry>`, aislando las actualizaciones de alta frecuencia (nota detectada, frecuencia en Hz, desviación en cents e indicador de estado afinado/desafinado) del resto del árbol de widgets de la pantalla.
   - Incorpora un botón de control directo del micrófono identificado con `Key('pro_persistent_mic_toggle_btn')` que invoca `viewModel.toggleRecording()`, reflejando en tiempo real si la captura acústica está activa o en pausa sin importar qué espacio de trabajo esté abierto.

2. **Accesos Directos de 1 Clic entre Estroboscopio y Laboratorio Acústico:**
   - Dentro de la barra persistente se integran dos controles de foco inmediato:
     - **`Key('tuner_quick_focus_strobe_btn')`:** Cambia instantáneamente el espacio activo a la vista de estroboscopio y práctica (`viewModel.setWorkspace(WorkspaceType.learning)`), resaltando visualmente su estado cuando `viewModel.activeWorkspace == WorkspaceType.learning`.
     - **`Key('tuner_quick_focus_pro_lab_btn')`:** Cambia instantáneamente al Laboratorio Acústico y Producción (`viewModel.setWorkspace(WorkspaceType.production)`), donde `ProductionAcousticLabWorkspaceView` mantiene el `StrobeTunerWidget` de alta visibilidad junto con espectrograma, temperamentos históricos y análisis armónico.

3. **Coherencia con la Transposición Instrumental y Tolerancia Pedagógica:**
   - La barra persistente respeta `viewModel.hasTransposition` (`writtenNoteName` frente a `noteName`) y `viewModel.centsTolerance` para la codificación cromática de afinación precisa, manteniendo la veracidad acústica definida en `ADR 0170`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Afinador Siempre Presente en Modo Pro:** El músico conserva lectura continua de nota, frecuencia (Hz), cents y control del micrófono mientras edita partituras, ajusta stems o analiza espectrogramas.
- **Navegación de 1 Clic sin Pérdida de Contexto:** El salto entre el Estroboscopio (`tuner_quick_focus_strobe_btn`) y el Laboratorio Acústico (`tuner_quick_focus_pro_lab_btn`) ocurre sin cerrar ni reiniciar el flujo de captura PCM.
- **Aislamiento de Repintado:** El uso de `ValueListenableBuilder<TunerAcousticTelemetry>` evita reconstrucciones innecesarias del editor de partituras o del selector de temperamentos a 60 Hz.

### 3.2 Compromisos y Mitigaciones
- **Duplicación Visual Potencial con el Estroboscopio Completo:** En `learning` y `production` ya existe un `StrobeTunerWidget` principal; la barra persistente mantiene un perfil compacto de telemetría numérica + micrófono + conmutadores de foco, evitando redundancia gráfica y actuando como cinta de estado unificada del afinador en todo el modo Pro.

---

## 4. Verificación

- **Caso de Uso Funcional:** [UC-194](../02_use_cases/194_uc_permanent_strobe_tuner_and_integrated_acoustic_lab.md).
- **Plan de Implementación Asociado:** [Plan Maestro de Rediseño UI/UX](../05_implementation_plans/plan_ux_unified_musical_workflow_redesign.md).
- **Suite de Pruebas Objetivo (`US-UX-02`):** `test/features/tuner/us_ux_02_unified_tuner_pro_lab_flow_test.dart`, validando:
  - Permanencia de `pro_persistent_tuner_readout_bar` y `pro_persistent_mic_toggle_btn` al conmutar a `AppDisplayMode.conservatoryPro` y recorrer `WorkspaceType.learning`, `WorkspaceType.composition` y `WorkspaceType.production`.
  - Conmutación directa hacia `WorkspaceType.production` mediante `tuner_quick_focus_pro_lab_btn` y retorno a estroboscopio mediante `tuner_quick_focus_strobe_btn`.
