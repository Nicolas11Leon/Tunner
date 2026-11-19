# ADR 0115: Blindaje de Seguridad en Sistema de Archivos, Formato Canonico .tunner y Persistencia Resiliente

- **Estado:** Aceptado
- **Fecha:** 2026-11-19
- **Autor:** Equipo de Arquitectura Tunner
- **Fase Asociada:** Pre-v1.0.0 Feature Hardening (Ola 1)
- **Issue:** #78

## Contexto
Durante la auditoria forense pre-v1.0.0 (`PLAN-PRE-V1-FEATURE-HARDENING-2026-002`) se detectaron vulnerabilidades de severidad S0 y defectos de persistencia que ponian en riesgo la integridad de los datos de los usuarios:
1. `LocalDiskStudioFileSystemRepository` utilizaba una comparacion errada de ID para la raiz (`_activeFolderId = 'root'` vs `folder_hash`), lo que permitia la eliminacion recursiva de todo el directorio `TunnerProjects`. Ademas, no validaba secuencias de Path Traversal (`..` o separadores de ruta en nombres de archivo) ni actualizaba recursivamente las rutas relativas de nodos hijos al mover o renombrar carpetas.
2. Multiples vistas y servicios utilizaban rutas POSIX `/tmp/` hardcodeadas (`rack_unit_card.dart`, `multitask_master_console_widget.dart`, `tuner_viewmodel_recorder_part.dart`, `StemExportPersistenceService`), lo que fallaba en entornos Windows y exponia la aplicacion a Path Traversal mediante nombres no sanitizados.
3. El formato de contenedor `.tunner` sufria de dualidad de implementaciones (un codec binario `TUNP` y un codec basado en ZIP en `TunnerPackageCodecService`). El exportador ZIP unicamente almacenaba metadatos basicos (`{title, composer, bpm}`), omitiendo compases, notas, pistas (`tracks`), sesion de DJ y del rack modular. A su vez, el descompresor carecia de validacion anti-Zip-Slip, limites contra Zip Bombs y saltaba la verificacion SHA-256 cuando `fileHashes` venia vacio.
4. `AppUserSettingsEntity` utilizaba `.take(50)` en una lista que se anade al final, descartando todas las sesiones posteriores a la 50. Asimismo, si un unico elemento del historial fallaba al deserializarse, se descartaba la totalidad del archivo de configuraciones.
5. `SongPackage.toMap()` y `fromMap()` no serializaban la lista de `tracks`, perdiendo los tallos de audio en cada reinicio. Ademas, `DjConsoleBlueprintStorageService` y `DjKeymapPersistenceService` conservaban los esquemas solo en memoria volatil.

## Decision
1. **Proteccion de Raiz y Sandbox de Archivos:**
   - Estandarizar la raiz del arbol de archivos de proyecto bajo el identificador inmutable `'root'`.
   - Prohibir explicitamente la eliminacion o renombrado del nodo raiz en `LocalDiskStudioFileSystemRepository` y `StudioWorkspaceFileSystemService`.
   - Implementar sanitizacion estricta contra Path Traversal, rechazando cualquier nombre que contenga `..`, separadores `/` o `\`, o caracteres de control.
   - Normalizar los separadores de ruta a formato canónico `/` y actualizar recursivamente los nodos descendientes cuando una carpeta es renombrada o movida.
2. **Erradicacion de `/tmp/` Hardcodeado:**
   - Reemplazar todas las rutas literales `/tmp/` por llamadas a traves del contrato abstracto `IPlatformFileGateway` o `path_provider` provisto por el Composition Root.
   - Sanitizar los nombres de archivo generados para exportacion de stems, grabaciones de afinador y consola modular.
3. **Formato Canónico `.tunner` Unificado y Blindado:**
   - Consolidar `TunnerPackageCodecService` como el estandar unificado de empaquetado comprimido con manifiesto JSON y activos PCM/WAV/SF2.
   - Serializar el arbol completo de partitura (`scoreJson`), arreglo de compases y notas, lista de `tracks` con sus propiedades, `timeSignature`, estado de consola DJ y rack modular.
   - Implementar validacion obligatoria de integridad SHA-256 (rechazando paquetes sin hash o con discrepancias).
   - Bloquear ataques de Zip Slip (validando que cada entrada descomprimida permanezca dentro del directorio destino canónico) y limitar el tamano total descomprimido a 250 MB (prevencion de Zip Bomb).
4. **Persistencia Resiliente de Usuario y Proyectos:**
   - Modificar `AppUserSettingsEntity` para conservar las 50 sesiones mas recientes utilizando `sublist(math.max(0, length - 50))`.
   - Implementar deserializacion elemento por elemento con manejo de excepciones granular en `fromMap`, de modo que un registro corrupto no destruya el resto de las preferencias.
   - Asegurar la serializacion y deserializacion simetrica de `tracks` en `SongPackage`.
   - Persistir en disco los blueprints y mapeos de DJ a traves de `IKeyValueStorage` o el repositorio local correspondiente.

## Consecuencias
- **Positivas:**
  - Se garantiza que los proyectos del usuario jamas se eliminaran accidentalmente por un fallo de seleccion de raiz.
  - La aplicacion es inmune a ataques de Path Traversal, Zip Slip y Zip Bomb a traves de archivos de proyecto o importacion de terceros.
  - Los archivos `.tunner` son completamente independientes, portables y reproducibles, preservando el estado integral del estudio.
  - El historial de afinacion y las configuraciones de usuario sobreviven de forma robusta a sesiones prolongadas y posibles corrupciones puntuales.
  - Compatibilidad total multiplataforma en rutas de exportacion temporal (Windows, Linux, macOS, Android, iOS).
- **Negativas / Compromisos:**
  - Los paquetes `.tunner` generados seran ligeramente mayores en tamano debido a la inclusion exhaustiva de la estructura de partitura y pistas, mitigado por compresion deflate nativa.
