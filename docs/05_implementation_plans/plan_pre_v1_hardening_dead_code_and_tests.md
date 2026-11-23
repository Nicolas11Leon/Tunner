# Plan de Implementacion: Ola 5 - Endurecimiento Final, Codigo Muerto y Pruebas Pre-v1.0.0

- **ID:** PLAN-PRE-V1-WAVE5-2026-001
- **Issue:** #72
- **Rama:** `chore/pre-v1-hardening-dead-code-and-tests` (base: `qa`)

## 1. Objetivo
Completar la limpieza de codigo muerto verificado, reemplazar bloques `catch (_)` silenciosos criticos mediante un puerto puro `IStudioLogger`, incorporar pruebas unitarias faltantes en `core/docking` y `ITerminalCommandHandler`, y ejecutar la compuerta completa de verificacion Pre-v1.0.0.

## 2. Alcance de Cambios
1. **Eliminacion de archivos muertos:**
   - `lib/features/guided_lessons/presentation/atomic_widgets/task_card_base.dart`
   - `lib/features/mixer/data/tone_generator_service.dart`
   - `lib/features/modular_rack/presentation/connection_matrix_modal.dart`
2. **Logging estructurado y eliminacion de `catch (_)` silenciosos:**
   - Crear `lib/core/logging/domain/i_studio_logger.dart`
   - Crear `lib/core/logging/infrastructure/studio_debug_logger.dart`
   - Actualizar bloques `catch (_)` criticos en `json_local_persistence_service.dart`, `studio_audio_input_engine.dart` y `tuner_viewmodel.dart`.
3. **Pruebas y Auditoria Final:**
   - Crear `test/core/docking/studio_docking_controller_test.dart`
   - Agregar pruebas de `ITerminalCommandHandler` en `test/core/terminal/tunner_os_kernel_test.dart`
   - Ejecutar `./scripts/build_native_dsp.sh`, `audit_tunner.py`, `audit_deep.py`, `flutter analyze --no-fatal-infos` y `flutter test`.
   - Actualizar `README.md` y `docs/07_releases/release_notes_v1.0.0.md`.
