# ADR 0119: Endurecimiento Pre-v1.0.0 de Clean Architecture, Inversión de Dependencias (DIP) y Descomposición Modular

## Estado
Aceptado

## Contexto
Durante la auditoría forense integral previa al lanzamiento de la versión 1.0.0 de Tunner (`PLAN-PRE-V1-FEATURE-HARDENING-2026-002`), se detectaron varias inconsistencias arquitectónicas acumuladas durante el desarrollo de prototipos rápidos:
1. **Acoplamiento de Presentación a Datos/Infraestructura:** Ciertos modales y widgets de presentación importaban clases concretas de `data/` (`SongDecomposerService`, `ProceduralInstrumentSynthesizer`, `DjHardwareCatalog`, `HarmonicReferenceSynth`, `LocalProjectStorageRepository`) en lugar de interactuar mediante contratos o especificaciones de dominio.
2. **I/O Crudo en Widgets de UI:** En `MediaVaultWorkspaceModal`, `DjTrackLoaderModal`, `RackUnitCard` y `MultitaskMasterConsoleWidget`, se detectaron importaciones de `dart:io`, `package:file_picker` y `package:path_provider` directamente en widgets de Flutter para abrir selectores de archivos y escribir bytes en disco, violando la separación de capas de Clean Architecture.
3. **Bloques `catch (_)` Silenciosos y Logs no Estructurados:** Se encontraron bloques vacíos `catch (_) {}` que ocultaban excepciones de deserialización y persistencia, además del uso directo de `debugPrint` en lugar del puerto formal de logging `IStudioLogger`.

## Decisión
1. **Reubicación de Catálogos y Motores Procedurales Puros a Dominio:**
   - Mover o definir contratos en `domain/` para catálogos puros (`DjHardwareCatalog` a `lib/features/dj_console/domain/`, `ProceduralInstrumentSynthesizer` a `lib/features/instrument/domain/`, `HarmonicReferenceSynth` a `lib/features/harmonic_tutor/domain/`, `ISongDecomposerService` / plantillas a `lib/features/song_library/domain/`).
   - Mantener re-exports en las rutas históricas de `data/` para garantizar retrocompatibilidad total sin romper imports existentes.
2. **Encapsulación de I/O en Puertos de Dominio y ViewModels:**
   - Desacoplar la selección y guardado de archivos en `MediaVault` y `ModularRack` mediante `IPlatformFileGateway` y los métodos correspondientes en sus ViewModels (`importFromPicker`, `exportTimelineAndSave`), eliminando las importaciones de `dart:io`, `file_picker` y `path_provider` de la capa de presentación.
3. **Erradicación de Bloques de Captura Vacíos y Centralización en `IStudioLogger`:**
   - Reemplazar todo bloque de captura vacío por manejo defensivo documentado y registro estructurado vía `StudioDebugLogger.instance.warning(...)` o `error(...)`.
   - Migrar llamadas de diagnóstico a `IStudioLogger`.

## Consecuencias
### Positivas
- Estricta pureza de la capa de presentación: los widgets solo renderizan interfaces de usuario y delegan toda la lógica y el acceso a recursos a ViewModels y entidades de dominio.
- Eliminación de dependencias de plataforma en la UI, facilitando pruebas unitarias de widgets sin necesidad de emular canales de plataforma de plugins externos.
- Total trazabilidad de advertencias y errores en tiempo de depuración mediante logging estructurado y tipado.

### Negativas / Mitigaciones
- Reubicación de archivos requiere verificación exhaustiva de rutas relativas y absolutas para evitar rotura de enlaces o dependencias en pruebas automatizadas.
