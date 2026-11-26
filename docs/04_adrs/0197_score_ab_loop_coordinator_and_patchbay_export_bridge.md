# ADR 0197: Coordinador Unificado de Bucle A-B en Partitura y Puente Multi-Canal Patchbay

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-205](../02_use_cases/205_uc_score_ab_loop_coordinator_and_patchbay_export_bridge.md)

---

## 1. Contexto

En `ScorePlaybackCoordinator` (`lib/features/sheet_music/domain/score_playback_coordinator.dart`) existen los metodos `setMeasureLoopRange(start, end)`, `clearMeasureLoop()` y el estado `isMeasureLoopActive`, los cuales son invocados por `CompositionNotationWorkspaceView` (`lib/features/workspaces/presentation/composition_notation_workspace_view.dart`) al pulsar `btn_set_loop_point_a` y `btn_set_loop_point_b`. Sin embargo, durante la reproduccion de partitura y practica en `TunerViewModel` (`lib/features/tuner/presentation/tuner_viewmodel.dart`), el avance de compas al llegar a `subTick == 0` ejecuta `(_currentMeasureIndex + 1) % maxMeasures`, ignorando el rango $[M_A, M_B]$ del coordinador. Por otra parte, `_sendActiveScoreToPatchbayChannelA` en `CompositionNotationWorkspaceView` esta fijado exclusivamente al canal `'canal_a'` sin permitir elegir otros canales del Patchbay ni exportar el segmento acotado `[A, B]`.

---

## 2. Decision

1. **Unificacion del Secuenciador A-B en `TunerViewModel`:** Modificar la transicion de compas en el bucle de metronomo/partitura de `TunerViewModel` para consultar `scorePlaybackCoordinator.isMeasureLoopActive`, `loopStartMeasureIndex` y `loopEndMeasureIndex`. Cuando el bucle A-B este activo, al superar `loopEndMeasureIndex` el cursor retornara deterministicamente a `loopStartMeasureIndex` (recortado a `[0, maxMeasures - 1]`).
2. **Puente Multi-Canal Patchbay y Exportacion de Segmento A-B en `CompositionNotationWorkspaceView`:** Reemplazar la publicacion fija a `'canal_a'` por un puente configurable con selector de canal (`Key('btn_score_patchbay_channel_selector')`) conectado a `StudioPatchbayRoutingService` (incluyendo titulo, BPM, tonalidad y metadatos del rango `[M_A, M_B]`), y agregar el disparador `Key('btn_export_ab_loop_segment')` para exportar un `SongPackage` recortado al bucle `[M_A, M_B]` hacia `AudioMidiExportModal` o `MediaVaultViewModel`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Coherencia Total entre Lienzo, Metronomo y Sintetizador:** El bucle A-B funciona de forma identica tanto en audicion aislada como en practica evaluada con microfono y Smart Wait.
- **Ruteo Flexible de Partituras:** El usuario puede enviar distintas partituras o extractos A-B a `canal_a`, `canal_b`, `canal_c`, `canal_d` o buses personalizados del estudio.

### 3.2 Compromisos y Mitigaciones
- **Evaluacion de Reporte en Bucle:** Al activarse `isMeasureLoopActive`, el reporte completo de fin de obra solo se dispara explicitamente al concluir una pasada completa fuera de bucle o al detener la sesion de practica, evitando interrumpir al musico con modales en cada repeticion de compas.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/workspaces/us_hc_03_score_ab_loop_coordinator_and_patchbay_bridge_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
