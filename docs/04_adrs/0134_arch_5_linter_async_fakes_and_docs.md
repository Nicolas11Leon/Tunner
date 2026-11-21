# ADR-0134: Endurecimiento de Linter, Contratos Future<void> y Normalización Documental

- **Estado:** Aceptado
- **Fecha:** 2026-11-20
- **Issue:** #112 (ARCH-5)
- **Relacionado:** UC-145

## Contexto
La auditoría final identificó configuraciones permisivas en `analysis_options.yaml`, métodos `void ...() async` que ocultaban excepciones y impedían `await`, bloques `catch (_)` silenciosos, un fallback artificial `Float32List(512)` en `DjConsoleViewModel.stopRecording()`, duplicación de fakes en pruebas, y deuda documental (colisiones de ADRs `0014`-`0016`, carpeta `docs/spikes/` ausente, `UC-52` con un solo diagrama Mermaid y emojis residuales en 6 documentos).

## Decisión
1. Habilitar `unawaited_futures`, `cancel_subscriptions`, `close_sinks`, `prefer_final_fields` y `use_super_parameters` en `analysis_options.yaml`.
2. Convertir `toggleRecording` y `startSongWithCountIn` a `Future<void>`, hacer `await vm.saveRecordingToDisk(...)` y reemplazar `catch (_)` por trazabilidad estructurada.
3. Retornar el resultado real de `_recorder.stopRecording()` sin rellenar silencio artificial `Float32List(512)`.
4. Crear `test/helpers/studio_test_fakes.dart` y endurecer `ux_wave_4_dj_dsp_and_vault_test.dart`.
5. Normalizar `docs/spikes/`, renumerar ADRs colisionados, completar `UC-52` y limpiar emojis residuales.

## Consecuencias
- **Positivas:** Prevención estática de fugas de recursos (`StreamSubscription`, `Sink`), trazabilidad diagnóstica de errores, y cumplimiento íntegro de `AGENTS.md`.
- **Negativas / Trade-offs:** Mayor rigor en CI ante futuros `Future` no esperados.
