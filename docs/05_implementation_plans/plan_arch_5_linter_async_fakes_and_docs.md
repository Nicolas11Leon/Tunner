# Plan de Implementación: ARCH-5 — Linter Estricto, Higiene Async, Fakes y Documentación

**ID:** PLAN-ARCH-5-LINTER-DOCS-2026-01  
**Issue:** #112  
**Rama:** `refactor/arch-5-linter-async-fakes-and-docs`  
**Base:** `qa`  

---

## 1. Objetivo
Completar el endurecimiento estático, asíncrono, de pruebas y documental de la arquitectura Tunner previo a la certificación v1.0.0.

## 2. Entregables
1. `analysis_options.yaml` endurecido y 0 issues en `flutter analyze --no-fatal-infos`.
2. `Future<void>` en `toggleRecording` / `startSongWithCountIn`, `await saveRecordingToDisk`, trazabilidad en `catch`, y eliminación de `Float32List(512)` en `DjConsoleViewModel.stopRecording()`.
3. `test/helpers/studio_test_fakes.dart` y fortalecimiento de `ux_wave_4_dj_dsp_and_vault_test.dart`.
4. `docs/spikes/001_dsp_isolate_and_pitch_benchmarks.md`, renumeración de ADRs duplicados, 2do Mermaid en `UC-52` y eliminación de emojis residuales en `docs/`.

## 3. Criterios de Aceptación
- `flutter analyze --no-fatal-infos`: 0 issues.
- `flutter test --no-pub`: 100% de pruebas aprobadas.
- Cero emojis en `docs/` y `lib/`.
