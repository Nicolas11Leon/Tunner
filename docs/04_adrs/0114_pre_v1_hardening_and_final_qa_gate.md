# ADR-0114: Endurecimiento Final Pre-v1.0.0, Telemetria de Errores y Compuerta de QA

- **Estado:** Aceptado
- **Fecha:** 2026-11-19
- **Contexto:** Tras completar las Olas 1 a 4 (estabilidad de memoria/DSP, pureza de Clean Architecture, inyeccion de dependencias y descomposicion modular), restaban tres focos de deuda tecnica antes de certificar la version `1.0.0`: archivos huerfanos sin referencias, bloques `catch (_)` silenciosos que ocultan errores de E/S o hardware de audio, y ausencia de pruebas unitarias dedicadas en `core/docking` y el registro de comandos de terminal.

## Decision
1. **Eliminacion de Codigo Muerto Verificado:** Remover del repositorio los archivos con cero referencias entrantes en `lib/` y `test/` (`task_card_base.dart`, `tone_generator_service.dart` y `connection_matrix_modal.dart`).
2. **Puerto de Registro Puro (`IStudioLogger`):** Introducir `IStudioLogger` en `lib/core/logging/domain/i_studio_logger.dart` (Dart puro, sin dependencias de Flutter) y `StudioDebugLogger` en `lib/core/logging/infrastructure/studio_debug_logger.dart`, reemplazando bloques `catch (_)` silenciosos criticos con reporte explicito de excepcion y traza.
3. **Cobertura de Modulos Criticos y Compuerta Final:** Incorporar pruebas unitarias para `StudioDockingController` y `ITerminalCommandHandler`, ejecutar compilacion nativa C, auditoria estatica completa y la totalidad de `flutter test` antes de actualizar `release_notes_v1.0.0.md` y `README.md`.

## Consecuencias
- **Positivas:**
  - Mayor observabilidad ante fallos de persistencia JSON, streams de audio y operaciones de archivo sin acoplar la capa de dominio a Flutter.
  - Reduccion de ruido en el arbol de codigo al eliminar modulos muertos.
  - Compuerta de QA reproducible y cuantitativa previa al lanzamiento oficial `v1.0.0`.
- **Negativas / Riesgos:**
  - Requiere mantener actualizada la referencia de pruebas en `README.md` y `release_notes_v1.0.0.md` en cada hito de release.
