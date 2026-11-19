# Plan de Implementacion: Ola 1 - Seguridad, Archivos y Persistencia Critica

- **ID del Plan:** `PLAN-PRE-V1-WAVE1-SEC-2026-001`
- **Titulo de la Implementacion:** Blindaje de Disco, Formato .tunner Unificado y Resiliencia de Persistencia
- **Fase del Proyecto:** Pre-v1.0.0 Feature Hardening (Ola 1)
- **Estado:** Aprobado
- **ADR Relacionado:** [0115_pre_v1_security_filesystem_and_persistence_hardening.md](../04_adrs/0115_pre_v1_security_filesystem_and_persistence_hardening.md)
- **Documento Funcional Base:** [126_uc_pre_v1_security_filesystem_and_persistence_hardening.md](../02_use_cases/126_uc_pre_v1_security_filesystem_and_persistence_hardening.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Resolver de manera integral y definitiva los hallazgos de severidad S0 identificados en el plan de auditoria forense pre-v1.0.0 (`F-19, F-21, F-28, F-29, F-31, F-33, F-34, F-38`), garantizando la proteccion de los archivos del usuario, eliminando rutas temporales inseguras, consolidando el formato canonico `.tunner` y asegurando la persistencia de configuraciones, sesiones y pistas.

### 1.2 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `lib/features/studio/data/local_disk_studio_file_system_repository.dart`
  - `lib/features/studio/application/studio_workspace_file_system_service.dart`
  - `lib/features/package_format/data/tunner_package_codec_service.dart`
  - `lib/features/settings/domain/entities/app_user_settings_entity.dart`
  - `lib/features/settings/data/json_local_persistence_service.dart`
  - `lib/features/decomposer/domain/models/song_package.dart`
  - `lib/features/dj/data/dj_console_blueprint_storage_service.dart`
  - `lib/features/dj/data/dj_keymap_persistence_service.dart`
  - `lib/features/stems/infrastructure/stem_export_persistence_service.dart`
  - `lib/features/rack/presentation/rack_unit_card.dart`
  - `lib/features/rack/presentation/multitask_master_console_widget.dart`
  - `lib/tuner/presentation/tuner_viewmodel_recorder_part.dart`
  - Pruebas unitarias en `test/features/` correspondientes a cada componente modificado.
- **Excluido (Out-of-Scope):**
  - Unificacion de inyeccion de dependencias y cadena Master DSP (reservado para Ola 2).
  - Motores de sintesis y Auto-Tune (reservado para Ola 3).
  - Parsers de notacion y modales de UI (reservados para Ola 4).

---

## 2. Analisis de Dependencias y Tecnologias

- **Dart SDK:** `^3.11.5`.
- **Flutter SDK:** Canal stable oficial.
- **Librerias:** `crypto` (calculo de SHA-256), `archive` (formato ZIP), sin dependencias externas adicionales.
- **Riesgo Tecnologico:** Cero riesgo de incompatibilidad; las modificaciones fortalecen las garantias de seguridad y resiliencia en tiempo de ejecucion.

---

## 3. Plan Paso a Paso de Ejecucion

### Paso 1: Blindaje del Repositorio de Archivos y Servicios del Workspace (F-31)
1. Normalizar el manejo de `folderId` en `LocalDiskStudioFileSystemRepository` y `StudioWorkspaceFileSystemService`:
   - El nodo raiz se identifica de manera constante e inmutable con `'root'`.
   - Prohibir explicitamente el borrado o renombrado del nodo raiz (`folderId == 'root'`).
   - Validar y sanitizar nombres de carpetas y archivos rechazando secuencias `..`, caracteres nulos, o separadores `/` y `\`.
   - Normalizar todas las rutas internas a separadores POSIX `/`.
   - Implementar propagacion recursiva del campo `relativePath` sobre todos los nodos hijos al mover o renombrar carpetas.
2. Anadir pruebas unitarias en `test/features/studio/local_disk_studio_file_system_repository_test.dart` y `studio_workspace_file_system_service_test.dart`.

### Paso 2: Eliminacion de Rutas Temporales Hardcodeadas `/tmp/` (F-19, F-21, F-29)
1. En `rack_unit_card.dart`, `multitask_master_console_widget.dart`, `tuner_viewmodel_recorder_part.dart` y `StemExportPersistenceService`:
   - Reemplazar cadenas `/tmp/...` literales por la resolucion dinamica del directorio temporal seguro provisto por la plataforma (`getTemporaryDirectory()` o `IPlatformFileGateway.getTemporaryDirectoryPath()`).
   - Sanitizar nombres de archivo para evitar caracteres no permitidos en sistemas Windows o Unix.

### Paso 3: Consolidacion del Formato Canonico `.tunner` y Proteccion de Descompresion (F-33)
1. En `TunnerPackageCodecService`:
   - Asegurar que `exportPackage` serialice completamente el JSON de la partitura (`scoreJson`), la coleccion completa de compases y notas, pistas (`tracks`), armadura y compas (`timeSignature`), sesion de DJ y sesion del rack modular.
   - Implementar calculo estricto de hash SHA-256 para cada recurso empaquetado.
   - En `importPackage`, verificar obligatoriamente la integridad SHA-256 de todas las entradas (rechazando paquetes con `fileHashes` vacio o incongruente).
   - Implementar proteccion contra Zip Slip: verificar que `canonicalPath` de cada entrada descomprimida este estrictamente dentro del directorio destino.
   - Implementar limite de cuota de descompresion (maximo 250 MB total y ratio de expansion maximo 100x) para prevenir ataques Zip Bomb.
2. Anadir pruebas unitarias en `test/features/package_format/tunner_package_codec_service_test.dart`.

### Paso 4: Persistencia Resiliente de Preferencias, Pistas y Blueprints (F-28, F-34, F-38)
1. En `AppUserSettingsEntity`:
   - Cambiar `.take(50)` por `sublist(math.max(0, recentSessions.length - 50))` para preservar las 50 sesiones mas recientes del usuario.
   - En `fromMap()`, envolver la deserializacion de cada sesion en un bloque `try/catch` individual para que un elemento corrupto no invalide el documento completo de preferencias.
   - Asegurar que el valor inicial de `_bpm` se propague adecuadamente al inicializar.
2. En `SongPackage`:
   - Asegurar la inclusion bidireccional del campo `tracks` en `toMap()` y `fromMap()`.
3. En `DjConsoleBlueprintStorageService` y `DjKeymapPersistenceService`:
   - Implementar persistencia real en almacenamiento local en disco (`IKeyValueStorage` o repositorio de archivos local).

### Paso 5: Verificacion y Cierre
1. Ejecutar `flutter analyze --no-fatal-infos` (0 advertencias).
2. Ejecutar la suite completa de pruebas unitarias (`flutter test`).
3. Commit estructurado sin emojis, apertura de PR hacia `qa` con `Closes #78`.

---

## 4. Estrategia de Rollback
- Si se detecta alguna regresion durante la ejecucion de la suite, se revierte al commit base de `qa` (`a7d895d`).

---

## 5. Criterios de Aceptacion (Definition of Done)
- [ ] 0 vulnerabilidades de Path Traversal y 0 posibilidades de borrado de raiz en `LocalDiskStudioFileSystemRepository`.
- [ ] 0 rutas `/tmp/` hardcodeadas.
- [ ] `.tunner` exporta e importa partitura completa, pistas, compas y sesiones con verificacion SHA-256 obligatoria y proteccion Zip Slip/Bomb.
- [ ] `AppUserSettingsEntity` conserva las 50 sesiones mas recientes y no crashea ante elementos corruptos.
- [ ] `SongPackage` persiste y restaura sus `tracks`.
- [ ] 100% de tests pasando y `flutter analyze` en 0 issues.
- [ ] Cero emojis en codigo, commits y documentacion.
