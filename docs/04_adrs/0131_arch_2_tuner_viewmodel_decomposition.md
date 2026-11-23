# ADR-0131: Decomposición Modular de TunerViewModel, Puertos ISP y Atomicidad Reactiva (ARCH-2)

- **Estado:** Aceptado
- **Fecha:** 2026-11-20
- **Issue Relacionado:** #109
- **Caso de Uso Base:** `docs/02_use_cases/142_uc_arch_2_tuner_viewmodel_decomposition.md`

## Contexto
La auditoría `PLAN-PRE-V1-ARCH-SOLID-2026-01` identificó que `TunerViewModel` era un monolito de 3,274 líneas fragmentado únicamente de forma cosmética mediante 3 directivas `part of`, provocando:
1. Estado privado compartido sin fronteras claras entre grabación multipista, edición/exportación de partituras y pedagogía/Auto-Tune.
2. Acoplamiento Hub-and-Spoke desde 16 features hacia toda la clase `TunerViewModel`.
3. Reconstrucciones completas de árbol UI a 30–60 Hz por `context.watch<TunerViewModel>()`.

## Decisión
1. **Composición Real sobre `part of`:** Se eliminan los 3 archivos `part of` convirtiendo sus responsabilidades en 3 controladores cohesivos independientes (`PracticeRecorderController`, `ScoreEditorController`, `VocalPedagogyController`) que reciben solo sus dependencias mínimas y exponen operaciones limpias. `TunerViewModel` compone dichos controladores y reenvía sus notificaciones.
2. **Segregación de Interfaces (ISP):** Se definen puertos estrechos (`IGuidedLessonSessionPort`, `IChordAnalyzerSessionPort`, `IScoreEditorSessionPort`) para desacoplar las vistas consumidoras del agregado completo.
3. **Atomicidad Reactiva (`ValueListenable`):** Se añade `ValueNotifier<TunerAcousticTelemetry>` en `TunerViewModel` para actualizar los indicadores de afinación a 60 Hz sin disparar rebuilds completos en contenedores superiores.
4. **Ubicación Canónica:** Se mueven las implementaciones canónicas de `TunerViewModel` y `TunerScreen` a `lib/features/tuner/presentation/`, dejando archivos puente de exportación mínima mientras migran todas las features.

## Consecuencias
### Positivas
- Eliminación del 100% de las directivas `part` / `part of` en `lib/`.
- Controladores unitariamente testeables de forma aislada y reducción significativa de líneas en `TunerViewModel`.
- Reducción de rebuilds innecesarios en `TunerScreen`.

### Negativas / Riesgos Mitigados
- Mantener la fachada de `TunerViewModel` evita romper las más de 40 suites de prueba existentes durante la transición gradual.
